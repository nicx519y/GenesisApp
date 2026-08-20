import 'package:flutter/material.dart';

abstract final class GenesisTypography {
  static const String fontFamily = 'Inter';
  static const List<String> fontFamilyFallback = <String>[
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
  ];

  static const double iosInlineEmphasisSkew = -0.16;

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    height: 1.4,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    height: 1.4,
  );

  static TextTheme get textTheme => const TextTheme(
    titleMedium: pageTitle,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: supporting,
    labelSmall: tabLabel,
  );

  static TextStyle withFallback(TextStyle style) {
    if (style.fontFamily != null) {
      return style;
    }
    return style.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
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
