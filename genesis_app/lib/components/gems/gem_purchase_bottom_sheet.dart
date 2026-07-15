import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/gem_wallet_store.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/gem_product.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/billing_service.dart';
import '../common/genesis_center_toast.dart';
import 'gem_purchase_catalog.dart';

typedef GemPurchaseProductsLoader = Future<List<GemProduct>> Function();

Future<void> showGemPurchaseBottomSheet(
  BuildContext context, {
  required GemBalanceAlert alert,
  GemPurchaseProductsLoader? productsLoader,
  GemWalletStore? walletStore,
  BillingService? billingService,
}) async {
  final services = AppServicesScope.maybeRead(context);
  final resolvedProductsLoader =
      productsLoader ??
      (services == null
          ? null
          : () async => (await services.api.v1.gem.products()).products);
  final resolvedWalletStore = walletStore ?? services?.gemWallet;
  final resolvedBillingService = billingService ?? services?.billing;
  if (resolvedProductsLoader == null ||
      resolvedWalletStore == null ||
      resolvedBillingService == null) {
    if (context.mounted) {
      showGenesisToast(context, 'Unable to load gem packs.');
    }
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (_) => FractionallySizedBox(
      key: const ValueKey<String>('gem-purchase-sheet-size'),
      heightFactor: 0.8,
      alignment: Alignment.bottomCenter,
      child: GemPurchaseBottomSheet(
        alert: alert,
        productsLoader: resolvedProductsLoader,
        walletStore: resolvedWalletStore,
        billingService: resolvedBillingService,
      ),
    ),
  );
}

class GemPurchaseBottomSheet extends StatefulWidget {
  const GemPurchaseBottomSheet({
    super.key,
    required this.alert,
    required this.productsLoader,
    required this.walletStore,
    required this.billingService,
  });

  final GemBalanceAlert alert;
  final GemPurchaseProductsLoader productsLoader;
  final GemWalletStore walletStore;
  final BillingService billingService;

  @override
  State<GemPurchaseBottomSheet> createState() => _GemPurchaseBottomSheetState();
}

class _GemPurchaseBottomSheetState extends State<GemPurchaseBottomSheet> {
  List<GemProduct>? _products;
  Object? _productsError;
  bool _productsLoading = false;
  int _productsRequestGeneration = 0;
  StreamSubscription<BillingUiEvent>? _billingEvents;
  final Set<String> _startedProductIds = <String>{};

  @override
  void initState() {
    super.initState();
    _billingEvents = widget.billingService.events.listen(_handleBillingEvent);
    unawaited(widget.billingService.start());
    unawaited(widget.walletStore.refresh());
    unawaited(_loadProducts());
  }

  @override
  void dispose() {
    _productsRequestGeneration += 1;
    _billingEvents?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final generation = ++_productsRequestGeneration;
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    try {
      final products = await widget.productsLoader();
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _products = products;
        _productsLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _productsRequestGeneration) return;
      setState(() {
        _productsError = error;
        _productsLoading = false;
      });
    }
  }

  Future<void> _purchase(GemProduct product) async {
    if (widget.billingService.state.value.hasBusyPurchase) return;
    _startedProductIds.add(product.productId);
    await widget.billingService.purchaseGem(product);
  }

  void _handleBillingEvent(BillingUiEvent event) {
    if (!mounted || !_startedProductIds.contains(event.productId)) return;
    showGenesisToast(context, event.message);
    if (event.kind == BillingUiEventKind.failure) {
      _startedProductIds.remove(event.productId);
      return;
    }
    if (event.kind == BillingUiEventKind.success) {
      Navigator.of(context).pop();
    }
  }

  String get _title => widget.alert.kind == GemBalanceAlertKind.insufficient
      ? 'Insufficient Gems'
      : 'Low Gems';

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom / 2;
    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          key: const ValueKey<String>('gem-purchase-sheet-safe-area'),
          padding: EdgeInsets.only(bottom: bottomSafeInset),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    children: [
                      ValueListenableBuilder<GemWalletState>(
                        valueListenable: widget.walletStore.state,
                        builder: (context, walletState, _) => GemBalancePanel(
                          balance: walletState.balance ?? 0,
                          balanceKey: const ValueKey<String>(
                            'gem-purchase-sheet-balance',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildProducts(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('gem-purchase-sheet-close'),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF111111), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts() {
    final products = _products;
    if (_productsLoading && products == null) {
      return const _GemProductGridSkeleton();
    }
    if (_productsError != null && products == null) {
      return _GemPurchaseSheetState(
        message: 'Unable to load gem packs.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_loadProducts()),
      );
    }
    if (products == null || products.isEmpty) {
      return const _GemPurchaseSheetState(message: 'No gem packs available.');
    }
    return GemProductGrid(
      products: products,
      billingStateListenable: widget.billingService.state,
      onPurchase: (product) => unawaited(_purchase(product)),
    );
  }
}

class _GemProductGridSkeleton extends StatelessWidget {
  const _GemProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: 105 / 142,
      ),
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
      ),
    );
  }
}

class _GemPurchaseSheetState extends StatelessWidget {
  const _GemPurchaseSheetState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF42C47),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
