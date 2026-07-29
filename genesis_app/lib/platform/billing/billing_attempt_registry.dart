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
    } catch (error) {
      final isTimeout =
          error is ApiException && error.kind == ApiExceptionKind.timeout;
      var shouldTrackTimeout = false;
      if (isTimeout && !record.reportTimeoutTracked) {
        try {
          shouldTrackTimeout = await _pendingPurchaseStore
              .markReportTimeoutTracked(
                provider: record.provider,
                purchaseToken: record.purchaseToken,
              );
        } catch (_) {}
      }
      final next = record.copyWith(
        retryCount: record.retryCount + 1,
        updatedAt: DateTime.now(),
        reportTimeoutTracked: record.reportTimeoutTracked || shouldTrackTimeout,
      );
      try {
        await _pendingPurchaseStore.upsert(next);
      } catch (_) {}
      if (shouldTrackTimeout) {
        _trackTimeoutById(
          attemptId: record.attemptId,
          productId: record.productId,
          storeProductId: record.storeProductId,
          timeoutType: 'report',
        );
      }
      _emitDeferred(record.productId, record.attemptId);
      _setBusy(record.productId, false);
      return;
    }

    final serverTransactionId = report.transactionId.trim();

    if (report.status == GemPurchaseReportStatus.completed) {
      if (!await _deletePurchaseRecord(record)) {
        await _handleLocalOrderMutationFailure(record);
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
      _events.add(
        BillingUiEvent(
          kind: BillingUiEventKind.success,
          productId: record.productId,
          attemptId: record.attemptId,
          message: 'Purchase successful!',
          grantedGems: report.grantedGems,
        ),
      );
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
        await _handleLocalOrderMutationFailure(record);
        return;
      }
      _finishPurchaseAttempt(record, purchase);
      if (record.status != BillingPendingPurchaseStatus.accepted) {
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
        await _handleLocalOrderMutationFailure(record);
        return;
      }
      _finishPurchaseAttempt(record, purchase);
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
    BillingPendingPurchase record,
  ) async {
    final next = record.copyWith(
      retryCount: record.retryCount + 1,
      updatedAt: DateTime.now(),
    );
    try {
      await _pendingPurchaseStore.upsert(next);
    } catch (_) {}
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
}
