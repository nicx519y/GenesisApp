import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/membership/subscription_analytics.dart';
import 'subscription_tracking_scope.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_catalog.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import 'pro_subscription_content.dart';
import 'wallet_purchase_tabs.dart';
import '../../ui/theme/genesis_dark_theme.dart';

enum PurchaseSheetTab { subscription, buyGems }

/// Shared purchase shell with Wallet's tabs and subscription presentation.
class PurchaseOptionsSheet extends StatefulWidget {
  const PurchaseOptionsSheet({
    super.key,
    required this.gemsBuilder,
    this.initialTab = PurchaseSheetTab.buyGems,
    this.showBuyGems = true,
    this.membershipProductsLoader,
    this.subscriptionBuilder,
    this.headerTrailing,
    this.analyticsPageId,
    this.subscriptionTracking,
    this.subscriptionSource = SubscriptionSource.unknown,
    this.onFirstBuyGems,
  });

  final WidgetBuilder gemsBuilder;
  final PurchaseSheetTab initialTab;
  final bool showBuyGems;
  final MembershipCatalogLoader? membershipProductsLoader;
  final WidgetBuilder? subscriptionBuilder;
  final Widget? headerTrailing;
  final String? analyticsPageId;
  final SubscriptionPageTracking? subscriptionTracking;
  final SubscriptionSource subscriptionSource;
  final VoidCallback? onFirstBuyGems;

  @override
  State<PurchaseOptionsSheet> createState() => _PurchaseOptionsSheetState();
}

class _PurchaseOptionsSheetState extends State<PurchaseOptionsSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabs;
  late bool _gemsVisited;
  late bool _subscriptionVisited;
  MembershipAccessStore? _membership;
  late final SubscriptionPageTracking _subscriptionTracking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final membership = AppServicesScope.maybeOf(context)?.membership;
    if (!identical(membership, _membership)) {
      _membership = membership;
      if (membership != null) unawaited(membership.refresh());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialTab = widget.showBuyGems
        ? widget.initialTab
        : PurchaseSheetTab.subscription;
    _subscriptionTracking =
        widget.subscriptionTracking ??
        SubscriptionPageTracking(
          pageId: widget.analyticsPageId,
          source: initialTab == PurchaseSheetTab.subscription
              ? widget.subscriptionSource
              : SubscriptionSource.buyGemsTab,
        );
    _gemsVisited = initialTab == PurchaseSheetTab.buyGems;
    _subscriptionVisited = initialTab == PurchaseSheetTab.subscription;
    _tabs = TabController(
      length: widget.showBuyGems ? 2 : 1,
      initialIndex: initialTab.index,
      vsync: this,
    );
    _tabs.addListener(_visitCurrentTab);
  }

  void _visitCurrentTab() {
    if (_tabs.index == PurchaseSheetTab.subscription.index &&
        !_subscriptionVisited) {
      setState(() => _subscriptionVisited = true);
    } else if (_tabs.index == PurchaseSheetTab.buyGems.index && !_gemsVisited) {
      setState(() => _gemsVisited = true);
      widget.onFirstBuyGems?.call();
    }
  }

  @override
  void didUpdateWidget(PurchaseOptionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBuyGems == widget.showBuyGems) return;
    final index = widget.showBuyGems ? _tabs.index : 0;
    _tabs.removeListener(_visitCurrentTab);
    _tabs.dispose();
    _tabs = TabController(
      length: widget.showBuyGems ? 2 : 1,
      initialIndex: index,
      vsync: this,
    )..addListener(_visitCurrentTab);
    if (!widget.showBuyGems) _gemsVisited = false;
    _visitCurrentTab();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.removeListener(_visitCurrentTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        _tabs.index != PurchaseSheetTab.subscription.index) {
      return;
    }
    final membership = _membership;
    if (membership != null) unawaited(membership.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return SubscriptionTrackingScope(
      page: _subscriptionTracking,
      child: GenesisDarkTheme(
        child: LayoutBuilder(
          builder: (context, constraints) => GenesisBottomSheetPanel(
            title: '',
            height: constraints.maxHeight,
            padding: EdgeInsets.zero,
            insetBody: false,
            header: GenesisActionSheetHeader.tabs(
              tabs: WalletPurchaseTabs(controller: _tabs),
              trailing: widget.headerTrailing,
              showClose: true,
              closeButtonKey: const ValueKey('gem-purchase-sheet-close'),
              onClose: () => Navigator.of(context).pop(),
            ),
            child: TabBarView(
              key: const ValueKey('purchase-sheet-pages'),
              controller: _tabs,
              children: [
                _PurchaseSheetPage(
                  child: GenesisActionSheetBody(
                    child: _subscriptionVisited
                        ? widget.subscriptionBuilder?.call(context) ??
                              ProSubscriptionContent(
                                refreshMembershipOnOpen: false,
                                productsLoader: widget.membershipProductsLoader,
                                closeOnPurchaseSuccess: true,
                                topSpacing: 0,
                                horizontalInset: 0,
                                // Buy Gems starts its balance at the header
                                // boundary; this tab starts there too.
                                headingTopSpacing: 0,
                              )
                        : const SizedBox.expand(),
                  ),
                ),
                if (widget.showBuyGems)
                  _PurchaseSheetPage(
                    child: GenesisActionSheetBody(
                      bottom: 10,
                      child: _gemsVisited
                          ? Builder(builder: widget.gemsBuilder)
                          : const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseSheetPage extends StatefulWidget {
  const _PurchaseSheetPage({required this.child});

  final Widget child;

  @override
  State<_PurchaseSheetPage> createState() => _PurchaseSheetPageState();
}

class _PurchaseSheetPageState extends State<_PurchaseSheetPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
