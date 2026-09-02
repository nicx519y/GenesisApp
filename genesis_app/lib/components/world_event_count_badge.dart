import 'package:flutter/material.dart';

import '../ui/tokens/genesis_colors.dart';
import '../ui/tokens/genesis_typography.dart';

/// Compact event count shown beside a map location label.
class WorldEventCountBadge extends StatelessWidget {
  const WorldEventCountBadge({super.key, required this.count});

  static const double minWidth = 14;
  static const double height = 14;
  static const double borderRadius = height / 2;
  static const double horizontalPadding = 4;
  static const double fontSize = 9.5;

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final isSingleDigit = count >= 0 && count < 10;
    return Container(
      width: isSingleDigit ? height : null,
      constraints: const BoxConstraints(minWidth: minWidth),
      height: height,
      padding: isSingleDigit
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: GenesisColors.brand,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
