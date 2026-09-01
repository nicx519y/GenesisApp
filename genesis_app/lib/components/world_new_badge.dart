import 'package:flutter/material.dart';

import '../ui/tokens/genesis_colors.dart';
import '../ui/tokens/genesis_typography.dart';

/// Marks world content that was added since the user's previous visit.
class WorldNewBadge extends StatelessWidget {
  const WorldNewBadge({super.key, this.compact = false});

  static const double compactWidth = 26;
  static const double compactHeight = 14;
  static const double width = 30;
  static const double height = 16;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'New',
      excludeSemantics: true,
      child: Container(
        width: compact ? compactWidth : width,
        height: compact ? compactHeight : height,
        decoration: BoxDecoration(
          color: GenesisColors.brand,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          'New',
          maxLines: 1,
          style: TextStyle(
            inherit: false,
            fontFamily: GenesisTypography.fontFamily,
            fontFamilyFallback: GenesisTypography.fontFamilyFallback,
            color: Colors.white,
            fontSize: compact ? 9 : 10,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
