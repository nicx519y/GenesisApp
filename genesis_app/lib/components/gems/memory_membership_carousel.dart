import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../../l10n/genesis_localizations.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_localized_rich_text.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import 'memory_membership_style.dart';
import 'gem_assets.dart';

/// Pure presentation. Prices supplied by a host must come from its real catalog.
/// Draft prices are opt-in and intended only for the explicit Developer gallery.
class MemoryMembershipSubscriptionCarousel extends StatefulWidget {
  const MemoryMembershipSubscriptionCarousel({
    super.key,
    this.premiumActive = false,
    this.deluxeActive = false,
    this.premiumExpiry,
    this.deluxeExpiry,
    this.initialTier,
    required this.onPremiumSubscribe,
    this.onPremiumPlanSubscribe,
    required this.onDeluxeSubscribe,
    this.premiumYearlyPrice,
    this.premiumMonthlyPrice,
    this.stackedPlans = false,
    this.onTierChanged,
  });

  final bool premiumActive;
  final bool deluxeActive;
  final DateTime? premiumExpiry;
  final DateTime? deluxeExpiry;

  /// The card to open on when the entry asks for one; otherwise the lead card.
  final MemoryMembershipTier? initialTier;
  final VoidCallback onPremiumSubscribe;

  /// Optional production checkout callback; true means Yearly, false Monthly.
  /// When supplied, replaces [onPremiumSubscribe] and carries the visible choice.
  final ValueChanged<bool>? onPremiumPlanSubscribe;
  final VoidCallback onDeluxeSubscribe;
  final String? premiumYearlyPrice;
  final String? premiumMonthlyPrice;
  final bool stackedPlans;
  final ValueChanged<MemoryMembershipTier>? onTierChanged;

  @override
  State<MemoryMembershipSubscriptionCarousel> createState() =>
      _SubscriptionCarouselState();
}

class _SubscriptionCarouselState
    extends State<MemoryMembershipSubscriptionCarousel> {
  MemoryMembershipTier? _picked;
  MemoryMembershipTier? _reported;
  final _yearly = {for (final tier in MemoryMembershipTier.values) tier: true};

  @override
  void didUpdateWidget(
    covariant MemoryMembershipSubscriptionCarousel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTier != widget.initialTier) {
      _picked = null;
    }
  }

  List<MemoryMembershipTier> get _order => memoryMembershipOrder(
    premiumActive: widget.premiumActive,
    deluxeActive: widget.deluxeActive,
  );

  MemoryMembershipTier get _tier =>
      _picked ?? widget.initialTier ?? _order.first;

  void _selectTier(MemoryMembershipTier tier) => setState(() => _picked = tier);

  /// Membership can settle after opening and move the lead card, so the card in
  /// view is reported whenever it changes, not only when the reader picks one.
  void _reportTier() {
    final tier = _tier;
    if (_reported == tier) return;
    _reported = tier;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTierChanged?.call(tier);
    });
  }

  Widget _cards() => _MembershipSlideTrack(
    key: const ValueKey('membership-subscription-pages'),
    selectedIndex: _order.indexOf(_tier),
    onChanged: (index) => _selectTier(_order[index]),
    children: [
      for (final tier in _order)
        _BenefitsCard(
          tier: tier,
          active: tier == MemoryMembershipTier.premium
              ? widget.premiumActive
              : widget.deluxeActive,
          expiry: tier == MemoryMembershipTier.premium
              ? widget.premiumExpiry
              : widget.deluxeExpiry,
        ),
    ],
  );

  Widget _footer(BuildContext context) {
    final premium = _tier == MemoryMembershipTier.premium;
    final active = premium ? widget.premiumActive : widget.deluxeActive;
    final yearlyPrice = premium && widget.premiumYearlyPrice != null
        ? widget.premiumYearlyPrice!
        : _tier.listYearlyPrice;
    final monthlyPrice = premium && widget.premiumMonthlyPrice != null
        ? widget.premiumMonthlyPrice!
        : _tier.listMonthlyPrice;
    final selectedPrice = _yearly[_tier]! ? yearlyPrice : monthlyPrice;
    final selectedPlan = _yearly[_tier]!
        ? context.l10n.yearlyPlan
        : context.l10n.monthlyPlan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DefaultTextStyle.merge(
        style: const TextStyle(letterSpacing: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tier in _order)
                  Semantics(
                    button: true,
                    selected: _tier == tier,
                    label: tier.title(context),
                    child: InkWell(
                      onTap: () => _selectTier(tier),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 8,
                        ),
                        child: Container(
                          width: _tier == tier ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _tier == tier
                                ? GenesisColors.darkTextPrimary
                                : const Color(0x59FFFFFF),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            MemoryMembershipPlanSelector(
              tier: _tier,
              stacked: widget.stackedPlans,
              yearly: _yearly[_tier]!,
              onChanged: (value) => setState(() => _yearly[_tier] = value),
              yearlyPrice: yearlyPrice,
              monthlyPrice: monthlyPrice,
            ),
            SizedBox(
              height: 35,
              child: Center(
                child: Text(
                  context.l10n.premiumAutoRenewsCancelAnytime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x8CFFFFFF),
                  ),
                ),
              ),
            ),
            MemoryMembershipButton(
              key: ValueKey('membership-subscribe-${_tier.name}'),
              tier: _tier,
              subscription: true,
              label: active
                  ? context.l10n.premiumSubscribed
                  : '$selectedPlan: $selectedPrice',
              onPressed: active
                  ? null
                  : premium
                  ? () {
                      final subscribe = widget.onPremiumPlanSubscribe;
                      if (subscribe != null) {
                        subscribe(_yearly[MemoryMembershipTier.premium]!);
                      } else {
                        widget.onPremiumSubscribe();
                      }
                    }
                  : widget.onDeluxeSubscribe,
            ),
            const SizedBox(height: 14),
            const _MembershipLegalLinks(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _reportTier();
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      // Short windows and large text scroll as a whole instead of crushing cards.
      if (!constraints.hasBoundedHeight ||
          constraints.maxHeight < 620 * scale) {
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 12),
              SizedBox(height: 360 * scale, child: _cards()),
              _footer(context),
            ],
          ),
        );
      }
      return Column(
        children: [
          const SizedBox(height: 12),
          Expanded(child: _cards()),
          _footer(context),
        ],
      );
    },
  );
}

class _BenefitsCard extends StatefulWidget {
  const _BenefitsCard({
    required this.tier,
    required this.active,
    required this.expiry,
  });
  final MemoryMembershipTier tier;
  final bool active;
  final DateTime? expiry;

  @override
  State<_BenefitsCard> createState() => _BenefitsCardState();
}

class _BenefitsCardState extends State<_BenefitsCard> {
  final _scroll = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateFade);
  }

  void _updateFade() {
    if (!mounted || !_scroll.hasClients) return;
    final more = _scroll.position.extentAfter >= 6;
    if (more != _more) setState(() => _more = more);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final premium = tier == MemoryMembershipTier.premium;
    final l10n = context.l10n;
    final benefits = premium
        ? [
            l10n.memoryMembershipSummaryBenefit,
            l10n.memoryMembershipInspirationsBenefit,
            l10n.memoryMembershipEditingBenefit,
            l10n.memoryMembershipBadgeBenefit(membership: 'Premium'),
            l10n.memoryMembershipRechargeBenefit,
          ]
        : [
            l10n.memoryMembershipBenefitTimeline,
            l10n.memoryMembershipBenefitCast,
            l10n.memoryMembershipBenefitBonds,
            l10n.memoryMembershipRememberBenefit,
            l10n.memoryMembershipInspirationsBenefit,
            l10n.memoryMembershipEditingBenefit,
            l10n.memoryMembershipBadgeBenefit(membership: 'Deluxe'),
          ];
    return MemoryMembershipSurface(
      tier: tier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The title holds its place; only the benefits below it scroll.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MemoryMembershipHeading(tier: tier, active: widget.active),
                const SizedBox(height: 6),
                if (widget.expiry != null)
                  Text(
                    l10n.expiresOn(date: memoryMembershipDate(widget.expiry!)),
                    style: TextStyle(
                      color: tier.bodyColor,
                      fontSize: 12,
                      height: 15 / 12,
                    ),
                  ),
                if (!widget.active)
                  Text(
                    premium
                        ? l10n.proSubscriptionTagline
                        : l10n.memoryMembershipDeluxeTagline,
                    style: TextStyle(
                      color: tier.bodyColor,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _updateFade(),
                      );
                      return false;
                    },
                    // Rows dissolve under the title rather than being cut by it.
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Colors.transparent, Colors.white],
                        stops: [0, (16 / bounds.height).clamp(0.0, 1.0)],
                      ).createShader(bounds),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 55),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MembershipBenefitRow(
                              icon: SvgPicture.asset(
                                gemDiamondIconAsset,
                                width: 18,
                                height: 18,
                                colorFilter: ColorFilter.mode(
                                  tier.accent,
                                  BlendMode.srcIn,
                                ),
                              ),
                              content: GenesisLocalizedRichText(
                                template: l10n.memoryMembershipMonthlyGems(
                                  amount: GenesisLocalizedRichText.placeholder(
                                    'amount',
                                  ),
                                ),
                                placeholders: {
                                  'amount': TextSpan(
                                    text: premium ? '3,500' : '18,000',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: premium
                                          ? const Color(0xFFFFE7A6)
                                          : Colors.white,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                },
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: GenesisColors.darkTextPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _GemAllowance(
                                      amount: premium ? '2,000' : '12,000',
                                      label: l10n.premiumPinkGems,
                                      note: l10n.premiumClaimedMonthly,
                                      asset: roseGemIconAsset,
                                      tier: tier,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _GemAllowance(
                                      amount: premium ? '+50' : '+200',
                                      daily: true,
                                      label: l10n.premiumRedGems,
                                      note: l10n.premiumExtraDailyCheck,
                                      asset: gemIconAsset,
                                      tier: tier,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              l10n.premiumAlsoIncluded,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0x8CFFFFFF),
                                height: 1,
                              ),
                            ),
                            for (
                              var index = 0;
                              index < benefits.length;
                              index++
                            ) ...[
                              SizedBox(height: index == 0 ? 16 : 20),
                              _MembershipBenefitRow(
                                icon: _benefitIcon(tier, index),
                                text: benefits[index],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 1,
                  right: 1,
                  bottom: 1,
                  height: 96,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _more ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(17),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tier.background.colors.last.withValues(alpha: 0),
                              tier.background.colors.last.withValues(alpha: .8),
                              tier.background.colors.last,
                            ],
                            stops: const [0, .55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GemAllowance extends StatelessWidget {
  const _GemAllowance({
    required this.amount,
    required this.label,
    required this.note,
    required this.asset,
    required this.tier,
    this.daily = false,
  });
  final String amount;
  final String label;
  final String note;
  final String asset;
  final MemoryMembershipTier tier;
  final bool daily;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 13),
    decoration: BoxDecoration(
      color: tier == MemoryMembershipTier.premium
          ? const Color(0x2E000000)
          : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(asset, width: 12, height: 18),
            const SizedBox(width: 7),
            Flexible(
              child: GenesisLocalizedRichText(
                template: daily
                    ? context.l10n.gemsPerDay(
                        amount: GenesisLocalizedRichText.placeholder('amount'),
                      )
                    : GenesisLocalizedRichText.placeholder('amount'),
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
                style: const TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: Color(0x8CFFFFFF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          note,
          style: const TextStyle(
            fontSize: 12,
            height: 1.3,
            color: Color(0x8CFFFFFF),
          ),
        ),
      ],
    ),
  );
}

/// Natural-height Me carousel. Active subscriptions sort first, independently.
/// No service lookup: suitable for all four ownership combinations in previews.
class MemoryMembershipProfileCarousel extends StatelessWidget {
  const MemoryMembershipProfileCarousel({
    super.key,
    this.premiumActive = false,
    this.deluxeActive = false,
    this.premiumExpired = false,
    this.deluxeExpired = false,
    this.premiumExpiry,
    this.deluxeExpiry,
    required this.onPremiumSubscribe,
    required this.onDeluxeSubscribe,
  });
  final bool premiumActive;
  final bool deluxeActive;
  final bool premiumExpired;
  final bool deluxeExpired;
  final DateTime? premiumExpiry;
  final DateTime? deluxeExpiry;
  final VoidCallback onPremiumSubscribe;
  final VoidCallback onDeluxeSubscribe;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tiers = memoryMembershipOrder(
        premiumActive: premiumActive,
        deluxeActive: deluxeActive,
      );
      final width = memoryMembershipCardWidth(constraints.maxWidth);
      return SingleChildScrollView(
        key: ValueKey('membership-profile-pages'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tier in tiers) ...[
                if (tier != tiers.first) const SizedBox(width: 10),
                SizedBox(width: width, child: _profileCard(context, tier)),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _profileCard(BuildContext context, MemoryMembershipTier tier) {
    final premium = tier == MemoryMembershipTier.premium;
    final active = premium ? premiumActive : deluxeActive;
    final expired = premium ? premiumExpired : deluxeExpired;
    final expiry = premium ? premiumExpiry : deluxeExpiry;
    final onTap = premium ? onPremiumSubscribe : onDeluxeSubscribe;
    final buttonText = TextPainter(
      text: TextSpan(
        text: context.l10n.premiumSubscribe,
        style: GenesisTypography.resolve(
          context,
          const TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 82 - 16);
    final buttonHeight = (buttonText.height + 12).clamp(30.0, double.infinity);
    buttonText.dispose();
    return Semantics(
      button: true,
      label: context.l10n.memoryMembershipDetails(
        membership: tier.title(context),
      ),
      child: GestureDetector(
        key: ValueKey('membership-profile-${tier.name}'),
        onTap: onTap,
        child: MemoryMembershipSurface(
          tier: tier,
          kind: MemoryMembershipSurfaceKind.profile,
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset(
                            tier.crownAsset,
                            width: 26,
                            height: 17,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ShaderMask(
                              shaderCallback: tier.foreground.createShader,
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                tier.title(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.08,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(width: 8),
                            MemoryMembershipStatus(tier: tier),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (active || expired) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (!active)
                              MemoryMembershipStatus(tier: tier, expired: true),
                            if (expiry != null)
                              Text(
                                active
                                    ? context.l10n.expiresOn(
                                        date: memoryMembershipDate(expiry),
                                      )
                                    : memoryMembershipDate(expiry),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: tier.bodyColor,
                                ),
                              ),
                          ],
                        ),
                      ] else
                        MemoryMembershipOfferText(
                          premium
                              ? context.l10n.premiumMonthlyOffer(
                                  amount: '3,500',
                                )
                              : context.l10n.memoryMembershipDeluxeProfileOffer(
                                  amount: '18,000',
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: tier.bodyColor,
                          ),
                          figureStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: premium
                                ? const Color(0xFFFFF2D2)
                                : Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (active)
                  Icon(Icons.chevron_right, size: 16, color: tier.accent)
                else
                  SizedBox(
                    width: 82,
                    height: buttonHeight,
                    child: MemoryMembershipButton(
                      key: ValueKey('membership-subscribe-${tier.name}'),
                      tier: tier,
                      onPressed: onTap,
                      compact: true,
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

/// The source's track moves 280px at 390px, not the 324px card pitch.
/// Keeping both cards mounted also preserves independent vertical scroll offsets.
class _MembershipSlideTrack extends StatefulWidget {
  const _MembershipSlideTrack({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.children,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Widget> children;

  @override
  State<_MembershipSlideTrack> createState() => _MembershipSlideTrackState();
}

class _MembershipSlideTrackState extends State<_MembershipSlideTrack> {
  double _drag = 0;
  bool _dragging = false;

  void _finish({bool canceled = false}) {
    final next = canceled
        ? widget.selectedIndex
        : _drag < -48
        ? 1
        : _drag > 48
        ? 0
        : widget.selectedIndex;
    setState(() {
      _drag = 0;
      _dragging = false;
    });
    if (next != widget.selectedIndex) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = memoryMembershipCardWidth(constraints.maxWidth);
      final step = (cardWidth * 2 + 10 + 32 - constraints.maxWidth).clamp(
        0.0,
        double.infinity,
      );
      final base = -widget.selectedIndex * step;
      var offset = base + _drag;
      if (offset > 0) offset /= 3;
      if (offset < -step) offset = -step + (offset + step) / 3;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() {
          _dragging = true;
          _drag = 0;
        }),
        onHorizontalDragUpdate: (details) =>
            setState(() => _drag += details.delta.dx),
        onHorizontalDragEnd: (_) => _finish(),
        onHorizontalDragCancel: () => _finish(canceled: true),
        child: ClipRect(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(milliseconds: _dragging ? 0 : 280),
                curve: const Cubic(.2, .8, .2, 1),
                left: 16 + offset,
                top: 0,
                bottom: 0,
                width: cardWidth * 2 + 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < widget.children.length;
                      index++
                    ) ...[
                      if (index != 0) const SizedBox(width: 10),
                      SizedBox(
                        width: cardWidth,
                        child: GestureDetector(
                          onTap: () => widget.onChanged(index),
                          child: AnimatedOpacity(
                            opacity: index == widget.selectedIndex ? 1 : .85,
                            duration: const Duration(milliseconds: 240),
                            child: widget.children[index],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MembershipBenefitRow extends StatelessWidget {
  const _MembershipBenefitRow({
    required this.icon,
    this.text = '',
    this.content,
  });
  final Widget icon;
  final String text;
  final Widget? content;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 20,
        height: 19,
        child: Center(child: ExcludeSemantics(child: icon)),
      ),
      const SizedBox(width: 11),
      Expanded(
        child:
            content ??
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: GenesisColors.darkTextPrimary,
              ),
            ),
      ),
    ],
  );
}

Widget _benefitIcon(MemoryMembershipTier tier, int index) {
  final deluxe = tier == MemoryMembershipTier.deluxe;
  final tint = ColorFilter.mode(tier.accent, BlendMode.srcIn);
  if (deluxe && (index == 1 || index == 2)) {
    return SvgPicture.asset(
      index == 1
          ? 'assets/mini_phone/icons/memory-cast.svg'
          : 'assets/mini_phone/icons/memory-bonds.svg',
      width: 18,
      height: 18,
      colorFilter: tint,
    );
  }
  // These two paths are copied verbatim from Subscribe.dc.html. The other
  // source icons already exist in the shared asset library.
  if (index == 0 || deluxe && index == 3) {
    return SvgPicture.string(
      index == 0
          ? '<svg viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6.5C10.4 5 7.9 4.5 4 4.5v13c3.9 0 6.4.5 8 2 1.6-1.5 4.1-2 8-2v-13c-3.9 0-6.4.5-8 2z"/><path d="M12 6.5v13"/></svg>'
          : '<svg viewBox="0 0 14 14" fill="none" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"><path d="M7 2 C10 2 12.4 4 12.4 6.6 C12.4 9.2 10 11.2 7 11.2 C6.4 11.2 5.8 11.1 5.3 11 L2.6 12 L3.4 9.8 C2.3 9 1.6 7.9 1.6 6.6 C1.6 4 4 2 7 2 Z"/></svg>',
      width: 18,
      height: 18,
      colorFilter: tint,
    );
  }
  final item = index - (deluxe ? 4 : 1);
  final assets = [
    inspirationIconAsset,
    editSquareIconAsset,
    proCrownIconAsset,
    upgradeIconAsset,
  ];
  final sizes = [16.0, 15.0, 18.0, 17.0];
  return SvgPicture.asset(
    assets[item],
    width: sizes[item],
    height: sizes[item],
    colorFilter: ColorFilter.mode(tier.accent, BlendMode.srcIn),
  );
}

class _MembershipLegalLinks extends StatelessWidget {
  const _MembershipLegalLinks();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      color: Color(0x8CFFFFFF),
    );
    Widget link(String document, String label) => Semantics(
      link: true,
      child: GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(RouteNames.legal, arguments: {'document': document}),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
          ),
          child: Text(label, style: style),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        link('privacy', context.l10n.privacyPolicy),
        const Text('&', style: style),
        link('terms', context.l10n.termsOfService),
        const Text('&', style: style),
        link('eula', context.l10n.eulaShort),
      ],
    );
  }
}
