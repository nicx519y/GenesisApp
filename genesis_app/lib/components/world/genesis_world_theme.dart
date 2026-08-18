import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_palette.dart';

/// Colors owned by world details, progress, and map-adjacent controls.
@immutable
class GenesisWorldColors extends ThemeExtension<GenesisWorldColors> {
  const GenesisWorldColors({
    required this.tickSurface,
    required this.tickPositiveSurface,
    required this.success,
    required this.tabSurface,
    required this.tickDivider,
    required this.loadingSurface,
    required this.locationLine,
    required this.locationPositiveLine,
    required this.closeSurface,
    required this.avatarBorder,
  });

  factory GenesisWorldColors.light() => const GenesisWorldColors(
    tickSurface: Color(0xFFF4F5F8),
    tickPositiveSurface: Color(0xFFF0F8F4),
    success: Color(0xFF2F9663),
    tabSurface: Color(0xFFEBEFF2),
    tickDivider: Color(0xFFE1E4EA),
    loadingSurface: Color(0xFFE9EDF2),
    locationLine: Color(0xFFE5E8EC),
    locationPositiveLine: Color(0x661A6B28),
    closeSurface: Color(0xFFF3F3F5),
    avatarBorder: Color(0xFFDDDDDD),
  );

  factory GenesisWorldColors.worldoRedesign() => const GenesisWorldColors(
    tickSurface: GenesisPalette.redesignWhite08,
    tickPositiveSurface: GenesisPalette.redesignAccent14,
    success: GenesisPalette.redesignAccentSoft,
    tabSurface: GenesisPalette.redesignWhite10,
    tickDivider: GenesisPalette.redesignWhite12,
    loadingSurface: GenesisPalette.redesignSkeletonBase,
    locationLine: GenesisPalette.redesignWhite10,
    locationPositiveLine: GenesisPalette.redesignAccentSoft40,
    closeSurface: GenesisPalette.redesignWhite10,
    avatarBorder: GenesisPalette.redesignWhite18,
  );

  final Color tickSurface;
  final Color tickPositiveSurface;
  final Color success;
  final Color tabSurface;
  final Color tickDivider;
  final Color loadingSurface;
  final Color locationLine;
  final Color locationPositiveLine;
  final Color closeSurface;
  final Color avatarBorder;

  static GenesisWorldColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisWorldColors>() ??
      GenesisWorldColors.light();

  @override
  GenesisWorldColors copyWith({
    Color? tickSurface,
    Color? tickPositiveSurface,
    Color? success,
    Color? tabSurface,
    Color? tickDivider,
    Color? loadingSurface,
    Color? locationLine,
    Color? locationPositiveLine,
    Color? closeSurface,
    Color? avatarBorder,
  }) => GenesisWorldColors(
    tickSurface: tickSurface ?? this.tickSurface,
    tickPositiveSurface: tickPositiveSurface ?? this.tickPositiveSurface,
    success: success ?? this.success,
    tabSurface: tabSurface ?? this.tabSurface,
    tickDivider: tickDivider ?? this.tickDivider,
    loadingSurface: loadingSurface ?? this.loadingSurface,
    locationLine: locationLine ?? this.locationLine,
    locationPositiveLine: locationPositiveLine ?? this.locationPositiveLine,
    closeSurface: closeSurface ?? this.closeSurface,
    avatarBorder: avatarBorder ?? this.avatarBorder,
  );

  @override
  GenesisWorldColors lerp(
    covariant ThemeExtension<GenesisWorldColors>? other,
    double t,
  ) {
    if (other is! GenesisWorldColors) return this;
    return GenesisWorldColors(
      tickSurface: Color.lerp(tickSurface, other.tickSurface, t)!,
      tickPositiveSurface: Color.lerp(
        tickPositiveSurface,
        other.tickPositiveSurface,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      tabSurface: Color.lerp(tabSurface, other.tabSurface, t)!,
      tickDivider: Color.lerp(tickDivider, other.tickDivider, t)!,
      loadingSurface: Color.lerp(loadingSurface, other.loadingSurface, t)!,
      locationLine: Color.lerp(locationLine, other.locationLine, t)!,
      locationPositiveLine: Color.lerp(
        locationPositiveLine,
        other.locationPositiveLine,
        t,
      )!,
      closeSurface: Color.lerp(closeSurface, other.closeSurface, t)!,
      avatarBorder: Color.lerp(avatarBorder, other.avatarBorder, t)!,
    );
  }
}

extension GenesisWorldThemeContext on BuildContext {
  GenesisWorldColors get genesisWorldColors => GenesisWorldColors.of(this);
}
