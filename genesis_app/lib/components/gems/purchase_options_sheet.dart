import 'memory_membership_style.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/attribution/adjust_device_registration.dart';
import '../../app/membership/subscription_analytics.dart';
import '../../platform/billing/billing_models.dart';
import 'subscription_tracking_scope.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/gem_store_catalog.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_catalog.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import 'pro_subscription_content.dart';
import 'gem_purchase_state.dart';
import 'purchase_attribution_registration.dart';
import 'purchase_legal_links.dart';
import 'wallet_purchase_tabs.dart';
import '../../ui/theme/genesis_dark_theme.dart';

enum PurchaseSheetTab { subscription, buyGems }

/// Shared frame for purchase sheets with either tabs or a title and action.
class PurchaseSheetPanel extends StatelessWidget {
  const PurchaseSheetPanel({
    super.key,
    required this.height,
    required this.header,
    required this.child,
  });

  static const heightFactor = 0.8;

  final double height;
  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => GenesisBottomSheetPanel(
    title: '',
    height: height,
    padding: EdgeInsets.zero,
    maintainBottomViewPadding: true,
    insetBody: false,
    header: header,
    child: child,
  );
}

/// Shared purchase shell with Wallet's tabs and subscription presentation.
class PurchaseOptionsSheet extends StatefulWidget {
  const PurchaseOptionsSheet({
    super.key,
    required this.gemsBuilder,
    this.gemsCatalog,
    this.initialTab = PurchaseSheetTab.buyGems,
    this.initialMembershipType,
    this.showBuyGems = true,
    this.membershipProductsLoader,
    this.subscriptionBuilder,
    this.headerTrailing,
    this.analyticsPageId,
    this.subscriptionTracking,
    this.subscriptionSource = SubscriptionSource.unknown,
    this.onFirstBuyGems,
    this.gemsSource = BillingPurchaseSource.unknown,
    this.attributionRegistration,
  });

  final WidgetBuilder gemsBuilder;

  /// Enables early rendering for a Gems builder that reads this catalog.
  final GemStoreCatalog? gemsCatalog;
  final BillingPurchaseSource gemsSource;
  final PurchaseSheetTab initialTab;
  final MemoryMembershipTier? initialMembershipType;
  final bool showBuyGems;
  final MembershipCatalogLoader? membershipProductsLoader;
  final WidgetBuilder? subscriptionBuilder;
  final Widget? headerTrailing;
  final String? analyticsPageId;
  final SubscriptionPageTracking? subscriptionTracking;
  final SubscriptionSource subscriptionSource;
  final VoidCallback? onFirstBuyGems;
  final AdjustDeviceRegistration? attributionRegistration;

  @override
  State<PurchaseOptionsSheet> createState() => _PurchaseOptionsSheetState();
}

class _PurchaseOptionsSheetState extends State<PurchaseOptionsSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabs;
  late bool _gemsVisited;
  late bool _subscriptionVisited;
  late int _lastEntryTab;
  final List<int> _entryRevisions = [0, 0];
  MembershipAccessStore? _membership;
  MembershipCatalog? _membershipCatalog;
  late final SubscriptionPageTracking _subscriptionTracking;
  final PurchaseAttributionRegistration _attributionRegistration =
      PurchaseAttributionRegistration();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServicesScope.maybeOf(context);
    final membership = services?.membership;
    if (!identical(membership, _membership)) {
      _membership = membership;
      if (membership != null) unawaited(membership.refresh());
    }
    final catalog = services?.membershipCatalog;
    if (!identical(catalog, _membershipCatalog)) {
      _membershipCatalog = catalog;
      if (!_subscriptionVisited &&
          widget.subscriptionBuilder == null &&
          widget.membershipProductsLoader == null &&
          catalog != null) {
        unawaited(catalog.loadCached());
      }
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
              : SubscriptionSource.fromGemsEntry(widget.gemsSource),
        );
    _gemsVisited = initialTab == PurchaseSheetTab.buyGems;
    _subscriptionVisited = initialTab == PurchaseSheetTab.subscription;
    _tabs = TabController(
      length: widget.showBuyGems ? 2 : 1,
      initialIndex: initialTab.index,
      vsync: this,
    );
    _tabs.addListener(_visitCurrentTab);
    _lastEntryTab = _tabs.index;
    _registerAttributionForCurrentTab();
    unawaited(_warmUnvisitedGemsCache());
  }

  Future<void> _warmUnvisitedGemsCache() async {
    final catalog = widget.gemsCatalog;
    if (!widget.showBuyGems || _gemsVisited || catalog == null) return;
    try {
      final cached = await catalog.loadCached();
      if (mounted && identical(catalog, widget.gemsCatalog) && cached != null) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('[Gems] catalog cache read failed: ${error.runtimeType}');
    }
  }

  void _visitCurrentTab() {
    _registerAttributionForCurrentTab();
    if (_lastEntryTab == _tabs.index) return;
    _lastEntryTab = _tabs.index;
    setState(() => _entryRevisions[_tabs.index]++);
    if (_tabs.index == PurchaseSheetTab.subscription.index &&
        !_subscriptionVisited) {
      setState(() => _subscriptionVisited = true);
    } else if (_tabs.index == PurchaseSheetTab.buyGems.index && !_gemsVisited) {
      setState(() => _gemsVisited = true);
      widget.onFirstBuyGems?.call();
    }
  }

  void _registerAttributionForCurrentTab() {
    _attributionRegistration.schedule(
      context,
      tabIndex: _tabs.index,
      currentTabIndex: () => _tabs.index,
      registration: widget.attributionRegistration,
    );
  }

  @override
  void didUpdateWidget(PurchaseOptionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gemsCatalog != widget.gemsCatalog ||
        (!oldWidget.showBuyGems && widget.showBuyGems)) {
      unawaited(_warmUnvisitedGemsCache());
    }
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

  Color? _membershipColor;

  @override
  Widget build(BuildContext context) {
    final canPreviewSubscription =
        _membershipCatalog != null &&
        widget.subscriptionBuilder == null &&
        widget.membershipProductsLoader == null;
    return SubscriptionTrackingScope(
      page: _subscriptionTracking,
      child: GenesisDarkTheme(
        child: LayoutBuilder(
          builder: (context, constraints) => PurchaseSheetPanel(
            height: constraints.maxHeight,
            header: GenesisActionSheetHeader.tabs(
              tabs: WalletPurchaseTabs(
                controller: _tabs,
                membershipColor: _membershipColor,
                initialMembershipType: widget.initialMembershipType,
                membershipCatalog: AppServicesScope.maybeOf(
                  context,
                )?.membershipCatalog,
              ),
              trailing: widget.headerTrailing,
              showClose: true,
              closeButtonKey: const ValueKey('gem-purchase-sheet-close'),
              onClose: () => Navigator.of(context).pop(),
            ),
            child: WalletPurchaseTabView(
              pageKey: const ValueKey('purchase-sheet-pages'),
              controller: _tabs,
              children: [
                _PurchaseSheetPage(
                  child: IgnorePointer(
                    ignoring: !_subscriptionVisited,
                    child: PurchaseCatalogEntry(
                      revision: _subscriptionVisited
                          ? _entryRevisions[0]
                          : null,
                      child: !_subscriptionVisited && !canPreviewSubscription
                          ? const GemPurchaseTabPlaceholder.subscription(
                              topSpacing: 0,
                            )
                          : widget.subscriptionBuilder != null
                          ? GenesisActionSheetBody(
                              child: widget.subscriptionBuilder!(context),
                            )
                          : ProSubscriptionContent.purchaseSheet(
                              initialMembershipType:
                                  widget.initialMembershipType,
                              onMembershipTypeChanged: (type) {
                                if (mounted &&
                                    _membershipColor != type.accent) {
                                  setState(
                                    () => _membershipColor = type.accent,
                                  );
                                }
                              },
                              refreshMembershipOnOpen: false,
                              productsLoader: widget.membershipProductsLoader,
                            ),
                    ),
                  ),
                ),
                if (widget.showBuyGems)
                  _PurchaseSheetPage(
                    child: GenesisActionSheetBody(
                      bottom: PurchaseLegalLinks.bottomSpacing,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: IgnorePointer(
                              ignoring: !_gemsVisited,
                              child: PurchaseCatalogEntry(
                                revision: _gemsVisited
                                    ? _entryRevisions[1]
                                    : null,
                                child:
                                    _gemsVisited || widget.gemsCatalog != null
                                    ? Builder(builder: widget.gemsBuilder)
                                    : const GemPurchaseTabPlaceholder.gems(
                                        horizontalInset: 0,
                                        topSpacing: 0,
                                      ),
                              ),
                            ),
                          ),
                          const PurchaseLegalLinks(),
                        ],
                      ),
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
