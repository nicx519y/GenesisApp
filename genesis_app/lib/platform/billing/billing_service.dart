import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/models/gem_product.dart';
import '../../network/models/gem_purchase_report.dart';
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
  }) : _platform = platform,
       _pendingPurchaseStore = pendingPurchaseStore,
       _loadBillingAccountId = loadBillingAccountId,
       _loadProductCatalog = loadProductCatalog,
       _reportPurchase = reportPurchase,
       _refreshWallet = refreshWallet,
       _readUid = readUid;

  final BillingPlatform _platform;
  final BillingPendingPurchaseStore _pendingPurchaseStore;
  final BillingAccountIdLoader _loadBillingAccountId;
  final BillingProductCatalogLoader _loadProductCatalog;
  final BillingPurchaseReporter _reportPurchase;
  final BillingWalletRefresher _refreshWallet;
  final BillingUidReader _readUid;
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
    await start();
    if (_disposed) return;
    if (!product.canPurchase || product.googleProductId.trim().isEmpty) {
      _emitFailure(product.productId, '', 'This product is unavailable.');
      return;
    }
    if (!_state.value.storeAvailable) {
      _emitFailure(product.productId, '', 'Google Play is unavailable.');
      return;
    }
    if (_state.value.hasBusyPurchase) return;
    if (billingProductKindFrom(product.billingType) !=
        BillingProductKind.consumable) {
      _emitFailure(
        product.productId,
        '',
        'This product type is not supported.',
      );
      return;
    }

    final attemptId = newBillingAttemptId();
    final startedAt = DateTime.now();
    _setBusy(product.productId, true);

    try {
      final billingAccountId = await _resolveBillingAccountId();
      if (billingAccountId.isEmpty) {
        throw const BillingPlatformException('billing_account_unavailable');
      }
      final attempt = BillingPurchaseAttempt(
        id: attemptId,
        product: product,
        billingAccountId: billingAccountId,
        source: BillingRecoverySource.direct,
        startedAt: startedAt,
      );
      _attemptByStoreProductId[product.googleProductId] = attempt;

      final result = await _platform.queryProduct(
        product.googleProductId,
        BillingStoreProductType.inApp,
        purchaseOptionId: _nonEmpty(product.googlePurchaseOptionId),
        offerId: _nonEmpty(product.googleOfferId),
      );
      if (!result.isSuccess) {
        _attemptByStoreProductId.remove(product.googleProductId);
        _cancelAttemptTimeout(product.googleProductId);
        _emitFailure(
          product.productId,
          attemptId,
          _productQueryFailureMessage(result.errorCode),
        );
        return;
      }

      final accepted = await _platform.buyConsumable(
        product: result.product!,
        billingAccountId: billingAccountId,
      );
      if (!accepted) {
        _attemptByStoreProductId.remove(product.googleProductId);
        _cancelAttemptTimeout(product.googleProductId);
        _emitFailure(product.productId, attemptId, 'Purchase failed.');
      } else {
        _scheduleAttemptTimeout(product, attemptId);
      }
    } catch (error) {
      debugPrint('[Billing] purchase launch failed: $error');
      _attemptByStoreProductId.remove(product.googleProductId);
      _cancelAttemptTimeout(product.googleProductId);
      _emitFailure(
        product.productId,
        attemptId,
        _purchaseFailureMessage(error),
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
    String uid;
    try {
      uid = (await _readUid())?.trim() ?? '';
    } catch (_) {
      return;
    }
    if (uid.isEmpty || uid.startsWith('guest_')) return;
    String billingAccountId;
    try {
      billingAccountId = await _resolveBillingAccountId();
    } catch (_) {
      return;
    }
    if (billingAccountId.isEmpty) return;

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
      return;
    }
    for (final record in records) {
      if (record.provider != _platform.provider ||
          record.billingAccountId != billingAccountId) {
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
          } catch (_) {}
        }
        continue;
      }
      if (pastPurchaseKeys.contains(record.key)) continue;
      await _processRecord(record);
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
      attempt?.product.googleProductId ?? purchase.productId,
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
        return;
      case BillingPurchaseStatus.error:
        _clearAttempt(purchase, attempt);
        _emitFailure(
          productId,
          attemptId,
          _purchaseDetailsFailureMessage(purchase),
        );
        return;
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        break;
    }

    if (token.isEmpty) {
      _clearAttempt(purchase, attempt);
      _emitFailure(productId, attemptId, 'Purchase failed.');
      return;
    }
    if (attempt != null) _attemptByPurchaseToken[token] = attempt;

    final processingKey = '${purchase.provider.name}:$token';
    if (_completedPurchaseKeys.contains(processingKey)) return;
    if (!_processingPurchaseKeys.add(processingKey)) return;
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
        if (resolvedAttempt == null) return;
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
          _emitDeferred(resolvedAttempt.product.productId, resolvedAttempt.id);
          return;
        }
      }
      await _processRecord(record, purchase: purchase);
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
      final reported = record.copyWith(
        status: BillingPendingPurchaseStatus.reported,
        updatedAt: DateTime.now(),
      );
      await _pendingPurchaseStore.upsert(reported);
    } catch (_) {
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
      );
      try {
        await _pendingPurchaseStore.upsert(next);
      } catch (_) {}
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
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
        _clearActiveAttempt(product.googleProductId, activeAttempt!);
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
