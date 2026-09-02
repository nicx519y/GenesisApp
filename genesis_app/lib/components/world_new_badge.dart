import 'package:flutter/material.dart';

import '../ui/tokens/genesis_colors.dart';
import '../ui/tokens/genesis_typography.dart';

/// Marks world content that was added since the user's previous visit.
class WorldNewBadge extends StatelessWidget {
  const WorldNewBadge({super.key, this.compact = false});

  static const double compactWidth = 20;
  static const double compactHeight = 14;
  static const double width = 22;
  static const double height = 16;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'New',
      excludeSemantics: true,
      child: SizedBox(
        width: compact ? compactWidth : width,
        height: compact ? compactHeight : height,
        child: Center(
          child: Text(
            'new',
            maxLines: 1,
            style: TextStyle(
              inherit: false,
              fontFamily: GenesisTypography.fontFamily,
              fontFamilyFallback: GenesisTypography.fontFamilyFallback,
              color: GenesisColors.brand,
              fontSize: compact ? 9 : 10,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
