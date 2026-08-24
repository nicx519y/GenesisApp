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
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.36,
  );

  static const TextStyle displayTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  static const TextStyle metricValue = displayTitle;

  static const TextStyle prominentMetricValue = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  static const TextStyle navigationTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// 地图顶栏的世界名。设计稿 9a/9b:17/800/1.1。
  /// 只有 world_top_overlay_bar 和 world_header 两处在用;顶栏返回按钮是顶对齐,
  /// 靠标题列的 `EdgeInsets.only(top: 2)` 配平,改动 fontSize/height 会连带错位。
  static const TextStyle immersiveTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  static const TextStyle contentTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const TextStyle navigationAction = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  static const TextStyle itemTitle = sectionTitle;

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    height: 1.45,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
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
