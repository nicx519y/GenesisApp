import 'package:flutter/material.dart';

import '../tokens/genesis_palette.dart';

/// Theme-aware color roles used by pages and reusable UI components.
///
/// Role names describe intent instead of a physical color, so another skin can
/// provide different values without requiring changes in consuming widgets.
@immutable
class GenesisSemanticColors extends ThemeExtension<GenesisSemanticColors> {
  const GenesisSemanticColors({
    required this.pageBackground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.surfaceSubtle,
    required this.inputBackground,
    required this.controlMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.accentText,
    required this.border,
    required this.borderSubtle,
    required this.borderStrong,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.primaryDisabled,
    required this.danger,
    required this.onDanger,
    required this.navigationBackground,
    required this.navigationSelected,
    required this.navigationUnselected,
    required this.scrim,
    required this.shadow,
  });

  factory GenesisSemanticColors.light() {
    return const GenesisSemanticColors(
      pageBackground: GenesisPalette.white,
      surface: GenesisPalette.white,
      surfaceRaised: GenesisPalette.surfacePanel,
      surfaceMuted: GenesisPalette.surfaceMuted,
      surfaceSubtle: GenesisPalette.surfaceSubtle,
      inputBackground: GenesisPalette.surfaceInput,
      controlMuted: GenesisPalette.controlMuted,
      textPrimary: GenesisPalette.textPrimary,
      textSecondary: GenesisPalette.textSecondary,
      textTertiary: GenesisPalette.textTertiary,
      textDisabled: GenesisPalette.textDisabled,
      textInverse: GenesisPalette.white,
      accentText: GenesisPalette.accentText,
      border: GenesisPalette.border,
      borderSubtle: GenesisPalette.borderSubtle,
      borderStrong: GenesisPalette.borderStrong,
      divider: GenesisPalette.border,
      primary: GenesisPalette.brand,
      onPrimary: GenesisPalette.white,
      primaryDisabled: GenesisPalette.brandSoft,
      danger: GenesisPalette.create,
      onDanger: GenesisPalette.white,
      navigationBackground: GenesisPalette.white,
      navigationSelected: GenesisPalette.navigationSelected,
      navigationUnselected: GenesisPalette.navigationUnselected,
      scrim: GenesisPalette.black,
      shadow: GenesisPalette.shadow,
    );
  }

  final Color pageBackground;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color surfaceSubtle;
  final Color inputBackground;
  final Color controlMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textInverse;
  final Color accentText;
  final Color border;
  final Color borderSubtle;
  final Color borderStrong;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final Color primaryDisabled;
  final Color danger;
  final Color onDanger;
  final Color navigationBackground;
  final Color navigationSelected;
  final Color navigationUnselected;
  final Color scrim;
  final Color shadow;

  static GenesisSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<GenesisSemanticColors>() ??
        GenesisSemanticColors.light();
  }

  @override
  GenesisSemanticColors copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? surfaceSubtle,
    Color? inputBackground,
    Color? controlMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textInverse,
    Color? accentText,
    Color? border,
    Color? borderSubtle,
    Color? borderStrong,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? primaryDisabled,
    Color? danger,
    Color? onDanger,
    Color? navigationBackground,
    Color? navigationSelected,
    Color? navigationUnselected,
    Color? scrim,
    Color? shadow,
  }) {
    return GenesisSemanticColors(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      inputBackground: inputBackground ?? this.inputBackground,
      controlMuted: controlMuted ?? this.controlMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      accentText: accentText ?? this.accentText,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDisabled: primaryDisabled ?? this.primaryDisabled,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      navigationBackground: navigationBackground ?? this.navigationBackground,
      navigationSelected: navigationSelected ?? this.navigationSelected,
      navigationUnselected: navigationUnselected ?? this.navigationUnselected,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  GenesisSemanticColors lerp(
    covariant ThemeExtension<GenesisSemanticColors>? other,
    double t,
  ) {
    if (other is! GenesisSemanticColors) return this;
    return GenesisSemanticColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      controlMuted: Color.lerp(controlMuted, other.controlMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryDisabled: Color.lerp(primaryDisabled, other.primaryDisabled, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      navigationSelected: Color.lerp(
        navigationSelected,
        other.navigationSelected,
        t,
      )!,
      navigationUnselected: Color.lerp(
        navigationUnselected,
        other.navigationUnselected,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension GenesisThemeContext on BuildContext {
  GenesisSemanticColors get genesisColors => GenesisSemanticColors.of(this);
}
