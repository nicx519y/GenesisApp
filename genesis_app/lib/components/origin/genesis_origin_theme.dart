import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

/// Colors owned by the Origin/Worldo experience rather than by global UI.
@immutable
class GenesisOriginColors extends ThemeExtension<GenesisOriginColors> {
  const GenesisOriginColors({
    required this.launchPreviewAccent,
    required this.feedTabInactive,
    required this.roleSetupBackdrop,
    required this.roleSetupPanel,
    required this.roleSetupGradientStart,
    required this.roleSetupGradientEnd,
    required this.roleSetupMuted,
    required this.roleSetupDisabled,
    required this.roleSetupSelectionOverlay,
    required this.launchSheetSurface,
    required this.launchSheetBorder,
    required this.launchSheetDisabled,
    required this.loadingBone,
    required this.launchSheetSecondaryText,
    required this.launchSheetInputBorder,
  });

  factory GenesisOriginColors.worldoLight() => const GenesisOriginColors(
    launchPreviewAccent: GenesisPalette.redesignAccentDark,
    feedTabInactive: GenesisPalette.redesignTextSecondary,
    roleSetupBackdrop: GenesisPalette.redesignBlack85,
    roleSetupPanel: GenesisPalette.redesignRaised,
    roleSetupGradientStart: GenesisPalette.redesignGradientStart,
    roleSetupGradientEnd: GenesisPalette.redesignInk,
    roleSetupMuted: GenesisPalette.redesignWhite55,
    roleSetupDisabled: GenesisPalette.redesignWhite32,
    roleSetupSelectionOverlay: GenesisPalette.redesignAccent40,
    launchSheetSurface: GenesisPalette.white,
    launchSheetBorder: GenesisPalette.border,
    launchSheetDisabled: GenesisPalette.surfaceDisabled,
    loadingBone: GenesisPalette.skeletonBase,
    launchSheetSecondaryText: GenesisPalette.redesignInk60,
    launchSheetInputBorder: GenesisPalette.inputBorder,
  );

  factory GenesisOriginColors.worldoDark() => const GenesisOriginColors(
    launchPreviewAccent: GenesisPalette.redesignAccentSoft,
    feedTabInactive: GenesisPalette.redesignFeedTabInactive,
    roleSetupBackdrop: GenesisPalette.redesignBlack85,
    roleSetupPanel: GenesisPalette.redesignRaised,
    roleSetupGradientStart: GenesisPalette.redesignGradientStart,
    roleSetupGradientEnd: GenesisPalette.redesignInk,
    roleSetupMuted: GenesisPalette.redesignWhite55,
    roleSetupDisabled: GenesisPalette.redesignWhite32,
    roleSetupSelectionOverlay: GenesisPalette.redesignAccent40,
    launchSheetSurface: GenesisPalette.redesignRaised,
    launchSheetBorder: GenesisPalette.redesignWhite12,
    launchSheetDisabled: GenesisPalette.redesignWhite08,
    loadingBone: GenesisPalette.redesignSkeletonBase,
    launchSheetSecondaryText: GenesisPalette.redesignWhite72,
    launchSheetInputBorder: GenesisPalette.redesignWhite18,
  );

  final Color launchPreviewAccent;
  final Color feedTabInactive;
  final Color roleSetupBackdrop;
  final Color roleSetupPanel;
  final Color roleSetupGradientStart;
  final Color roleSetupGradientEnd;
  final Color roleSetupMuted;
  final Color roleSetupDisabled;
  final Color roleSetupSelectionOverlay;
  final Color launchSheetSurface;
  final Color launchSheetBorder;
  final Color launchSheetDisabled;
  final Color loadingBone;
  final Color launchSheetSecondaryText;
  final Color launchSheetInputBorder;

  static GenesisOriginColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? GenesisOriginColors.worldoDark()
      : GenesisOriginColors.worldoLight();

  static GenesisOriginColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisOriginColors>() ??
      GenesisOriginColors.forBrightness(Theme.of(context).brightness);

  @override
  GenesisOriginColors copyWith({
    Color? launchPreviewAccent,
    Color? feedTabInactive,
    Color? roleSetupBackdrop,
    Color? roleSetupPanel,
    Color? roleSetupGradientStart,
    Color? roleSetupGradientEnd,
    Color? roleSetupMuted,
    Color? roleSetupDisabled,
    Color? roleSetupSelectionOverlay,
    Color? launchSheetSurface,
    Color? launchSheetBorder,
    Color? launchSheetDisabled,
    Color? loadingBone,
    Color? launchSheetSecondaryText,
    Color? launchSheetInputBorder,
  }) => GenesisOriginColors(
    launchPreviewAccent: launchPreviewAccent ?? this.launchPreviewAccent,
    feedTabInactive: feedTabInactive ?? this.feedTabInactive,
    roleSetupBackdrop: roleSetupBackdrop ?? this.roleSetupBackdrop,
    roleSetupPanel: roleSetupPanel ?? this.roleSetupPanel,
    roleSetupGradientStart:
        roleSetupGradientStart ?? this.roleSetupGradientStart,
    roleSetupGradientEnd: roleSetupGradientEnd ?? this.roleSetupGradientEnd,
    roleSetupMuted: roleSetupMuted ?? this.roleSetupMuted,
    roleSetupDisabled: roleSetupDisabled ?? this.roleSetupDisabled,
    roleSetupSelectionOverlay:
        roleSetupSelectionOverlay ?? this.roleSetupSelectionOverlay,
    launchSheetSurface: launchSheetSurface ?? this.launchSheetSurface,
    launchSheetBorder: launchSheetBorder ?? this.launchSheetBorder,
    launchSheetDisabled: launchSheetDisabled ?? this.launchSheetDisabled,
    loadingBone: loadingBone ?? this.loadingBone,
    launchSheetSecondaryText:
        launchSheetSecondaryText ?? this.launchSheetSecondaryText,
    launchSheetInputBorder:
        launchSheetInputBorder ?? this.launchSheetInputBorder,
  );

  @override
  GenesisOriginColors lerp(
    covariant ThemeExtension<GenesisOriginColors>? other,
    double t,
  ) {
    if (other is! GenesisOriginColors) return this;
    return GenesisOriginColors(
      launchPreviewAccent: Color.lerp(
        launchPreviewAccent,
        other.launchPreviewAccent,
        t,
      )!,
      feedTabInactive: Color.lerp(feedTabInactive, other.feedTabInactive, t)!,
      roleSetupBackdrop: Color.lerp(
        roleSetupBackdrop,
        other.roleSetupBackdrop,
        t,
      )!,
      roleSetupPanel: Color.lerp(roleSetupPanel, other.roleSetupPanel, t)!,
      roleSetupGradientStart: Color.lerp(
        roleSetupGradientStart,
        other.roleSetupGradientStart,
        t,
      )!,
      roleSetupGradientEnd: Color.lerp(
        roleSetupGradientEnd,
        other.roleSetupGradientEnd,
        t,
      )!,
      roleSetupMuted: Color.lerp(roleSetupMuted, other.roleSetupMuted, t)!,
      roleSetupDisabled: Color.lerp(
        roleSetupDisabled,
        other.roleSetupDisabled,
        t,
      )!,
      roleSetupSelectionOverlay: Color.lerp(
        roleSetupSelectionOverlay,
        other.roleSetupSelectionOverlay,
        t,
      )!,
      launchSheetSurface: Color.lerp(
        launchSheetSurface,
        other.launchSheetSurface,
        t,
      )!,
      launchSheetBorder: Color.lerp(
        launchSheetBorder,
        other.launchSheetBorder,
        t,
      )!,
      launchSheetDisabled: Color.lerp(
        launchSheetDisabled,
        other.launchSheetDisabled,
        t,
      )!,
      loadingBone: Color.lerp(loadingBone, other.loadingBone, t)!,
      launchSheetSecondaryText: Color.lerp(
        launchSheetSecondaryText,
        other.launchSheetSecondaryText,
        t,
      )!,
      launchSheetInputBorder: Color.lerp(
        launchSheetInputBorder,
        other.launchSheetInputBorder,
        t,
      )!,
    );
  }
}

extension GenesisOriginThemeContext on BuildContext {
  GenesisOriginColors get genesisOriginColors => GenesisOriginColors.of(this);
}
