import 'dart:math' as math;
import '../../network/models/membership_order_product.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_colors.dart';
import 'gem_assets.dart';
import 'pro_colors.dart';

/// Independent subscriptions: owning either tier never implies the other.
typedef MemoryMembershipTier = MembershipType;

const membershipTierTransitionDuration = Duration(milliseconds: 480);
const membershipTierTransitionCurve = Cubic(.2, .8, .2, 1);
const purchaseTabContentTopSpacing = 12.0;
const membershipPricePlaceholder = '--';
const deluxeInkOnPearl = Color(0xFF3A2530);

enum MemoryMembershipSurfaceKind { subscription, offer, profile }

/// Reproduces CSS gradient angles without distorting them on tall cards.
class MemoryMembershipGradient extends LinearGradient {
  const MemoryMembershipGradient({
    required this.degrees,
    required super.colors,
    super.stops,
  });
  final double degrees;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final radians = degrees * math.pi / 180;
    final direction = Offset(math.sin(radians), -math.cos(radians));
    final halfLength =
        (rect.width * direction.dx.abs() + rect.height * direction.dy.abs()) /
        2;
    return ui.Gradient.linear(
      rect.center - direction * halfLength,
      rect.center + direction * halfLength,
      colors,
      stops,
    );
  }
}

/// Product order is fixed. Purchase history selects the initial card only.
List<MemoryMembershipTier> memoryMembershipOrder() => const [
  MemoryMembershipTier.premium,
  MemoryMembershipTier.deluxe,
];

MemoryMembershipTier memoryMembershipInitialTier({
  required bool hasPurchased,
}) => hasPurchased ? MemoryMembershipTier.deluxe : MemoryMembershipTier.premium;

extension MemoryMembershipStyle on MemoryMembershipTier {
  String title(BuildContext context) => this == MemoryMembershipTier.premium
      ? context.l10n.premiumWorldo
      : context.l10n.memoryMembershipDeluxe;

  String offer(BuildContext context) => this == MemoryMembershipTier.premium
      ? context.l10n.memoryMembershipPremiumOffer
      : context.l10n.memoryMembershipDeluxeOffer;

  Color get accent => this == MemoryMembershipTier.premium
      ? premiumGold
      : const Color(0xFFFFD3DD);
  Color get bodyColor => this == MemoryMembershipTier.premium
      ? const Color(0xFFF0DDB2)
      : const Color(0xFFEBDDE2);
  String get crownAsset => this == MemoryMembershipTier.premium
      ? proCrownGoldIconAsset
      : proCrownDeluxeIconAsset;

  LinearGradient get foreground => this == MemoryMembershipTier.premium
      ? proTitleGradient
      : const LinearGradient(
          colors: [
            Color(0xFFF7B94A),
            Color(0xFFFFE9A6),
            Color(0xFFFFFFFF),
            Color(0xFFFFD3DD),
            Color(0xFFE3C6FF),
          ],
          stops: [0, .24, .5, .76, 1],
        );

  LinearGradient get background => MemoryMembershipGradient(
    degrees: 165,
    colors: this == MemoryMembershipTier.premium
        ? const [Color(0xFF3A2C12), Color(0xFF2A2214), Color(0xFF221C13)]
        : const [Color(0xFF322A3E), Color(0xFF26222F), Color(0xFF1F1C27)],
    stops: const [0, .55, 1],
  );

  LinearGradient cardBackground(MemoryMembershipSurfaceKind kind) =>
      this == MemoryMembershipTier.premium
      ? const MemoryMembershipGradient(
          degrees: 104,
          colors: [Color(0xFF3E2C0C), Color(0xFF6B4C12), Color(0xFF4A3410)],
          stops: [0, .52, 1],
        )
      : MemoryMembershipGradient(
          degrees: 104,
          colors: kind == MemoryMembershipSurfaceKind.profile
              ? const [Color(0xFF2B2536), Color(0xFF2A2533)]
              : const [Color(0xFF1B1922), Color(0xFF221E2B)],
        );

  LinearGradient? get cardSheen =>
      this == MemoryMembershipTier.deluxe ? _pearlSheen : null;

  LinearGradient get buttonGradient => this == MemoryMembershipTier.premium
      ? const MemoryMembershipGradient(
          degrees: 100,
          colors: [Color(0xFFF0B02F), Color(0xFFFFD96B), Color(0xFFF3B534)],
          stops: [0, .46, 1],
        )
      : const LinearGradient(
          colors: [
            Color(0xFFFFE3A3),
            Color(0xFFFFF6F2),
            Color(0xFFFFD3DD),
            Color(0xFFE3C6FF),
          ],
          stops: [0, .45, .75, 1],
        );
}

const _pearlSheen = MemoryMembershipGradient(
  degrees: 112,
  colors: [
    Color(0x47F7B94A),
    Color(0x00F7B94A),
    Color(0x00FFD3DD),
    Color(0x38FFD3DD),
    Color(0x42E3C6FF),
    Color(0x00E3C6FF),
  ],
  stops: [0, .26, .44, .58, .82, 1],
);

class MemoryMembershipSurface extends StatelessWidget {
  const MemoryMembershipSurface({
    super.key,
    required this.tier,
    required this.child,
    this.kind = MemoryMembershipSurfaceKind.subscription,
  });
  final MemoryMembershipTier tier;
  final Widget child;
  final MemoryMembershipSurfaceKind kind;

  @override
  Widget build(BuildContext context) {
    final subscription = kind == MemoryMembershipSurfaceKind.subscription;
    final offer = kind == MemoryMembershipSurfaceKind.offer;
    final profile = kind == MemoryMembershipSurfaceKind.profile;
    final radius = subscription ? 18.0 : 16.0;
    Widget sheen() => DecoratedBox(
      decoration: BoxDecoration(gradient: tier.cardBackground(kind)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: tier == MemoryMembershipTier.deluxe ? _pearlSheen : null,
        ),
        child: const SizedBox.expand(),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: subscription ? tier.background : tier.cardBackground(kind),
        ),
        child: Stack(
          children: [
            // An inset ring must not add padding to the 314px source card. It
            // sits under the sheen, so the line only shows where the sheen fades.
            if (subscription)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: tier.accent.withValues(alpha: .35),
                      ),
                    ),
                  ),
                ),
              ),
            if (subscription)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 200,
                child: IgnorePointer(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, .3, 1],
                    ).createShader,
                    child: sheen(),
                  ),
                ),
              )
            else if (tier == MemoryMembershipTier.deluxe)
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: _pearlSheen),
                  ),
                ),
              ),
            Positioned(
              right: offer
                  ? -22
                  : profile
                  ? -30
                  : -24,
              top: offer
                  ? -28
                  : profile
                  ? -22
                  : -26,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: offer ? .42 : .3,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: offer
                            ? const [Colors.white, Colors.white]
                            : const [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                        stops: offer ? const [0, 1] : const [0, .35, .92],
                      ).createShader,
                      child: SvgPicture.asset(
                        tier.crownAsset,
                        width: offer ? 176 : 150,
                        height: offer ? 125 : 106,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (offer)
              const Positioned.fill(
                child: IgnorePointer(
                  child: FractionallySizedBox(
                    heightFactor: .5,
                    alignment: Alignment.topCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x17FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (profile)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 56,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          offer
                              ? const Color(0x17FFFFFF)
                              : const Color(0x1AFFE296),
                          const Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            DefaultTextStyle.merge(
              style: const TextStyle(letterSpacing: 0),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Offer copy with its Gems figure set off, as the design has it: heavier and
/// brighter, with a Rose gem in front on the lock card.
class MemoryMembershipOfferText extends StatelessWidget {
  const MemoryMembershipOfferText(
    this.text, {
    super.key,
    required this.style,
    required this.figureStyle,
    this.gem = false,
    this.maxLines,
  });
  final String text;
  final TextStyle style;
  final TextStyle figureStyle;
  final bool gem;

  /// Ends in an ellipsis past this many lines; null lets the copy run on.
  final int? maxLines;

  static final _figure = RegExp(r'\d[\d,.\s\u00A0\u202F]*\d');

  @override
  Widget build(BuildContext context) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final figure = _figure.firstMatch(text);
    if (figure == null) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    return Text.rich(
      maxLines: maxLines,
      overflow: overflow,
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, figure.start)),
          // The gem and its figure never wrap apart.
          if (gem)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 1, right: 3),
                    child: SvgPicture.asset(
                      roseGemIconAsset,
                      width: 8,
                      height: 13,
                    ),
                  ),
                  Text(figure.group(0)!, style: style.merge(figureStyle)),
                ],
              ),
            )
          else
            TextSpan(text: figure.group(0), style: figureStyle),
          TextSpan(text: text.substring(figure.end)),
        ],
      ),
    );
  }
}

class MemoryMembershipStatus extends StatelessWidget {
  const MemoryMembershipStatus({
    super.key,
    required this.tier,
    this.expired = false,
  });
  final MemoryMembershipTier tier;
  final bool expired;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: expired
          ? const Color(0x1FFFFFFF)
          : tier == MemoryMembershipTier.premium
          ? const Color(0x33FFD98A)
          : const Color(0x2EFFD3DD),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      expired ? context.l10n.expiredStatus : context.l10n.activeStatus,
      style: TextStyle(
        color: expired
            ? GenesisColors.darkTextSecondary
            : tier == MemoryMembershipTier.premium
            ? const Color(0xFFFFD98A)
            : tier.accent,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .72,
      ),
    ),
  );
}

class MemoryMembershipHeading extends StatelessWidget {
  const MemoryMembershipHeading({
    super.key,
    required this.tier,
    this.active = false,
    this.fontSize = 20,
  });
  final MemoryMembershipTier tier;
  final bool active;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SvgPicture.asset(
        tier.crownAsset,
        width: 26,
        height: fontSize == 16 ? 17 : 18,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: tier.foreground.createShader,
              blendMode: BlendMode.srcIn,
              child: Text(
                tier.title(context),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: fontSize == 20 ? 1.2 : 20 / fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.005 * fontSize,
                ),
              ),
            ),
            if (active) MemoryMembershipStatus(tier: tier),
          ],
        ),
      ),
    ],
  );
}

class MemoryMembershipButton extends StatelessWidget {
  const MemoryMembershipButton({
    super.key,
    required this.tier,
    required this.onPressed,
    this.label,
    this.compact = false,
    this.subscription = false,
  });
  final MemoryMembershipTier tier;
  final VoidCallback? onPressed;
  final String? label;
  final bool compact;
  final bool subscription;

  @override
  Widget build(BuildContext context) {
    final premium = tier == MemoryMembershipTier.premium;
    final radius = subscription ? 13.0 : 12.0;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: subscription && onPressed != null
                ? [
                    BoxShadow(
                      color: premium
                          ? const Color(0x3DF5B62E)
                          : const Color(0x33FFD3DD),
                      offset: const Offset(0, 4),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                color: !subscription && premium
                    ? const Color(0xFFF3C558)
                    : null,
                gradient: subscription || !premium ? tier.buttonGradient : null,
              ),
              child: InkWell(
                onTap: onPressed,
                child: Container(
                  constraints: BoxConstraints(minHeight: compact ? 30 : 44),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 16,
                    vertical: compact ? 6 : 10,
                  ),
                  child: Text(
                    label ?? context.l10n.premiumSubscribe,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: premium
                          ? (subscription
                                ? premiumInkOnGold
                                : const Color(0xFF42290A))
                          : deluxeInkOnPearl,
                      letterSpacing: 0,
                      fontSize: compact
                          ? 12
                          : subscription
                          ? 18
                          : 13,
                      height: compact
                          ? 1.25
                          : subscription
                          ? 24 / 18
                          : 18 / 13,
                      fontWeight: subscription
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presentation-only selection. No SKU, order, or billing side effects.
class MemoryMembershipPlanSelector extends StatelessWidget {
  const MemoryMembershipPlanSelector({
    super.key,
    required this.tier,
    required this.yearly,
    required this.onChanged,
    this.yearlyPrice,
    this.savings,
    this.monthlyPrice,
    this.stacked = false,
    this.offer = false,
    this.deluxeColorProgress,
  });
  final MemoryMembershipTier tier;
  final bool yearly;
  final ValueChanged<bool> onChanged;
  final String? yearlyPrice;
  final int? savings;
  final String? monthlyPrice;
  final bool stacked;
  final bool offer;
  final double? deluxeColorProgress;

  Widget _plan(BuildContext context, bool annual) {
    final selected = annual == yearly;
    final premium = tier == MemoryMembershipTier.premium;
    final deluxeProgress = deluxeColorProgress ?? (premium ? 0.0 : 1.0);
    Color tierColor(Color gold, Color pink) =>
        Color.lerp(gold, pink, deluxeProgress)!;
    final price =
        (annual ? yearlyPrice : monthlyPrice) ?? membershipPricePlaceholder;
    final accent = offer
        ? (premium ? const Color(0xFFF3C558) : const Color(0xFFFFE3A3))
        : tierColor(premiumGold, MemoryMembershipTier.deluxe.accent);
    return Semantics(
      key: ValueKey('membership-${tier.name}-${annual ? 'yearly' : 'monthly'}'),
      selected: selected,
      button: true,
      label: context.l10n
          .subscriptionPlanAccessibility(
            period: annual ? 'year' : 'month',
            plan: annual ? context.l10n.yearlyPlan : context.l10n.monthlyPlan,
            price: price,
          )
          .replaceAll('Premium', premium ? 'Premium' : 'Deluxe'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(annual),
              child: Container(
                width: double.infinity,
                padding: offer
                    ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
                    : const EdgeInsets.fromLTRB(14, 16, 14, 14),
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: selected
                      ? offer
                            ? const Color(0x14FFFFFF)
                            : tierColor(
                                const Color(0x17F5C24B),
                                const Color(0x14FFD3DD),
                              )
                      : offer
                      ? const Color(0x08FFFFFF)
                      : const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    width: 1.5,
                    color: selected
                        ? accent
                        : offer
                        ? const Color(0x26FFFFFF)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      annual
                          ? context.l10n.yearlyPlan
                          : context.l10n.monthlyPlan,
                      style: TextStyle(
                        fontSize: offer ? 13 : 14,
                        height: offer ? 16 / 13 : 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: GenesisColors.darkTextPrimary,
                      ),
                    ),
                    SizedBox(height: offer ? 6 : 10),
                    Wrap(
                      spacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: offer ? 17 : 20,
                            height: offer ? 20 / 17 : 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: offer ? 0 : -.2,
                            color: offer
                                ? Colors.white
                                : !selected
                                ? GenesisColors.darkTextPrimary
                                : tierColor(
                                    premiumGoldLight,
                                    const Color(0xFFFFE8ED),
                                  ),
                          ),
                        ),
                        Text(
                          context.l10n.memoryMembershipPeriod(
                            period: annual ? 'year' : 'month',
                          ),
                          style: TextStyle(
                            fontSize: offer ? 11 : 12,
                            height: 1.25,
                            letterSpacing: 0,
                            color: const Color(0x8CFFFFFF),
                            fontWeight: offer
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: offer ? 6 : 8),
                    Text(
                      annual
                          ? context.l10n.memoryMembershipBilledAnnually
                          : context.l10n.premiumBilledMonthly,
                      style: TextStyle(
                        fontSize: offer ? 11 : 12,
                        height: offer ? 14 / 11 : 1.25,
                        letterSpacing: 0,
                        color: const Color(0x8CFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (annual && savings != null)
            Positioned(
              left: offer ? 10 : 0,
              top: -9,
              child: IgnorePointer(
                child: Container(
                  constraints: BoxConstraints(minHeight: offer ? 18 : 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: offer
                        ? accent
                        : tierColor(
                            const Color(0xFF3C3726),
                            const Color(0xFF352D38),
                          ),
                    gradient: offer && !premium ? tier.buttonGradient : null,
                    borderRadius: BorderRadius.circular(offer ? 9 : 5),
                    border: offer
                        ? null
                        : Border.all(color: accent.withValues(alpha: .5)),
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      context.l10n.premiumSaveSavings(
                        savings: savings.toString(),
                      ),
                      style: TextStyle(
                        color: offer
                            ? (premium
                                  ? const Color(0xFF42290A)
                                  : deluxeInkOnPearl)
                            : tier.accent,
                        fontSize: offer ? 10 : 12,
                        height: 1,
                        letterSpacing: 0,
                        fontWeight: offer ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => stacked
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _plan(context, true),
            const SizedBox(height: 12),
            _plan(context, false),
          ],
        )
      : IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _plan(context, true)),
              SizedBox(width: offer ? 10 : 12),
              Expanded(child: _plan(context, false)),
            ],
          ),
        );
}

String memoryMembershipDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

/// Cards hold the design's 314 wherever the next one can still peek in; only
/// narrower screens give up card width, so the peek never disappears.
double memoryMembershipCardWidth(double trackWidth) =>
    trackWidth >= 360 ? 314 : (trackWidth - 76).clamp(180.0, double.infinity);

/// Me cards are 216 wide at standard widths, leaving 148 of the adjacent card
/// visible at 390. The card shrinks on narrower screens, down to 180.
double memoryMembershipProfileCardWidth(double trackWidth) =>
    (trackWidth - 104).clamp(180.0, 216.0);
