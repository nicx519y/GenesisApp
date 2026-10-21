part of 'google_play_billing_service.dart';

extension _GooglePlayBillingAttemptRegistry on GooglePlayBillingService {
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
    List<GemProduct>? productCatalog,
  }) async {
    String accountId;
    try {
      accountId = await _resolveBillingAccountId();
    } catch (_) {
      return null;
    }
    if (accountId.isEmpty) return null;
    try {
      final products = productCatalog ?? await _loadProductCatalog();
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
    int? priceAmountMicros,
    String priceCurrencyCode = '',
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
      priceAmountMicros: priceAmountMicros,
      priceCurrencyCode: priceCurrencyCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> _processRecord(
    BillingPendingPurchase record, {
    BillingPurchase? purchase,
    required BillingRecoverySource source,
    bool silent = false,
  }) async {
    String accountId;
    try {
      accountId = await _resolveBillingAccountId();
    } catch (_) {
      return;
    }
    if (accountId.isEmpty ||
        !_sameBillingAccount(accountId, record.billingAccountId)) {
      return;
    }

    late final GemPurchaseReport report;
    try {
      report = await _sendPurchaseReport(record, purchase: purchase);
    } catch (error) {
      _completedPurchaseKeys.add(record.key);
      if (!silent) {
        _emitDeferred(
          record.productId,
          record.attemptId,
          debugInfo: purchaseDebugInfo('gems.report', error: error),
        );
      }
      _setBusy(record.productId, false);
      return;
    }

    if (report.status == GemPurchaseReportStatus.completed) {
      _finishPurchaseAttempt(record, purchase);
      if (!silent) {
        _emitUiEvent(
          BillingUiEvent(
            kind: BillingUiEventKind.success,
            productId: record.productId,
            attemptId: record.attemptId,
            message: 'Purchase successful!',
            grantedGemsCent: report.grantedGemsCent!,
          ),
        );
      }
      _refreshWalletInBackground();
    } else {
      _finishPurchaseAttempt(record, purchase);
      if (!silent) {
        _emitFailure(
          record.productId,
          record.attemptId,
          GenesisL10n.current.gemsPurchaseRefunded,
          debugInfo: purchaseDebugInfo(
            'gems.report',
            status: report.status.name,
            reason: report.reason,
          ),
        );
      }
    }
    _completedPurchaseKeys.add(record.key);
  }

  Future<GemPurchaseReport> _sendPurchaseReport(
    BillingPendingPurchase record, {
    BillingPurchase? purchase,
  }) {
    return _reportPurchase(
      GemPurchaseReportRequest(
        provider: record.provider.apiValue,
        productId: record.productId,
        storeProductId: record.storeProductId,
        transactionId: record.transactionId,
        originalTransactionId:
            purchase?.originalTransactionId.trim().isNotEmpty == true
            ? purchase!.originalTransactionId
            : null,
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
  }

  Future<void> _processTransientStoreRecovery(
    BillingPendingPurchase record, {
    required BillingPurchase purchase,
  }) async {
    String currentAccountId;
    try {
      currentAccountId = await _resolveBillingAccountId();
    } catch (_) {
      return;
    }
    if (!_sameBillingAccount(currentAccountId, record.billingAccountId)) {
      return;
    }
    late final GemPurchaseReport report;
    try {
      report = await _sendPurchaseReport(record, purchase: purchase);
    } catch (error) {
      debugPrint('[Billing] transient store recovery report failed: $error');
      _completedPurchaseKeys.add(record.key);
      _emitDeferred(
        record.productId,
        record.attemptId,
        debugInfo: purchaseDebugInfo('gems.restore_report', error: error),
      );
      _setBusy(record.productId, false);
      return;
    }

    if (report.status == GemPurchaseReportStatus.completed) {
      _emitUiEvent(
        BillingUiEvent(
          kind: BillingUiEventKind.success,
          productId: record.productId,
          attemptId: record.attemptId,
          message: 'Purchase successful!',
          grantedGemsCent: report.grantedGemsCent!,
        ),
      );
      _refreshWalletInBackground();
    } else {
      _emitFailure(
        record.productId,
        record.attemptId,
        GenesisL10n.current.gemsPurchaseRefunded,
        debugInfo: purchaseDebugInfo(
          'gems.restore_report',
          status: report.status.name,
          reason: report.reason,
        ),
      );
    }
    _setBusy(record.productId, false);
    _completedPurchaseKeys.add(record.key);
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
      BillingProvider.googlePlay => GenesisL10n.current.meGooglePlayUnavailable,
      BillingProvider.appStore => GenesisL10n.current.gemsPaymentUnavailable,
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

  BillingPurchaseAttempt? _attemptForPurchase(BillingPurchase purchase) {
    final token = purchase.purchaseToken.trim();
    final tokenAttempt = _attemptByPurchaseToken[token];
    final interruptedAttempt =
        _interruptedAttemptByStoreProductId[purchase.productId];
    return tokenAttempt ??
        _attemptByStoreProductId[purchase.productId] ??
        interruptedAttempt ??
        _onlyActiveAttemptForStoreError(purchase);
  }

  bool _purchaseBelongsToBillingAccount(
    BillingPurchase purchase,
    BillingPurchaseAttempt? attempt,
    String billingAccountId,
  ) {
    final currentAccountId = billingAccountId.trim();
    if (currentAccountId.isEmpty) return false;
    if (attempt != null &&
        !_sameBillingAccount(attempt.billingAccountId, currentAccountId)) {
      return false;
    }
    final purchaseAccountId = purchase.obfuscatedAccountId?.trim() ?? '';
    if (purchaseAccountId.isNotEmpty) {
      return _sameBillingAccount(purchaseAccountId, currentAccountId);
    }
    return attempt != null &&
        _sameBillingAccount(attempt.billingAccountId, currentAccountId);
  }

  bool _storePurchaseBelongsToCurrentAccount(
    BillingPurchase purchase,
    String billingAccountId,
  ) {
    final currentAccountId = billingAccountId.trim();
    if (currentAccountId.isEmpty) return false;
    final platformAccountId = purchase.obfuscatedAccountId?.trim() ?? '';
    return platformAccountId.isNotEmpty &&
        _sameBillingAccount(platformAccountId, currentAccountId);
  }

  bool _sameBillingAccount(String first, String second) {
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  void _clearActiveAttempt(
    String storeProductId,
    BillingPurchaseAttempt attempt,
  ) {
    final current = _attemptByStoreProductId[storeProductId];
    if (current?.id == attempt.id) {
      _attemptByStoreProductId.remove(storeProductId);
    }
    if (_interruptedAttemptByStoreProductId[storeProductId]?.id == attempt.id) {
      _interruptedAttemptByStoreProductId.remove(storeProductId);
    }
    _cancelAttemptTimeout(storeProductId);
    _attemptByPurchaseToken.removeWhere(
      (_, candidate) => candidate.id == attempt.id,
    );
    _setBusy(attempt.product.productId, false);
  }
}
