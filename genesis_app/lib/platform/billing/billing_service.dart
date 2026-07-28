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
    Duration attemptTimeout = const Duration(seconds: 90),
    Duration reportTimeout = const Duration(minutes: 1),
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _readUid = readUid,
       _analytics = analytics,
       _attemptTimeout = attemptTimeout,
       _reportTimeout = reportTimeout;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingUidReader _readUid;
  final BillingAnalytics _analytics;
  final Duration _attemptTimeout;
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
  final Set<String> _trackedPendingAttemptIds = <String>{};
  final Map<String, Timer> _attemptTimeouts = <String, Timer>{};
  final Map<String, Timer> _reportTimeouts = <String, Timer>{};

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;
  Future<void>? _startFuture;
  Future<void>? _recoverFuture;
  var _sessionGeneration = 0;
  var _lastRecoveredSessionGeneration = -1;
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
    var activeProduct = product;
    var storeProductId = _storeProductIdFor(product, _platform.provider);
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
    var attempt = BillingPurchaseAttempt(
      id: attemptId,
      product: activeProduct,
      billingAccountId: billingAccountId,
      source: BillingRecoverySource.direct,
      startedAt: startedAt,
    );
    _attemptByStoreProductId[storeProductId] = attempt;

    late BillingProductQueryResult queryResult;
    try {
      queryResult = await _queryStoreProduct(activeProduct, storeProductId);
      if (!queryResult.isSuccess &&
          queryResult.errorCode?.trim() == 'product_not_found') {
        final refreshedProduct = await _reloadProduct(product.productId);
        if (refreshedProduct != null &&
            refreshedProduct.canPurchase &&
            billingProductKindFrom(refreshedProduct.billingType) ==
                BillingProductKind.consumable) {
          final refreshedStoreProductId = _storeProductIdFor(
            refreshedProduct,
            _platform.provider,
          );
          if (refreshedStoreProductId.isNotEmpty) {
            if (refreshedStoreProductId != storeProductId) {
              _clearActiveAttempt(storeProductId, attempt);
              activeProduct = refreshedProduct;
              storeProductId = refreshedStoreProductId;
              attempt = BillingPurchaseAttempt(
                id: attemptId,
                product: activeProduct,
                billingAccountId: billingAccountId,
                source: BillingRecoverySource.direct,
                startedAt: startedAt,
              );
              _attemptByStoreProductId[storeProductId] = attempt;
            }
            queryResult = await _queryStoreProduct(
              activeProduct,
              storeProductId,
            );
          }
        }
      }
    } catch (error) {
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        activeProduct.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(
        activeProduct,
        attemptId,
        'query_failed',
        errorCode: _queryFailureErrorCode(error),
      );
      return;
    }
    if (!queryResult.isSuccess) {
      final errorCode = queryResult.errorCode?.trim().isNotEmpty == true
          ? queryResult.errorCode!.trim()
          : 'unknown';
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        activeProduct.productId,
        attemptId,
        _productQueryFailureMessage(queryResult.errorCode),
      );
      _trackFlowResult(
        activeProduct,
        attemptId,
        'query_failed',
        errorCode: errorCode,
      );
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
        _emitFailure(activeProduct.productId, attemptId, 'Purchase failed.');
        _trackFlowResult(activeProduct, attemptId, 'launch_rejected');
      } else {
        _scheduleAttemptTimeout(activeProduct, storeProductId, attemptId);
      }
    } catch (error) {
      debugPrint('[Billing] purchase launch failed: $error');
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        activeProduct.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(activeProduct, attemptId, 'launch_failed');
    }
  }

  Future<BillingProductQueryResult> _queryStoreProduct(
    GemProduct product,
    String storeProductId,
  ) {
    final googlePurchaseOptionId = product.googlePurchaseOptionId.trim();
    final googleOfferId = product.googleOfferId.trim();
    final shouldUseGoogleOffer =
        _platform.provider == BillingProvider.googlePlay &&
        googlePurchaseOptionId.isNotEmpty &&
        googleOfferId.isNotEmpty;
    return _platform.queryProduct(
      storeProductId,
      BillingStoreProductType.inApp,
      purchaseOptionId: shouldUseGoogleOffer ? googlePurchaseOptionId : null,
      offerId: shouldUseGoogleOffer ? googleOfferId : null,
    );
  }

  Future<GemProduct?> _reloadProduct(String productId) async {
    try {
      final products = await _loadProductCatalog();
      for (final product in products) {
        if (product.productId == productId) return product;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<void> recover(BillingRecoverySource source) async {
    await start();
    if (_disposed) return;
    final requestedGeneration = _sessionGeneration;
    while (true) {
      final inFlight = _recoverFuture;
      if (inFlight != null) {
        await inFlight;
        if (_lastRecoveredSessionGeneration >= requestedGeneration) return;
        continue;
      }

      final runGeneration = _sessionGeneration;
      late final Future<void> tracked;
      tracked = _recoverInternal(source, sessionGeneration: runGeneration)
          .whenComplete(() {
            if (_lastRecoveredSessionGeneration < runGeneration) {
              _lastRecoveredSessionGeneration = runGeneration;
            }
            if (identical(_recoverFuture, tracked)) {
              _recoverFuture = null;
            }
          });
      _recoverFuture = tracked;
      await tracked;
      return;
    }
  }

  Future<void> _recoverInternal(
    BillingRecoverySource source, {
    required int sessionGeneration,
  }) async {
    if (_disposed || sessionGeneration != _sessionGeneration) return;
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
    if (billingAccountId.isEmpty ||
        _disposed ||
        sessionGeneration != _sessionGeneration) {
      return;
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
      await _runExclusivePurchase(
        record.key,
        () => _processRecord(record, source: source),
      );
    }
  }

  Future<void> _handlePurchases(
    List<BillingPurchase> purchases, {
    required BillingRecoverySource source,
    String? billingAccountId,
    int? sessionGeneration,
  }) async {
    var currentBillingAccountId = billingAccountId?.trim() ?? '';
    final hasGooglePurchase = purchases.any(
      (purchase) => purchase.provider == BillingProvider.googlePlay,
    );
    if (hasGooglePurchase && currentBillingAccountId.isEmpty) {
      try {
        currentBillingAccountId = await _resolveBillingAccountId();
      } catch (_) {
        return;
      }
    }
    for (final purchase in purchases) {
      if (sessionGeneration != null &&
          sessionGeneration != _sessionGeneration) {
        return;
      }
      await _handlePurchase(
        purchase,
        source: source,
        billingAccountId: currentBillingAccountId,
      );
    }
  }

  Future<void> _handlePurchase(
    BillingPurchase purchase, {
    required BillingRecoverySource source,
    required String billingAccountId,
  }) async {
    final token = purchase.purchaseToken.trim();
    BillingPendingPurchase? persistedRecord;
    var persistedRecordLookupSucceeded = true;
    try {
      persistedRecord = token.isEmpty
          ? null
          : await _findPendingPurchase(
              provider: purchase.provider,
              purchaseToken: token,
            );
    } catch (_) {
      persistedRecordLookupSucceeded = false;
    }
    final attempt = _attemptForPurchase(
      purchase,
      persistedRecord: persistedRecord,
    );
    if (!_purchaseBelongsToBillingAccount(
      purchase,
      attempt,
      billingAccountId,
      persistedRecord: persistedRecord,
    )) {
      debugPrint(
        '[Billing] ignored purchase callback without a matching account',
      );
      return;
    }
    final persistedAttemptId = persistedRecord?.attemptId.trim() ?? '';
    final persistedProductId = persistedRecord?.productId.trim() ?? '';
    final attemptId =
        attempt?.id ??
        (persistedAttemptId.isNotEmpty
            ? persistedAttemptId
            : newBillingAttemptId());
    final productId =
        attempt?.product.productId ??
        (persistedProductId.isNotEmpty
            ? persistedProductId
            : purchase.productId);
    _cancelAttemptTimeout(
      attempt == null
          ? purchase.productId
          : _storeProductIdFor(attempt.product, purchase.provider),
    );
    if (!persistedRecordLookupSucceeded &&
        (purchase.status == BillingPurchaseStatus.purchased ||
            purchase.status == BillingPurchaseStatus.restored)) {
      _emitDeferred(productId, attemptId);
      return;
    }

    switch (purchase.status) {
      case BillingPurchaseStatus.pending:
        if (token.isNotEmpty && attempt != null) {
          _attemptByPurchaseToken[token] = attempt;
        }
        var pendingPersisted = false;
        if (token.isNotEmpty) {
          pendingPersisted = await _persistPendingPurchase(
            purchase: purchase,
            attempt: attempt,
            existing: persistedRecord,
            attemptId: attemptId,
            productId: productId,
            billingAccountId: billingAccountId,
            existingLookupSucceeded: persistedRecordLookupSucceeded,
          );
        }
        _setBusy(productId, false);
        if (persistedRecord == null &&
            _trackedPendingAttemptIds.add(attemptId)) {
          _trackPendingById(
            attemptId: attemptId,
            productId: productId,
            storeProductId: purchase.productId,
          );
        }
        _events.add(
          BillingUiEvent(
            kind: BillingUiEventKind.pending,
            productId: productId,
            attemptId: attemptId,
            message: 'Payment is pending.',
          ),
        );
        BillingPendingPurchase? pendingRecord = persistedRecord;
        if (pendingRecord == null && pendingPersisted) {
          try {
            pendingRecord = await _findPendingPurchase(
              provider: purchase.provider,
              purchaseToken: token,
            );
          } catch (_) {}
        }
        if (pendingRecord != null) {
          final recordToReport = pendingRecord;
          await _runExclusivePurchase(
            recordToReport.key,
            () => _processRecord(
              recordToReport,
              purchase: purchase,
              source: source,
            ),
          );
        }
        return;
      case BillingPurchaseStatus.canceled:
        await _removePendingPurchase(purchase);
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
        await _removePendingPurchase(purchase);
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
    if (_disposed || _completedPurchaseKeys.contains(processingKey)) return;
    if (!_beginExclusivePurchase(processingKey)) return;
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
    }
    try {
      var record = persistedRecord;
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
        record = _purchaseRecord(
          purchase: purchase,
          attemptId: resolvedAttempt.id,
          billingAccountId: resolvedAttempt.billingAccountId,
          productId: resolvedAttempt.product.productId,
          status: BillingPendingPurchaseStatus.received,
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
      } else if (record.status != BillingPendingPurchaseStatus.received) {
        record = _purchaseRecord(
          purchase: purchase,
          attemptId: record.attemptId,
          billingAccountId: record.billingAccountId,
          productId: record.productId,
          status: record.status == BillingPendingPurchaseStatus.accepted
              ? BillingPendingPurchaseStatus.accepted
              : BillingPendingPurchaseStatus.received,
          createdAt: record.createdAt,
          updatedAt: DateTime.now(),
          retryCount: record.retryCount,
          reportTimeoutTracked: record.reportTimeoutTracked,
        );
        try {
          await _pendingPurchaseStore.upsert(record);
        } catch (_) {
          _cancelReportTimeout(processingKey);
          if (suppressUiForTimedOutReport) {
            _setBusy(record.productId, false);
            return;
          }
          _emitDeferred(record.productId, record.attemptId);
          return;
        }
      }
      await _processRecord(record, purchase: purchase, source: source);
    } finally {
      _endExclusivePurchase(processingKey);
    }
  }

  bool _beginExclusivePurchase(String processingKey) {
    if (_disposed || _completedPurchaseKeys.contains(processingKey)) {
      return false;
    }
    return _processingPurchaseKeys.add(processingKey);
  }

  void _endExclusivePurchase(String processingKey) {
    _processingPurchaseKeys.remove(processingKey);
  }

  Future<void> _runExclusivePurchase(
    String processingKey,
    Future<void> Function() action,
  ) async {
    if (!_beginExclusivePurchase(processingKey)) return;
    try {
      await action();
    } finally {
      _endExclusivePurchase(processingKey);
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

  Future<BillingPendingPurchase?> _findPendingPurchase({
    required BillingProvider provider,
    required String purchaseToken,
  }) async {
    return _pendingPurchaseStore.find(
      provider: provider,
      purchaseToken: purchaseToken,
    );
  }

  Future<bool> _persistPendingPurchase({
    required BillingPurchase purchase,
    required BillingPurchaseAttempt? attempt,
    required BillingPendingPurchase? existing,
    required String attemptId,
    required String productId,
    required String billingAccountId,
    required bool existingLookupSucceeded,
  }) async {
    if (!existingLookupSucceeded) return false;
    if (existing != null &&
        existing.status != BillingPendingPurchaseStatus.pending) {
      return false;
    }
    final token = purchase.purchaseToken.trim();
    final ownerId =
        attempt?.billingAccountId.trim() ??
        existing?.billingAccountId.trim() ??
        billingAccountId.trim();
    if (token.isEmpty ||
        ownerId.isEmpty ||
        ownerId != billingAccountId.trim()) {
      return false;
    }
    final now = DateTime.now();
    final record = BillingPendingPurchase(
      provider: purchase.provider,
      purchaseToken: token,
      attemptId: existing?.attemptId.trim().isNotEmpty == true
          ? existing!.attemptId.trim()
          : attemptId,
      billingAccountId: ownerId,
      productId: existing?.productId.trim().isNotEmpty == true
          ? existing!.productId.trim()
          : productId,
      storeProductId: purchase.productId.trim().isNotEmpty
          ? purchase.productId.trim()
          : existing?.storeProductId ?? '',
      transactionId: purchase.transactionId.trim().isNotEmpty
          ? purchase.transactionId.trim()
          : existing?.transactionId ?? '',
      originalJson: purchase.originalJson.trim().isNotEmpty
          ? purchase.originalJson
          : existing?.originalJson ?? '',
      purchaseTime: purchase.purchaseTime.trim().isNotEmpty
          ? purchase.purchaseTime
          : existing?.purchaseTime ?? '',
      status: BillingPendingPurchaseStatus.pending,
      retryCount: existing?.retryCount ?? 0,
      reportTimeoutTracked: existing?.reportTimeoutTracked ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await _pendingPurchaseStore.upsert(record);
      return true;
    } catch (error) {
      debugPrint('[Billing] failed to persist pending checkout: $error');
      return false;
    }
  }

  BillingPendingPurchase _purchaseRecord({
    required BillingPurchase purchase,
    required String attemptId,
    required String billingAccountId,
    required String productId,
    required BillingPendingPurchaseStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    int retryCount = 0,
    bool reportTimeoutTracked = false,
  }) {
    return BillingPendingPurchase(
      provider: purchase.provider,
      purchaseToken: purchase.purchaseToken.trim(),
      attemptId: attemptId,
      billingAccountId: billingAccountId,
      productId: productId,
      storeProductId: purchase.productId,
      transactionId: purchase.transactionId,
      originalJson: purchase.originalJson,
      purchaseTime: purchase.purchaseTime,
      status: status,
      retryCount: retryCount,
      reportTimeoutTracked: reportTimeoutTracked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> _removePendingPurchase(BillingPurchase purchase) async {
    final token = purchase.purchaseToken.trim();
    if (token.isEmpty) return;
    BillingPendingPurchase? existing;
    try {
      existing = await _findPendingPurchase(
        provider: purchase.provider,
        purchaseToken: token,
      );
    } catch (_) {
      return;
    }
    if (existing?.status != BillingPendingPurchaseStatus.pending) return;
    try {
      await _pendingPurchaseStore.remove(
        provider: purchase.provider,
        purchaseToken: token,
      );
    } catch (_) {}
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

    _scheduleReportTimeout(record: record, purchase: purchase);
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
      final reportTimedOut = _timedOutReportKeys.contains(record.key);
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
        reportTimeoutTracked: record.reportTimeoutTracked || reportTimedOut,
      );
      try {
        await _pendingPurchaseStore.upsert(next);
      } catch (_) {}
      if (reportTimedOut) {
        _setBusy(record.productId, false);
        return;
      }
      _cancelReportTimeout(record.key);
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
      return;
    }

    final reportTimedOut = _timedOutReportKeys.remove(record.key);
    if (reportTimedOut && !record.reportTimeoutTracked) {
      record = record.copyWith(reportTimeoutTracked: true);
    }
    _cancelReportTimeout(record.key);
    final serverTransactionId = report.transactionId.trim();

    if (report.status == GemPurchaseReportStatus.completed) {
      if (!await _deletePurchaseRecord(record)) {
        await _handleLocalOrderMutationFailure(
          record,
          reportTimedOut: reportTimedOut,
        );
        return;
      }
      _finishPurchaseAttempt(record, purchase);
      _track(
        'purchase_success',
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        data: <String, Object?>{
          'transaction_id': serverTransactionId.isNotEmpty
              ? serverTransactionId
              : record.transactionId,
        },
      );
      if (!reportTimedOut) {
        _events.add(
          BillingUiEvent(
            kind: BillingUiEventKind.success,
            productId: record.productId,
            attemptId: record.attemptId,
            message: 'Purchase successful!',
            grantedGems: report.grantedGems,
          ),
        );
      }
      _refreshWalletInBackground();
    } else if (report.status == GemPurchaseReportStatus.accepted) {
      final accepted = record.copyWith(
        status: BillingPendingPurchaseStatus.accepted,
        transactionId: serverTransactionId.isNotEmpty
            ? serverTransactionId
            : null,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(accepted);
      } catch (_) {
        await _handleLocalOrderMutationFailure(
          record,
          reportTimedOut: reportTimedOut,
        );
        return;
      }
      _finishPurchaseAttempt(record, purchase);
      if (!reportTimedOut &&
          record.status != BillingPendingPurchaseStatus.accepted) {
        _events.add(
          BillingUiEvent(
            kind: BillingUiEventKind.accepted,
            productId: record.productId,
            attemptId: record.attemptId,
            message:
                'Payment received.\nYour Gems will be added shortly. Please check your balance again in a moment.',
          ),
        );
      }
    } else {
      if (!await _deletePurchaseRecord(record)) {
        await _handleLocalOrderMutationFailure(
          record,
          reportTimedOut: reportTimedOut,
        );
        return;
      }
      _finishPurchaseAttempt(record, purchase);
      if (!reportTimedOut) {
        _emitFailure(
          record.productId,
          record.attemptId,
          'Purchase was refunded.',
        );
      }
    }
    _trackFlowResultById(
      attemptId: record.attemptId,
      productId: record.productId,
      storeProductId: record.storeProductId,
      status: report.status.name,
      source: source,
    );

    if (report.status != GemPurchaseReportStatus.accepted) {
      _completedPurchaseKeys.add(record.key);
    }
  }

  Future<bool> _deletePurchaseRecord(BillingPendingPurchase record) async {
    try {
      await _pendingPurchaseStore.remove(
        provider: record.provider,
        purchaseToken: record.purchaseToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleLocalOrderMutationFailure(
    BillingPendingPurchase record, {
    required bool reportTimedOut,
  }) async {
    final next = record.copyWith(
      retryCount: record.retryCount + 1,
      updatedAt: DateTime.now(),
    );
    try {
      await _pendingPurchaseStore.upsert(next);
    } catch (_) {}
    if (reportTimedOut) {
      _setBusy(record.productId, false);
      return;
    }
    _emitDeferred(record.productId, record.attemptId);
    _setBusy(record.productId, false);
  }

  void _finishPurchaseAttempt(
    BillingPendingPurchase record,
    BillingPurchase? purchase,
  ) {
    if (purchase != null) {
      _clearAttempt(purchase, _attemptByPurchaseToken[record.purchaseToken]);
    } else {
      _setBusy(record.productId, false);
    }
  }

  void _refreshWalletInBackground() {
    unawaited(
      _refreshWallet().catchError((error, stackTrace) {
        debugPrint('[Billing] wallet refresh failed after purchase: $error');
      }),
    );
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

  BillingPurchaseAttempt? _attemptForPurchase(
    BillingPurchase purchase, {
    BillingPendingPurchase? persistedRecord,
  }) {
    final token = purchase.purchaseToken.trim();
    final tokenAttempt = _attemptByPurchaseToken[token];
    if (persistedRecord != null) {
      return tokenAttempt?.id == persistedRecord.attemptId
          ? tokenAttempt
          : null;
    }
    return tokenAttempt ??
        _attemptByStoreProductId[purchase.productId] ??
        _onlyActiveAttemptForStoreError(purchase);
  }

  bool _purchaseBelongsToBillingAccount(
    BillingPurchase purchase,
    BillingPurchaseAttempt? attempt,
    String billingAccountId, {
    BillingPendingPurchase? persistedRecord,
  }) {
    if (purchase.provider != BillingProvider.googlePlay) return true;
    final currentAccountId = billingAccountId.trim();
    if (currentAccountId.isEmpty) return false;
    if (persistedRecord != null &&
        persistedRecord.billingAccountId != currentAccountId) {
      return false;
    }
    final purchaseAccountId = purchase.obfuscatedAccountId?.trim() ?? '';
    if (purchaseAccountId.isNotEmpty) {
      return purchaseAccountId == currentAccountId;
    }
    return attempt?.billingAccountId == currentAccountId ||
        persistedRecord?.billingAccountId == currentAccountId;
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
    required BillingPendingPurchase record,
    BillingPurchase? purchase,
  }) {
    _cancelReportTimeout(record.key);
    if (_reportTimeout <= Duration.zero) return;
    _reportTimeouts[record.key] = Timer(
      _reportTimeout,
      () => unawaited(_handleReportTimeout(record: record, purchase: purchase)),
    );
  }

  Future<void> _handleReportTimeout({
    required BillingPendingPurchase record,
    BillingPurchase? purchase,
  }) async {
    final purchaseKey = record.key;
    _reportTimeouts.remove(purchaseKey);
    if (_disposed ||
        _completedPurchaseKeys.contains(purchaseKey) ||
        _timedOutReportKeys.contains(purchaseKey) ||
        !_processingPurchaseKeys.contains(purchaseKey)) {
      return;
    }
    _timedOutReportKeys.add(purchaseKey);
    var shouldTrack = false;
    try {
      shouldTrack = await _pendingPurchaseStore.markReportTimeoutTracked(
        provider: record.provider,
        purchaseToken: record.purchaseToken,
      );
    } catch (_) {}
    if (shouldTrack) {
      _trackTimeoutById(
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        timeoutType: 'report',
      );
    }
    if (purchase != null) {
      _clearAttempt(purchase, _attemptByPurchaseToken[purchase.purchaseToken]);
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.failure,
          productId: record.productId,
          attemptId: record.attemptId,
          message: 'purchase timeout',
        ),
      );
    } else {
      _setBusy(record.productId, false);
    }
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
    _attemptTimeouts[storeProductId] = Timer(_attemptTimeout, () {
      _attemptTimeouts.remove(storeProductId);
      final activeAttempt = _attemptByStoreProductId[storeProductId];
      if (activeAttempt?.id != attemptId) return;
      _trackTimeoutById(
        attemptId: attemptId,
        productId: product.productId,
        storeProductId: storeProductId,
        timeoutType: 'store_no_callback',
      );
      _setBusy(activeAttempt!.product.productId, false);
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

  String _queryFailureErrorCode(Object error) {
    if (error is BillingPlatformException && error.code.trim().isNotEmpty) {
      return error.code.trim();
    }
    return 'unknown';
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
        errorCode:
            failedReason == 'purchase_callback_error' ||
                failedReason == 'query_failed'
            ? errorCode
            : null,
      );
    }
  }

  void _trackFailedById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String reason,
    String? errorCode,
  }) {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) return;
    final normalizedErrorCode = errorCode?.trim() ?? '';
    _track(
      'purchase_failed',
      attemptId: attemptId,
      productId: productId,
      storeProductId: storeProductId,
      data: <String, Object?>{
        'reason': normalizedReason,
        if (normalizedErrorCode.isNotEmpty) 'error_code': normalizedErrorCode,
      },
    );
  }

  void _trackPendingById({
    required String attemptId,
    required String productId,
    required String storeProductId,
  }) {
    _track(
      'purchase_pending',
      attemptId: attemptId,
      productId: productId,
      storeProductId: storeProductId,
    );
  }

  void _trackTimeoutById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String timeoutType,
  }) {
    _track(
      'purchase_timeout',
      attemptId: attemptId,
      productId: productId,
      storeProductId: storeProductId,
      data: <String, Object?>{'timeout_type': timeoutType},
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
      'unsupported_product_type' => 'unsupported_product_type',
      _ => null,
    };
  }

  @override
  void resetForSession() {
    _sessionGeneration += 1;
    _cachedBillingAccountId = null;
    _cachedBillingAccountOwnerUid = null;
    _attemptByStoreProductId.clear();
    _attemptByPurchaseToken.clear();
    _completedPurchaseKeys.clear();
    _timedOutReportKeys.clear();
    _trackedPendingAttemptIds.clear();
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
