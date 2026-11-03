import 'payment_failure_diagnostics.dart';
import 'dart:async';
import 'checkout_preparation_budget.dart';
import 'store_product_access.dart';

import '../../l10n/genesis_l10n.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app/telemetry/purchase_event_reporting.dart';
import '../../network/models/gem_product.dart';
import '../../network/models/gem_purchase_report.dart';
import 'billing_analytics.dart';
import 'billing_contract.dart';
import 'billing_models.dart';
import 'billing_store_failure_reason.dart';
import 'purchase_toast_diagnostics.dart';
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
    BillingWalletRefresher? refreshProductsAfterPurchase,
    required BillingUidReader readUid,
    BillingAnalytics analytics = const GenesisBillingAnalytics(),
    Duration attemptTimeout = CheckoutPreparationBudget.timeout,
    Future<bool> Function(BillingPurchase)? interceptPurchase,
    bool Function()? otherPurchaseBusy,
    ValueChanged<Object>? onPurchaseStreamError,
    void Function(Object, StackTrace)? onPurchaseStreamErrorWithStack,
    this.purchaseEventReporting,
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _refreshProductsAfterPurchase = refreshProductsAfterPurchase,
       _readUid = readUid,
       _analytics = analytics,
       _attemptTimeout = attemptTimeout,
       _interceptPurchase = interceptPurchase,
       _otherPurchaseBusy = otherPurchaseBusy,
       _onPurchaseStreamError = onPurchaseStreamError,
       _onPurchaseStreamErrorWithStack = onPurchaseStreamErrorWithStack;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingWalletRefresher? _refreshProductsAfterPurchase;
  final BillingUidReader _readUid;
  final BillingAnalytics _analytics;
  final Duration _attemptTimeout;
  final Future<bool> Function(BillingPurchase)? _interceptPurchase;
  final bool Function()? _otherPurchaseBusy;
  final ValueChanged<Object>? _onPurchaseStreamError;
  final void Function(Object, StackTrace)? _onPurchaseStreamErrorWithStack;
  final PurchaseEventRecorder? purchaseEventReporting;
  final ValueNotifier<BillingState> _state = ValueNotifier<BillingState>(
    BillingState(),
  );
  final StreamController<BillingUiEvent> _events =
      StreamController<BillingUiEvent>.broadcast();
  final Map<String, BillingPurchaseAttempt> _attemptByStoreProductId =
      <String, BillingPurchaseAttempt>{};
  final Map<String, BillingPurchaseAttempt>
  _interruptedAttemptByStoreProductId = <String, BillingPurchaseAttempt>{};
  final Map<String, BillingPurchaseAttempt> _attemptByPurchaseToken =
      <String, BillingPurchaseAttempt>{};
  final Set<String> _processingPurchaseKeys = <String>{};
  final Set<String> _completedPurchaseKeys = <String>{};
  final Set<String> _trackedPurchasedKeys = <String>{};
  final Set<String> _trackedPendingAttemptIds = <String>{};
  final Set<String> _trackedFailedAttemptIds = <String>{};
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
    String operationId = '',
  }) async {
    final startedAt =
        CheckoutPreparationBudget.current?.startedAt ?? DateTime.now();
    final attemptId = operationId.trim().isNotEmpty
        ? operationId.trim()
        : newBillingAttemptId();
    var activeProduct = product;
    var storeProductId = _storeProductIdFor(product, _platform.provider);
    _trackProduct(
      'product_click',
      product: product,
      attemptId: attemptId,
      data: <String, Object?>{'source': source.value},
    );
    if (_disposed) return;
    if (_state.value.hasBusyPurchase || (_otherPurchaseBusy?.call() ?? false)) {
      _trackPrecheckFailure(product, attemptId, 'purchase_in_progress');
      return;
    }
    if (!product.canPurchase || storeProductId.trim().isEmpty) {
      _trackPrecheckFailure(
        product,
        attemptId,
        !product.canPurchase
            ? 'product_not_purchasable'
            : 'store_product_id_missing',
      );
      _emitFailure(
        product.productId,
        attemptId,
        GenesisL10n.current.gemsProductUnavailable,
        debugInfo: purchaseDebugInfo(
          'gems.precheck',
          reason: !product.canPurchase
              ? 'product_not_purchasable'
              : 'store_product_id_missing',
        ),
      );
      return;
    }
    if (billingProductKindFrom(product.billingType) !=
        BillingProductKind.consumable) {
      _trackPrecheckFailure(product, attemptId, 'unsupported_product_type');
      _emitFailure(
        product.productId,
        attemptId,
        GenesisL10n.current.gemsTypeUnsupported,
        debugInfo: purchaseDebugInfo(
          'gems.precheck',
          reason: 'unsupported_product_type',
        ),
      );
      return;
    }

    final session = _sessionGeneration;
    final expired = Completer<void>();
    var timedOut = false;
    var launchRequested = false;
    var storeHandedOff = false;
    // Keep preflight separate from receipt timers: an older store callback
    // must not cancel this deadline while account lookup is still pending.
    final preflightTimerKey = 'checkout:$attemptId';
    bool isCurrent() =>
        !timedOut && !_disposed && session == _sessionGeneration;
    void onTimeout() {
      if (!isCurrent() || storeHandedOff) return;
      timedOut = true;
      _cancelAttemptTimeout(preflightTimerKey);
      _cancelAttemptTimeout(storeProductId);
      _trackTimeoutById(
        attemptId: attemptId,
        productId: activeProduct.productId,
        storeProductId: storeProductId,
        timeoutType: 'store_no_callback',
      );
      if (!launchRequested) {
        final attempt = _attemptByStoreProductId[storeProductId];
        if (attempt?.id == attemptId) {
          _clearActiveAttempt(storeProductId, attempt!);
        }
      }
      _setBusy(activeProduct.productId, false);
      if (launchRequested) {
        _emitDeferred(
          activeProduct.productId,
          attemptId,
          debugInfo: purchaseDebugInfo(
            'gems.launch_store',
            reason: 'prepare_timeout',
          ),
        );
      } else {
        _emitUiEvent(
          BillingUiEvent(
            kind: BillingUiEventKind.deferred,
            productId: activeProduct.productId,
            attemptId: attemptId,
            message: GenesisL10n.current.gemsPurchaseTimeout,
            debugInfo: purchaseDebugInfo(
              'gems.prepare',
              reason: 'prepare_timeout',
            ),
          ),
        );
      }
      expired.complete();
    }

    bool canContinue() {
      if (!isCurrent()) return false;
      if (!storeHandedOff &&
          DateTime.now().difference(startedAt) >= _attemptTimeout) {
        onTimeout();
        return false;
      }
      return true;
    }

    bool onStoreHandoff() {
      if (_attemptByStoreProductId[storeProductId]?.id != attemptId ||
          !canContinue()) {
        return false;
      }
      storeHandedOff = true;
      _cancelAttemptTimeout(preflightTimerKey);
      _cancelAttemptTimeout(storeProductId);
      return true;
    }

    void scheduleTimeout(String key) => _scheduleAttemptTimeout(
      key,
      startedAt: startedAt,
      onTimeout: onTimeout,
    );

    _setBusy(product.productId, true);
    scheduleTimeout(preflightTimerKey);
    Future<void> runCheckout() async {
      try {
        await start();
        if (!canContinue()) return;
        if (!_state.value.storeAvailable) {
          final available = await _refreshStoreAvailability();
          if (!canContinue()) return;
          if (!available) {
            _trackPrecheckFailure(product, attemptId, 'gp_unavailable');
            _emitFailure(
              product.productId,
              attemptId,
              _storeUnavailableMessage(),
              debugInfo: purchaseDebugInfo(
                'gems.precheck',
                reason: 'store_unavailable',
              ),
            );
            return;
          }
        }

        late final String billingAccountId;
        try {
          billingAccountId = await _resolveBillingAccountId();
        } catch (error, stackTrace) {
          if (!canContinue()) return;
          _trackPrecheckFailure(
            product,
            attemptId,
            'uuid_unavailable',
            error: error,
            stackTrace: stackTrace,
            step: 'load_account_uuid',
            durationMs: DateTime.now().difference(startedAt).inMilliseconds,
          );
          _emitFailure(
            product.productId,
            attemptId,
            GenesisL10n.current.mePurchaseFailed,
            debugInfo: purchaseDebugInfo(
              'gems.load_account_uuid',
              error: error,
            ),
          );
          return;
        }
        if (!canContinue()) return;
        if (billingAccountId.isEmpty) {
          _trackPrecheckFailure(product, attemptId, 'uuid_unavailable');
          _emitFailure(
            product.productId,
            attemptId,
            GenesisL10n.current.mePurchaseFailed,
            debugInfo: purchaseDebugInfo(
              'gems.load_account_uuid',
              reason: 'uuid_unavailable',
            ),
          );
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
        _cancelAttemptTimeout(preflightTimerKey);
        scheduleTimeout(storeProductId);

        final recovery = StoreProductRecovery(canContinue: canContinue);
        BillingStoreProduct? refreshedProduct;
        Future<void> refreshProduct() async {
          storeHandedOff = false;
          if (!canContinue()) {
            throw const BillingPlatformException('checkout_aborted');
          }
          scheduleTimeout(storeProductId);
          final fresh = await _loadProductCatalog();
          if (!canContinue()) {
            throw const BillingPlatformException('checkout_aborted');
          }
          final matches = fresh.where(
            (p) => p.productId == activeProduct.productId && p.canPurchase,
          );
          if (matches.length != 1 ||
              billingProductKindFrom(matches.single.billingType) !=
                  BillingProductKind.consumable) {
            throw const BillingPlatformException('product_not_found');
          }
          final nextProduct = matches.single;
          final nextId = _storeProductIdFor(nextProduct, _platform.provider);
          if (nextId.trim().isEmpty) {
            throw const BillingPlatformException('product_not_found');
          }
          final response = await StoreProductAccess.refresh(
            () => _queryStoreProduct(nextProduct, nextId),
          );
          if (!canContinue()) {
            throw const BillingPlatformException('checkout_aborted');
          }
          if (!response.isSuccess) {
            throw BillingPlatformException(
              response.errorCode ?? 'product_not_found',
            );
          }
          _attemptByStoreProductId.remove(storeProductId);
          _cancelAttemptTimeout(storeProductId);
          activeProduct = nextProduct;
          storeProductId = nextId;
          refreshedProduct = response.product!;
          attempt =
              BillingPurchaseAttempt(
                id: attemptId,
                product: activeProduct,
                billingAccountId: billingAccountId,
                source: BillingRecoverySource.direct,
                startedAt: startedAt,
              ).copyWithStorePrice(
                priceAmountMicros: refreshedProduct!.priceAmountMicros,
                priceCurrencyCode: refreshedProduct!.priceCurrencyCode,
              );
          _attemptByStoreProductId[storeProductId] = attempt;
          scheduleTimeout(storeProductId);
        }

        final queryClock = Stopwatch()..start();
        late BillingProductQueryResult queryResult;
        try {
          queryResult = await recovery.run(
            action: () async {
              if (refreshedProduct != null) {
                return BillingProductQueryResult.success(refreshedProduct!);
              }
              final result = await _queryStoreProduct(
                activeProduct,
                storeProductId,
              );
              if (!result.isSuccess) {
                final error = BillingPlatformException(
                  result.errorCode ?? 'unknown',
                );
                if (StoreProductRecovery.isUnavailable(error)) throw error;
              }
              return result;
            },
            refresh: refreshProduct,
          );
          if (!canContinue()) return;
        } catch (error, stackTrace) {
          if (!canContinue()) return;
          _clearActiveAttempt(storeProductId, attempt);
          _emitFailure(
            activeProduct.productId,
            attemptId,
            _purchaseFailureMessage(error),
            debugInfo: purchaseDebugInfo(
              'gems.query_store_product',
              error: error,
            ),
          );
          _trackFlowResult(
            activeProduct,
            attemptId,
            'query_failed',
            errorCode: _platformFailureErrorCode(error),
            failureReason: _storeFailureReason(error: error, stage: 'query'),
            failureDiagnostics: _storeFailureDiagnostics(
              error: error,
              stackTrace: stackTrace,
              stage: 'query',
              context: {
                'step': 'query_store_product',
                'stage_duration_ms': queryClock.elapsedMilliseconds,
                'retry_count': recovery.used ? 1 : 0,
                'total_duration_ms': DateTime.now()
                    .difference(startedAt)
                    .inMilliseconds,
              },
            ),
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
            debugInfo: purchaseDebugInfo(
              'gems.query_store_product',
              errorCode: errorCode,
            ),
          );
          _trackFlowResult(
            activeProduct,
            attemptId,
            'query_failed',
            errorCode: errorCode,
            failureReason: _storeFailureReason(
              code: queryResult.errorCode,
              source: queryResult.errorSource,
              details: queryResult.errorDetails,
              stage: 'query',
            ),
            failureDiagnostics: _storeFailureDiagnostics(
              message: queryResult.errorMessage,
              code: queryResult.errorCode,
              source: queryResult.errorSource,
              details: queryResult.errorDetails,
              stage: 'query',
              context: {
                'step': 'query_store_product',
                'stage_duration_ms': queryClock.elapsedMilliseconds,
                'retry_count': recovery.used ? 1 : 0,
                'total_duration_ms': DateTime.now()
                    .difference(startedAt)
                    .inMilliseconds,
              },
            ),
          );
          return;
        }

        var storeProduct = queryResult.product!;
        if (!recovery.used &&
            product.requiresStorePrice &&
            (product.storeAmountMicros != storeProduct.priceAmountMicros ||
                product.storeCurrencyCode != storeProduct.priceCurrencyCode)) {
          _clearActiveAttempt(storeProductId, attempt);
          _emitFailure(
            product.productId,
            attemptId,
            _productQueryFailureMessage('product_not_found'),
            debugInfo: purchaseDebugInfo(
              'gems.price_check',
              reason: 'store_price_changed',
            ),
          );
          _trackFlowResult(
            product,
            attemptId,
            'precheck_failed',
            errorCode: 'store_price_changed',
            failureDiagnostics: {
              'stage': 'query',
              'step': 'check_store_price',
              'expected_price_amount_micros': product.storeAmountMicros,
              'actual_price_amount_micros': storeProduct.priceAmountMicros,
              'expected_currency': product.storeCurrencyCode,
              'actual_currency': storeProduct.priceCurrencyCode,
            },
          );
          return;
        }
        final storeCurrency = storeProduct.priceCurrencyCode.trim();
        if (storeProduct.priceAmountMicros >= 0 && storeCurrency.isNotEmpty) {
          attempt = attempt.copyWithStorePrice(
            priceAmountMicros: storeProduct.priceAmountMicros,
            priceCurrencyCode: storeCurrency,
          );
          _attemptByStoreProductId[storeProductId] = attempt;
        }

        final launchClock = Stopwatch()..start();
        try {
          launchRequested = true;
          final accepted = await StoreProductAccess.withCheckoutGuard(
            canContinue,
            () => recovery.run(
              action: () => _platform.buyConsumable(
                product: storeProduct,
                billingAccountId: billingAccountId,
                onStoreHandoff: onStoreHandoff,
              ),
              refresh: () async {
                await refreshProduct();
                storeProduct = refreshedProduct!;
              },
            ),
            attemptId: attemptId,
          );
          if (_attemptByStoreProductId[storeProductId]?.id != attemptId ||
              !canContinue()) {
            return;
          }
          if (!accepted) {
            _clearActiveAttempt(storeProductId, attempt);
            _emitFailure(
              activeProduct.productId,
              attemptId,
              GenesisL10n.current.mePurchaseFailed,
              debugInfo: purchaseDebugInfo(
                'gems.launch_store',
                reason: 'launch_rejected',
              ),
            );
            _trackFlowResult(
              activeProduct,
              attemptId,
              'launch_rejected',
              errorCode: 'launch_rejected',
              failureReason: 'store_failure[stage=launch]',
              failureDiagnostics: {
                'stage': 'launch',
                'step': 'launch_store',
                'stage_duration_ms': launchClock.elapsedMilliseconds,
                'total_duration_ms': DateTime.now()
                    .difference(startedAt)
                    .inMilliseconds,
                'retry_count': recovery.used ? 1 : 0,
              },
            );
          }
        } catch (error, stackTrace) {
          if (_attemptByStoreProductId[storeProductId]?.id != attemptId ||
              !canContinue()) {
            return;
          }
          debugPrint('[Billing] purchase launch failed: $error');
          _clearActiveAttempt(storeProductId, attempt);
          _emitFailure(
            activeProduct.productId,
            attemptId,
            _purchaseFailureMessage(error),
            debugInfo: purchaseDebugInfo('gems.launch_store', error: error),
            requiresProductRefresh:
                _platformFailureErrorCode(error) == 'product_details_changed',
          );
          _trackFlowResult(
            activeProduct,
            attemptId,
            'launch_failed',
            errorCode: _platformFailureErrorCode(error),
            failureReason: _storeFailureReason(error: error, stage: 'launch'),
            failureDiagnostics: _storeFailureDiagnostics(
              error: error,
              stackTrace: stackTrace,
              stage: 'launch',
              context: {
                'step': 'launch_store',
                'stage_duration_ms': launchClock.elapsedMilliseconds,
                'retry_count': recovery.used ? 1 : 0,
                'store_handoff_started': storeHandedOff,
                'total_duration_ms': DateTime.now()
                    .difference(startedAt)
                    .inMilliseconds,
              },
            ),
          );
        }
      } catch (_) {
        if (!canContinue()) return;
        _setBusy(activeProduct.productId, false);
        rethrow;
      } finally {
        _cancelAttemptTimeout(preflightTimerKey);
      }
    }

    // Let callers dismiss loading even if an SDK/account Future never resolves.
    await Future.any<void>([runCheckout(), expired.future]);
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
    _interruptedAttemptByStoreProductId.clear();
    _attemptByPurchaseToken.clear();
    _completedPurchaseKeys.clear();
    _trackedPurchasedKeys.clear();
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
