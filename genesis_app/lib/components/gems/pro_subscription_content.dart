import '../../platform/session/app_background_resume.dart';
import '../../l10n/genesis_l10n.dart';
import 'dart:async';
import '../../platform/billing/checkout_preparation_budget.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'subscription_tracking_scope.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/membership/membership_catalog.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_purchase_service.dart';
import '../../app/membership/membership_purchase_eligibility.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../network/models/membership_product.dart';
import '../../network/models/membership_benefit.dart';
import 'gem_assets.dart';
import 'gem_purchase_state.dart';
import 'membership_purchase_presentation.dart';
import 'purchase_legal_links.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_bottom_sheet_panel.dart';
import 'pro_colors.dart';
import 'memory_membership_style.dart';
import 'memory_membership_carousel.dart';
import 'subscription_benefit_icon.dart';

enum _ProPlan {
  yearly,
  monthly;

  String get label => switch (this) {
    _ProPlan.yearly => GenesisL10n.current.yearlyPlan,
    _ProPlan.monthly => GenesisL10n.current.monthlyPlan,
  };
}

class SubscriptionTierChanged extends Notification {
  const SubscriptionTierChanged(this.tier);

  final MemoryMembershipTier tier;
}

class ProSubscriptionContent extends StatefulWidget {
  const ProSubscriptionContent({
    super.key,
    this.productsLoader,
    this.initialMembershipType,
    this.onMembershipTypeChanged,
    this.catalog,
    this.purchaseHandler,
    this.purchaseService,
    this.membershipAccess,
    this.refreshMembershipOnOpen = true,
    this.closeOnPurchaseSuccess = false,
    this.onCloseAfterPurchaseSuccess,
    this.showHeading = true,
    this.headingTopSpacing = 22,
    this.topSpacing = purchaseTabContentTopSpacing,
    this.horizontalInset = 20,
    this.tagline,
    this.headingSuffix,
    this.sheetScrollController,
    this.sheetExpandedContentHeight = 0,
    this.loadingPlaceholder,
    this.pinPurchaseActions = false,
    this.includeBottomSafeArea = false,
    this.onBenefitsPullDown,
  });

  const ProSubscriptionContent.purchaseSheet({
    Key? key,
    MembershipCatalogLoader? productsLoader,
    MemoryMembershipTier? initialMembershipType,
    ValueChanged<MemoryMembershipTier>? onMembershipTypeChanged,
    Future<void> Function(MembershipProduct)? purchaseHandler,
    MembershipAccessStore? membershipAccess,
    bool refreshMembershipOnOpen = true,
    VoidCallback? onCloseAfterPurchaseSuccess,
  }) : this(
         key: key,
         productsLoader: productsLoader,
         initialMembershipType: initialMembershipType,
         onMembershipTypeChanged: onMembershipTypeChanged,
         purchaseHandler: purchaseHandler,
         membershipAccess: membershipAccess,
         refreshMembershipOnOpen: refreshMembershipOnOpen,
         closeOnPurchaseSuccess: true,
         onCloseAfterPurchaseSuccess: onCloseAfterPurchaseSuccess,
         topSpacing: 0,
         headingTopSpacing: 0,
         horizontalInset: GenesisActionSheetBody.horizontalInset,
         loadingPlaceholder: const GemPurchaseTabPlaceholder.subscription(
           topSpacing: 0,
         ),
         pinPurchaseActions: true,
       );

  final MembershipCatalogLoader? productsLoader;
  final MembershipType? initialMembershipType;
  final ValueChanged<MembershipType>? onMembershipTypeChanged;
  final MembershipCatalog? catalog;
  final Future<void> Function(MembershipProduct)? purchaseHandler;
  final MembershipPurchaseService? purchaseService;
  final MembershipAccessStore? membershipAccess;
  final bool refreshMembershipOnOpen;
  final bool closeOnPurchaseSuccess;

  /// Optional host-owned close when [closeOnPurchaseSuccess] is enabled.
  /// Onboarding uses this to acknowledge success past its system-back guard.
  final VoidCallback? onCloseAfterPurchaseSuccess;

  /// False where the host's own header already titles the page, so the body
  /// drops the whole heading block rather than repeating it.
  final bool showHeading;

  /// Space above the heading. A host whose other tab starts its content at the
  /// header boundary passes 0, so switching tabs does not shift the page.
  final double headingTopSpacing;

  /// Embedded flows can let their shared header own the content spacing.
  final double topSpacing;

  /// Set to zero when GenesisActionSheetBody owns the outer spacing.
  final double horizontalInset;

  /// Optional copy below the Premium heading for a specific host.
  final String? tagline;

  /// Optional context displayed after the Premium wordmark.
  final String? headingSuffix;

  /// When set, the entire subscription content scrolls with the host sheet.
  final ScrollController? sheetScrollController;

  /// Keeps the purchase area at the expanded sheet's bottom while it closes.
  final double sheetExpandedContentHeight;
  final Widget? loadingPlaceholder;

  /// Keeps the purchase button and legal links in the host's visible area.
  final bool pinPurchaseActions;

  /// Adds the device's bottom inset below the legal links.
  final bool includeBottomSafeArea;

  /// Passes a downward pull to the host only when that drag began at the top.
  final ValueChanged<double>? onBenefitsPullDown;

  @override
  State<ProSubscriptionContent> createState() => _ProSubscriptionContentState();
}

class _ProSubscriptionContentState extends State<ProSubscriptionContent>
    with WidgetsBindingObserver {
  _ProPlan _plan = _ProPlan.yearly;
  MembershipType _type = MembershipType.premium;
  bool _hasPurchased = false;
  bool _pickedType = false;
  final Map<MembershipType, _ProPlan> _plans = {};
  AppServices? _services;
  MembershipCatalog? _displayCatalog;
  List<MembershipOffer> _offers = [];
  MembershipAccessStore? _membership;
  bool _submitting = false;
  bool _benefitsDragCanMoveSheet = false;
  bool _checkingCatalog = false;
  bool _hasFreshCatalog = false;
  MembershipCheckoutPreparation? _checkoutPreparation;
  bool _loading = false;
  final _backgroundResume = AppBackgroundResume();
  bool _started = false;
  int? _entryRevision;
  int _requestGeneration = 0;
  MembershipPurchasePresentation? _purchasePresentation;
  MembershipPurchaseService? _presentationService;
  MembershipPurchaseService? _catalogService;
  final _ownTracking = SubscriptionPageTracking();
  late SubscriptionPageTracking _tracking;

  MembershipCatalog? get _catalog =>
      widget.catalog ??
      (widget.productsLoader == null ? _services?.membershipCatalog : null);

  MembershipOffer? _offerFor(_ProPlan plan) {
    for (final offer in _offers) {
      if (offer.product.membershipType == _type &&
          offer.product.isYearly == (plan == _ProPlan.yearly)) {
        return offer;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialMembershipType ?? MembershipType.premium;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumedFromBackground = _backgroundResume.update(state);
    if (state != AppLifecycleState.resumed) {
      _clearCheckoutPreparation();
    } else if (resumedFromBackground && !_submitting && _hasFreshCatalog) {
      unawaited(_load(silent: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = PurchaseCatalogEntry.of(context);
    final reentered = _entryRevision != null && revision != _entryRevision;
    _entryRevision = revision;
    _tracking = SubscriptionTrackingScope.maybeOf(context) ?? _ownTracking;
    final services = AppServicesScope.maybeOf(context);
    if (!_started || !identical(services, _services)) {
      _services?.sessionRevision.removeListener(_sessionChanged);
      _services = services;
      _bindDisplayCatalog();
      _bindMembership();
      _bindPurchaseUpdates();
      _purchasePresentation?.dispose();
      _purchasePresentation = null;
      _presentationService = null;
      services?.sessionRevision.addListener(_sessionChanged);
      _started = true;
      unawaited(_load());
    } else if (reentered) {
      unawaited(_load(silent: _offers.isNotEmpty));
    }
  }

  @override
  void didUpdateWidget(ProSubscriptionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindDisplayCatalog();
    _bindMembership();
    if (oldWidget.productsLoader != widget.productsLoader ||
        oldWidget.catalog != widget.catalog) {
      unawaited(_load());
    }
    _bindPurchaseUpdates();
  }

  void _bindDisplayCatalog() {
    final catalog = _catalog;
    if (identical(catalog, _displayCatalog)) return;
    _displayCatalog?.displayRevision.removeListener(_catalogDisplayChanged);
    _displayCatalog = catalog;
    catalog?.displayRevision.addListener(_catalogDisplayChanged);
  }

  void _catalogDisplayChanged() {
    final catalog = _displayCatalog;
    final display = catalog?.cached;
    if (!mounted || display == null) return;
    setState(() {
      _applyCatalog(display);
      _loading = false;
      _hasFreshCatalog = catalog!.hasCheckoutProducts;
    });
  }

  void _bindMembership() {
    final membership = widget.membershipAccess ?? _services?.membership;
    if (identical(membership, _membership)) return;
    _membership?.state.removeListener(_membershipChanged);
    _membership = membership;
    membership?.state.addListener(_membershipChanged);
    if (widget.refreshMembershipOnOpen && membership != null) {
      unawaited(membership.refresh());
    }
  }

  void _membershipChanged() {
    if (mounted) setState(() {});
  }

  void _bindPurchaseUpdates() {
    final service = widget.purchaseService ?? _services?.membershipPurchases;
    if (identical(service, _catalogService)) return;
    _catalogService?.catalogRevision.removeListener(_purchaseChanged);
    _clearCheckoutPreparation();
    _catalogService = service;
    service?.catalogRevision.addListener(_purchaseChanged);
  }

  void _purchaseChanged() {
    unawaited(_load(silent: true));
  }

  void _sessionChanged() {
    unawaited(_load(silent: _offers.isNotEmpty));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayCatalog?.displayRevision.removeListener(_catalogDisplayChanged);
    _clearCheckoutPreparation();
    _purchasePresentation?.dispose();
    _membership?.state.removeListener(_membershipChanged);
    _requestGeneration++;
    _services?.sessionRevision.removeListener(_sessionChanged);
    _catalogService?.catalogRevision.removeListener(_purchaseChanged);
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool checkoutOnly = false}) async {
    final request = ++_requestGeneration;
    final source = _catalog;
    _hasFreshCatalog = source?.hasCheckoutProducts == true;
    final cached = source?.cached;
    setState(() {
      if (!silent) {
        _loading = cached == null;
        _applyCatalog(cached ?? const MembershipCatalogData());
      }
    });
    var freshApplied = false;
    if (source != null && cached == null && !silent) {
      unawaited(() async {
        try {
          final snapshot = await source.loadCached();
          if (!mounted ||
              request != _requestGeneration ||
              freshApplied ||
              snapshot == null) {
            return;
          }
          setState(() {
            _applyCatalog(snapshot);
            _loading = false;
          });
        } catch (error) {
          debugPrint(
            '[Membership] catalog cache display failed: ${error.runtimeType}',
          );
        }
      }());
    }
    try {
      final loader =
          widget.productsLoader ??
          (checkoutOnly ? source?.loadForCheckout : source?.loadForEntry);
      if (loader == null) throw MembershipPlatformUnavailable();
      final catalog = await loader();
      if (!mounted || request != _requestGeneration) return;
      freshApplied = true;
      _hasFreshCatalog = true;
      setState(() {
        _applyCatalog(catalog);
        _loading = false;
      });
      _prepareSelectedCheckout();
    } catch (error) {
      if (!mounted || request != _requestGeneration) return;
      debugPrint('[Membership] catalog load failed: ${error.runtimeType}');
      setState(() => _loading = false);
    }
  }

  void _applyCatalog(MembershipCatalogData catalog) {
    _offers = catalog.offers;
    _hasPurchased = catalog.hasPurchased;
    if (!_pickedType && widget.initialMembershipType == null) {
      _type = memoryMembershipInitialTier(hasPurchased: _hasPurchased);
    }
    if (_offerFor(_plan) == null && _offers.isNotEmpty) {
      _plan = _ProPlan.values.firstWhere(
        (plan) => _offerFor(plan) != null,
        orElse: () => _plan,
      );
    }
  }

  void _clearCheckoutPreparation() {
    _checkoutPreparation?.invalidate();
    _checkoutPreparation = null;
  }

  void _prepareSelectedCheckout() {
    _clearCheckoutPreparation();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final service = widget.purchaseService ?? _services?.membershipPurchases;
    if (!mounted ||
        widget.purchaseHandler != null ||
        !_hasFreshCatalog ||
        _submitting ||
        service == null ||
        service.isBusy ||
        (service.otherPurchaseBusy?.call() ?? false) ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final offer = _offerFor(_plan);
    if (offer == null) return;
    MembershipCheckoutPreparation? preparation;
    preparation = service.prepareCheckout(
      offer.product,
      onExpired: () {
        if (!mounted || !identical(_checkoutPreparation, preparation)) return;
        _prepareSelectedCheckout();
      },
    );
    _checkoutPreparation = preparation;
  }

  Future<void> _onSubscribePressed() async {
    if (_submitting) return;
    final budget = CheckoutPreparationBudget();
    final session = _services?.sessionRevision.value;
    setState(() {
      _submitting = true;
      _checkingCatalog = true;
    });
    try {
      // A display cache is enough to render the plans, but cannot authorize a
      // checkout. Refresh it first and do not emit a purchase click until the
      // in-memory catalog includes current checkout credentials.
      if (!_hasFreshCatalog ||
          (_catalog != null &&
              !_catalog!.hasStoreProduct(_offerFor(_plan)?.product))) {
        final previous = _offerFor(_plan);
        await budget.wait(_load(silent: true, checkoutOnly: true));
        if (!mounted || !_hasFreshCatalog) return;
        final current = _offerFor(_plan);
        if ((_catalog?.loadStorePrices != null &&
                current?.storePrice == null) ||
            current?.price == null ||
            previous?.price?.amount != current?.price?.amount ||
            previous?.price?.currencyCode != current?.price?.currencyCode ||
            previous?.product.storeProductId !=
                current?.product.storeProductId ||
            previous?.product.basePlanId != current?.product.basePlanId ||
            previous?.product.offerId != current?.product.offerId) {
          // Updated conditions stay visible; a new tap confirms the new price.
          return;
        }
      }
      if (!mounted) return;
      if (_services?.sessionRevision.value != session ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      setState(() => _checkingCatalog = false);
      await budget.run(_subscribe);
    } on TimeoutException {
      if (mounted) {
        showGenesisToast(context, GenesisL10n.current.gemsPurchaseTimeout);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _checkingCatalog = false;
        });
        _prepareSelectedCheckout();
      } else {
        _submitting = false;
        _checkingCatalog = false;
      }
    }
  }

  Future<void> _subscribe() async {
    if (_loading) return;
    final offer = _offerFor(_plan);
    if (offer == null) {
      unawaited(_load());
      return;
    }
    if (offer.price == null) {
      unawaited(_load());
      return;
    }
    final tracking = _tracking.click(
      membershipType: _type,
      isYearly: offer.product.isYearly,
      storeProductId: offer.product.storeProductId,
      basePlanId: offer.product.provider == MembershipProvider.google
          ? offer.product.basePlanId
          : '',
    );
    final access = _membership?.state.value ?? const MembershipAccessState();
    if (membershipIsSubscribedToSelectedPlan(offer.product, access)) {
      _tracking.analytics.failed(
        tracking,
        'precheck_failed[already_subscribed]',
        once: true,
      );
      await showMembershipPurchaseFailure(
        context,
        'already_subscribed',
        product: offer.product,
      );
      return;
    }
    final handler = widget.purchaseHandler;
    if (handler != null) {
      await handler(offer.product);
      return;
    }
    final service = widget.purchaseService ?? _services?.membershipPurchases;
    if (service == null) {
      _tracking.analytics.failed(
        tracking,
        'precheck_failed[service_unavailable]',
        once: true,
      );
      showGenesisToast(
        context,
        purchaseToastMessage(
          GenesisL10n.current.premiumPurchasesUnavailable,
          debugInfo: purchaseDebugInfo(
            'vip.precheck',
            reason: 'service_unavailable',
          ),
        ),
      );
      return;
    }
    if (!identical(service, _presentationService)) {
      _purchasePresentation?.dispose();
      _presentationService = service;
      _purchasePresentation = MembershipPurchasePresentation(
        context: context,
        service: service,
      );
    }
    final preparation = _checkoutPreparation;
    _checkoutPreparation = null;
    final confirmed = await _purchasePresentation!.purchase(
      offer.product,
      tracking: tracking,
      preparation: preparation,
    );
    preparation?.invalidate();
    if (!confirmed &&
        _purchasePresentation!.requiresCatalogRefresh &&
        mounted) {
      // Keep this click occupied until the fresh catalog resolves. Without
      // this, a fast pre-store catalog failure releases `_submitting` and
      // repeated touches emit click/failed pairs in the same second.
      await _load();
    }
    if (confirmed &&
        mounted &&
        widget.closeOnPurchaseSuccess &&
        ModalRoute.of(context)?.isCurrent == true) {
      final close = widget.onCloseAfterPurchaseSuccess;
      if (close != null) {
        close();
      } else {
        await Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      if (_catalog != null) _catalog!.queryingStore,
    ]),
    builder: (_, _) => _buildExposure(context),
  );

  Widget _buildExposure(BuildContext context) => SubscriptionExposure(
    key: ValueKey('subscription-exposure-${_tracking.pageId}'),
    onVisible: () {
      if (!mounted || _loading || ModalRoute.of(context)?.isCurrent == false) {
        return false;
      }
      _tracking.show(_type);
      return true;
    },
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      if (widget.sheetScrollController == null) {
        return widget.loadingPlaceholder ?? const GemPurchaseLoading();
      }
      return ListView(
        controller: widget.sheetScrollController,
        children: [
          SizedBox(
            height: widget.sheetExpandedContentHeight > 0
                ? widget.sheetExpandedContentHeight
                : 160,
            child: const GemPurchaseLoading(),
          ),
        ],
      );
    }

    final state = _membership?.state.value ?? const MembershipAccessState();
    final carousel = MemoryMembershipSubscriptionCarousel(
      hasPurchased: _hasPurchased,
      initialTier: _type,
      topSpacing: widget.topSpacing,
      // Sheet hosts already provide the carousel's outer horizontal spacing.
      horizontalInset: widget.horizontalInset == 0 ? 0 : 16,
      premiumActive: state.activeFor(MembershipType.premium),
      deluxeActive: state.activeFor(MembershipType.deluxe),
      premiumExpiry: state.membership?.expiresAt,
      deluxeExpiry: state.membershipDeluxe?.expiresAt,
      onTierChanged: (type) {
        if (!mounted || _submitting) return;
        widget.onMembershipTypeChanged?.call(type);
        SubscriptionTierChanged(type).dispatch(context);
        if (_type == type) return;
        setState(() {
          _plans[_type] = _plan;
          _type = type;
          _pickedType = true;
          _plan = _plans[type] ?? _ProPlan.yearly;
        });
        _prepareSelectedCheckout();
      },
      onBenefitsScroll: _handleBenefitsScroll,
      benefitsBuilder: (type) {
        final matching = _offers.where(
          (offer) =>
              offer.product.membershipType == type &&
              offer.product.isYearly ==
                  ((_plans[type] ?? _plan) == _ProPlan.yearly),
        );
        return _buildBenefitRows(
          matching.isEmpty ? null : matching.first.product,
        );
      },
      plansBuilder: _buildPlanControls,
      actionsBuilder: (progress) => _buildPurchaseActions(context, progress),
      pinPurchaseActions: widget.pinPurchaseActions,
    );
    if (widget.sheetScrollController == null) {
      return AbsorbPointer(absorbing: _submitting, child: carousel);
    }
    final height = widget.sheetExpandedContentHeight < 600
        ? 600.0
        : widget.sheetExpandedContentHeight;
    return ListView(
      controller: widget.sheetScrollController,
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: height,
          child: AbsorbPointer(absorbing: _submitting, child: carousel),
        ),
      ],
    );
  }

  bool _handleBenefitsScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      // A drag that starts in the list belongs to the list until release,
      // even if it reaches the top with distance left in the same gesture.
      _benefitsDragCanMoveSheet =
          notification.dragDetails != null &&
          notification.metrics.extentBefore <= 0;
    } else if (notification is ScrollEndNotification) {
      _benefitsDragCanMoveSheet = false;
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null &&
        _benefitsDragCanMoveSheet) {
      var remaining = -notification.overscroll;
      final controller = widget.sheetScrollController;
      if (controller != null && controller.hasClients) {
        final position = controller.position;
        final consumed = remaining.clamp(0.0, position.extentBefore);
        if (consumed > 0) {
          controller.jumpTo(position.pixels - consumed);
          remaining -= consumed;
        }
      }
      if (remaining > 0) widget.onBenefitsPullDown?.call(remaining);
    }
    return true;
  }

  List<Widget> _buildBenefitRows(MembershipProduct? selectedProduct) {
    final benefits = selectedProduct?.benefits ?? const <MembershipBenefit>[];
    // The gem grants read as one module: the first line heads it and the rest
    // become the cards under it, instead of repeating it as their own rows.
    final gemGrants = [
      for (final benefit in benefits)
        if (benefit.iconKey == _gemIconKey) benefit,
    ];
    final gemHeadCode = gemGrants.isEmpty ? null : gemGrants.first.code;
    final rows = [
      for (final benefit in benefits)
        if (benefit.iconKey != _gemIconKey || benefit.code == gemHeadCode)
          benefit,
    ];
    return [
      for (final (index, benefit) in rows.indexed) ...[
        if (index > 0) const SizedBox(height: 20),
        if (gemHeadCode != null && index == 1) ...[
          Text(
            _restLabel,
            key: ValueKey('pro-benefits-rest-label'),
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
              color: GenesisColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ProBenefit(
          key: ValueKey('pro-benefit-${benefit.code}'),
          benefit: benefit,
          accent: selectedProduct?.membershipType == MembershipType.deluxe
              ? MemoryMembershipTier.deluxe.accent
              : premiumGold,
          grants: benefit.code == gemHeadCode
              ? gemGrants.skip(1).toList()
              : const <MembershipBenefit>[],
        ),
      ],
    ];
  }

  Widget _buildPlanControls(double deluxeColorProgress) => Padding(
    padding: EdgeInsets.fromLTRB(
      widget.horizontalInset,
      12,
      widget.horizontalInset,
      0,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemoryMembershipPlanSelector(
          tier: _type,
          deluxeColorProgress: deluxeColorProgress,
          savings: _offerFor(_ProPlan.yearly) == null
              ? null
              : membershipYearlySavings(_offerFor(_ProPlan.yearly)!, _offers),
          yearly: _plan == _ProPlan.yearly,
          yearlyPrice: _offerFor(_ProPlan.yearly)?.price?.formattedPrice,
          monthlyPrice: _offerFor(_ProPlan.monthly)?.price?.formattedPrice,
          onChanged: (yearly) {
            setState(() {
              _plan = yearly ? _ProPlan.yearly : _ProPlan.monthly;
              _plans[_type] = _plan;
            });
            _prepareSelectedCheckout();
          },
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 35),
          child: Center(
            child: Text(
              GenesisL10n.current.premiumAutoRenewsCancelAnytime,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: GenesisColors.darkTextTertiary,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildPurchaseActions(
    BuildContext context,
    double deluxeColorProgress,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSubscribeButton(_offerFor(_plan)?.product, deluxeColorProgress),
        const SizedBox(height: 24),
        const PurchaseLegalLinks(),
        SizedBox(
          key: const ValueKey('pro-bottom-safe-space'),
          height:
              PurchaseLegalLinks.bottomSpacing +
              (widget.includeBottomSafeArea
                  ? MediaQuery.viewPaddingOf(context).bottom
                  : 0),
        ),
      ],
    ),
  );

  Widget _buildSubscribeButton(
    MembershipProduct? product,
    double deluxeColorProgress,
  ) {
    final access = _membership?.state.value ?? const MembershipAccessState();
    final subscribed =
        product != null &&
        membershipIsSubscribedToSelectedPlan(product, access);
    final radius = BorderRadius.circular(13);
    final premiumGradient = MembershipType.premium.buttonGradient;
    final deluxeGradient = MembershipType.deluxe.buttonGradient;
    final period = _plan.label;
    final price = _offerFor(_plan)?.price?.formattedPrice;
    final label = subscribed
        ? GenesisL10n.current.premiumSubscribed
        : '$period: ${price ?? membershipPricePlaceholder}';
    final gradient = switch (deluxeColorProgress) {
      0 => premiumGradient,
      1 => deluxeGradient,
      _ => LinearGradient.lerp(
        premiumGradient,
        deluxeGradient,
        deluxeColorProgress,
      )!,
    };
    Widget labelSide(String text, Alignment alignment, {Color? color}) =>
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        );
    return DecoratedBox(
      key: const ValueKey('pro-subscribe-gold-surface'),
      decoration: BoxDecoration(
        gradient: subscribed ? gradient.scale(.5) : gradient,
        borderRadius: radius,
        boxShadow: subscribed
            ? null
            : const [
                BoxShadow(
                  color: Color(0x3DF5B62E),
                  blurRadius: 18,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: GenesisPrimaryButton(
        key: const ValueKey('pro-subscribe-button'),
        shrinkLabelToFit: true,
        backgroundColor: Colors.transparent,
        foregroundColor: premiumInkOnGold,
        disabledBackgroundColor: subscribed ? Colors.transparent : null,
        disabledForegroundColor: subscribed
            ? GenesisColors.darkBackground
            : null,
        label: label,
        labelContent: subscribed || price == null
            ? null
            : Semantics(
                label: label,
                excludeSemantics: true,
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    labelSide(period, Alignment.centerRight),
                    const SizedBox(width: 4),
                    const Text(':'),
                    const SizedBox(width: 4),
                    labelSide(
                      price,
                      Alignment.centerLeft,
                      color: Color.lerp(
                        premiumInkOnGold,
                        deluxeInkOnPearl,
                        deluxeColorProgress,
                      ),
                    ),
                  ],
                ),
              ),
        height: 44,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        borderRadius: radius,
        onPressed: subscribed ? null : _onSubscribePressed,
        isLoading: _checkingCatalog,
      ),
    );
  }

  /// The server marks every gem grant with this icon.
  static const String _gemIconKey = 'gem';

  /// App-side copy: the plan's positioning line and the label that introduces
  /// whatever the gem module did not already cover.
  static String get _restLabel => GenesisL10n.current.premiumAlsoIncluded;
}

/// The tier's title and gradient for a subscription sheet header.
class MembershipWordmark extends StatelessWidget {
  const MembershipWordmark({super.key, required this.tier, this.textStyle});

  final MemoryMembershipTier tier;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: tier.foreground.createShader,
      // No compressed line height: at height 1 the glyphs sit above the centre
      // of their own box, which tips the wordmark off whatever is centred
      // beside it. The font's natural leading keeps the two level.
      child: Text(
        tier.title(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            textStyle ??
            const TextStyle(
              color: GenesisColors.darkTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
      ),
    );
  }
}

/// One line of the plan's copy: a gold check and the server's wording. The
/// design carries no per-benefit artwork or status, so neither does this.
///
/// The gem line carries more: the grants folded into it show as cards below.
class _ProBenefit extends StatelessWidget {
  const _ProBenefit({
    super.key,
    required this.benefit,
    this.accent = premiumGold,
    this.grants = const <MembershipBenefit>[],
  });

  final MembershipBenefit benefit;
  final Color accent;

  /// Gem grants folded into this line, drawn as cards under the copy.
  final List<MembershipBenefit> grants;

  /// The design sets the figure in the copy apart; the rest stays plain.
  static final RegExp _figure = RegExp(r'\d[\d,]*');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              // Centred on the copy's first line box (14 x 1.35) so the icon
              // sits on the words, not on the block of text below them.
              height: 14 * 1.35,
              child: Center(
                child: SubscriptionBenefitIcon(
                  key: ValueKey('pro-benefit-icon-${benefit.code}'),
                  iconKey: benefit.iconKey,
                  size: 18,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text.rich(
                _titleSpan(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                  color: GenesisColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
        if (grants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 13),
            // Equal height: a note that wraps on a narrow screen must not
            // leave the other card short.
            child: IntrinsicHeight(
              child: Row(
                key: const ValueKey('pro-gem-breakdown'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, grant) in grants.indexed) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _GemGrantCard(
                        key: ValueKey('pro-gem-card-${grant.code}'),
                        grant: grant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  TextSpan _titleSpan() {
    final title = benefit.title;
    final match = _figure.firstMatch(title);
    if (match == null) return TextSpan(text: title);
    return TextSpan(
      children: [
        TextSpan(text: title.substring(0, match.start)),
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: premiumGoldLight,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        TextSpan(text: title.substring(match.end)),
      ],
    );
  }
}

/// One folded-in gem grant: how many, of which gem, and how often — all read
/// out of the server's copy so the numbers stay the server's.
class _GemGrantCard extends StatelessWidget {
  const _GemGrantCard({super.key, required this.grant});

  final MembershipBenefit grant;

  static final RegExp _figure = RegExp(r'\d[\d,]*');

  @override
  Widget build(BuildContext context) {
    final title = grant.title;
    final lower = title.toLowerCase();
    final pink = lower.contains('pink');
    final extra = lower.contains('extra');
    final name = pink
        ? GenesisL10n.current.premiumPinkGems
        : lower.contains('red')
        ? GenesisL10n.current.premiumRedGems
        : '';
    // Copy this line can't be read apart falls back to carrying the card whole.
    if (name.isEmpty) return _GemGrantCardShell(child: _note(title));
    final match = _figure.firstMatch(title);
    final amount = match == null ? '' : '${extra ? '+' : ''}${match.group(0)}';
    // A grant that repeats says so beside its figure, the way a plan's price
    // carries "/mo", rather than leaving the rate to the note alone.
    final perUnit = lower.contains('check-in')
        ? GenesisL10n.current.gemsPerDay(amount: '').trim()
        : '';
    // The design words the cadence itself and leaves only the figure to the
    // server, so read which cadence this is and use the design's line. Its
    // wording is shortened to hold one line at 12px down to a 360 screen.
    final sourceName = pink ? 'Pink Gems' : 'Red Gems';
    final nameAt = lower.indexOf(sourceName.toLowerCase());
    final note = lower.contains('check-in')
        ? (extra
              ? GenesisL10n.current.premiumExtraDailyCheck
              : GenesisL10n.current.premiumDailyCheck)
        : lower.contains('month')
        ? GenesisL10n.current.premiumClaimedMonthly
        : nameAt < 0
        ? title
        : title.substring(nameAt + sourceName.length).trim();
    return _GemGrantCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amount.isNotEmpty) ...[
            Row(
              children: [
                SvgPicture.asset(
                  pink ? roseGemIconAsset : gemIconAsset,
                  width: 12,
                  height: 18,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: GenesisLocalizedRichText(
                    template: perUnit.isEmpty
                        ? GenesisLocalizedRichText.placeholder('amount')
                        : context.l10n.gemsPerDay(
                            amount: GenesisLocalizedRichText.placeholder(
                              'amount',
                            ),
                          ),
                    placeholders: {
                      'amount': TextSpan(
                        text: amount,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: GenesisColors.darkTextPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: GenesisColors.darkTextTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w600,
              color: GenesisColors.darkTextPrimary,
            ),
          ),
          if (note.isNotEmpty) ...[const SizedBox(height: 5), _note(note)],
        ],
      ),
    );
  }

  Widget _note(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: GenesisColors.darkTextTertiary,
    ),
  );
}

class _GemGrantCardShell extends StatelessWidget {
  const _GemGrantCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        color: GenesisColors.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
