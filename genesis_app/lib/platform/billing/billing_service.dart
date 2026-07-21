import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/models/gem_product.dart';
import '../../network/models/gem_purchase_report.dart';
import 'billing_analytics.dart';
import 'billing_models.dart';
import 'google_play_billing_platform.dart';
import 'pending_purchase_store.dart';

typedef BillingAccountIdLoader = Future<String> Function();
typedef BillingProductCatalogLoader = Future<List<GemProduct>> Function();
typedef BillingPurchaseReporter =
    Future<GemPurchaseReport> Function(GemPurchaseReportRequest request);
typedef BillingWalletRefresher = Future<void> Function();
typedef BillingUidReader = Future<String?> Function();

abstract interface class BillingService {
  ValueListenable<BillingState> get state;

  Stream<BillingUiEvent> get events;

  Future<void> start();

  Future<void> purchaseGem(
    GemProduct product, {
    BillingPurchaseSource source = BillingPurchaseSource.buyGemsPage,
    String payTrackId = '',
  });

  Future<void> recover(BillingRecoverySource source);

  void resetForSession();

  void dispose();
}

class GooglePlayBillingService implements BillingService {
  GooglePlayBillingService({
    required BillingPlatform platform,
    required BillingPendingPurchaseStore pendingPurchaseStore,
    required BillingAccountIdLoader loadBillingAccountId,
    required BillingProductCatalogLoader loadProductCatalog,
    required BillingPurchaseReporter reportPurchase,
    required BillingWalletRefresher refreshWallet,
    required BillingUidReader readUid,
    BillingAnalytics analytics = const GenesisBillingAnalytics(),
    Duration reportTimeout = const Duration(minutes: 1),
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _readUid = readUid,
       _analytics = analytics,
       _reportTimeout = reportTimeout;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingUidReader _readUid;
  final BillingAnalytics _analytics;
  final Duration _reportTimeout;
  final ValueNotifier<BillingState> _state = ValueNotifier<BillingState>(
    BillingState(),
  );
  final StreamController<BillingUiEvent> _events =
      StreamController<BillingUiEvent>.broadcast();
  final Map<String, BillingPurchaseAttempt> _attemptByStoreProductId =
      <String, BillingPurchaseAttempt>{};
  final Map<String, BillingPurchaseAttempt> _attemptByPurchaseToken =
      <String, BillingPurchaseAttempt>{};
  final Set<String> _processingPurchaseKeys = <String>{};
  final Set<String> _completedPurchaseKeys = <String>{};
  final Set<String> _timedOutReportKeys = <String>{};
  final Map<String, Timer> _attemptTimeouts = <String, Timer>{};
  final Map<String, Timer> _reportTimeouts = <String, Timer>{};

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;
  Future<void>? _startFuture;
  Future<void>? _recoverFuture;
  String? _cachedBillingAccountId;
  String? _cachedBillingAccountOwnerUid;
  bool _disposed = false;

  @override
  ValueListenable<BillingState> get state => _state;

  @override
  Stream<BillingUiEvent> get events => _events.stream;

  @override
  Future<void> start() {
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;
    final future = _start();
    _startFuture = future;
    return future;
  }

  Future<void> _start() async {
    _purchaseSubscription ??= _platform.purchaseStream.listen(
      (purchases) => unawaited(
        _handlePurchases(purchases, source: BillingRecoverySource.direct),
      ),
    );

    var available = false;
    try {
      available = await _platform.isAvailable();
    } catch (_) {}
    _setState(storeAvailable: available);
    if (available) {
      await _recoverInternal(BillingRecoverySource.appStart);
    }
  }

  @override
  Future<void> purchaseGem(
    GemProduct product, {
    BillingPurchaseSource source = BillingPurchaseSource.buyGemsPage,
    String payTrackId = '',
  }) async {
    final attemptId = payTrackId.trim().isNotEmpty
        ? payTrackId.trim()
        : newBillingAttemptId();
    final storeProductId = _storeProductIdFor(product, _platform.provider);
    _trackProduct(
      'product_click',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{'source': source.value},
    );
    await start();
    if (_disposed) return;
    if (!product.canPurchase) {
      _trackPrecheckFailure(product, attemptId, 'product_not_purchasable');
      _emitFailure(
        product.productId,
        attemptId,
        'This product is unavailable.',
      );
      return;
    }
    if (storeProductId.trim().isEmpty) {
      _trackPrecheckFailure(product, attemptId, 'store_product_id_missing');
      _emitFailure(
        product.productId,
        attemptId,
        'This product is unavailable.',
      );
      return;
    }
    if (!_state.value.storeAvailable) {
      _trackPrecheckFailure(product, attemptId, 'gp_unavailable');
      _emitFailure(product.productId, attemptId, _storeUnavailableMessage());
      return;
    }
    if (_state.value.hasBusyPurchase) {
      _trackPrecheckFailure(product, attemptId, 'purchase_in_progress');
      return;
    }
    if (billingProductKindFrom(product.billingType) !=
        BillingProductKind.consumable) {
      _trackPrecheckFailure(product, attemptId, 'unsupported_product_type');
      _emitFailure(
        product.productId,
        attemptId,
        'This product type is not supported.',
      );
      return;
    }

    final startedAt = DateTime.now();
    _setBusy(product.productId, true);

    late final String billingAccountId;
    try {
      billingAccountId = await _resolveBillingAccountId();
    } catch (_) {
      _trackPrecheckFailure(product, attemptId, 'uuid_unavailable');
      _emitFailure(product.productId, attemptId, 'Purchase failed.');
      return;
    }
    if (billingAccountId.isEmpty) {
      _trackPrecheckFailure(product, attemptId, 'uuid_unavailable');
      _emitFailure(product.productId, attemptId, 'Purchase failed.');
      return;
    }
    final attempt = BillingPurchaseAttempt(
      id: attemptId,
      product: product,
      billingAccountId: billingAccountId,
      source: BillingRecoverySource.direct,
      startedAt: startedAt,
    );
    _attemptByStoreProductId[storeProductId] = attempt;

    late final BillingProductQueryResult queryResult;
    try {
      final googlePurchaseOptionId = product.googlePurchaseOptionId.trim();
      final googleOfferId = product.googleOfferId.trim();
      final shouldUseGoogleOffer =
          _platform.provider == BillingProvider.googlePlay &&
          googlePurchaseOptionId.isNotEmpty &&
          googleOfferId.isNotEmpty;
      queryResult = await _platform.queryProduct(
        storeProductId,
        BillingStoreProductType.inApp,
        purchaseOptionId: shouldUseGoogleOffer ? googlePurchaseOptionId : null,
        offerId: shouldUseGoogleOffer ? googleOfferId : null,
      );
    } catch (error) {
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(product, attemptId, 'query_failed');
      return;
    }
    if (!queryResult.isSuccess) {
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _productQueryFailureMessage(queryResult.errorCode),
      );
      _trackFlowResult(product, attemptId, 'query_failed');
      return;
    }

    final storeProduct = queryResult.product!;
    try {
      final accepted = await _platform.buyConsumable(
        product: storeProduct,
        billingAccountId: billingAccountId,
      );
      if (!accepted) {
        _clearActiveAttempt(storeProductId, attempt);
        _emitFailure(product.productId, attemptId, 'Purchase failed.');
        _trackFlowResult(product, attemptId, 'launch_rejected');
      } else {
        _scheduleAttemptTimeout(product, storeProductId, attemptId);
      }
    } catch (error) {
      debugPrint('[Billing] purchase launch failed: $error');
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(product, attemptId, 'launch_failed');
    }
  }

  @override
  Future<void> recover(BillingRecoverySource source) async {
    await start();
    if (_disposed || !_state.value.storeAvailable) return;
    final inFlight = _recoverFuture;
    if (inFlight != null) return inFlight;
    final future = _recoverInternal(source);
    _recoverFuture = future.whenComplete(() => _recoverFuture = null);
    return _recoverFuture!;
  }

  Future<void> _recoverInternal(BillingRecoverySource source) async {
    String uid;
    try {
      uid = (await _readUid())?.trim() ?? '';
    } catch (_) {
      return;
    }
    if (uid.isEmpty || uid.startsWith('guest_')) {
      return;
    }
    String billingAccountId;
    try {
      billingAccountId = await _resolveBillingAccountId();
    } catch (_) {
      return;
    }
    if (billingAccountId.isEmpty) {
      return;
    }

    final pastPurchaseKeys = <String>{};
    final reportedStoreProductIds = <String>{};
    var pastPurchaseQuerySucceeded = false;
    try {
      final purchases = await _platform.queryPastPurchases(
        billingAccountId: billingAccountId,
      );
      pastPurchaseQuerySucceeded = true;
      for (final purchase in purchases) {
        if (purchase.productId.trim().isNotEmpty) {
          reportedStoreProductIds.add(purchase.productId.trim());
        }
        if (purchase.purchaseToken.trim().isNotEmpty) {
          pastPurchaseKeys.add(
            '${purchase.provider.name}:${purchase.purchaseToken.trim()}',
          );
        }
      }
      await _handlePurchases(purchases, source: source);
    } catch (_) {}

    // A native Play error dialog can be dismissed without emitting a
    // PurchaseDetails error/cancelled callback. A successful empty query is
    // the authoritative signal that this checkout did not create an order.
    if (_platform.provider == BillingProvider.googlePlay &&
        pastPurchaseQuerySucceeded &&
        _processingPurchaseKeys.isEmpty) {
      final activeAttempts = _attemptByStoreProductId.entries.toList(
        growable: false,
      );
      for (final entry in activeAttempts) {
        if (reportedStoreProductIds.contains(entry.key)) continue;
        _clearActiveAttempt(entry.key, entry.value);
      }
    }

    List<BillingPendingPurchase> records;
    try {
      records = await _pendingPurchaseStore.loadAll();
    } catch (_) {
      return;
    }
    for (final record in records) {
      if (record.provider != _platform.provider ||
          record.billingAccountId != billingAccountId) {
        continue;
      }
      if (record.status == BillingPendingPurchaseStatus.reported) {
        if (_platform.provider == BillingProvider.googlePlay &&
            pastPurchaseQuerySucceeded &&
            !pastPurchaseKeys.contains(record.key)) {
          try {
            await _pendingPurchaseStore.remove(
              provider: record.provider,
              purchaseToken: record.purchaseToken,
            );
          } catch (_) {}
        }
        continue;
      }
      if (pastPurchaseKeys.contains(record.key)) {
        continue;
      }
      await _processRecord(record, source: source);
    }
  }

  Future<void> _handlePurchases(
    List<BillingPurchase> purchases, {
    required BillingRecoverySource source,
  }) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase, source: source);
    }
  }

  Future<void> _handlePurchase(
    BillingPurchase purchase, {
    required BillingRecoverySource source,
  }) async {
    final token = purchase.purchaseToken.trim();
    final attempt =
        _attemptByPurchaseToken[token] ??
        _attemptByStoreProductId[purchase.productId] ??
        _onlyActiveAttemptForStoreError(purchase);
    final attemptId = attempt?.id ?? newBillingAttemptId();
    final productId = attempt?.product.productId ?? purchase.productId;
    _cancelAttemptTimeout(
      attempt == null
          ? purchase.productId
          : _storeProductIdFor(attempt.product, purchase.provider),
    );

    switch (purchase.status) {
      case BillingPurchaseStatus.pending:
        if (token.isNotEmpty && attempt != null) {
          _attemptByPurchaseToken[token] = attempt;
        }
        _setBusy(productId, false);
        _trackFailedById(
          attemptId: attemptId,
          productId: productId,
          storeProductId: purchase.productId,
          reason: 'purchase_callback_pending',
        );
        _events.add(
          BillingUiEvent(
            kind: BillingUiEventKind.pending,
            productId: productId,
            attemptId: attemptId,
            message: 'Payment is pending.',
          ),
        );
        return;
      case BillingPurchaseStatus.canceled:
        _clearAttempt(purchase, attempt);
        _events.add(
          BillingUiEvent(
            kind: BillingUiEventKind.failure,
            productId: productId,
            attemptId: attemptId,
            message: 'Purchase cancelled.',
          ),
        );
        _trackFlowResultById(
          attemptId: attemptId,
          productId: productId,
          storeProductId: purchase.productId,
          status: 'canceled',
          source: source,
        );
        return;
      case BillingPurchaseStatus.error:
        _clearAttempt(purchase, attempt);
        _emitFailure(
          productId,
          attemptId,
          _purchaseDetailsFailureMessage(purchase),
        );
        _trackFlowResultById(
          attemptId: attemptId,
          productId: productId,
          storeProductId: purchase.productId,
          status: 'store_failed',
          source: source,
          errorCode: purchase.errorCode?.trim().isNotEmpty == true
              ? purchase.errorCode!.trim()
              : 'store_error',
        );
        return;
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        break;
    }

    if (token.isEmpty) {
      _clearAttempt(purchase, attempt);
      _emitFailure(productId, attemptId, 'Purchase failed.');
      _trackFlowResultById(
        attemptId: attemptId,
        productId: productId,
        storeProductId: purchase.productId,
        status: 'store_failed',
        source: source,
        errorCode: purchase.provider == BillingProvider.appStore
            ? 'store_error'
            : 'purchase_token_missing',
      );
      return;
    }
    if (attempt != null) _attemptByPurchaseToken[token] = attempt;

    final processingKey = '${purchase.provider.name}:$token';
    if (_completedPurchaseKeys.contains(processingKey)) {
      return;
    }
    if (!_processingPurchaseKeys.add(processingKey)) {
      return;
    }
    final suppressUiForTimedOutReport = _timedOutReportKeys.contains(
      processingKey,
    );
    if (!suppressUiForTimedOutReport) {
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.processing,
          productId: productId,
          attemptId: attemptId,
          message: 'Purchasing Gems',
        ),
      );
      _scheduleReportTimeout(
        purchaseKey: processingKey,
        productId: productId,
        attemptId: attemptId,
        storeProductId: purchase.productId,
        purchase: purchase,
        source: source,
      );
    }
    try {
      BillingPendingPurchase? record;
      try {
        record = await _pendingPurchaseStore.find(
          provider: purchase.provider,
          purchaseToken: token,
        );
      } catch (_) {
        _cancelReportTimeout(processingKey);
        if (suppressUiForTimedOutReport) {
          _setBusy(productId, false);
          return;
        }
        _emitDeferred(productId, attemptId);
        return;
      }
      if (record == null) {
        final resolvedAttempt =
            attempt ??
            await _recoveredAttemptFor(
              purchase,
              source: source,
              fallbackAttemptId: attemptId,
            );
        if (resolvedAttempt == null) {
          return;
        }
        final now = DateTime.now();
        record = BillingPendingPurchase(
          provider: purchase.provider,
          purchaseToken: token,
          attemptId: resolvedAttempt.id,
          billingAccountId: resolvedAttempt.billingAccountId,
          productId: resolvedAttempt.product.productId,
          storeProductId: purchase.productId,
          transactionId: purchase.transactionId,
          originalJson: purchase.originalJson,
          purchaseTime: purchase.purchaseTime,
          status: BillingPendingPurchaseStatus.received,
          retryCount: 0,
          createdAt: now,
          updatedAt: now,
        );
        try {
          await _pendingPurchaseStore.upsert(record);
        } catch (_) {
          _cancelReportTimeout(processingKey);
          if (suppressUiForTimedOutReport) {
            _setBusy(resolvedAttempt.product.productId, false);
            return;
          }
          _emitDeferred(resolvedAttempt.product.productId, resolvedAttempt.id);
          return;
        }
      }
      await _processRecord(record, purchase: purchase, source: source);
    } finally {
      _processingPurchaseKeys.remove(processingKey);
    }
  }

  Future<BillingPurchaseAttempt?> _recoveredAttemptFor(
    BillingPurchase purchase, {
    required BillingRecoverySource source,
    required String fallbackAttemptId,
  }) async {
    String accountId;
    try {
      accountId = await _resolveBillingAccountId();
    } catch (_) {
      return null;
    }
    if (accountId.isEmpty) return null;
    try {
      final products = await _loadProductCatalog();
      final product = products.cast<GemProduct?>().firstWhere(
        (candidate) =>
            candidate != null &&
            _storeProductIdFor(candidate, purchase.provider) ==
                purchase.productId,
        orElse: () => null,
      );
      if (product == null ||
          billingProductKindFrom(product.billingType) !=
              BillingProductKind.consumable) {
        return null;
      }
      return BillingPurchaseAttempt(
        id: fallbackAttemptId,
        product: product,
        billingAccountId: accountId,
        source: source,
        startedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _processRecord(
    BillingPendingPurchase record, {
    BillingPurchase? purchase,
    required BillingRecoverySource source,
  }) async {
    String accountId;
    try {
      accountId = await _resolveBillingAccountId();
    } catch (_) {
      return;
    }
    if (accountId.isEmpty || accountId != record.billingAccountId) return;

    if (record.status == BillingPendingPurchaseStatus.reported) {
      await _completeAppStorePurchase(purchase);
      _completedPurchaseKeys.add(record.key);
      _cancelReportTimeout(record.key);
      _timedOutReportKeys.remove(record.key);
      if (purchase != null) {
        _clearAttempt(purchase, _attemptByPurchaseToken[record.purchaseToken]);
      } else {
        _setBusy(record.productId, false);
      }
      return;
    }

    late final GemPurchaseReport report;
    try {
      report = await _reportPurchase(
        GemPurchaseReportRequest(
          provider: record.provider.apiValue,
          productId: record.productId,
          storeProductId: record.storeProductId,
          transactionId: record.transactionId,
          purchaseToken: record.provider == BillingProvider.googlePlay
              ? record.purchaseToken
              : null,
          requestId: record.attemptId,
          payload: <String, Object?>{
            'purchase_time': record.purchaseTime,
            if (record.provider == BillingProvider.googlePlay)
              'original_json': record.originalJson,
          },
        ),
      );
    } catch (_) {
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(next);
      } catch (_) {}
      if (_timedOutReportKeys.contains(record.key)) {
        _setBusy(record.productId, false);
        return;
      }
      _cancelReportTimeout(record.key);
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
      _trackFlowResultById(
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        status: 'report_deferred',
        source: source,
      );
      return;
    }

    final reported = record.copyWith(
      status: BillingPendingPurchaseStatus.reported,
      updatedAt: DateTime.now(),
    );
    try {
      await _pendingPurchaseStore.upsert(reported);
    } catch (_) {
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(next);
      } catch (_) {}
      if (_timedOutReportKeys.contains(record.key)) {
        _setBusy(record.productId, false);
        return;
      }
      _cancelReportTimeout(record.key);
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
      _trackFlowResultById(
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        status: 'report_deferred',
        source: source,
        errorCode: 'local_mark_reported_failed',
      );
      return;
    }

    await _completeAppStorePurchase(purchase);
    _completedPurchaseKeys.add(record.key);
    final reportTimedOut = _timedOutReportKeys.remove(record.key);
    _cancelReportTimeout(record.key);
    if (purchase != null) {
      _clearAttempt(purchase, _attemptByPurchaseToken[record.purchaseToken]);
    } else {
      _setBusy(record.productId, false);
    }

    if (report.status == GemPurchaseReportStatus.completed) {
      _track(
        'purchase_success',
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        data: <String, Object?>{'transaction_id': record.transactionId},
      );
      try {
        await _refreshWallet();
      } catch (_) {}
      if (reportTimedOut) return;
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.success,
          productId: record.productId,
          attemptId: record.attemptId,
          message: 'Purchase successful!',
          grantedGems: report.grantedGems,
        ),
      );
    } else if (report.status == GemPurchaseReportStatus.accepted) {
      if (reportTimedOut) return;
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.accepted,
          productId: record.productId,
          attemptId: record.attemptId,
          message:
              'Payment received.\nYour Gems will be added shortly. Please check your balance again in a moment.',
        ),
      );
    } else {
      if (reportTimedOut) return;
      _emitFailure(
        record.productId,
        record.attemptId,
        'Purchase was refunded.',
      );
    }
    _trackFlowResultById(
      attemptId: record.attemptId,
      productId: record.productId,
      storeProductId: record.storeProductId,
      status: report.status.name,
      source: source,
    );
  }

  Future<void> _completeAppStorePurchase(BillingPurchase? purchase) async {
    if (purchase == null || purchase.provider != BillingProvider.appStore) {
      return;
    }
    try {
      await _platform.completePurchase(purchase);
    } catch (error) {
      // Server fulfillment is already durable; retry StoreKit finalization on
      // the next callback/app start instead of reporting the purchase again.
      debugPrint('[Billing][AppStore] purchase completion failed: $error');
    }
  }

  Future<String> _resolveBillingAccountId() async {
    final uid = (await _readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return '';
    if (_cachedBillingAccountOwnerUid == uid &&
        (_cachedBillingAccountId ?? '').isNotEmpty) {
      return _cachedBillingAccountId!;
    }
    final accountId = (await _loadBillingAccountId()).trim();
    if (accountId.isEmpty) return '';
    _cachedBillingAccountOwnerUid = uid;
    _cachedBillingAccountId = accountId;
    return accountId;
  }

  String _storeProductIdFor(GemProduct product, BillingProvider provider) {
    return switch (provider) {
      BillingProvider.googlePlay => product.googleProductId.trim(),
      BillingProvider.appStore => product.appleProductId.trim(),
    };
  }

  String _storeUnavailableMessage() {
    return switch (_platform.provider) {
      BillingProvider.googlePlay => 'Google Play is unavailable.',
      BillingProvider.appStore => 'Payment service is unavailable.',
    };
  }

  void _clearAttempt(
    BillingPurchase purchase,
    BillingPurchaseAttempt? attempt,
  ) {
    final activeAttempt =
        attempt ?? _attemptByStoreProductId[purchase.productId];
    if (activeAttempt != null) {
      _clearActiveAttempt(
        _storeProductIdFor(activeAttempt.product, purchase.provider),
        activeAttempt,
      );
    } else {
      _cancelAttemptTimeout(purchase.productId);
      _attemptByStoreProductId.remove(purchase.productId);
    }
    if (purchase.purchaseToken.isNotEmpty) {
      _attemptByPurchaseToken.remove(purchase.purchaseToken);
    }
  }

  BillingPurchaseAttempt? _onlyActiveAttemptForStoreError(
    BillingPurchase purchase,
  ) {
    if (purchase.productId.trim().isNotEmpty ||
        _attemptByStoreProductId.length != 1) {
      return null;
    }
    return _attemptByStoreProductId.values.single;
  }

  void _clearActiveAttempt(
    String storeProductId,
    BillingPurchaseAttempt attempt,
  ) {
    final current = _attemptByStoreProductId[storeProductId];
    if (current?.id == attempt.id) {
      _attemptByStoreProductId.remove(storeProductId);
    }
    _cancelAttemptTimeout(storeProductId);
    _attemptByPurchaseToken.removeWhere(
      (_, candidate) => candidate.id == attempt.id,
    );
    _setBusy(attempt.product.productId, false);
  }

  void _emitFailure(String productId, String attemptId, String message) {
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.failure,
        productId: productId,
        attemptId: attemptId,
        message: message,
      ),
    );
    _setBusy(productId, false);
  }

  void _emitDeferred(String productId, String attemptId) {
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.deferred,
        productId: productId,
        attemptId: attemptId,
        message: 'Payment is being confirmed.',
      ),
    );
  }

  void _scheduleReportTimeout({
    required String purchaseKey,
    required String productId,
    required String attemptId,
    required String storeProductId,
    required BillingPurchase purchase,
    required BillingRecoverySource source,
  }) {
    _cancelReportTimeout(purchaseKey);
    if (_reportTimeout <= Duration.zero) return;
    _reportTimeouts[purchaseKey] = Timer(_reportTimeout, () {
      _reportTimeouts.remove(purchaseKey);
      if (_disposed ||
          _completedPurchaseKeys.contains(purchaseKey) ||
          _timedOutReportKeys.contains(purchaseKey) ||
          !_processingPurchaseKeys.contains(purchaseKey)) {
        return;
      }
      _timedOutReportKeys.add(purchaseKey);
      _trackFlowResultById(
        attemptId: attemptId,
        productId: productId,
        storeProductId: storeProductId,
        status: 'report_timeout',
        source: source,
      );
      _clearAttempt(purchase, _attemptByPurchaseToken[purchase.purchaseToken]);
      _setBusy(productId, false);
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.failure,
          productId: productId,
          attemptId: attemptId,
          message: 'purchase timeout',
        ),
      );
    });
  }

  void _cancelReportTimeout(String purchaseKey) {
    _reportTimeouts.remove(purchaseKey)?.cancel();
  }

  void _scheduleAttemptTimeout(
    GemProduct product,
    String storeProductId,
    String attemptId,
  ) {
    _cancelAttemptTimeout(storeProductId);
    _attemptTimeouts[storeProductId] = Timer(const Duration(seconds: 90), () {
      _attemptTimeouts.remove(storeProductId);
      final activeAttempt = _attemptByStoreProductId[storeProductId];
      if (activeAttempt?.id != attemptId) return;
      _trackFlowResult(product, attemptId, 'timeout');
      _clearActiveAttempt(storeProductId, activeAttempt!);
    });
  }

  void _cancelAttemptTimeout(String storeProductId) {
    _attemptTimeouts.remove(storeProductId)?.cancel();
  }

  void _setBusy(String productId, bool busy) {
    if (_disposed || productId.isEmpty) return;
    final next = <String>{..._state.value.busyProductIds};
    if (busy) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    _setState(busyProductIds: next);
  }

  void _setState({bool? storeAvailable, Set<String>? busyProductIds}) {
    if (_disposed) return;
    _state.value = BillingState(
      storeAvailable: storeAvailable ?? _state.value.storeAvailable,
      busyProductIds: busyProductIds ?? _state.value.busyProductIds,
    );
  }

  String _purchaseFailureMessage(Object error) {
    if (error is BillingPlatformException && error.code.isNotEmpty) {
      return 'Purchase failed (${error.code}).';
    }
    return 'Purchase failed.';
  }

  String _productQueryFailureMessage(String? errorCode) {
    final code = errorCode?.trim() ?? '';
    if (code.isNotEmpty) return 'Purchase failed ($code).';
    return 'This product is currently unavailable.';
  }

  String _purchaseDetailsFailureMessage(BillingPurchase purchase) {
    final code = purchase.errorCode?.trim() ?? '';
    final detail = purchase.errorMessage?.trim() ?? '';
    if (detail.isNotEmpty && code.isNotEmpty) {
      return 'Purchase failed ($code: $detail).';
    }
    if (detail.isNotEmpty) return 'Purchase failed ($detail).';
    if (code.isNotEmpty) return 'Purchase failed ($code).';
    return 'Purchase failed.';
  }

  void _track(
    String action, {
    String attemptId = '',
    String productId = '',
    String storeProductId = '',
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    try {
      _analytics.track(
        action,
        properties: <String, Object?>{
          'attempt_id': attemptId,
          'product_id': productId,
          'store_product_id': storeProductId,
          ...data,
        },
      );
    } catch (_) {
      // A custom analytics sink must not be able to break billing.
    }
  }

  void _trackProduct(
    String action, {
    required GemProduct product,
    required String attemptId,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    _track(
      action,
      attemptId: attemptId,
      productId: product.productId,
      storeProductId: _storeProductIdFor(product, _platform.provider),
      data: <String, Object?>{
        'provider': _platform.provider.apiValue,
        'trigger': BillingRecoverySource.direct.value,
        ...data,
      },
    );
  }

  void _trackPrecheckFailure(
    GemProduct product,
    String attemptId,
    String errorCode,
  ) {
    _trackFlowResult(
      product,
      attemptId,
      'precheck_failed',
      errorCode: errorCode,
    );
  }

  void _trackFlowResult(
    GemProduct product,
    String attemptId,
    String status, {
    String? errorCode,
  }) {
    _trackFlowResultById(
      attemptId: attemptId,
      productId: product.productId,
      storeProductId: _storeProductIdFor(product, _platform.provider),
      status: status,
      source: BillingRecoverySource.direct,
      errorCode: errorCode,
    );
  }

  void _trackFlowResultById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String status,
    required BillingRecoverySource source,
    String? errorCode,
  }) {
    final failedReason = _failedReasonForFlowResult(
      status: status,
      errorCode: errorCode,
    );
    if (failedReason != null) {
      _trackFailedById(
        attemptId: attemptId,
        productId: productId,
        storeProductId: storeProductId,
        reason: failedReason,
      );
    }
  }

  void _trackFailedById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String reason,
  }) {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) return;
    _track(
      'purchase_failed',
      attemptId: attemptId,
      productId: productId,
      storeProductId: storeProductId,
      data: <String, Object?>{'reason': normalizedReason},
    );
  }

  String? _failedReasonForFlowResult({
    required String status,
    String? errorCode,
  }) {
    return switch (status) {
      'completed' || 'accepted' => null,
      'precheck_failed' => _precheckFailedReason(errorCode),
      'query_failed' => 'query_failed',
      'launch_rejected' || 'launch_failed' => 'launch_failed',
      'canceled' => 'canceled',
      'store_failed' =>
        errorCode == 'purchase_token_missing'
            ? 'purchase_token_missing'
            : 'purchase_callback_error',
      'report_deferred' => 'report_failed',
      'timeout' || 'report_timeout' => 'timeout',
      _ => 'report_rejected',
    };
  }

  String? _precheckFailedReason(String? errorCode) {
    return switch (errorCode) {
      'gp_unavailable' => 'gp_unavailable',
      'uuid_unavailable' => 'uuid_unavailable',
      'product_not_purchasable' => 'product_not_purchasable',
      'store_product_id_missing' => 'store_product_id_missing',
      'purchase_in_progress' => 'purchase_in_progress',
      _ => null,
    };
  }

  @override
  void resetForSession() {
    _cachedBillingAccountId = null;
    _cachedBillingAccountOwnerUid = null;
    _attemptByStoreProductId.clear();
    _attemptByPurchaseToken.clear();
    _completedPurchaseKeys.clear();
    _timedOutReportKeys.clear();
    for (final timeout in _attemptTimeouts.values) {
      timeout.cancel();
    }
    _attemptTimeouts.clear();
    for (final timeout in _reportTimeouts.values) {
      timeout.cancel();
    }
    _reportTimeouts.clear();
    _setState(busyProductIds: const <String>{});
  }

  @override
  void dispose() {
    _disposed = true;
    _purchaseSubscription?.cancel();
    for (final timeout in _attemptTimeouts.values) {
      timeout.cancel();
    }
    _attemptTimeouts.clear();
    for (final timeout in _reportTimeouts.values) {
      timeout.cancel();
    }
    _reportTimeouts.clear();
    _events.close();
    _state.dispose();
  }
}
