part of 'google_play_billing_service.dart';

extension _GooglePlayBillingTracking on GooglePlayBillingService {
  void _emitFailure(
    String productId,
    String attemptId,
    String message, {
    required String debugInfo,
  }) {
    _emitUiEvent(
      BillingUiEvent(
        kind: BillingUiEventKind.failure,
        productId: productId,
        attemptId: attemptId,
        message: message,
        debugInfo: debugInfo,
      ),
    );
    _setBusy(productId, false);
  }

  void _emitDeferred(
    String productId,
    String attemptId, {
    required String debugInfo,
  }) {
    _emitUiEvent(
      BillingUiEvent(
        kind: BillingUiEventKind.deferred,
        productId: productId,
        attemptId: attemptId,
        message: 'Payment is being confirmed.',
        debugInfo: debugInfo,
      ),
    );
  }

  void _scheduleAttemptTimeout(
    String timerKey, {
    required DateTime startedAt,
    required VoidCallback onTimeout,
  }) {
    _cancelAttemptTimeout(timerKey);
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = elapsed < _attemptTimeout
        ? _attemptTimeout - elapsed
        : Duration.zero;
    _attemptTimeouts[timerKey] = Timer(remaining, () {
      _attemptTimeouts.remove(timerKey);
      onTimeout();
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
    final code = switch (error) {
      BillingPlatformException(:final code) => code,
      PlatformException(:final code) => code,
      _ => null,
    };
    return _storeFailureMessage(code, fallback: 'Purchase failed.');
  }

  String _platformFailureErrorCode(Object error) {
    final code = switch (error) {
      PlatformException(:final code) => code,
      BillingPlatformException(:final code) => code,
      _ => '',
    }.trim();
    return code.isEmpty ? 'unknown' : code;
  }

  String _productQueryFailureMessage(String? errorCode) {
    return _storeFailureMessage(
      errorCode,
      fallback: errorCode?.trim().isEmpty != false
          ? 'This product is currently unavailable.'
          : 'Purchase failed.',
    );
  }

  String _purchaseDetailsFailureMessage(BillingPurchase purchase) {
    return _storeFailureMessage(
      purchase.errorCode ?? purchase.rawErrorCode,
      fallback: 'Purchase failed.',
    );
  }

  String _storeFailureMessage(String? code, {required String fallback}) {
    final normalized = code?.trim().toLowerCase() ?? '';
    if (normalized.contains('user_canceled') ||
        normalized.contains('user_cancelled') ||
        normalized.contains('usercanceled') ||
        normalized.contains('payment_cancelled')) {
      return 'Purchase canceled.';
    }
    if (normalized.contains('network') ||
        normalized.contains('service_disconnected') ||
        normalized.contains('servicedisconnected') ||
        normalized.contains('service_unavailable') ||
        normalized.contains('serviceunavailable') ||
        normalized.contains('service_timeout')) {
      return 'Unable to connect to the store. Please try again.';
    }
    if (normalized.contains('product_not_found') ||
        normalized.contains('product_not_purchasable') ||
        normalized.contains('item_unavailable') ||
        normalized.contains('itemunavailable') ||
        normalized.contains('store_product_id_missing')) {
      return 'This product is currently unavailable.';
    }
    if (normalized.contains('billing_unavailable') ||
        normalized.contains('billingunavailable')) {
      return 'Purchases are unavailable on this device.';
    }
    return fallback;
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
      failureReason: switch (errorCode) {
        'gp_unavailable' => 'service_unavailable',
        'product_not_purchasable' ||
        'store_product_id_missing' ||
        'unsupported_product_type' => 'catalog_unavailable',
        _ => errorCode,
      },
    );
  }

  void _trackFlowResult(
    GemProduct product,
    String attemptId,
    String status, {
    String? errorCode,
    String? failureReason,
  }) {
    _trackFlowResultById(
      attemptId: attemptId,
      productId: product.productId,
      storeProductId: _storeProductIdFor(product, _platform.provider),
      status: status,
      source: BillingRecoverySource.direct,
      errorCode: errorCode,
      failureReason: failureReason,
    );
  }

  void _trackFlowResultById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String status,
    required BillingRecoverySource source,
    String? errorCode,
    String? failureReason,
  }) {
    final failedReason = _failedReasonForFlowResult(
      status: status,
      errorCode: errorCode,
    );
    if (failedReason != null) {
      if (attemptId.isNotEmpty && !_trackedFailedAttemptIds.add(attemptId)) {
        return;
      }
      _trackFailedById(
        attemptId: attemptId,
        productId: productId,
        storeProductId: storeProductId,
        reason: failedReason,
        errorCode:
            failedReason == 'precheck_failed' ||
                failedReason == 'purchase_callback_error' ||
                failedReason == 'query_failed' ||
                failedReason == 'launch_failed'
            ? errorCode
            : null,
        failureReason: failureReason,
      );
    }
  }

  void _trackFailedById({
    required String attemptId,
    required String productId,
    required String storeProductId,
    required String reason,
    String? errorCode,
    String? failureReason,
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
        if (failureReason?.trim().isNotEmpty == true)
          'failure_reason': failureReason!.trim(),
      },
    );
  }

  String? _storeFailureReason({
    Object? error,
    String? code,
    String? source,
    Object? details,
    required String stage,
    String? status,
  }) {
    return billingStoreFailureReason(
      _platform.provider,
      error: error,
      code: code,
      source: source,
      details: details,
      stage: stage,
      status: status,
      sdkFailureReason: (sdkCode, _, sdkStage) {
        switch (sdkCode) {
          case 'platform_unavailable':
            return 'service_unavailable';
          case 'product_not_found':
          case 'product_not_purchasable':
          case 'store_product_id_missing':
          case 'invalid_google_product':
          case 'invalid_app_store_product':
          case 'unsupported_product_type':
            return 'catalog_unavailable';
          case 'purchase_rejected':
            return 'store_failure[stage=$sdkStage]';
        }
        return null;
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

  void _trackPurchasedCallback(
    BillingPurchase purchase, {
    required String productId,
    int? priceAmountMicros,
    String priceCurrencyCode = '',
  }) {
    if (purchase.status != BillingPurchaseStatus.purchased) return;
    final receipt = purchase.provider == BillingProvider.googlePlay
        ? purchase.purchaseToken.trim()
        : purchase.transactionId.trim().isNotEmpty
        ? purchase.transactionId.trim()
        : purchase.purchaseToken.trim();
    if (receipt.isEmpty ||
        !_trackedPurchasedKeys.add('${purchase.provider.name}:$receipt')) {
      return;
    }
    _track(
      'purchase_success',
      productId: productId,
      storeProductId: purchase.productId,
      data: <String, Object?>{
        'transaction_id': purchase.transactionId,
        'event_id': const Uuid().v5(
          Namespace.url.value,
          'worldo:gems:${purchase.provider.apiValue}:$receipt',
        ),
      },
    );
    final reporter = purchaseEventReporting;
    if (reporter != null) {
      unawaited(
        reporter.recordPurchase(
          provider: purchase.provider.apiValue,
          productId: purchase.productId,
          kind: PurchaseEventKind.gems,
          purchaseIdentity: purchase.purchaseToken,
          transactionIdentity: receipt,
          priceAmountMicros: priceAmountMicros,
          priceCurrencyCode: priceCurrencyCode,
        ),
      );
    }
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
      'completed' => null,
      'precheck_failed' =>
        _precheckFailedReason(errorCode) == null ? null : 'precheck_failed',
      'query_failed' => 'query_failed',
      'launch_rejected' || 'launch_failed' => 'launch_failed',
      'stream_failed' => 'stream_failed',
      'canceled' => 'canceled',
      'store_failed' =>
        errorCode == 'purchase_token_missing'
            ? 'receipt_missing'
            : 'purchase_callback_error',
      _ => null,
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
}
