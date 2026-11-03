part of 'gem_wallet_page.dart';

extension _GemWalletBillingFlow on _GemWalletPageState {
  void _bindBillingService(BillingService service) {
    if (identical(_billingService, service)) return;
    _billingEvents?.cancel();
    _billingService = service;
    _billingEvents = service.events.listen(_handleBillingEvent);
    unawaited(service.start());
    if (mounted) _updateState(() {});
  }

  Future<void> _purchaseProduct(GemProduct product) async {
    if (_isProductRefreshBlocking ||
        _productsError != null ||
        _checkingStorePrice) {
      return;
    }
    final service =
        _billingService ??
        widget.billingService ??
        AppServicesScope.maybeRead(context)?.billing;
    if (service?.state.value.hasBusyPurchase == true) return;
    final clickAttemptId = newBillingAttemptId();
    final budget = CheckoutPreparationBudget();
    _showBillingPurchaseProcessing();
    if (product.requiresStorePrice) {
      final catalog = AppServicesScope.read(context).gemStoreCatalog;
      _checkingStorePrice = true;
      try {
        final fresh = await budget.wait(catalog.confirm(product));
        if (!mounted) return;
        _updateState(() {
          _products = catalog.cached;
        });
        if (fresh == null) {
          reportGemConfirmationFailure(
            product: product,
            attemptId: clickAttemptId,
            source: BillingPurchaseSource.buyGemsPage.value,
            reason: 'catalog_unavailable',
            currentProducts: catalog.cached,
            durationMs: DateTime.now()
                .difference(budget.startedAt)
                .inMilliseconds,
          );
          _dismissBillingPurchaseDialog();
          return;
        }
        product = fresh;
      } on TimeoutException {
        reportGemConfirmationTimeout(
          product: product,
          attemptId: clickAttemptId,
        );
        _dismissBillingPurchaseDialog();
        if (mounted) {
          showGenesisToast(context, GenesisL10n.current.gemsPurchaseTimeout);
        }
        return;
      } catch (error, stackTrace) {
        reportGemConfirmationFailure(
          product: product,
          attemptId: clickAttemptId,
          source: BillingPurchaseSource.buyGemsPage.value,
          reason: 'store_query_error',
          error: error,
          stackTrace: stackTrace,
          durationMs: DateTime.now()
              .difference(budget.startedAt)
              .inMilliseconds,
        );
        _dismissBillingPurchaseDialog();
        if (mounted) unawaited(_refreshProducts(silent: true));
        return;
      } finally {
        _checkingStorePrice = false;
      }
    }
    if (service == null) {
      _dismissBillingPurchaseDialog();
      const analytics = GenesisBillingAnalytics();
      analytics.track(
        'product_click',
        properties: <String, Object?>{
          'product_id': product.productId,
          'source': BillingPurchaseSource.buyGemsPage.value,
        },
      );
      analytics.track(
        'purchase_failed',
        properties: <String, Object?>{
          'product_id': product.productId,
          'attempt_id': clickAttemptId,
          'source': BillingPurchaseSource.buyGemsPage.value,
          'provider': defaultTargetPlatform == TargetPlatform.iOS
              ? 'apple'
              : defaultTargetPlatform == TargetPlatform.android
              ? 'google'
              : 'unknown',
          'store_product_id': defaultTargetPlatform == TargetPlatform.iOS
              ? product.appleProductId
              : product.googleProductId,
          'reason': 'precheck_failed',
          'error_code': 'service_unavailable',
          'failure_diagnostics': {
            'stage': 'prepare',
            'step': 'resolve_billing_service',
            'error_layer': 'business',
          },
        },
      );
      showGenesisToast(
        context,
        purchaseToastMessage(
          GenesisL10n.current.meGooglePlayUnavailable,
          debugInfo: purchaseDebugInfo(
            'gems.precheck',
            reason: 'service_unavailable',
          ),
        ),
      );
      return;
    }
    _bindBillingService(service);
    if (service.state.value.hasBusyPurchase) return;
    _showBillingPurchaseProcessing();
    try {
      await budget.run(
        () => service.purchaseGem(
          product,
          source: BillingPurchaseSource.buyGemsPage,
          operationId: clickAttemptId,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _dismissBillingPurchaseDialog();
      showGenesisToast(
        context,
        purchaseToastMessage(
          GenesisL10n.current.mePurchaseFailed,
          debugInfo: purchaseDebugInfo('gems.checkout_exception', error: error),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (!service.state.value.hasBusyPurchase &&
        _billingPurchaseDialogState?.value.phase ==
            GemBillingPurchaseDialogPhase.processing) {
      _dismissBillingPurchaseDialog();
    }
  }

  void _handleBillingEvent(BillingUiEvent event) {
    if (!mounted) return;
    switch (event.kind) {
      case BillingUiEventKind.processing:
        _showBillingPurchaseProcessing(attemptId: event.attemptId);
        return;
      case BillingUiEventKind.success:
        _showBillingPurchaseSuccess(event);
        unawaited(_refreshAll(silent: true));
        return;
      case BillingUiEventKind.failure:
      case BillingUiEventKind.pending:
      case BillingUiEventKind.deferred:
        _dismissBillingPurchaseDialog();
        if (event.requiresProductRefresh) unawaited(_refreshAll(silent: true));
        showGenesisToast(
          context,
          purchaseToastMessage(
            event.message,
            debugInfo:
                event.debugInfo ??
                purchaseDebugInfo('gems.checkout', status: event.kind.name),
          ),
        );
    }
  }

  void _showBillingPurchaseProcessing({String attemptId = ''}) {
    final nextState = GemBillingPurchaseDialogState.processing(
      attemptId: attemptId,
    );
    final notifier = _billingPurchaseDialogState;
    if (notifier != null) {
      notifier.value = nextState;
    } else {
      _billingPurchaseDialogState =
          ValueNotifier<GemBillingPurchaseDialogState>(nextState);
    }
    _presentBillingPurchaseDialog();
  }

  void _showBillingPurchaseSuccess(BillingUiEvent event) {
    final grantedGemsCent = event.grantedGemsCent;
    final grantedText = formatGemCent(grantedGemsCent);
    final nextState = GemBillingPurchaseDialogState.success(
      attemptId: event.attemptId,
      grantedText: grantedText,
    );
    final notifier = _billingPurchaseDialogState;
    if (notifier != null) {
      notifier.value = nextState;
      return;
    }
    _billingPurchaseDialogState = ValueNotifier<GemBillingPurchaseDialogState>(
      nextState,
    );
    _presentBillingPurchaseDialog();
  }

  void _presentBillingPurchaseDialog() {
    _billingPurchaseDialogState ??=
        ValueNotifier<GemBillingPurchaseDialogState>(
          GemBillingPurchaseDialogState.processing(attemptId: ''),
        );
    if (_billingPurchaseDialogShowing) return;
    _billingPurchaseDialogShowing = true;
    if (mounted) _updateState(() {});
    final dialogState = _billingPurchaseDialogState!;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = RawDialogRoute<void>(
      barrierColor: kGenesisModalBarrierColor,
      barrierDismissible: false,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: GemBillingPurchaseDialog(
            state: dialogState,
            onConfirm: _dismissBillingPurchaseDialog,
          ),
        );
      },
    );
    _billingPurchaseDialogRoute = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(_billingPurchaseDialogRoute, route)) {
          _billingPurchaseDialogRoute = null;
        }
        if (!mounted) {
          _disposeBillingPurchaseDialogState();
          return;
        }
        _billingPurchaseDialogShowing = false;
        _billingPurchaseDialogDismissing = false;
        _disposeBillingPurchaseDialogState();
        _updateState(() {});
      }),
    );
  }

  void _dismissBillingPurchaseDialog() {
    if (!_billingPurchaseDialogShowing) {
      _disposeBillingPurchaseDialogState();
      return;
    }
    if (_billingPurchaseDialogDismissing) return;
    _billingPurchaseDialogDismissing = true;
    final route = _billingPurchaseDialogRoute;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  void _disposeBillingPurchaseDialogState() {
    final dialogState = _billingPurchaseDialogState;
    if (dialogState != null) {
      _billingPurchaseDialogState = null;
      dialogState.dispose();
    }
  }
}
