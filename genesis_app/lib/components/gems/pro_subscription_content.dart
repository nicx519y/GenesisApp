import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'subscription_tracking_scope.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/membership/membership_catalog.dart';
import '../../app/membership/membership_access_store.dart';
import '../../app/membership/membership_purchase_service.dart';
import '../../app/membership/membership_purchase_eligibility.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';
import '../../icons/custom_icon_assets.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../network/models/membership_product.dart';
import '../../network/models/membership_benefit.dart';
import 'gem_assets.dart';
import 'gem_purchase_state.dart';
import 'membership_purchase_presentation.dart';
import '../common/genesis_center_toast.dart';
import 'pro_colors.dart';
import 'subscription_benefit_icon.dart';

enum _ProPlan {
  yearly('pro_yearly', 'Yearly', 'year'),
  monthly('pro_monthly', 'Monthly', 'month');

  const _ProPlan(this.code, this.label, this.period);
  final String code;
  final String label;
  final String period;
}

class ProSubscriptionContent extends StatefulWidget {
  const ProSubscriptionContent({
    super.key,
    this.productsLoader,
    this.catalog,
    this.purchaseHandler,
    this.purchaseService,
    this.membershipAccess,
    this.refreshMembershipOnOpen = true,
    this.closeOnPurchaseSuccess = false,
    this.onCloseAfterPurchaseSuccess,
    this.showHeading = true,
    this.headingTopSpacing = 22,
    this.topSpacing = 10,
    this.horizontalInset = 20,
  });

  final MembershipCatalogLoader? productsLoader;
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

  @override
  State<ProSubscriptionContent> createState() => _ProSubscriptionContentState();
}

class _ProSubscriptionContentState extends State<ProSubscriptionContent>
    with WidgetsBindingObserver {
  _ProPlan _plan = _ProPlan.yearly;
  AppServices? _services;
  List<MembershipOffer> _offers = [];
  MembershipAccessStore? _membership;
  bool _submitting = false;
  bool _hasFreshCatalog = false;
  MembershipCheckoutPreparation? _checkoutPreparation;
  bool _loading = false;
  bool _started = false;
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
      if (offer.product.planCode == plan.code) return offer;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _clearCheckoutPreparation();
    } else if (!_submitting && _hasFreshCatalog) {
      _prepareSelectedCheckout();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tracking = SubscriptionTrackingScope.maybeOf(context) ?? _ownTracking;
    final services = AppServicesScope.maybeOf(context);
    if (!_started || !identical(services, _services)) {
      _services?.sessionRevision.removeListener(_sessionChanged);
      _services = services;
      _bindMembership();
      _bindPurchaseUpdates();
      _purchasePresentation?.dispose();
      _purchasePresentation = null;
      _presentationService = null;
      services?.sessionRevision.addListener(_sessionChanged);
      _started = true;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(ProSubscriptionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindMembership();
    if (oldWidget.productsLoader != widget.productsLoader ||
        oldWidget.catalog != widget.catalog) {
      unawaited(_load());
    }
    _bindPurchaseUpdates();
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
    unawaited(_load(silent: true, forceRefresh: true));
  }

  void _sessionChanged() {
    unawaited(_load(silent: _offers.isNotEmpty, forceRefresh: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearCheckoutPreparation();
    _purchasePresentation?.dispose();
    _membership?.state.removeListener(_membershipChanged);
    _requestGeneration++;
    _services?.sessionRevision.removeListener(_sessionChanged);
    _catalogService?.catalogRevision.removeListener(_purchaseChanged);
    super.dispose();
  }

  Future<void> _load({bool silent = false, bool forceRefresh = false}) async {
    _clearCheckoutPreparation();
    _hasFreshCatalog = false;
    final request = ++_requestGeneration;
    final source = _catalog;
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
          (forceRefresh ? source?.load : source?.loadForEntry);
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
    _submitting = true;
    try {
      await _subscribe();
    } finally {
      _submitting = false;
      if (mounted) _prepareSelectedCheckout();
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
    final tracking = _tracking.click(isYearly: offer.product.isYearly);
    final handler = widget.purchaseHandler;
    if (handler != null) {
      await handler(offer.product);
      return;
    }
    final service = widget.purchaseService ?? _services?.membershipPurchases;
    if (service == null) {
      _tracking.analytics.failed(tracking, 'service_unavailable', once: true);
      showGenesisToast(
        context,
        purchaseToastMessage(
          'Purchases are currently unavailable.',
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
  Widget build(BuildContext context) => SubscriptionExposure(
    key: ValueKey('subscription-exposure-${_tracking.pageId}'),
    onVisible: () {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
      _tracking.show();
      return true;
    },
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final selectedProduct = _offerFor(_plan)?.product;
    if (_loading) {
      // Match Buy Gems' initial loading indicator in the same tab content area.
      return const GemPurchaseLoading();
    }
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
    return Column(
      children: [
        SizedBox(height: widget.topSpacing),
        Expanded(
          child: KeyedSubtree(
            key: const ValueKey('pro-benefits-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The heading is fixed and only the benefits scroll, as the
                // design lays it out.
                if (widget.showHeading)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.horizontalInset,
                      widget.headingTopSpacing,
                      widget.horizontalInset,
                      // Reads as wide as the hairline the design once ruled
                      // here, now that the tagline sits above the list.
                      22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          key: const ValueKey('pro-tier-title'),
                          children: [
                            SvgPicture.asset(
                              proCrownGoldIconAsset,
                              width: 26,
                              height: 18,
                            ),
                            // 26 + 5 matches the benefit rows' 20 + 11, so the
                            // wordmark starts on the copy's own column.
                            const SizedBox(width: 5),
                            const Flexible(child: PremiumWordmark()),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          _tagline,
                          key: ValueKey('pro-tagline'),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: GenesisColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    key: const PageStorageKey('pro-benefits-scroll'),
                    padding: EdgeInsets.fromLTRB(
                      widget.horizontalInset,
                      // A host that titles itself already sits below a header's
                      // own bottom half, so the list needs little of its own.
                      widget.showHeading ? 0 : 8,
                      widget.horizontalInset,
                      26,
                    ),
                    children: [
                      for (final (index, benefit) in rows.indexed) ...[
                        if (index > 0) const SizedBox(height: 20),
                        // Everything the gem module did not cover sits under a label.
                        if (gemHeadCode != null && index == 1) ...[
                          const Text(
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
                          grants: benefit.code == gemHeadCode
                              ? gemGrants.skip(1).toList()
                              : const <MembershipBenefit>[],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalInset,
            26,
            widget.horizontalInset,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Equal height: the yearly card carries a billing line the
              // monthly one does not, and the pair must still sit level.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final plan in _ProPlan.values) ...[
                      if (plan != _ProPlan.values.first)
                        const SizedBox(width: 12),
                      Expanded(
                        child: _ProPlanCard(
                          plan: plan,
                          offer: _offerFor(plan),
                          savings: _offerFor(plan) == null
                              ? null
                              : membershipYearlySavings(
                                  _offerFor(plan)!,
                                  _offers,
                                ),
                          selected: _plan == plan,
                          onTap: () {
                            if (_plan == plan) return;
                            setState(() => _plan = plan);
                            _prepareSelectedCheckout();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(
                height: 35,
                child: Center(
                  child: Text(
                    'Auto-renews. Cancel anytime.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: GenesisColors.darkTextTertiary,
                    ),
                  ),
                ),
              ),
              _buildSubscribeButton(selectedProduct),
              const SizedBox(height: 24),
              _buildLegalRow(context),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton(MembershipProduct? product) {
    final access = _membership?.state.value ?? const MembershipAccessState();
    final subscribed =
        product != null &&
        membershipHasSelectedPlan(product, access) &&
        access.membership?.autoRenew == true;
    final radius = BorderRadius.circular(13);
    return DecoratedBox(
      key: const ValueKey('pro-subscribe-gold-surface'),
      decoration: BoxDecoration(
        gradient: premiumCtaGradient,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x3DF5B62E),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: GenesisPrimaryButton(
        key: const ValueKey('pro-subscribe-button'),
        backgroundColor: Colors.transparent,
        foregroundColor: premiumInkOnGold,
        label: subscribed
            ? 'Subscribed'
            : '${_plan.label}: ${_offerFor(_plan)?.price?.formattedPrice ?? ''}',
        height: 44,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        borderRadius: radius,
        onPressed: _onSubscribePressed,
      ),
    );
  }

  Widget _buildLegalRow(BuildContext context) {
    Widget link(String document, String label) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.legal, arguments: {'document': document}),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
        ),
        child: Text(
          label,
          style: GenesisTypography.resolve(context, _legalStyle),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        link('privacy', 'Privacy Policy'),
        Text('&', style: GenesisTypography.resolve(context, _legalStyle)),
        link('terms', 'Terms of Service'),
        Text('&', style: GenesisTypography.resolve(context, _legalStyle)),
        link('eula', 'EULA'),
      ],
    );
  }

  /// The server marks every gem grant with this icon.
  static const String _gemIconKey = 'gem';

  /// App-side copy: the plan's positioning line and the label that introduces
  /// whatever the gem module did not already cover.
  static const String _tagline = 'Go deeper into every Worldo you play.';
  static const String _restLabel = 'Also included';

  static const TextStyle _legalStyle = TextStyle(
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w400,
    color: GenesisColors.darkTextTertiary,
  );
}

/// "Worldo Premium" under a gold sweep, as on the profile card. Public so a
/// sheet that titles itself with the plan can show the same lockup.
class PremiumWordmark extends StatelessWidget {
  const PremiumWordmark({super.key, this.textStyle});

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => proTitleGradient.createShader(bounds),
      // No compressed line height: at height 1 the glyphs sit above the centre
      // of their own box, which tips the wordmark off whatever is centred
      // beside it. The font's natural leading keeps the two level.
      child: Text(
        'Worldo Premium',
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
    this.grants = const <MembershipBenefit>[],
  });

  final MembershipBenefit benefit;

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
                  color: premiumGold,
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
        ? 'Pink Gems'
        : lower.contains('red')
        ? 'Red Gems'
        : '';
    // Copy this line can't be read apart falls back to carrying the card whole.
    if (name.isEmpty) return _GemGrantCardShell(child: _note(title));
    final match = _figure.firstMatch(title);
    final amount = match == null ? '' : '${extra ? '+' : ''}${match.group(0)}';
    // A grant that repeats says so beside its figure, the way a plan's price
    // carries "/mo", rather than leaving the rate to the note alone.
    final perUnit = lower.contains('check-in') ? ' /day' : '';
    // The design words the cadence itself and leaves only the figure to the
    // server, so read which cadence this is and use the design's line. Its
    // wording is shortened to hold one line at 12px down to a 360 screen.
    final nameAt = lower.indexOf(name.toLowerCase());
    final note = lower.contains('check-in')
        ? (extra ? 'Extra, daily check-in' : 'Daily check-in')
        : lower.contains('month')
        ? 'Claimed monthly'
        : title.substring(nameAt + name.length).trim();
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
                  child: Text.rich(
                    TextSpan(
                      text: amount,
                      children: [
                        if (perUnit.isNotEmpty)
                          TextSpan(
                            text: perUnit,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GenesisColors.darkTextTertiary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: GenesisColors.darkTextPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
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

class _ProPlanCard extends StatelessWidget {
  const _ProPlanCard({
    required this.plan,
    required this.offer,
    required this.savings,
    required this.selected,
    required this.onTap,
  });

  final _ProPlan plan;
  final MembershipOffer? offer;
  final int? savings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = offer?.price;
    final monthlyPrice = price == null
        ? ''
        : plan == _ProPlan.yearly
        ? NumberFormat.simpleCurrency(
            locale: Localizations.localeOf(context).toString(),
            name: price.currencyCode,
            decimalDigits: 2,
          ).format(price.amountCent / 100 / offer!.product.billingMonths)
        : price.formattedPrice;
    final note = plan == _ProPlan.yearly
        ? (price == null ? '' : '${price.formattedPrice}, Billed annually')
        : 'Billed monthly';
    final showSavings =
        plan == _ProPlan.yearly && savings != null && savings! > 0;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${plan.label} Premium, ${price?.formattedPrice ?? ''} per ${plan.period}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            key: ValueKey('pro-plan-${plan.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              // Keep the border independent of content geometry.
              padding: const EdgeInsets.fromLTRB(15.5, 19.5, 15.5, 15.5),
              decoration: BoxDecoration(
                color: selected
                    ? premiumGoldTint
                    : GenesisColors.darkPurchaseCardBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: selected
                    ? Border.all(color: premiumGold, width: 1.5)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: GenesisColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // A long currency shrinks rather than breaking the card.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: monthlyPrice,
                        children: const [
                          TextSpan(
                            text: '/mo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GenesisColors.darkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: selected
                            ? premiumGoldLight
                            : GenesisColors.darkTextPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      color: GenesisColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showSavings)
            Positioned(
              left: 0,
              top: -9,
              child: IgnorePointer(
                child: _SavingsTag(
                  key: const ValueKey('pro-yearly-savings-badge'),
                  savings: savings!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavingsTag extends StatelessWidget {
  const _SavingsTag({super.key, required this.savings});

  final int savings;

  @override
  Widget build(BuildContext context) {
    // Padding rather than a height and an alignment: an aligned box with no
    // width fills whatever it is given, which in a Wrap is the whole line.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        // Opaque: the tag rides the card's top edge, and a translucent fill
        // would let the gold border read as a line struck through the words.
        color: premiumGoldTagSolid,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: premiumGoldTagRing),
      ),
      child: Text(
        'Save $savings%',
        style: const TextStyle(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w600,
          color: premiumGold,
        ),
      ),
    );
  }
}
