import 'package:flutter/material.dart';

import '../ui/tokens/genesis_typography.dart';

/// Compact event count shown beside a map location label.
class WorldEventCountBadge extends StatelessWidget {
  const WorldEventCountBadge({super.key, required this.count});

  static const double minWidth = 20;
  static const double height = 16;
  static const double borderRadius = 6;
  static const double horizontalPadding = 5;
  static const double fontSize = 9.5;

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: minWidth),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF82B3C),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          inherit: false,
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
