import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_palette.dart';

/// Colors with discussion-specific meaning.
@immutable
class GenesisDiscussColors extends ThemeExtension<GenesisDiscussColors> {
  const GenesisDiscussColors({
    required this.authorAccent,
    required this.actionAccent,
    required this.actionInactive,
    required this.composerCursor,
    required this.composerHint,
    required this.composerSubmit,
    required this.composerAction,
    required this.composerActionDisabled,
    required this.replyRail,
    required this.replySurface,
    required this.replyText,
    required this.nestedReplyRail,
    required this.nestedReplySurface,
    required this.imageAddBorder,
    required this.imageAddIcon,
    required this.imageRemoveSurface,
  });

  factory GenesisDiscussColors.worldoLight() => const GenesisDiscussColors(
    authorAccent: GenesisPalette.redesignAccentDark,
    actionAccent: GenesisPalette.redesignAccentDark,
    actionInactive: GenesisPalette.redesignInk42,
    composerCursor: GenesisPalette.redesignAccent,
    composerHint: Color(0xFFB8B8B8),
    composerSubmit: GenesisPalette.redesignAccent,
    composerAction: GenesisPalette.redesignInk60,
    composerActionDisabled: GenesisPalette.textDisabled,
    replyRail: Color(0xFFD7DBE3),
    replySurface: Color(0xFFF6F7F9),
    replyText: Color(0xFF60636A),
    nestedReplyRail: Color(0xFFD9DDE2),
    nestedReplySurface: Color(0xFFF5F6F7),
    imageAddBorder: Color(0xFFE3E3E3),
    imageAddIcon: Color(0xFF8E8E8E),
    imageRemoveSurface: Color(0xFF4F4F4F),
  );

  factory GenesisDiscussColors.worldoDark() => const GenesisDiscussColors(
    authorAccent: GenesisPalette.redesignAccentSoft,
    actionAccent: GenesisPalette.redesignAccentSoft,
    actionInactive: GenesisPalette.redesignWhite45,
    composerCursor: GenesisPalette.redesignAccentSoft,
    composerHint: GenesisPalette.redesignWhite45,
    composerSubmit: GenesisPalette.redesignAccent,
    composerAction: GenesisPalette.redesignWhite72,
    composerActionDisabled: GenesisPalette.redesignWhite32,
    replyRail: GenesisPalette.redesignWhite12,
    replySurface: GenesisPalette.redesignWhite08,
    replyText: GenesisPalette.redesignWhite72,
    nestedReplyRail: GenesisPalette.redesignWhite10,
    nestedReplySurface: GenesisPalette.redesignWhite06,
    imageAddBorder: GenesisPalette.redesignWhite18,
    imageAddIcon: GenesisPalette.redesignWhite55,
    imageRemoveSurface: GenesisPalette.redesignRaised,
  );

  final Color authorAccent;
  final Color actionAccent;
  final Color actionInactive;
  final Color composerCursor;
  final Color composerHint;
  final Color composerSubmit;
  final Color composerAction;
  final Color composerActionDisabled;
  final Color replyRail;
  final Color replySurface;
  final Color replyText;
  final Color nestedReplyRail;
  final Color nestedReplySurface;
  final Color imageAddBorder;
  final Color imageAddIcon;
  final Color imageRemoveSurface;

  static GenesisDiscussColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
      ? GenesisDiscussColors.worldoDark()
      : GenesisDiscussColors.worldoLight();

  static GenesisDiscussColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisDiscussColors>() ??
      GenesisDiscussColors.forBrightness(Theme.of(context).brightness);

  @override
  GenesisDiscussColors copyWith({
    Color? authorAccent,
    Color? actionAccent,
    Color? actionInactive,
    Color? composerCursor,
    Color? composerHint,
    Color? composerSubmit,
    Color? composerAction,
    Color? composerActionDisabled,
    Color? replyRail,
    Color? replySurface,
    Color? replyText,
    Color? nestedReplyRail,
    Color? nestedReplySurface,
    Color? imageAddBorder,
    Color? imageAddIcon,
    Color? imageRemoveSurface,
  }) => GenesisDiscussColors(
    authorAccent: authorAccent ?? this.authorAccent,
    actionAccent: actionAccent ?? this.actionAccent,
    actionInactive: actionInactive ?? this.actionInactive,
    composerCursor: composerCursor ?? this.composerCursor,
    composerHint: composerHint ?? this.composerHint,
    composerSubmit: composerSubmit ?? this.composerSubmit,
    composerAction: composerAction ?? this.composerAction,
    composerActionDisabled:
        composerActionDisabled ?? this.composerActionDisabled,
    replyRail: replyRail ?? this.replyRail,
    replySurface: replySurface ?? this.replySurface,
    replyText: replyText ?? this.replyText,
    nestedReplyRail: nestedReplyRail ?? this.nestedReplyRail,
    nestedReplySurface: nestedReplySurface ?? this.nestedReplySurface,
    imageAddBorder: imageAddBorder ?? this.imageAddBorder,
    imageAddIcon: imageAddIcon ?? this.imageAddIcon,
    imageRemoveSurface: imageRemoveSurface ?? this.imageRemoveSurface,
  );

  @override
  GenesisDiscussColors lerp(
    covariant ThemeExtension<GenesisDiscussColors>? other,
    double t,
  ) {
    if (other is! GenesisDiscussColors) return this;
    return GenesisDiscussColors(
      authorAccent: Color.lerp(authorAccent, other.authorAccent, t)!,
      actionAccent: Color.lerp(actionAccent, other.actionAccent, t)!,
      actionInactive: Color.lerp(actionInactive, other.actionInactive, t)!,
      composerCursor: Color.lerp(composerCursor, other.composerCursor, t)!,
      composerHint: Color.lerp(composerHint, other.composerHint, t)!,
      composerSubmit: Color.lerp(composerSubmit, other.composerSubmit, t)!,
      composerAction: Color.lerp(composerAction, other.composerAction, t)!,
      composerActionDisabled: Color.lerp(
        composerActionDisabled,
        other.composerActionDisabled,
        t,
      )!,
      replyRail: Color.lerp(replyRail, other.replyRail, t)!,
      replySurface: Color.lerp(replySurface, other.replySurface, t)!,
      replyText: Color.lerp(replyText, other.replyText, t)!,
      nestedReplyRail: Color.lerp(nestedReplyRail, other.nestedReplyRail, t)!,
      nestedReplySurface: Color.lerp(
        nestedReplySurface,
        other.nestedReplySurface,
        t,
      )!,
      imageAddBorder: Color.lerp(imageAddBorder, other.imageAddBorder, t)!,
      imageAddIcon: Color.lerp(imageAddIcon, other.imageAddIcon, t)!,
      imageRemoveSurface: Color.lerp(
        imageRemoveSurface,
        other.imageRemoveSurface,
        t,
      )!,
    );
  }
}

extension GenesisDiscussThemeContext on BuildContext {
  GenesisDiscussColors get genesisDiscussColors =>
      GenesisDiscussColors.of(this);
}
