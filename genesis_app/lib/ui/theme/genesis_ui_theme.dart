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
    required this.centeredAppBarHeight,
    required this.leadingTitleAppBarHeight,
    required this.compactAppBarHeight,
    required this.searchFieldHeight,
    required this.compactSearchFieldHeight,
    required this.regularButtonHeight,
    required this.compactButtonHeight,
    required this.searchBorderRadius,
    required this.tabIndicatorWidth,
    required this.tabIndicatorHeight,
    required this.panelBorderRadius,
  });

  factory GenesisUiTheme.light() {
    return const GenesisUiTheme(
      centeredAppBarHeight: 50,
      leadingTitleAppBarHeight: 64,
      compactAppBarHeight: 46,
      searchFieldHeight: 38,
      compactSearchFieldHeight: 36,
      regularButtonHeight: 42,
      compactButtonHeight: 40,
      searchBorderRadius: GenesisRadii.input,
      tabIndicatorWidth: 34,
      tabIndicatorHeight: 3,
      panelBorderRadius: GenesisRadii.panel,
    );
  }

  factory GenesisUiTheme.worldoRedesign() => GenesisUiTheme.light();

  final double centeredAppBarHeight;
  final double leadingTitleAppBarHeight;
  final double compactAppBarHeight;
  final double searchFieldHeight;
  final double compactSearchFieldHeight;
  final double regularButtonHeight;
  final double compactButtonHeight;
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
    double? centeredAppBarHeight,
    double? leadingTitleAppBarHeight,
    double? compactAppBarHeight,
    double? searchFieldHeight,
    double? compactSearchFieldHeight,
    double? regularButtonHeight,
    double? compactButtonHeight,
    BorderRadius? searchBorderRadius,
    double? tabIndicatorWidth,
    double? tabIndicatorHeight,
    BorderRadius? panelBorderRadius,
  }) {
    return GenesisUiTheme(
      centeredAppBarHeight: centeredAppBarHeight ?? this.centeredAppBarHeight,
      leadingTitleAppBarHeight:
          leadingTitleAppBarHeight ?? this.leadingTitleAppBarHeight,
      compactAppBarHeight: compactAppBarHeight ?? this.compactAppBarHeight,
      searchFieldHeight: searchFieldHeight ?? this.searchFieldHeight,
      compactSearchFieldHeight:
          compactSearchFieldHeight ?? this.compactSearchFieldHeight,
      regularButtonHeight: regularButtonHeight ?? this.regularButtonHeight,
      compactButtonHeight: compactButtonHeight ?? this.compactButtonHeight,
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
      centeredAppBarHeight: lerpDouble(
        centeredAppBarHeight,
        other.centeredAppBarHeight,
        t,
      )!,
      leadingTitleAppBarHeight: lerpDouble(
        leadingTitleAppBarHeight,
        other.leadingTitleAppBarHeight,
        t,
      )!,
      compactAppBarHeight: lerpDouble(
        compactAppBarHeight,
        other.compactAppBarHeight,
        t,
      )!,
      searchFieldHeight: lerpDouble(
        searchFieldHeight,
        other.searchFieldHeight,
        t,
      )!,
      compactSearchFieldHeight: lerpDouble(
        compactSearchFieldHeight,
        other.compactSearchFieldHeight,
        t,
      )!,
      regularButtonHeight: lerpDouble(
        regularButtonHeight,
        other.regularButtonHeight,
        t,
      )!,
      compactButtonHeight: lerpDouble(
        compactButtonHeight,
        other.compactButtonHeight,
        t,
      )!,
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
