import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/genesis_radii.dart';

/// Theme metrics for reusable Genesis UI components.
///
/// Adaptive colors live in `GenesisSemanticColors`, while typography structure
/// lives in `GenesisTypography`. Keeping this extension metric-only prevents a
/// second, competing source of theme colors.
class GenesisUiTheme extends ThemeExtension<GenesisUiTheme> {
  const GenesisUiTheme({
    required this.searchBorderRadius,
    required this.tabIndicatorWidth,
    required this.tabIndicatorHeight,
    required this.panelBorderRadius,
  });

  factory GenesisUiTheme.light() {
    return const GenesisUiTheme(
      searchBorderRadius: GenesisRadii.input,
      tabIndicatorWidth: 34,
      tabIndicatorHeight: 3,
      panelBorderRadius: GenesisRadii.panel,
    );
  }

  factory GenesisUiTheme.worldoRedesign() => GenesisUiTheme.light();

  final BorderRadius searchBorderRadius;
  final double tabIndicatorWidth;
  final double tabIndicatorHeight;
  final BorderRadius panelBorderRadius;

  static GenesisUiTheme of(BuildContext context) {
    return Theme.of(context).extension<GenesisUiTheme>() ??
        GenesisUiTheme.light();
  }

  @override
  GenesisUiTheme copyWith({
    BorderRadius? searchBorderRadius,
    double? tabIndicatorWidth,
    double? tabIndicatorHeight,
    BorderRadius? panelBorderRadius,
  }) {
    return GenesisUiTheme(
      searchBorderRadius: searchBorderRadius ?? this.searchBorderRadius,
      tabIndicatorWidth: tabIndicatorWidth ?? this.tabIndicatorWidth,
      tabIndicatorHeight: tabIndicatorHeight ?? this.tabIndicatorHeight,
      panelBorderRadius: panelBorderRadius ?? this.panelBorderRadius,
    );
  }

  @override
  GenesisUiTheme lerp(
    covariant ThemeExtension<GenesisUiTheme>? other,
    double t,
  ) {
    if (other is! GenesisUiTheme) return this;
    return GenesisUiTheme(
      searchBorderRadius: BorderRadius.lerp(
        searchBorderRadius,
        other.searchBorderRadius,
        t,
      )!,
      tabIndicatorWidth: lerpDouble(
        tabIndicatorWidth,
        other.tabIndicatorWidth,
        t,
      )!,
      tabIndicatorHeight: lerpDouble(
        tabIndicatorHeight,
        other.tabIndicatorHeight,
        t,
      )!,
      panelBorderRadius: BorderRadius.lerp(
        panelBorderRadius,
        other.panelBorderRadius,
        t,
      )!,
    );
  }
}
