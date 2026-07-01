import 'package:flutter/material.dart';

import '../tokens/genesis_typography.dart';

class GenesisTextFallback extends StatelessWidget {
  const GenesisTextFallback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamilyFallback: GenesisTypography.fallbackFontFamilies,
      ),
      child: child,
    );
  }
}
