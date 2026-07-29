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
    final service =
        _billingService ??
        widget.billingService ??
        AppServicesScope.maybeRead(context)?.billing;
    if (service == null) {
      showGenesisToast(context, 'Google Play is unavailable.');
      return;
    }
    _bindBillingService(service);
    if (service.state.value.hasBusyPurchase) return;
    _showBillingPurchaseProcessing();
    try {
      await service.purchaseGem(
        product,
        source: BillingPurchaseSource.buyGemsPage,
        payTrackId: billingPurchaseTrackId(_payTrackPageId),
      );
    } catch (_) {
      if (!mounted) return;
      _dismissBillingPurchaseDialog();
      showGenesisToast(context, 'Purchase failed.');
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
        unawaited(_refreshProducts(silent: true));
        unawaited(_refreshTasks(silent: true));
        return;
      case BillingUiEventKind.accepted:
      case BillingUiEventKind.failure:
      case BillingUiEventKind.pending:
      case BillingUiEventKind.deferred:
        _dismissBillingPurchaseDialog();
        showGenesisToast(context, event.message);
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
    final grantedGems = event.grantedGems;
    final grantedText = grantedGems > 0 ? formatGemInteger(grantedGems) : '';
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
    unawaited(
      showGenesisGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Center(
            child: GemBillingPurchaseDialog(
              state: dialogState,
              onConfirm: _dismissBillingPurchaseDialog,
            ),
          );
        },
      ).whenComplete(() {
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
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _disposeBillingPurchaseDialogState() {
    final dialogState = _billingPurchaseDialogState;
    if (dialogState != null) {
      _billingPurchaseDialogState = null;
      dialogState.dispose();
    }
  }
}
