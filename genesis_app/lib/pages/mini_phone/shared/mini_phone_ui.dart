import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../ui/tokens/genesis_blur.dart';
import '../../../ui/tokens/genesis_colors.dart';
import '../../../ui/tokens/genesis_typography.dart';
import '../../../ui/tokens/genesis_spacing.dart';
import '../../../ui/tokens/genesis_radii.dart';
import '../../../ui/components/genesis_dark_close_button.dart';

const miniPhoneAssets = 'assets/mini_phone/';

const miniBackground = GenesisColors.darkBackground;
const miniRaised = GenesisColors.darkRaisedBackground;
const miniPink = GenesisColors.redSecondary;
const miniRed = GenesisColors.redPrimary;
const miniWhite = GenesisColors.darkTextPrimary;
const miniSecondary = GenesisColors.darkTextSecondary;
const miniTertiary = GenesisColors.darkTextTertiary;
const miniPlaceholder = GenesisColors.darkInputPlaceholder;
const miniLine = GenesisColors.darkFaintFill;
const miniDivider = Color(0x0DFFFFFF);
const miniPageInset = GenesisSpacing.page;
const miniInputRadius = GenesisRadii.input;
const miniButtonRadius = GenesisRadii.button;
final miniPageTitle = GenesisTypography.pageTitle.copyWith(color: miniWhite);
final miniSectionTitle = GenesisTypography.bodyStrong.copyWith(
  fontSize: 16,
  color: miniWhite,
);

TextStyle miniStyle([
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = miniWhite,
]) => (size <= 12 ? GenesisTypography.supporting : GenesisTypography.body)
    .copyWith(fontSize: size, fontWeight: weight, color: color);

class MiniIcon extends StatelessWidget {
  const MiniIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = miniWhite,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    '${miniPhoneAssets}icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class MiniGlass extends StatelessWidget {
  const MiniGlass({
    super.key,
    required this.child,
    this.radius = 21,
    this.opacity = .42,
    this.light = false,
    this.outlined = true,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double radius, opacity;
  final bool light, outlined;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: GenesisBlur.strong,
        sigmaY: GenesisBlur.strong,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: (light ? Colors.white : miniRaised).withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: outlined
              ? Border.all(
                  color: light
                      ? const Color(0x40FFFFFF)
                      : const Color(0x33F4F3F6),
                )
              : null,
          gradient: light
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .1),
                    Colors.white.withValues(alpha: .02),
                  ],
                ),
        ),
        child: child,
      ),
    ),
  );
}

class MiniBadge extends StatelessWidget {
  const MiniBadge(this.count, {super.key});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: miniRed,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: GenesisTypography.supporting.copyWith(
        color: miniWhite,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class MiniIconButton extends StatelessWidget {
  const MiniIconButton(
    this.icon,
    this.label,
    this.onPressed, {
    super.key,
    this.glass = false,
  });
  final String icon, label;
  final VoidCallback? onPressed;
  final bool glass;
  @override
  Widget build(BuildContext context) {
    if (icon == 'close' && !glass) {
      return GenesisDarkCloseButton(onPressed: onPressed);
    }
    final button = IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      icon: MiniIcon(icon, size: 18),
    );
    return glass
        ? MiniGlass(radius: 13, child: button)
        : Container(
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: button,
          );
  }
}
