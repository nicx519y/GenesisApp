import 'package:flutter/material.dart';

import 'genesis_colors.dart';

abstract final class GenesisTypography {
  static const double iosInlineEmphasisSkew = -0.16;

  static const TextStyle pageTitle = TextStyle(
    color: GenesisColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    color: GenesisColors.textPrimary,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    color: GenesisColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle supporting = TextStyle(
    color: GenesisColors.textSecondary,
    fontSize: 12,
    height: 1.4,
  );

  static const TextStyle tabLabel = TextStyle(fontSize: 11, height: 1.4);

  static TextTheme get textTheme => const TextTheme(
    titleMedium: pageTitle,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: supporting,
    labelSmall: tabLabel,
  );

  static TextStyle withFallback(TextStyle style) {
    return style;
  }

  static TextStyle inlineEmphasis(
    TextStyle baseStyle, {
    required TargetPlatform platform,
    Color? color,
  }) {
    final style = baseStyle.copyWith(color: color);
    if (platform == TargetPlatform.iOS) {
      return style.copyWith(fontStyle: FontStyle.normal);
    }
    return style.copyWith(fontStyle: FontStyle.italic);
  }
}
