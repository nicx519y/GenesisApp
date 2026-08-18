import 'package:flutter/material.dart';

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
  });

  factory GenesisMessageColors.light() => const GenesisMessageColors(
    notificationsSurface: Color(0xFFDDF2EF),
    followersSurface: Color(0xFFFFF0D8),
    commentsSurface: Color(0xFFE9F0FF),
    statusPositive: Color(0xFF25845C),
    statusMuted: Color(0xFF8A8D93),
    originAccent: Color(0xFF2F4F7A),
  );

  final Color notificationsSurface;
  final Color followersSurface;
  final Color commentsSurface;
  final Color statusPositive;
  final Color statusMuted;
  final Color originAccent;

  static GenesisMessageColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisMessageColors>() ??
      GenesisMessageColors.light();

  @override
  GenesisMessageColors copyWith({
    Color? notificationsSurface,
    Color? followersSurface,
    Color? commentsSurface,
    Color? statusPositive,
    Color? statusMuted,
    Color? originAccent,
  }) => GenesisMessageColors(
    notificationsSurface: notificationsSurface ?? this.notificationsSurface,
    followersSurface: followersSurface ?? this.followersSurface,
    commentsSurface: commentsSurface ?? this.commentsSurface,
    statusPositive: statusPositive ?? this.statusPositive,
    statusMuted: statusMuted ?? this.statusMuted,
    originAccent: originAccent ?? this.originAccent,
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
    );
  }
}

extension GenesisMessageThemeContext on BuildContext {
  GenesisMessageColors get genesisMessageColors =>
      GenesisMessageColors.of(this);
}
