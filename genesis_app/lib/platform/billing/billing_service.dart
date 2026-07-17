import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/api_exception.dart';
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

  Future<void> purchaseGem(GemProduct product);

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
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _readUid = readUid,
       _analytics = analytics;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingUidReader _readUid;
  final BillingAnalytics _analytics;
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
  final Map<String, Timer> _attemptTimeouts = <String, Timer>{};

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
  Future<void> purchaseGem(GemProduct product) async {
    final attemptId = newBillingAttemptId();
    _trackProduct(
      'product_click',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{
        'can_purchase': product.canPurchase,
        'billing_type': product.billingType,
        'base_gems': product.baseGems,
        'bonus_gems': product.bonusGems,
        'price_amount': product.priceAmount,
        'price_currency_code': product.priceCurrencyCode,
        'activity_type': product.activityType,
        'purchase_option_id': product.googlePurchaseOptionId,
        'offer_id': product.googleOfferId,
      },
    );
    await start();
    if (_disposed) return;
    if (!product.canPurchase || product.googleProductId.trim().isEmpty) {
      _trackPrecheckFailure(product, attemptId, 'product_unavailable');
      _emitFailure(
        product.productId,
        attemptId,
        'This product is unavailable.',
      );
      return;
    }
    if (!_state.value.storeAvailable) {
      _trackPrecheckFailure(product, attemptId, 'store_unavailable');
      _emitFailure(product.productId, attemptId, 'Google Play is unavailable.');
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
      _trackPrecheckFailure(product, attemptId, 'billing_account_load_failed');
      _emitFailure(product.productId, attemptId, 'Purchase failed.');
      return;
    }
    if (billingAccountId.isEmpty) {
      _trackPrecheckFailure(product, attemptId, 'billing_account_unavailable');
      _emitFailure(product.productId, attemptId, 'Purchase failed.');
      return;
    }
    _trackProduct(
      'purchase_precheck_result',
      product: product,
      attemptId: attemptId,
      data: const <String, Object?>{'result': 'success'},
    );

    final attempt = BillingPurchaseAttempt(
      id: attemptId,
      product: product,
      billingAccountId: billingAccountId,
      source: BillingRecoverySource.direct,
      startedAt: startedAt,
    );
    _attemptByStoreProductId[product.googleProductId] = attempt;

    final queryStartedAt = DateTime.now();
    _trackProduct(
      'product_query_start',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{
        'product_type': BillingStoreProductType.inApp.value,
        'purchase_option_id': product.googlePurchaseOptionId,
        'offer_id': product.googleOfferId,
      },
    );
    late final BillingProductQueryResult queryResult;
    try {
      queryResult = await _platform.queryProduct(
        product.googleProductId,
        BillingStoreProductType.inApp,
        purchaseOptionId: _nonEmpty(product.googlePurchaseOptionId),
        offerId: _nonEmpty(product.googleOfferId),
      );
    } catch (error) {
      final errorCode = _safeErrorCode(error, fallback: 'query_failed');
      _trackProduct(
        'product_query_result',
        product: product,
        attemptId: attemptId,
        data: <String, Object?>{
          'result': 'failure',
          'error_code': errorCode,
          'duration_ms': _elapsedMilliseconds(queryStartedAt),
        },
      );
      _clearActiveAttempt(product.googleProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(
        product,
        attemptId,
        'query_failed',
        errorCode: errorCode,
      );
      return;
    }
    if (!queryResult.isSuccess) {
      final errorCode = queryResult.errorCode?.trim().isNotEmpty == true
          ? queryResult.errorCode!.trim()
          : 'product_unavailable';
      _trackProduct(
        'product_query_result',
        product: product,
        attemptId: attemptId,
        data: <String, Object?>{
          'result': 'failure',
          'error_code': errorCode,
          'duration_ms': _elapsedMilliseconds(queryStartedAt),
        },
      );
      _clearActiveAttempt(product.googleProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _productQueryFailureMessage(queryResult.errorCode),
      );
      _trackFlowResult(
        product,
        attemptId,
        'query_failed',
        errorCode: errorCode,
      );
      return;
    }

    final storeProduct = queryResult.product!;
    _trackProduct(
      'product_query_result',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{
        'result': 'success',
        ..._storeProductAnalytics(storeProduct),
        'duration_ms': _elapsedMilliseconds(queryStartedAt),
      },
    );

    final launchStartedAt = DateTime.now();
    _trackProduct(
      'purchase_launch_start',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{
        ..._storeProductAnalytics(storeProduct),
        'can_purchase': product.canPurchase,
        'billing_type': product.billingType,
        'base_gems': product.baseGems,
        'bonus_gems': product.bonusGems,
        'price_amount': product.priceAmount,
        'activity_type': product.activityType,
        'billing_account_id_present': billingAccountId.isNotEmpty,
      },
    );
    try {
      final accepted = await _platform.buyConsumable(
        product: storeProduct,
        billingAccountId: billingAccountId,
      );
      _trackProduct(
        'purchase_launch_result',
        product: product,
        attemptId: attemptId,
        data: <String, Object?>{
          'result': accepted ? 'success' : 'failure',
          'status': accepted ? 'accepted' : 'rejected',
          'duration_ms': _elapsedMilliseconds(launchStartedAt),
        },
      );
      if (!accepted) {
        _clearActiveAttempt(product.googleProductId, attempt);
        _emitFailure(product.productId, attemptId, 'Purchase failed.');
        _trackFlowResult(product, attemptId, 'launch_rejected');
      } else {
        _scheduleAttemptTimeout(product, attemptId);
      }
    } catch (error) {
      debugPrint('[Billing] purchase launch failed: $error');
      final errorCode = _safeErrorCode(error, fallback: 'launch_failed');
      _trackProduct(
        'purchase_launch_result',
        product: product,
        attemptId: attemptId,
        data: <String, Object?>{
          'result': 'failure',
          'error_code': errorCode,
          'duration_ms': _elapsedMilliseconds(launchStartedAt),
        },
      );
      _clearActiveAttempt(product.googleProductId, attempt);
      _emitFailure(
        product.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(
        product,
        attemptId,
        'launch_failed',
        errorCode: errorCode,
      );
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
    final recoveryStartedAt = DateTime.now();
    _track(
      'recovery_start',
      data: <String, Object?>{
        'provider': _platform.provider.apiValue,
        'trigger': source.value,
      },
    );
    String uid;
    try {
      uid = (await _readUid())?.trim() ?? '';
    } catch (_) {
      _trackRecoveryResult(
        source,
        recoveryStartedAt,
        result: 'failure',
        reason: 'user_read_failed',
      );
      return;
    }
    if (uid.isEmpty || uid.startsWith('guest_')) {
      _trackRecoveryResult(
        source,
        recoveryStartedAt,
        result: 'skipped',
        reason: 'user_unavailable',
      );
      return;
    }
    String billingAccountId;
    try {
      billingAccountId = await _resolveBillingAccountId();
    } catch (_) {
      _trackRecoveryResult(
        source,
        recoveryStartedAt,
        result: 'failure',
        reason: 'billing_account_load_failed',
      );
      return;
    }
    if (billingAccountId.isEmpty) {
      _trackRecoveryResult(
        source,
        recoveryStartedAt,
        result: 'skipped',
        reason: 'billing_account_unavailable',
      );
      return;
    }

    final pastPurchaseKeys = <String>{};
    final reportedStoreProductIds = <String>{};
    var pastPurchaseQuerySucceeded = false;
    var googlePurchaseCount = 0;
    try {
      final purchases = await _platform.queryPastPurchases(
        billingAccountId: billingAccountId,
      );
      pastPurchaseQuerySucceeded = true;
      googlePurchaseCount = purchases.length;
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
    if (pastPurchaseQuerySucceeded && _processingPurchaseKeys.isEmpty) {
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
      _trackRecoveryResult(
        source,
        recoveryStartedAt,
        result: 'failure',
        reason: 'local_order_load_failed',
        googlePurchaseCount: googlePurchaseCount,
        pastPurchaseQuerySucceeded: pastPurchaseQuerySucceeded,
      );
      return;
    }
    var retryOrderCount = 0;
    var skippedOrderCount = 0;
    for (final record in records) {
      if (record.provider != _platform.provider ||
          record.billingAccountId != billingAccountId) {
        skippedOrderCount += 1;
        continue;
      }
      if (record.status == BillingPendingPurchaseStatus.reported) {
        if (pastPurchaseQuerySucceeded &&
            !pastPurchaseKeys.contains(record.key)) {
          try {
            await _pendingPurchaseStore.remove(
              provider: record.provider,
              purchaseToken: record.purchaseToken,
            );
            _trackRecordPersistence(
              record,
              operation: 'delete_terminal',
              result: 'success',
              source: source,
            );
          } catch (_) {
            _trackRecordPersistence(
              record,
              operation: 'delete_terminal',
              result: 'failure',
              source: source,
              errorCode: 'local_delete_failed',
            );
          }
        }
        skippedOrderCount += 1;
        continue;
      }
      if (pastPurchaseKeys.contains(record.key)) {
        skippedOrderCount += 1;
        continue;
      }
      retryOrderCount += 1;
      await _processRecord(record, source: source);
    }
    _trackRecoveryResult(
      source,
      recoveryStartedAt,
      result: pastPurchaseQuerySucceeded ? 'success' : 'partial',
      localOrderCount: records.length,
      retryOrderCount: retryOrderCount,
      skippedOrderCount: skippedOrderCount,
      googlePurchaseCount: googlePurchaseCount,
      pastPurchaseQuerySucceeded: pastPurchaseQuerySucceeded,
    );
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
      attempt?.product.googleProductId ?? purchase.productId,
    );
    _track(
      'store_callback',
      attemptId: attemptId,
      productId: productId,
      storeProductId: purchase.productId,
      data: <String, Object?>{
        'provider': purchase.provider.apiValue,
        'trigger': source.value,
        'purchase_status': purchase.status.name,
        'purchase_token_present': token.isNotEmpty,
        'transaction_id_present': purchase.transactionId.trim().isNotEmpty,
        'error_code': purchase.errorCode,
      },
    );

    switch (purchase.status) {
      case BillingPurchaseStatus.pending:
        if (token.isNotEmpty && attempt != null) {
          _attemptByPurchaseToken[token] = attempt;
        }
        _setBusy(productId, false);
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
        errorCode: 'purchase_token_missing',
      );
      return;
    }
    if (attempt != null) _attemptByPurchaseToken[token] = attempt;

    final processingKey = '${purchase.provider.name}:$token';
    if (_completedPurchaseKeys.contains(processingKey)) {
      _track(
        'duplicate_callback_ignored',
        attemptId: attemptId,
        productId: productId,
        storeProductId: purchase.productId,
        data: <String, Object?>{
          'provider': purchase.provider.apiValue,
          'trigger': source.value,
          'purchase_status': purchase.status.name,
          'reason': 'already_completed',
        },
      );
      return;
    }
    if (!_processingPurchaseKeys.add(processingKey)) {
      _track(
        'duplicate_callback_ignored',
        attemptId: attemptId,
        productId: productId,
        storeProductId: purchase.productId,
        data: <String, Object?>{
          'provider': purchase.provider.apiValue,
          'trigger': source.value,
          'purchase_status': purchase.status.name,
          'reason': 'already_processing',
        },
      );
      return;
    }
    _events.add(
      BillingUiEvent(
        kind: BillingUiEventKind.processing,
        productId: productId,
        attemptId: attemptId,
        message: 'Purchasing Gems',
      ),
    );
    try {
      BillingPendingPurchase? record;
      try {
        record = await _pendingPurchaseStore.find(
          provider: purchase.provider,
          purchaseToken: token,
        );
      } catch (_) {
        _track(
          'local_order_persist_result',
          attemptId: attemptId,
          productId: productId,
          storeProductId: purchase.productId,
          data: <String, Object?>{
            'provider': purchase.provider.apiValue,
            'trigger': source.value,
            'operation': 'lookup',
            'result': 'failure',
            'error_code': 'local_lookup_failed',
          },
        );
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
          _track(
            'local_order_persist_result',
            attemptId: attemptId,
            productId: productId,
            storeProductId: purchase.productId,
            data: <String, Object?>{
              'provider': purchase.provider.apiValue,
              'trigger': source.value,
              'operation': 'insert_received',
              'result': 'failure',
              'error_code': 'product_mapping_unavailable',
            },
          );
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
          _trackRecordPersistence(
            record,
            operation: 'insert_received',
            result: 'success',
            source: source,
          );
        } catch (_) {
          _trackRecordPersistence(
            record,
            operation: 'insert_received',
            result: 'failure',
            source: source,
            errorCode: 'local_save_failed',
          );
          _emitDeferred(resolvedAttempt.product.productId, resolvedAttempt.id);
          return;
        }
      } else {
        _trackRecordPersistence(
          record,
          operation: 'insert_received',
          result: 'already_exists',
          source: source,
        );
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
        (candidate) => candidate!.googleProductId == purchase.productId,
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
      _completedPurchaseKeys.add(record.key);
      if (purchase != null) {
        _clearAttempt(purchase, _attemptByPurchaseToken[record.purchaseToken]);
      } else {
        _setBusy(record.productId, false);
      }
      return;
    }

    final reportType =
        source == BillingRecoverySource.direct && record.retryCount == 0
        ? 'initial'
        : 'retry';
    final reportStartedAt = DateTime.now();
    final reportData = <String, Object?>{
      'provider': record.provider.apiValue,
      'trigger': source.value,
      'report_type': reportType,
      'retry_count': record.retryCount,
      'order_age_ms': DateTime.now()
          .difference(record.createdAt)
          .inMilliseconds
          .clamp(0, 0x7fffffff),
    };
    _track(
      'report_start',
      attemptId: record.attemptId,
      productId: record.productId,
      storeProductId: record.storeProductId,
      data: reportData,
    );

    late final GemPurchaseReport report;
    try {
      report = await _reportPurchase(
        GemPurchaseReportRequest(
          provider: record.provider.apiValue,
          productId: record.productId,
          storeProductId: record.storeProductId,
          transactionId: record.transactionId,
          purchaseToken: record.purchaseToken,
          requestId: record.attemptId,
          payload: <String, Object?>{
            'purchase_time': record.purchaseTime,
            'original_json': record.originalJson,
          },
        ),
      );
    } catch (error) {
      final errorCode = _safeReportErrorCode(error);
      _track(
        'report_result',
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        data: <String, Object?>{
          ...reportData,
          'result': 'failure',
          'error_code': errorCode,
          'duration_ms': _elapsedMilliseconds(reportStartedAt),
        },
      );
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(next);
        _trackRecordPersistence(
          next,
          operation: 'update_retry',
          result: 'success',
          source: source,
        );
      } catch (_) {
        _trackRecordPersistence(
          next,
          operation: 'update_retry',
          result: 'failure',
          source: source,
          errorCode: 'local_retry_update_failed',
        );
      }
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
      _trackFlowResultById(
        attemptId: record.attemptId,
        productId: record.productId,
        storeProductId: record.storeProductId,
        status: 'report_deferred',
        source: source,
        errorCode: errorCode,
      );
      return;
    }

    _track(
      'report_result',
      attemptId: record.attemptId,
      productId: record.productId,
      storeProductId: record.storeProductId,
      data: <String, Object?>{
        ...reportData,
        'result': 'success',
        'status': report.status.name,
        'granted_gems': report.grantedGems,
        'duration_ms': _elapsedMilliseconds(reportStartedAt),
      },
    );
    final reported = record.copyWith(
      status: BillingPendingPurchaseStatus.reported,
      updatedAt: DateTime.now(),
    );
    try {
      await _pendingPurchaseStore.upsert(reported);
      _trackRecordPersistence(
        reported,
        operation: 'mark_reported',
        result: 'success',
        source: source,
      );
    } catch (_) {
      _trackRecordPersistence(
        reported,
        operation: 'mark_reported',
        result: 'failure',
        source: source,
        errorCode: 'local_mark_reported_failed',
      );
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(next);
        _trackRecordPersistence(
          next,
          operation: 'update_retry',
          result: 'success',
          source: source,
        );
      } catch (_) {
        _trackRecordPersistence(
          next,
          operation: 'update_retry',
          result: 'failure',
          source: source,
          errorCode: 'local_retry_update_failed',
        );
      }
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

    _completedPurchaseKeys.add(record.key);
    if (purchase != null) {
      _clearAttempt(purchase, _attemptByPurchaseToken[record.purchaseToken]);
    } else {
      _setBusy(record.productId, false);
    }

    if (report.status == GemPurchaseReportStatus.completed) {
      try {
        await _refreshWallet();
      } catch (_) {}
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
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.accepted,
          productId: record.productId,
          attemptId: record.attemptId,
          message:
              'Payment successful. Your Gems are being issued as quickly as possible. Please check your balance again later.',
        ),
      );
    } else {
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

  void _clearAttempt(
    BillingPurchase purchase,
    BillingPurchaseAttempt? attempt,
  ) {
    final activeAttempt =
        attempt ?? _attemptByStoreProductId[purchase.productId];
    if (activeAttempt != null) {
      _clearActiveAttempt(activeAttempt.product.googleProductId, activeAttempt);
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

  void _scheduleAttemptTimeout(GemProduct product, String attemptId) {
    _cancelAttemptTimeout(product.googleProductId);
    _attemptTimeouts[product.googleProductId] = Timer(
      const Duration(seconds: 90),
      () {
        _attemptTimeouts.remove(product.googleProductId);
        final activeAttempt = _attemptByStoreProductId[product.googleProductId];
        if (activeAttempt?.id != attemptId) return;
        _trackProduct(
          'purchase_timeout',
          product: product,
          attemptId: attemptId,
          data: <String, Object?>{
            'result': 'failure',
            'status': 'timeout',
            'duration_ms': _elapsedMilliseconds(activeAttempt!.startedAt),
          },
        );
        _trackFlowResult(product, attemptId, 'timeout');
        _clearActiveAttempt(product.googleProductId, activeAttempt);
      },
    );
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

  String? _nonEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
      storeProductId: product.googleProductId,
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
    _trackProduct(
      'purchase_precheck_result',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{'result': 'failure', 'error_code': errorCode},
    );
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
      storeProductId: product.googleProductId,
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
    final result = switch (status) {
      'completed' => 'success',
      'accepted' => 'accepted',
      'report_deferred' => 'deferred',
      'timeout' => 'timeout',
      _ => 'failure',
    };
    _track(
      'flow_result',
      attemptId: attemptId,
      productId: productId,
      storeProductId: storeProductId,
      data: <String, Object?>{
        'provider': _platform.provider.apiValue,
        'trigger': source.value,
        'result': result,
        'status': status,
        'error_code': errorCode,
      },
    );
  }

  Map<String, Object?> _storeProductAnalytics(BillingStoreProduct product) {
    return <String, Object?>{
      'product_type': product.type.value,
      'purchase_option_id': product.purchaseOptionId,
      'offer_id': product.offerId,
      'formatted_price': product.formattedPrice,
      'price_amount_micros': product.priceAmountMicros,
      'price_currency_code': product.priceCurrencyCode,
      'offer_token_present': product.offerToken?.trim().isNotEmpty == true,
    };
  }

  void _trackRecordPersistence(
    BillingPendingPurchase record, {
    required String operation,
    required String result,
    required BillingRecoverySource source,
    String? errorCode,
  }) {
    _track(
      'local_order_persist_result',
      attemptId: record.attemptId,
      productId: record.productId,
      storeProductId: record.storeProductId,
      data: <String, Object?>{
        'provider': record.provider.apiValue,
        'trigger': source.value,
        'operation': operation,
        'result': result,
        'order_status': record.status.name,
        'retry_count': record.retryCount,
        'error_code': errorCode,
      },
    );
  }

  void _trackRecoveryResult(
    BillingRecoverySource source,
    DateTime startedAt, {
    required String result,
    String? reason,
    int localOrderCount = 0,
    int retryOrderCount = 0,
    int skippedOrderCount = 0,
    int googlePurchaseCount = 0,
    bool pastPurchaseQuerySucceeded = false,
  }) {
    _track(
      'recovery_result',
      data: <String, Object?>{
        'provider': _platform.provider.apiValue,
        'trigger': source.value,
        'result': result,
        'reason': reason,
        'duration_ms': _elapsedMilliseconds(startedAt),
        'local_order_count': localOrderCount,
        'retry_order_count': retryOrderCount,
        'skipped_order_count': skippedOrderCount,
        'google_purchase_count': googlePurchaseCount,
        'past_purchase_query_succeeded': pastPurchaseQuerySucceeded,
      },
    );
  }

  int _elapsedMilliseconds(DateTime startedAt) {
    return DateTime.now()
        .difference(startedAt)
        .inMilliseconds
        .clamp(0, 0x7fffffff);
  }

  String _safeErrorCode(Object error, {required String fallback}) {
    if (error is BillingPlatformException && error.code.trim().isNotEmpty) {
      return error.code.trim();
    }
    if (error is TimeoutException) return 'timeout';
    return fallback;
  }

  String _safeReportErrorCode(Object error) {
    if (error is ApiException) {
      final prefix = switch (error.kind) {
        ApiExceptionKind.timeout => 'timeout',
        ApiExceptionKind.transport => 'transport',
        ApiExceptionKind.httpStatus => 'http_status',
        ApiExceptionKind.response => 'invalid_response',
        ApiExceptionKind.business => 'business',
        ApiExceptionKind.gatewayAuth => 'gateway_auth',
        ApiExceptionKind.cancelled => 'cancelled',
        ApiExceptionKind.unknown => 'report_failed',
      };
      final code = error.code;
      return code == null ? prefix : '${prefix}_$code';
    }
    if (error is TimeoutException) return 'timeout';
    return 'report_failed';
  }

  @override
  void resetForSession() {
    _cachedBillingAccountId = null;
    _cachedBillingAccountOwnerUid = null;
    _attemptByStoreProductId.clear();
    _attemptByPurchaseToken.clear();
    _completedPurchaseKeys.clear();
    for (final timeout in _attemptTimeouts.values) {
      timeout.cancel();
    }
    _attemptTimeouts.clear();
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
    _events.close();
    _state.dispose();
  }
}
