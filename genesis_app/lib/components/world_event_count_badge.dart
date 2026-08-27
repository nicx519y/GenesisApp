import 'package:flutter/material.dart';

/// Compact event count shown at the top-right of a map location label.
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
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Keep a 4 × 4px seam with the label corner: this is the prior 3px seam moved
// one pixel farther into the label on both axes. The badge otherwise sits
// outside the label so it cannot cover the location name.
const double worldMapLocationEventBadgeRight = -16;
const double worldMapLocationEventBadgeTop = -12;
