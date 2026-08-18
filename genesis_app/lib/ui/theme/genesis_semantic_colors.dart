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
    required this.surfaceEmpty,
    required this.surfaceSoft,
    required this.surfaceSubtle,
    required this.surfaceProgress,
    required this.surfaceSheet,
    required this.imagePlaceholder,
    required this.inputBackground,
    required this.controlMuted,
    required this.controlBackground,
    required this.textPrimary,
    required this.textHighEmphasis,
    required this.foregroundStrong,
    required this.textHeading,
    required this.textStrong,
    required this.textBody,
    required this.textCinematic,
    required this.textQuaternary,
    required this.textMuted,
    required this.textSecondary,
    required this.textSubtle,
    required this.textTagline,
    required this.textFaint,
    required this.textSupporting,
    required this.textTimestamp,
    required this.textMetadata,
    required this.inputHint,
    required this.textTertiary,
    required this.textEmptyState,
    required this.textLabelMuted,
    required this.textPlaceholder,
    required this.textDisabled,
    required this.textInverse,
    required this.accentText,
    required this.link,
    required this.iconMuted,
    required this.imagePlaceholderIcon,
    required this.border,
    required this.borderNeutral,
    required this.borderSubtle,
    required this.borderStrong,
    required this.inputBorder,
    required this.divider,
    required this.dividerSubtle,
    required this.dividerMuted,
    required this.dividerAction,
    required this.dragHandle,
    required this.dragHandleSubtle,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.primary,
    required this.onPrimary,
    required this.primaryDisabled,
    required this.danger,
    required this.dangerControl,
    required this.dangerSurface,
    required this.dangerBorder,
    required this.onDanger,
    required this.surfaceDisabled,
    required this.surfaceGrouped,
    required this.surfaceTag,
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
      surfaceEmpty: GenesisPalette.surfaceEmpty,
      surfaceSoft: GenesisPalette.surfaceSoft,
      surfaceSubtle: GenesisPalette.surfaceSubtle,
      surfaceProgress: GenesisPalette.surfaceProgress,
      surfaceSheet: GenesisPalette.surfaceSheet,
      imagePlaceholder: GenesisPalette.imagePlaceholder,
      inputBackground: GenesisPalette.surfaceInput,
      controlMuted: GenesisPalette.controlMuted,
      controlBackground: GenesisPalette.controlBackground,
      textPrimary: GenesisPalette.textPrimary,
      textHighEmphasis: GenesisPalette.textHighEmphasis,
      foregroundStrong: GenesisPalette.foregroundStrong,
      textHeading: GenesisPalette.textHeading,
      textStrong: GenesisPalette.textStrong,
      textBody: GenesisPalette.textBody,
      textCinematic: GenesisPalette.textCinematic,
      textQuaternary: GenesisPalette.textQuaternary,
      textMuted: GenesisPalette.textMuted,
      textSecondary: GenesisPalette.textSecondary,
      textSubtle: GenesisPalette.textSubtle,
      textTagline: GenesisPalette.textTagline,
      textFaint: GenesisPalette.textFaint,
      textSupporting: GenesisPalette.textSupporting,
      textTimestamp: GenesisPalette.textTimestamp,
      textMetadata: GenesisPalette.textMetadata,
      inputHint: GenesisPalette.inputHint,
      textTertiary: GenesisPalette.textTertiary,
      textEmptyState: GenesisPalette.textEmptyState,
      textLabelMuted: GenesisPalette.textLabelMuted,
      textPlaceholder: GenesisPalette.textPlaceholder,
      textDisabled: GenesisPalette.textDisabled,
      textInverse: GenesisPalette.white,
      accentText: GenesisPalette.accentText,
      link: GenesisPalette.link,
      iconMuted: GenesisPalette.iconMuted,
      imagePlaceholderIcon: GenesisPalette.imagePlaceholderIcon,
      border: GenesisPalette.border,
      borderNeutral: GenesisPalette.borderNeutral,
      borderSubtle: GenesisPalette.borderSubtle,
      borderStrong: GenesisPalette.borderStrong,
      inputBorder: GenesisPalette.inputBorder,
      divider: GenesisPalette.border,
      dividerSubtle: GenesisPalette.dividerSubtle,
      dividerMuted: GenesisPalette.dividerMuted,
      dividerAction: GenesisPalette.dividerAction,
      dragHandle: GenesisPalette.dragHandle,
      dragHandleSubtle: GenesisPalette.dragHandleSubtle,
      skeletonBase: GenesisPalette.skeletonBase,
      skeletonHighlight: GenesisPalette.skeletonHighlight,
      primary: GenesisPalette.brand,
      onPrimary: GenesisPalette.white,
      primaryDisabled: GenesisPalette.brandSoft,
      danger: GenesisPalette.create,
      dangerControl: GenesisPalette.dangerControl,
      dangerSurface: GenesisPalette.dangerSurface,
      dangerBorder: GenesisPalette.dangerBorder,
      onDanger: GenesisPalette.white,
      surfaceDisabled: GenesisPalette.surfaceDisabled,
      surfaceGrouped: GenesisPalette.surfaceGrouped,
      surfaceTag: GenesisPalette.surfaceTag,
      navigationBackground: GenesisPalette.white,
      navigationSelected: GenesisPalette.navigationSelected,
      navigationUnselected: GenesisPalette.navigationUnselected,
      scrim: GenesisPalette.black,
      shadow: GenesisPalette.shadow,
    );
  }

  factory GenesisSemanticColors.worldoRedesign() {
    return const GenesisSemanticColors(
      pageBackground: GenesisPalette.redesignBackground,
      surface: GenesisPalette.redesignBackground,
      surfaceRaised: GenesisPalette.redesignRaised,
      surfaceMuted: GenesisPalette.redesignRaised,
      surfaceEmpty: GenesisPalette.redesignRaised,
      surfaceSoft: GenesisPalette.redesignWhite08,
      surfaceSubtle: GenesisPalette.redesignWhite06,
      surfaceProgress: GenesisPalette.redesignWhite08,
      surfaceSheet: GenesisPalette.redesignRaised,
      imagePlaceholder: GenesisPalette.redesignWhite08,
      inputBackground: GenesisPalette.redesignWhite07,
      controlMuted: GenesisPalette.redesignWhite10,
      controlBackground: GenesisPalette.redesignWhite08,
      textPrimary: GenesisPalette.white,
      textHighEmphasis: GenesisPalette.redesignWhite88,
      foregroundStrong: GenesisPalette.white,
      textHeading: GenesisPalette.white,
      textStrong: GenesisPalette.redesignWhite88,
      textBody: GenesisPalette.redesignWhite82,
      textCinematic: GenesisPalette.redesignWhite82,
      textQuaternary: GenesisPalette.redesignWhite72,
      textMuted: GenesisPalette.redesignWhite60,
      textSecondary: GenesisPalette.redesignWhite72,
      textSubtle: GenesisPalette.redesignWhite55,
      textTagline: GenesisPalette.redesignWhite55,
      textFaint: GenesisPalette.redesignWhite50,
      textSupporting: GenesisPalette.redesignWhite55,
      textTimestamp: GenesisPalette.redesignWhite45,
      textMetadata: GenesisPalette.redesignWhite45,
      inputHint: GenesisPalette.redesignWhite55,
      textTertiary: GenesisPalette.redesignWhite50,
      textEmptyState: GenesisPalette.redesignWhite50,
      textLabelMuted: GenesisPalette.redesignWhite50,
      textPlaceholder: GenesisPalette.redesignWhite45,
      textDisabled: GenesisPalette.redesignWhite32,
      textInverse: GenesisPalette.redesignInk,
      accentText: GenesisPalette.redesignAccentSoft,
      link: GenesisPalette.redesignAccentSoft,
      iconMuted: GenesisPalette.redesignWhite60,
      imagePlaceholderIcon: GenesisPalette.redesignWhite45,
      border: GenesisPalette.redesignWhite10,
      borderNeutral: GenesisPalette.redesignWhite12,
      borderSubtle: GenesisPalette.redesignWhite08,
      borderStrong: GenesisPalette.redesignWhite18,
      inputBorder: GenesisPalette.redesignWhite18,
      divider: GenesisPalette.redesignWhite10,
      dividerSubtle: GenesisPalette.redesignWhite07,
      dividerMuted: GenesisPalette.redesignWhite06,
      dividerAction: GenesisPalette.redesignWhite12,
      dragHandle: GenesisPalette.redesignWhite40,
      dragHandleSubtle: GenesisPalette.redesignWhite22,
      skeletonBase: GenesisPalette.redesignSkeletonBase,
      skeletonHighlight: GenesisPalette.redesignSkeletonHighlight,
      primary: GenesisPalette.redesignAccent,
      onPrimary: GenesisPalette.white,
      primaryDisabled: GenesisPalette.redesignAccent40,
      danger: GenesisPalette.redesignAccent,
      dangerControl: GenesisPalette.redesignAccent,
      dangerSurface: GenesisPalette.redesignAccent14,
      dangerBorder: GenesisPalette.redesignAccent30,
      onDanger: GenesisPalette.white,
      surfaceDisabled: GenesisPalette.redesignWhite08,
      surfaceGrouped: GenesisPalette.redesignRaised,
      surfaceTag: GenesisPalette.redesignWhite13,
      navigationBackground: GenesisPalette.redesignBackground,
      navigationSelected: GenesisPalette.white,
      navigationUnselected: GenesisPalette.redesignNavigationInactive,
      scrim: GenesisPalette.black,
      shadow: GenesisPalette.redesignBlack40,
    );
  }

  final Color pageBackground;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color surfaceEmpty;
  final Color surfaceSoft;
  final Color surfaceSubtle;
  final Color surfaceProgress;
  final Color surfaceSheet;
  final Color imagePlaceholder;
  final Color inputBackground;
  final Color controlMuted;
  final Color controlBackground;
  final Color textPrimary;
  final Color textHighEmphasis;
  final Color foregroundStrong;
  final Color textHeading;
  final Color textStrong;
  final Color textBody;
  final Color textCinematic;
  final Color textQuaternary;
  final Color textMuted;
  final Color textSecondary;
  final Color textSubtle;
  final Color textTagline;
  final Color textFaint;
  final Color textSupporting;
  final Color textTimestamp;
  final Color textMetadata;
  final Color inputHint;
  final Color textTertiary;
  final Color textEmptyState;
  final Color textLabelMuted;
  final Color textPlaceholder;
  final Color textDisabled;
  final Color textInverse;
  final Color accentText;
  final Color link;
  final Color iconMuted;
  final Color imagePlaceholderIcon;
  final Color border;
  final Color borderNeutral;
  final Color borderSubtle;
  final Color borderStrong;
  final Color inputBorder;
  final Color divider;
  final Color dividerSubtle;
  final Color dividerMuted;
  final Color dividerAction;
  final Color dragHandle;
  final Color dragHandleSubtle;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color primary;
  final Color onPrimary;
  final Color primaryDisabled;
  final Color danger;
  final Color dangerControl;
  final Color dangerSurface;
  final Color dangerBorder;
  final Color onDanger;
  final Color surfaceDisabled;
  final Color surfaceGrouped;
  final Color surfaceTag;
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
    Color? surfaceEmpty,
    Color? surfaceSoft,
    Color? surfaceSubtle,
    Color? surfaceProgress,
    Color? surfaceSheet,
    Color? imagePlaceholder,
    Color? inputBackground,
    Color? controlMuted,
    Color? controlBackground,
    Color? textPrimary,
    Color? textHighEmphasis,
    Color? foregroundStrong,
    Color? textHeading,
    Color? textStrong,
    Color? textBody,
    Color? textCinematic,
    Color? textQuaternary,
    Color? textMuted,
    Color? textSecondary,
    Color? textSubtle,
    Color? textTagline,
    Color? textFaint,
    Color? textSupporting,
    Color? textTimestamp,
    Color? textMetadata,
    Color? inputHint,
    Color? textTertiary,
    Color? textEmptyState,
    Color? textLabelMuted,
    Color? textPlaceholder,
    Color? textDisabled,
    Color? textInverse,
    Color? accentText,
    Color? link,
    Color? iconMuted,
    Color? imagePlaceholderIcon,
    Color? border,
    Color? borderNeutral,
    Color? borderSubtle,
    Color? borderStrong,
    Color? inputBorder,
    Color? divider,
    Color? dividerSubtle,
    Color? dividerMuted,
    Color? dividerAction,
    Color? dragHandle,
    Color? dragHandleSubtle,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? primary,
    Color? onPrimary,
    Color? primaryDisabled,
    Color? danger,
    Color? dangerControl,
    Color? dangerSurface,
    Color? dangerBorder,
    Color? onDanger,
    Color? surfaceDisabled,
    Color? surfaceGrouped,
    Color? surfaceTag,
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
      surfaceEmpty: surfaceEmpty ?? this.surfaceEmpty,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceProgress: surfaceProgress ?? this.surfaceProgress,
      surfaceSheet: surfaceSheet ?? this.surfaceSheet,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      inputBackground: inputBackground ?? this.inputBackground,
      controlMuted: controlMuted ?? this.controlMuted,
      controlBackground: controlBackground ?? this.controlBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textHighEmphasis: textHighEmphasis ?? this.textHighEmphasis,
      foregroundStrong: foregroundStrong ?? this.foregroundStrong,
      textHeading: textHeading ?? this.textHeading,
      textStrong: textStrong ?? this.textStrong,
      textBody: textBody ?? this.textBody,
      textCinematic: textCinematic ?? this.textCinematic,
      textQuaternary: textQuaternary ?? this.textQuaternary,
      textMuted: textMuted ?? this.textMuted,
      textSecondary: textSecondary ?? this.textSecondary,
      textSubtle: textSubtle ?? this.textSubtle,
      textTagline: textTagline ?? this.textTagline,
      textFaint: textFaint ?? this.textFaint,
      textSupporting: textSupporting ?? this.textSupporting,
      textTimestamp: textTimestamp ?? this.textTimestamp,
      textMetadata: textMetadata ?? this.textMetadata,
      inputHint: inputHint ?? this.inputHint,
      textTertiary: textTertiary ?? this.textTertiary,
      textEmptyState: textEmptyState ?? this.textEmptyState,
      textLabelMuted: textLabelMuted ?? this.textLabelMuted,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      accentText: accentText ?? this.accentText,
      link: link ?? this.link,
      iconMuted: iconMuted ?? this.iconMuted,
      imagePlaceholderIcon: imagePlaceholderIcon ?? this.imagePlaceholderIcon,
      border: border ?? this.border,
      borderNeutral: borderNeutral ?? this.borderNeutral,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      inputBorder: inputBorder ?? this.inputBorder,
      divider: divider ?? this.divider,
      dividerSubtle: dividerSubtle ?? this.dividerSubtle,
      dividerMuted: dividerMuted ?? this.dividerMuted,
      dividerAction: dividerAction ?? this.dividerAction,
      dragHandle: dragHandle ?? this.dragHandle,
      dragHandleSubtle: dragHandleSubtle ?? this.dragHandleSubtle,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDisabled: primaryDisabled ?? this.primaryDisabled,
      danger: danger ?? this.danger,
      dangerControl: dangerControl ?? this.dangerControl,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      onDanger: onDanger ?? this.onDanger,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      surfaceGrouped: surfaceGrouped ?? this.surfaceGrouped,
      surfaceTag: surfaceTag ?? this.surfaceTag,
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
      surfaceEmpty: Color.lerp(surfaceEmpty, other.surfaceEmpty, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceProgress: Color.lerp(surfaceProgress, other.surfaceProgress, t)!,
      surfaceSheet: Color.lerp(surfaceSheet, other.surfaceSheet, t)!,
      imagePlaceholder: Color.lerp(
        imagePlaceholder,
        other.imagePlaceholder,
        t,
      )!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      controlMuted: Color.lerp(controlMuted, other.controlMuted, t)!,
      controlBackground: Color.lerp(
        controlBackground,
        other.controlBackground,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textHighEmphasis: Color.lerp(
        textHighEmphasis,
        other.textHighEmphasis,
        t,
      )!,
      foregroundStrong: Color.lerp(
        foregroundStrong,
        other.foregroundStrong,
        t,
      )!,
      textHeading: Color.lerp(textHeading, other.textHeading, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textCinematic: Color.lerp(textCinematic, other.textCinematic, t)!,
      textQuaternary: Color.lerp(textQuaternary, other.textQuaternary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      textTagline: Color.lerp(textTagline, other.textTagline, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      textSupporting: Color.lerp(textSupporting, other.textSupporting, t)!,
      textTimestamp: Color.lerp(textTimestamp, other.textTimestamp, t)!,
      textMetadata: Color.lerp(textMetadata, other.textMetadata, t)!,
      inputHint: Color.lerp(inputHint, other.inputHint, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textEmptyState: Color.lerp(textEmptyState, other.textEmptyState, t)!,
      textLabelMuted: Color.lerp(textLabelMuted, other.textLabelMuted, t)!,
      textPlaceholder: Color.lerp(textPlaceholder, other.textPlaceholder, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      link: Color.lerp(link, other.link, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      imagePlaceholderIcon: Color.lerp(
        imagePlaceholderIcon,
        other.imagePlaceholderIcon,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      borderNeutral: Color.lerp(borderNeutral, other.borderNeutral, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerSubtle: Color.lerp(dividerSubtle, other.dividerSubtle, t)!,
      dividerMuted: Color.lerp(dividerMuted, other.dividerMuted, t)!,
      dividerAction: Color.lerp(dividerAction, other.dividerAction, t)!,
      dragHandle: Color.lerp(dragHandle, other.dragHandle, t)!,
      dragHandleSubtle: Color.lerp(
        dragHandleSubtle,
        other.dragHandleSubtle,
        t,
      )!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryDisabled: Color.lerp(primaryDisabled, other.primaryDisabled, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerControl: Color.lerp(dangerControl, other.dangerControl, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      surfaceGrouped: Color.lerp(surfaceGrouped, other.surfaceGrouped, t)!,
      surfaceTag: Color.lerp(surfaceTag, other.surfaceTag, t)!,
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
