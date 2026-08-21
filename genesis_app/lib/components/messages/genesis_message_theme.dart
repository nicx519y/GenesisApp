import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

/// Colors with message-center-specific meaning.
@immutable
class GenesisMessageColors extends ThemeExtension<GenesisMessageColors> {
  const GenesisMessageColors({
    required this.notificationsSurface,
    required this.followersSurface,
    required this.commentsSurface,
    required this.statusPositive,
    required this.statusMuted,
    required this.originAccent,
    required this.conversationPreview,
  });

  factory GenesisMessageColors.worldoLight() => const GenesisMessageColors(
    notificationsSurface: GenesisPalette.dangerSurface,
    followersSurface: GenesisPalette.surfaceMuted,
    commentsSurface: GenesisPalette.surfaceMuted,
    statusPositive: GenesisPalette.redesignAccentDark,
    statusMuted: GenesisPalette.redesignInk42,
    originAccent: GenesisPalette.redesignAccentDark,
    conversationPreview: GenesisPalette.redesignInk50,
  );

  factory GenesisMessageColors.worldoDark() => const GenesisMessageColors(
    notificationsSurface: GenesisPalette.redesignAccent14,
    followersSurface: GenesisPalette.redesignWhite10,
    commentsSurface: GenesisPalette.redesignWhite10,
    statusPositive: GenesisPalette.redesignAccentSoft,
    statusMuted: GenesisPalette.redesignWhite45,
    originAccent: GenesisPalette.redesignAccentSoft,
    conversationPreview: GenesisPalette.redesignFeedTabInactive,
  );

  final Color notificationsSurface;
  final Color followersSurface;
  final Color commentsSurface;
  final Color statusPositive;
  final Color statusMuted;
  final Color originAccent;
  final Color conversationPreview;

  static GenesisMessageColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? GenesisMessageColors.worldoDark()
      : GenesisMessageColors.worldoLight();

  static GenesisMessageColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisMessageColors>() ??
      GenesisMessageColors.forBrightness(Theme.of(context).brightness);

  @override
  GenesisMessageColors copyWith({
    Color? notificationsSurface,
    Color? followersSurface,
    Color? commentsSurface,
    Color? statusPositive,
    Color? statusMuted,
    Color? originAccent,
    Color? conversationPreview,
  }) => GenesisMessageColors(
    notificationsSurface: notificationsSurface ?? this.notificationsSurface,
    followersSurface: followersSurface ?? this.followersSurface,
    commentsSurface: commentsSurface ?? this.commentsSurface,
    statusPositive: statusPositive ?? this.statusPositive,
    statusMuted: statusMuted ?? this.statusMuted,
    originAccent: originAccent ?? this.originAccent,
    conversationPreview: conversationPreview ?? this.conversationPreview,
  );

  @override
  GenesisMessageColors lerp(
    covariant ThemeExtension<GenesisMessageColors>? other,
    double t,
  ) {
    if (other is! GenesisMessageColors) return this;
    return GenesisMessageColors(
      notificationsSurface: Color.lerp(
        notificationsSurface,
        other.notificationsSurface,
        t,
      )!,
      followersSurface: Color.lerp(
        followersSurface,
        other.followersSurface,
        t,
      )!,
      commentsSurface: Color.lerp(commentsSurface, other.commentsSurface, t)!,
      statusPositive: Color.lerp(statusPositive, other.statusPositive, t)!,
      statusMuted: Color.lerp(statusMuted, other.statusMuted, t)!,
      originAccent: Color.lerp(originAccent, other.originAccent, t)!,
      conversationPreview: Color.lerp(
        conversationPreview,
        other.conversationPreview,
        t,
      )!,
    );
  }
}

extension GenesisMessageThemeContext on BuildContext {
  GenesisMessageColors get genesisMessageColors =>
      GenesisMessageColors.of(this);
}
