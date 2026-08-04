import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../network/api_exception.dart';
import '../../network/models/gem_product.dart';
import '../../network/models/gem_purchase_report.dart';
import 'billing_analytics.dart';
import 'billing_contract.dart';
import 'billing_models.dart';
import 'google_play_billing_platform.dart';
import 'pending_purchase_store.dart';

part 'billing_checkout.dart';
part 'billing_recovery.dart';
part 'billing_attempt_registry.dart';
part 'billing_tracking.dart';

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
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _readUid = readUid,
       _analytics = analytics,
       _attemptTimeout = attemptTimeout;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingUidReader _readUid;
  final BillingAnalytics _analytics;
  final Duration _attemptTimeout;
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
  final Set<String> _trackedPendingAttemptIds = <String>{};
  final Map<String, Timer> _attemptTimeouts = <String, Timer>{};

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;
  Future<void>? _startFuture;
  Future<void>? _recoverFuture;
  Future<bool>? _storeRecoveryFuture;
  var _sessionGeneration = 0;
  var _lastRecoveredSessionGeneration = -1;
  String? _cachedBillingAccountId;
  String? _cachedBillingAccountOwnerUid;
  bool _disposed = false;

  @override
  ValueListenable<BillingState> get state => _state;

  @override
  Stream<BillingUiEvent> get events => _events.stream;

  void _emitUiEvent(BillingUiEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  @override
  Future<void> start() {
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;
    final future = _start();
    _startFuture = future;
    return future;
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
      final available = await _refreshStoreAvailability();
      if (_disposed) return;
      if (!available) {
        _trackPrecheckFailure(product, attemptId, 'gp_unavailable');
        _emitFailure(product.productId, attemptId, _storeUnavailableMessage());
        return;
      }
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
    _scheduleAttemptTimeout(
      activeProduct,
      storeProductId,
      attemptId,
      startedAt: startedAt,
    );

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
              _setBusy(activeProduct.productId, true);
              _scheduleAttemptTimeout(
                activeProduct,
                storeProductId,
                attemptId,
                startedAt: startedAt,
              );
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
      }
    } catch (error) {
      debugPrint('[Billing] purchase launch failed: $error');
      _clearActiveAttempt(storeProductId, attempt);
      _emitFailure(
        activeProduct.productId,
        attemptId,
        _purchaseFailureMessage(error),
      );
      _trackFlowResult(
        activeProduct,
        attemptId,
        'launch_failed',
        errorCode: _purchaseLaunchErrorCode(error),
      );
    }
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

  @override
  Future<bool> recoverStorePurchases({List<GemProduct>? productCatalog}) {
    final inFlight = _storeRecoveryFuture;
    if (inFlight != null) return inFlight;
    late final Future<bool> tracked;
    tracked = _recoverStorePurchases(productCatalog: productCatalog)
        .whenComplete(() {
          if (identical(_storeRecoveryFuture, tracked)) {
            _storeRecoveryFuture = null;
          }
        });
    _storeRecoveryFuture = tracked;
    return tracked;
  }

  @override
  void resetForSession() {
    _sessionGeneration += 1;
    _cachedBillingAccountId = null;
    _cachedBillingAccountOwnerUid = null;
    _attemptByStoreProductId.clear();
    _attemptByPurchaseToken.clear();
    _completedPurchaseKeys.clear();
    _trackedPendingAttemptIds.clear();
    for (final timeout in _attemptTimeouts.values) {
      timeout.cancel();
    }
    _attemptTimeouts.clear();
    _setState(busyProductIds: const <String>{});
  }

  @override
  void dispose() {
    if (_disposed) return;
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
