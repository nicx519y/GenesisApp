import 'package:flutter/gestures.dart';
import '../../ui/tokens/genesis_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/genesis_localizations.dart';
import 'memory_membership_style.dart';

const double _membershipCardSwipeThreshold = 12;
const double _subscriptionCardSwipeThreshold = 12;
const double _membershipCardFlingDistance = 8;
const double _membershipCardFlingVelocity = 200;

/// Presentation migrated from the design branch. Catalog and checkout remain
/// owned by the host; this widget performs no loading or billing.
class MemoryMembershipSubscriptionCarousel extends StatefulWidget {
  const MemoryMembershipSubscriptionCarousel({
    super.key,
    this.hasPurchased = false,
    this.premiumActive = false,
    this.deluxeActive = false,
    this.premiumExpiry,
    this.deluxeExpiry,
    this.initialTier,
    required this.footerBuilder,
    required this.benefitsBuilder,
    this.onBenefitsScroll,
    this.onTierChanged,
  });

  final bool hasPurchased;
  final bool premiumActive;
  final bool deluxeActive;
  final DateTime? premiumExpiry;
  final DateTime? deluxeExpiry;

  /// The card to open on when the entry asks for one; otherwise the lead card.
  final MemoryMembershipTier? initialTier;
  final Widget Function(double deluxeColorProgress) footerBuilder;
  final List<Widget> Function(MemoryMembershipTier) benefitsBuilder;
  final bool Function(ScrollNotification)? onBenefitsScroll;

  final ValueChanged<MemoryMembershipTier>? onTierChanged;

  @override
  State<MemoryMembershipSubscriptionCarousel> createState() =>
      _SubscriptionCarouselState();
}

class _SubscriptionCarouselState
    extends State<MemoryMembershipSubscriptionCarousel> {
  MemoryMembershipTier? _picked;
  MemoryMembershipTier? _reported;
  double? _dragColorProgress;

  @override
  void didUpdateWidget(
    covariant MemoryMembershipSubscriptionCarousel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTier != widget.initialTier) {
      _picked = null;
    }
  }

  List<MemoryMembershipTier> get _order => memoryMembershipOrder();

  MemoryMembershipTier get _tier =>
      _picked ??
      widget.initialTier ??
      memoryMembershipInitialTier(hasPurchased: widget.hasPurchased);

  void _selectTier(MemoryMembershipTier tier) {
    if (_tier == tier) return;
    setState(() => _picked = tier);
    _reported = tier;
    // User gestures update the purchase context in this event, before another
    // tap can use the footer. Initial/report-only notifications remain deferred.
    widget.onTierChanged?.call(tier);
  }

  /// Purchase history can settle after opening and change the default, so the card in
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
    onDragProgress: (progress) => setState(() => _dragColorProgress = progress),
    children: [
      for (final tier in _order)
        _BenefitsCard(
          tier: tier,
          benefits: widget.benefitsBuilder(tier),
          onBenefitsScroll: widget.onBenefitsScroll,
          active: tier == MemoryMembershipTier.premium
              ? widget.premiumActive
              : widget.deluxeActive,
          expiry: tier == MemoryMembershipTier.premium
              ? widget.premiumExpiry
              : widget.deluxeExpiry,
        ),
    ],
  );

  Widget _footer(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final tier in _order)
            Padding(
              padding: const EdgeInsets.all(5),
              child: InkWell(
                onTap: () => _selectTier(tier),
                child: Semantics(
                  button: true,
                  selected: _tier == tier,
                  label: tier.title(context),
                  child: Container(
                    width: _tier == tier ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _tier == tier
                          ? Colors.white
                          : const Color(0x59FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      TweenAnimationBuilder<double>(
        tween: Tween(
          end: _dragColorProgress ?? _order.indexOf(_tier).toDouble(),
        ),
        duration: _dragColorProgress == null
            ? membershipTierTransitionDuration
            : Duration.zero,
        curve: membershipTierTransitionCurve,
        builder: (_, progress, _) => widget.footerBuilder(progress),
      ),
    ],
  );

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
    required this.benefits,
    this.onBenefitsScroll,
    required this.expiry,
  });
  final MemoryMembershipTier tier;
  final bool active;
  final List<Widget> benefits;
  final bool Function(ScrollNotification)? onBenefitsScroll;
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
    return NotificationListener<ScrollNotification>(
      onNotification: widget.onBenefitsScroll,
      child: MemoryMembershipSurface(
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
                      l10n.expiresOn(
                        date: memoryMembershipDate(widget.expiry!),
                      ),
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
                            children: widget.benefits,
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
                                tier.background.colors.last.withValues(
                                  alpha: 0,
                                ),
                                tier.background.colors.last.withValues(
                                  alpha: .8,
                                ),
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
      ),
    );
  }
}

/// Natural-height Me carousel. The host supplies independent ownership and
/// purchase-history initial position; the Premium / Deluxe order never changes.
class MemoryMembershipProfileCarousel extends StatefulWidget {
  const MemoryMembershipProfileCarousel({
    super.key,
    this.hasPurchased = false,
    this.premiumActive = false,
    this.deluxeActive = false,
    this.premiumExpired = false,
    this.deluxeExpired = false,
    this.premiumOfferText,
    this.deluxeOfferText,
    this.premiumExpiry,
    this.deluxeExpiry,
    required this.onPremiumSubscribe,
    required this.onDeluxeSubscribe,
  });
  final String? premiumOfferText;
  final String? deluxeOfferText;
  final bool hasPurchased;
  final bool premiumActive;
  final bool deluxeActive;
  final bool premiumExpired;
  final bool deluxeExpired;
  final DateTime? premiumExpiry;
  final DateTime? deluxeExpiry;
  final VoidCallback onPremiumSubscribe;
  final VoidCallback onDeluxeSubscribe;

  @override
  State<MemoryMembershipProfileCarousel> createState() =>
      _MemoryMembershipProfileCarouselState();

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
                              ? premiumOfferText ??
                                    context.l10n.proSubscriptionTagline
                              : deluxeOfferText ??
                                    context.l10n.memoryMembershipDeluxeTagline,
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

class _MemoryMembershipProfileCarouselState
    extends State<MemoryMembershipProfileCarousel> {
  final _scroll = ScrollController();
  bool? _positionedAtDeluxe;
  bool _userScrolled = false;
  double _dragOrigin = 0;

  bool get _defaultsToDeluxe =>
      widget.deluxeActive || (!widget.premiumActive && widget.hasPurchased);

  void _positionDefault() {
    final deluxe = _defaultsToDeluxe;
    if (_userScrolled || _positionedAtDeluxe == deluxe) return;
    _positionedAtDeluxe = deluxe;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _userScrolled ||
          _defaultsToDeluxe != deluxe ||
          !_scroll.hasClients) {
        return;
      }
      _scroll.jumpTo(deluxe ? _scroll.position.maxScrollExtent : 0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _positionDefault();
      final tiers = memoryMembershipOrder();
      final width = memoryMembershipCardWidth(constraints.maxWidth);
      return NotificationListener<ScrollStartNotification>(
        onNotification: (event) {
          if (event.dragDetails != null &&
              event.metrics.axis == Axis.horizontal) {
            _userScrolled = true;
            _dragOrigin = _scroll.offset;
          }
          return false;
        },
        child: SingleChildScrollView(
          key: const ValueKey('membership-profile-pages'),
          controller: _scroll,
          physics: _MembershipCardSnapPhysics(dragOrigin: () => _dragOrigin),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tier in tiers) ...[
                  if (tier != tiers.first) const SizedBox(width: 10),
                  SizedBox(
                    width: width,
                    child: widget._profileCard(context, tier),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Snap the natural-height Me carousel to either card without changing its
/// width, side preview or scroll controller. The compact Me cards use a shorter
/// threshold and recognize quick flicks; tiny slow drags return to their origin.
class _MembershipCardSnapPhysics extends ScrollPhysics {
  const _MembershipCardSnapPhysics({required this.dragOrigin, super.parent});

  final double Function() dragOrigin;

  @override
  double get minFlingDistance => _membershipCardFlingDistance;

  @override
  double get minFlingVelocity => _membershipCardFlingVelocity;

  @override
  _MembershipCardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _MembershipCardSnapPhysics(
        dragOrigin: dragOrigin,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final start = position.minScrollExtent;
    final end = position.maxScrollExtent;
    final distance = end - start;
    if (distance <= 0) return null;
    final origin = dragOrigin().clamp(start, end);
    final delta = position.pixels - origin;
    final threshold = (distance / 2).clamp(0.0, _membershipCardSwipeThreshold);
    final quickFlick =
        velocity.abs() >= minFlingVelocity && delta.abs() >= minFlingDistance;
    final target = quickFlick
        ? (velocity > 0 ? end : start)
        : delta > threshold
        ? end
        : delta < -threshold
        ? start
        : origin <= start + distance / 2
        ? start
        : end;
    final tolerance = toleranceFor(position);
    if ((position.pixels - target).abs() <= tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// The source's track moves 280px at 390px, not the 324px card pitch.
/// Keeping both cards mounted also preserves independent vertical scroll offsets.
class _MembershipSlideTrack extends StatefulWidget {
  const _MembershipSlideTrack({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onDragProgress,
    required this.children,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final ValueChanged<double?> onDragProgress;
  final List<Widget> children;

  @override
  State<_MembershipSlideTrack> createState() => _MembershipSlideTrackState();
}

class _MembershipSlideTrackState extends State<_MembershipSlideTrack> {
  double _drag = 0;
  bool _dragging = false;
  DragStartDetails? _dragStart;
  Drag? _pageDrag;

  void _startDrag(DragStartDetails details) {
    setState(() {
      _dragStart = details;
      _dragging = true;
      _drag = 0;
    });
    widget.onDragProgress(widget.selectedIndex.toDouble());
  }

  void _updateDrag(DragUpdateDetails details, double step) {
    // The card track owns horizontal gestures inside the carousel. At its
    // boundary, forward the real drag to the surrounding TabBarView so its
    // page and tab indicator follow the finger, including canceled swipes.
    final atEnd =
        widget.selectedIndex == widget.children.length - 1 &&
        details.delta.dx < 0;
    final atStart = widget.selectedIndex == 0 && details.delta.dx > 0;
    if (_pageDrag == null &&
        _drag == 0 &&
        (atEnd || atStart) &&
        context.findAncestorWidgetOfExactType<TabBarView>() != null) {
      final position = Scrollable.maybeOf(
        context,
        axis: Axis.horizontal,
      )?.position;
      final canMove =
          position != null &&
          (atEnd
              ? position.pixels < position.maxScrollExtent
              : position.pixels > position.minScrollExtent);
      if (canMove && _dragStart != null) {
        _pageDrag = position.drag(_dragStart!, () => _pageDrag = null);
      }
    }
    final pageDrag = _pageDrag;
    if (pageDrag != null) {
      pageDrag.update(details);
    } else {
      setState(() => _drag += details.delta.dx);
      if (step > 0) {
        widget.onDragProgress(
          (widget.selectedIndex - _drag / step).clamp(0, 1),
        );
      }
    }
  }

  void _endDrag(DragEndDetails details) {
    final pageDrag = _pageDrag;
    if (pageDrag == null) {
      _finish();
      return;
    }
    _pageDrag = null;
    pageDrag.end(details);
    setState(() {
      _drag = 0;
      _dragging = false;
    });
    widget.onDragProgress(null);
  }

  void _cancelDrag() {
    final pageDrag = _pageDrag;
    _pageDrag = null;
    pageDrag?.cancel();
    _finish(canceled: true);
  }

  @override
  void dispose() {
    final pageDrag = _pageDrag;
    _pageDrag = null;
    pageDrag?.cancel();
    super.dispose();
  }

  void _finish({bool canceled = false}) {
    final next = canceled
        ? widget.selectedIndex
        : _drag < -_subscriptionCardSwipeThreshold
        ? 1
        : _drag > _subscriptionCardSwipeThreshold
        ? 0
        : widget.selectedIndex;
    setState(() {
      _drag = 0;
      _dragging = false;
    });
    if (next != widget.selectedIndex) widget.onChanged(next);
    widget.onDragProgress(null);
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
        onHorizontalDragStart: _startDrag,
        onHorizontalDragUpdate: (details) => _updateDrag(details, step),
        onHorizontalDragEnd: _endDrag,
        onHorizontalDragCancel: _cancelDrag,
        child: ClipRect(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : membershipTierTransitionDuration,
                curve: membershipTierTransitionCurve,
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
