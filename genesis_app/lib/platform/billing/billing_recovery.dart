part of 'google_play_billing_service.dart';

extension _GooglePlayBillingRecovery on GooglePlayBillingService {
  Future<bool> _recoverStorePurchases({
    List<GemProduct>? productCatalog,
  }) async {
    await start();
    if (_disposed || !_state.value.storeAvailable) return false;

    String billingAccountId;
    try {
      billingAccountId = await _resolveBillingAccountId();
    } catch (_) {
      return false;
    }
    if (billingAccountId.isEmpty || _disposed) return false;

    late final List<BillingPurchase> purchases;
    try {
      purchases = await _platform.queryRecoverablePurchases();
    } catch (error) {
      debugPrint('[Billing] store recovery query failed: $error');
      return false;
    }

    final seenPurchaseKeys = <String>{};
    for (final purchase in purchases) {
      if (await _routeSubscription(purchase, productCatalog: productCatalog)) {
        continue;
      }
      final purchaseIdentity = purchase.purchaseToken.trim();
      final purchaseKey = '${purchase.provider.name}:$purchaseIdentity';
      if (purchaseIdentity.isNotEmpty && !seenPurchaseKeys.add(purchaseKey)) {
        continue;
      }
      await _recoverStorePurchase(
        purchase,
        billingAccountId: billingAccountId,
        productCatalog: productCatalog,
      );
    }
    return true;
  }

  Future<void> _recoverStorePurchase(
    BillingPurchase purchase, {
    required String billingAccountId,
    List<GemProduct>? productCatalog,
  }) async {
    if (purchase.status != BillingPurchaseStatus.purchased) return;
    final token = purchase.purchaseToken.trim();
    if (token.isEmpty) {
      debugPrint('[Billing] skipped store recovery without purchase identity');
      return;
    }

    final fallbackAttemptId = newBillingAttemptId();
    if (!_storePurchaseBelongsToCurrentAccount(purchase, billingAccountId)) {
      debugPrint('[Billing] skipped store recovery for another account');
      return;
    }
    final recoveredAttempt = await _recoveredAttemptFor(
      purchase,
      source: BillingRecoverySource.foreground,
      fallbackAttemptId: fallbackAttemptId,
      productCatalog: productCatalog,
    );
    if (recoveredAttempt == null) return;
    final now = DateTime.now();
    final record = _purchaseRecord(
      purchase: purchase,
      attemptId: recoveredAttempt.id,
      billingAccountId: recoveredAttempt.billingAccountId,
      productId: recoveredAttempt.product.productId,
      status: BillingPendingPurchaseStatus.received,
      createdAt: now,
      updatedAt: now,
      priceAmountMicros: recoveredAttempt.priceAmountMicros,
      priceCurrencyCode: recoveredAttempt.priceCurrencyCode,
    );
    _recordVerifiedPurchaseForAnalytics(purchase);
    final processingKey = record.key;
    await _runExclusivePurchase(processingKey, () async {
      await _processTransientStoreRecovery(record, purchase: purchase);
    });
  }

  Future<void> _recoverInternal(
    BillingRecoverySource source, {
    required int sessionGeneration,
  }) async {
    if (_disposed || sessionGeneration != _sessionGeneration) return;
    // Retire legacy Gems rows; new checkouts never read or write this table.
    List<BillingPendingPurchase> records;
    try {
      records = await _pendingPurchaseStore.loadAll();
    } catch (_) {
      return;
    }
    for (final record in records) {
      try {
        await _pendingPurchaseStore.remove(
          provider: record.provider,
          purchaseToken: record.purchaseToken,
        );
      } catch (_) {}
    }
  }

  Future<void> _handlePurchases(
    List<BillingPurchase> purchases, {
    required BillingRecoverySource source,
    String? billingAccountId,
    int? sessionGeneration,
  }) async {
    final gemPurchases = <BillingPurchase>[];
    for (final purchase in purchases) {
      if (!await _routeSubscription(purchase)) gemPurchases.add(purchase);
    }
    purchases = gemPurchases;
    if (purchases.isEmpty) return;
    var currentBillingAccountId = billingAccountId?.trim() ?? '';
    if (purchases.isNotEmpty && currentBillingAccountId.isEmpty) {
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

  void _recordVerifiedPurchaseForAnalytics(BillingPurchase purchase) {
    if (purchase.status != BillingPurchaseStatus.purchased &&
        purchase.status != BillingPurchaseStatus.restored) {
      return;
    }
    try {
      _platform.recordVerifiedPurchaseForAnalytics(purchase);
    } catch (error) {
      debugPrint('[Billing] store transaction analytics failed: $error');
    }
  }

  Future<void> _handlePurchase(
    BillingPurchase purchase, {
    required BillingRecoverySource source,
    required String billingAccountId,
  }) async {
    final token = purchase.purchaseToken.trim();
    final attempt = _attemptForPurchase(purchase);
    if (!_purchaseBelongsToBillingAccount(
      purchase,
      attempt,
      billingAccountId,
    )) {
      debugPrint(
        '[Billing] ignored purchase callback without a matching account',
      );
      return;
    }
    _recordVerifiedPurchaseForAnalytics(purchase);
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
        final pendingKey = token.isEmpty
            ? attemptId
            : '${purchase.provider.name}:$token';
        if (_trackedPendingAttemptIds.add(pendingKey)) {
          _trackPendingById(
            attemptId: attemptId,
            productId: productId,
            storeProductId: purchase.productId,
          );
        }
        _emitUiEvent(
          BillingUiEvent(
            kind: BillingUiEventKind.pending,
            productId: productId,
            attemptId: attemptId,
            message: GenesisL10n.current.gemsPaymentPending,
            debugInfo: purchaseDebugInfo(
              'gems.store_callback',
              status: purchase.status.name,
            ),
          ),
        );
        return;
      case BillingPurchaseStatus.canceled:
        _clearAttempt(purchase, attempt);
        _emitUiEvent(
          BillingUiEvent(
            kind: BillingUiEventKind.failure,
            productId: productId,
            attemptId: attemptId,
            message: GenesisL10n.current.purchaseCanceled,
            debugInfo: purchaseDebugInfo(
              'gems.store_callback',
              status: purchase.status.name,
            ),
          ),
        );
        _trackFlowResultById(
          attemptId: attemptId,
          productId: productId,
          storeProductId: purchase.productId,
          status: 'canceled',
          source: source,
          failureReason: _storeFailureReason(
            code: purchase.rawErrorCode ?? purchase.errorCode,
            source: purchase.errorSource,
            details: purchase.errorDetails,
            stage: 'callback',
            status: 'canceled',
          ),
        );
        return;
      case BillingPurchaseStatus.error:
        _clearAttempt(purchase, attempt);
        _emitFailure(
          productId,
          attemptId,
          _purchaseDetailsFailureMessage(purchase),
          debugInfo: purchaseDebugInfo(
            'gems.store_callback',
            status: purchase.status.name,
            errorCode: purchase.errorCode,
            errorMessage: purchase.errorMessage,
          ),
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
          failureReason: _storeFailureReason(
            code: purchase.rawErrorCode ?? purchase.errorCode,
            source: purchase.errorSource,
            details: purchase.errorDetails,
            stage: 'callback',
            status: 'error',
          ),
        );
        return;
      case BillingPurchaseStatus.purchased:
      case BillingPurchaseStatus.restored:
        break;
    }

    if (purchase.status != BillingPurchaseStatus.purchased) return;

    if (token.isEmpty) {
      _clearAttempt(purchase, attempt);
      if (attempt != null) {
        // Keep this attempt available if the store later supplies the receipt.
        _interruptedAttemptByStoreProductId[purchase.productId] = attempt;
      }
      _trackFlowResultById(
        attemptId: attemptId,
        productId: productId,
        storeProductId: purchase.productId,
        status: 'store_failed',
        source: source,
        errorCode: 'purchase_token_missing',
      );
      _emitFailure(
        productId,
        attemptId,
        GenesisL10n.current.mePurchaseFailed,
        debugInfo: purchaseDebugInfo(
          'gems.store_callback',
          reason: 'receipt_missing',
        ),
      );
      return;
    }
    if (attempt != null) _attemptByPurchaseToken[token] = attempt;

    final resolvedAttempt =
        attempt ??
        await _recoveredAttemptFor(
          purchase,
          source: source,
          fallbackAttemptId: attemptId,
        );
    if (resolvedAttempt == null ||
        !_sameBillingAccount(
          resolvedAttempt.billingAccountId,
          billingAccountId,
        )) {
      return;
    }

    _trackPurchasedCallback(
      purchase,
      productId: resolvedAttempt.product.productId,
      priceAmountMicros: resolvedAttempt.priceAmountMicros,
      priceCurrencyCode: resolvedAttempt.priceCurrencyCode,
    );

    final processingKey = '${purchase.provider.name}:$token';
    if (_disposed || _completedPurchaseKeys.contains(processingKey)) return;
    if (!_beginExclusivePurchase(processingKey)) return;
    _emitUiEvent(
      BillingUiEvent(
        kind: BillingUiEventKind.processing,
        productId: productId,
        attemptId: attemptId,
        message: 'Purchasing Gems',
      ),
    );
    try {
      final now = DateTime.now();
      final record = _purchaseRecord(
        purchase: purchase,
        attemptId: resolvedAttempt.id,
        billingAccountId: resolvedAttempt.billingAccountId,
        productId: resolvedAttempt.product.productId,
        status: BillingPendingPurchaseStatus.received,
        createdAt: now,
        updatedAt: now,
        priceAmountMicros: resolvedAttempt.priceAmountMicros,
        priceCurrencyCode: resolvedAttempt.priceCurrencyCode,
      );
      await _processRecord(record, purchase: purchase, source: source);
    } finally {
      _endExclusivePurchase(processingKey);
    }
  }
}
