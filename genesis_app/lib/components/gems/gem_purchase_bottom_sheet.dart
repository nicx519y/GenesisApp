import '../../l10n/genesis_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'subscription_tracking_scope.dart';
import '../../app/membership/subscription_analytics.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/gem_wallet_store.dart';
import '../../app/debug/billing_price_diagnostics.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../network/models/gem_product.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/billing_service.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';
import '../../utils/gem_amount.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_modal_routes.dart';
import 'gem_billing_purchase_dialog.dart';
import 'gem_purchase_state.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_purchase_catalog.dart';
import 'purchase_options_sheet.dart';
import 'purchase_session_builder.dart';

typedef GemPurchaseProductsLoader = Future<List<GemProduct>> Function();

Future<void> showGemPurchaseBottomSheet(
  BuildContext context, {
  String? analyticsTrigger,
  GemPurchaseProductsLoader? productsLoader,
  GemWalletStore? walletStore,
  BillingService? billingService,
}) async {
  final services = AppServicesScope.maybeRead(context);
  final resolvedProductsLoader =
      productsLoader ?? services?.gemStoreCatalog.load;
  final resolvedWalletStore = walletStore ?? services?.gemWallet;
  final resolvedBillingService = billingService ?? services?.billing;
  if (resolvedProductsLoader == null ||
      resolvedWalletStore == null ||
      resolvedBillingService == null) {
    if (context.mounted) {
      showGenesisToast(
        context,
        purchaseToastMessage(
          GenesisL10n.current.gemsUnableLoadGemPacks,
          debugInfo: purchaseDebugInfo(
            'gems.precheck',
            reason: 'service_unavailable',
          ),
        ),
      );
    }
    return;
  }

  final analyticsPageId = newBillingPageId();
  _trackGemPurchaseSheetShow(analyticsTrigger);

  await showGenesisModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      key: const ValueKey<String>('gem-purchase-sheet-size'),
      heightFactor: 0.8,
      alignment: Alignment.bottomCenter,
      child: PurchaseOptionsSheet(
        analyticsPageId: analyticsPageId,
        gemsBuilder: (_) => GemPurchaseBottomSheet(
          productsLoader: resolvedProductsLoader,
          walletStore: resolvedWalletStore,
          billingService: resolvedBillingService,
        ),
      ),
    ),
  );
}

Future<void> showSubscriptionPurchaseBottomSheet(
  BuildContext context, {
  SubscriptionSource source = SubscriptionSource.unknown,
}) async {
  final services = AppServicesScope.maybeRead(context);
  final billingService = services?.billing;
  final analyticsPageId = newBillingPageId();
  final subscriptionTracking = SubscriptionPageTracking(
    pageId: analyticsPageId,
    source: source,
  );
  await showGenesisModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      alignment: Alignment.bottomCenter,
      child: PurchaseSessionBuilder(
        backgroundColor: GenesisColors.darkRaisedBackground,
        builder: (_, showBuyGems) => PurchaseOptionsSheet(
          showBuyGems: showBuyGems,
          initialTab: PurchaseSheetTab.subscription,
          analyticsPageId: analyticsPageId,
          subscriptionSource: source,
          subscriptionTracking: subscriptionTracking,
          onFirstBuyGems: () => _trackGemPurchaseSheetShow('subscription_tab'),
          gemsBuilder: (_) => services == null || billingService == null
              ? const SizedBox.expand()
              : GemPurchaseBottomSheet(
                  productsLoader: services.gemStoreCatalog.load,
                  walletStore: services.gemWallet,
                  billingService: billingService,
                ),
        ),
      ),
    ),
  );
}

void _trackGemPurchaseSheetShow(String? analyticsTrigger) {
  final trigger = analyticsTrigger?.trim() ?? '';
  GenesisTelemetry.collectLog(
    actionType: 'pay_event',
    action: 'buy_page_show',
    object1: BillingPurchaseSource.buyGemsSheet.value,
    object3: trigger.isEmpty ? null : trigger,
  );
}

/// Buy Gems content embedded in PurchaseOptionsSheet, which owns the header.
class GemPurchaseBottomSheet extends StatefulWidget {
  const GemPurchaseBottomSheet({
    super.key,
    required this.productsLoader,
    required this.walletStore,
    required this.billingService,
  });

  final GemPurchaseProductsLoader productsLoader;
  final GemWalletStore walletStore;
  final BillingService billingService;

  @override
  State<GemPurchaseBottomSheet> createState() => _GemPurchaseBottomSheetState();
}

class _GemPurchaseBottomSheetState extends State<GemPurchaseBottomSheet>
    with WidgetsBindingObserver {
  bool _checkingPrice = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_checkingPrice &&
        !widget.billingService.state.value.hasBusyPurchase) {
      unawaited(_loadProducts());
    }
  }

  List<GemProduct>? _products;
  Object? _productsError;
  bool _productsLoading = false;
  int _productsRequestGeneration = 0;
  StreamSubscription<BillingUiEvent>? _billingEvents;
  final Set<String> _startedProductIds = <String>{};
  ValueNotifier<GemBillingPurchaseDialogState>? _purchaseDialogState;
  bool _purchaseDialogShowing = false;
  bool _purchaseDialogDismissing = false;
  bool _closeSheetAfterDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billingEvents = widget.billingService.events.listen(_handleBillingEvent);
    unawaited(widget.billingService.start());
    unawaited(widget.walletStore.refresh());
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _productsRequestGeneration += 1;
    _billingEvents?.cancel();
    _disposePurchaseDialogState();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final generation = ++_productsRequestGeneration;
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    final catalog = AppServicesScope.maybeRead(context)?.gemStoreCatalog;
    if (catalog != null) {
      unawaited(() async {
        final snapshot = await catalog.loadCached();
        if (!mounted ||
            generation != _productsRequestGeneration ||
            !_productsLoading ||
            snapshot == null) {
          return;
        }
        setState(() {
          _products = snapshot;
        });
        billingPriceDiagnostics.recordGems(
          surface: 'Buy Gems sheet',
          snapshotSource: 'cache',
          products: snapshot,
        );
      }());
    }
    try {
      final products = await widget.productsLoader();
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _products = products;
        _productsLoading = false;
      });
      billingPriceDiagnostics.recordGems(
        surface: 'Buy Gems sheet',
        snapshotSource: 'fresh',
        products: products,
        lookupStatuses: catalog?.lastStoreLookupStatuses ?? const {},
      );
    } catch (error) {
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _productsError = error;
        _productsLoading = false;
      });
      billingPriceDiagnostics.recordFailure('Buy Gems sheet', error);
    }
  }

  Future<void> _purchase(GemProduct product) async {
    if (_checkingPrice || widget.billingService.state.value.hasBusyPurchase) {
      return;
    }
    if (product.requiresStorePrice) {
      final catalog = AppServicesScope.maybeRead(context)?.gemStoreCatalog;
      if (catalog == null) return;
      _checkingPrice = true;
      try {
        final fresh = await catalog.confirm(product);
        if (!mounted) return;
        setState(() {
          _products = catalog.cached;
        });
        if (catalog.cached case final products?) {
          billingPriceDiagnostics.recordGems(
            surface: 'Buy Gems sheet',
            snapshotSource: 'fresh',
            products: products,
            lookupStatuses: catalog.lastStoreLookupStatuses,
          );
        }
        if (fresh == null) return;
        product = fresh;
      } catch (_) {
        if (mounted) unawaited(_loadProducts());
        return;
      } finally {
        _checkingPrice = false;
      }
    }
    _startedProductIds.add(product.productId);
    _showPurchaseProcessing(attemptId: '');
    try {
      await widget.billingService.purchaseGem(
        product,
        source: BillingPurchaseSource.buyGemsSheet,
      );
    } catch (error) {
      if (!mounted) return;
      _startedProductIds.remove(product.productId);
      _dismissPurchaseDialog();
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
    if (!widget.billingService.state.value.hasBusyPurchase &&
        _purchaseDialogState?.value.phase ==
            GemBillingPurchaseDialogPhase.processing) {
      _dismissPurchaseDialog();
    }
  }

  void _handleBillingEvent(BillingUiEvent event) {
    if (!mounted || !_startedProductIds.contains(event.productId)) return;
    switch (event.kind) {
      case BillingUiEventKind.processing:
        _showPurchaseProcessing(attemptId: event.attemptId);
        return;
      case BillingUiEventKind.success:
        _showPurchaseSuccess(event);
        return;
      case BillingUiEventKind.failure:
      case BillingUiEventKind.pending:
      case BillingUiEventKind.deferred:
        _startedProductIds.remove(event.productId);
        _dismissPurchaseDialog();
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

  void _showPurchaseProcessing({required String attemptId}) {
    final nextState = GemBillingPurchaseDialogState.processing(
      attemptId: attemptId,
    );
    final notifier = _purchaseDialogState;
    if (notifier != null) {
      notifier.value = nextState;
    } else {
      _purchaseDialogState = ValueNotifier<GemBillingPurchaseDialogState>(
        nextState,
      );
    }
    _presentPurchaseDialog();
  }

  void _showPurchaseSuccess(BillingUiEvent event) {
    final grantedGemsCent = event.grantedGemsCent;
    final nextState = GemBillingPurchaseDialogState.success(
      attemptId: event.attemptId,
      grantedText: formatGemCent(grantedGemsCent),
    );
    _updatePurchaseDialog(nextState);
  }

  void _updatePurchaseDialog(GemBillingPurchaseDialogState nextState) {
    final notifier = _purchaseDialogState;
    if (notifier != null) {
      notifier.value = nextState;
      return;
    }
    _purchaseDialogState = ValueNotifier<GemBillingPurchaseDialogState>(
      nextState,
    );
    _presentPurchaseDialog();
  }

  void _presentPurchaseDialog() {
    _purchaseDialogState ??= ValueNotifier<GemBillingPurchaseDialogState>(
      GemBillingPurchaseDialogState.processing(attemptId: ''),
    );
    if (_purchaseDialogShowing) return;
    _purchaseDialogShowing = true;
    final dialogState = _purchaseDialogState!;
    unawaited(
      showGenesisGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Center(
            child: GemBillingPurchaseDialog(
              state: dialogState,
              onConfirm: _confirmPurchaseDialog,
            ),
          );
        },
      ).whenComplete(() {
        if (!mounted) {
          _disposePurchaseDialogState();
          return;
        }
        final shouldCloseSheet = _closeSheetAfterDialog;
        _purchaseDialogShowing = false;
        _purchaseDialogDismissing = false;
        _closeSheetAfterDialog = false;
        _disposePurchaseDialogState();
        if (shouldCloseSheet) Navigator.of(context).maybePop();
      }),
    );
  }

  void _confirmPurchaseDialog() {
    _closeSheetAfterDialog = true;
    _dismissPurchaseDialog();
  }

  void _dismissPurchaseDialog() {
    if (!_purchaseDialogShowing) {
      _disposePurchaseDialogState();
      return;
    }
    if (_purchaseDialogDismissing) return;
    _purchaseDialogDismissing = true;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _disposePurchaseDialogState() {
    final dialogState = _purchaseDialogState;
    if (dialogState == null) return;
    _purchaseDialogState = null;
    dialogState.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 14),
      child: ValueListenableBuilder<GemWalletState>(
        valueListenable: widget.walletStore.state,
        builder: (context, walletState, _) => GemPurchaseCatalogSection(
          balanceCent: walletState.balanceCent ?? 0,
          balanceKey: const ValueKey<String>('gem-purchase-sheet-balance'),
          compactBalance: true,
          catalog: _buildProducts(),
        ),
      ),
    );
  }

  Widget _buildProducts() {
    final products = _products;
    if (_productsLoading && products == null) {
      return const GemProductGridSkeleton();
    }
    if (_productsError != null && products == null) {
      return GemPurchaseState(
        message: GenesisL10n.current.gemsUnableLoadGemPacks,
        onRetry: () => unawaited(_loadProducts()),
      );
    }
    if (products == null || products.isEmpty) {
      return GemPurchaseState(
        message: GenesisL10n.current.gemsNoGemPacksAvailable,
      );
    }
    return GemProductGrid(
      products: products,
      billingStateListenable: widget.billingService.state,
      onPurchase: (product) => unawaited(_purchase(product)),
    );
  }
}
