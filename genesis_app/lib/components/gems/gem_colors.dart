import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_palette.dart';

/// Gem product and state colors supplied by the active app skin.
@immutable
class GenesisGemColors extends ThemeExtension<GenesisGemColors> {
  const GenesisGemColors({
    required this.accent,
    required this.soldOutBorder,
    required this.soldOutForeground,
    required this.taskAction,
    required this.taskClaimedForeground,
    required this.taskProgressForeground,
    required this.success,
    required this.reward,
    required this.selectionSurface,
    required this.selectionDisabled,
    required this.priceGradientStart,
    required this.priceGradientEnd,
  });

  factory GenesisGemColors.light() => const GenesisGemColors(
    accent: Color(0xFFFF2442),
    soldOutBorder: Color(0xFFFFD1D8),
    soldOutForeground: Color(0xFFD47B89),
    taskAction: Color(0xFFAD403B),
    taskClaimedForeground: Color(0xFFD47B89),
    taskProgressForeground: Color(0xFF338960),
    success: Color(0xFF34C759),
    reward: Color(0xFFFF7A1A),
    selectionSurface: Color(0xFFFFF4F6),
    selectionDisabled: Color(0xFFCCCCCC),
    priceGradientStart: Color(0xFFE85C39),
    priceGradientEnd: Color(0xFFB53B52),
  );

  factory GenesisGemColors.worldoRedesign() => const GenesisGemColors(
    accent: GenesisPalette.redesignAccent,
    soldOutBorder: GenesisPalette.redesignAccent30,
    soldOutForeground: GenesisPalette.redesignWhite45,
    taskAction: GenesisPalette.redesignAccentSoft,
    taskClaimedForeground: GenesisPalette.redesignWhite45,
    taskProgressForeground: GenesisPalette.redesignAccentSoft,
    success: GenesisPalette.redesignAccentSoft,
    reward: GenesisPalette.redesignAccentSoft,
    selectionSurface: GenesisPalette.redesignAccent14,
    selectionDisabled: GenesisPalette.redesignWhite32,
    priceGradientStart: GenesisPalette.redesignAccentSoft,
    priceGradientEnd: GenesisPalette.redesignAccent,
  );

  final Color accent;
  final Color soldOutBorder;
  final Color soldOutForeground;
  final Color taskAction;
  final Color taskClaimedForeground;
  final Color taskProgressForeground;
  final Color success;
  final Color reward;
  final Color selectionSurface;
  final Color selectionDisabled;
  final Color priceGradientStart;
  final Color priceGradientEnd;

  static GenesisGemColors of(BuildContext context) {
    return Theme.of(context).extension<GenesisGemColors>() ??
        GenesisGemColors.light();
  }

  @override
  GenesisGemColors copyWith({
    Color? accent,
    Color? soldOutBorder,
    Color? soldOutForeground,
    Color? taskAction,
    Color? taskClaimedForeground,
    Color? taskProgressForeground,
    Color? success,
    Color? reward,
    Color? selectionSurface,
    Color? selectionDisabled,
    Color? priceGradientStart,
    Color? priceGradientEnd,
  }) {
    return GenesisGemColors(
      accent: accent ?? this.accent,
      soldOutBorder: soldOutBorder ?? this.soldOutBorder,
      soldOutForeground: soldOutForeground ?? this.soldOutForeground,
      taskAction: taskAction ?? this.taskAction,
      taskClaimedForeground:
          taskClaimedForeground ?? this.taskClaimedForeground,
      taskProgressForeground:
          taskProgressForeground ?? this.taskProgressForeground,
      success: success ?? this.success,
      reward: reward ?? this.reward,
      selectionSurface: selectionSurface ?? this.selectionSurface,
      selectionDisabled: selectionDisabled ?? this.selectionDisabled,
      priceGradientStart: priceGradientStart ?? this.priceGradientStart,
      priceGradientEnd: priceGradientEnd ?? this.priceGradientEnd,
    );
  }

  @override
  GenesisGemColors lerp(
    covariant ThemeExtension<GenesisGemColors>? other,
    double t,
  ) {
    if (other is! GenesisGemColors) return this;
    return GenesisGemColors(
      accent: Color.lerp(accent, other.accent, t)!,
      soldOutBorder: Color.lerp(soldOutBorder, other.soldOutBorder, t)!,
      soldOutForeground: Color.lerp(
        soldOutForeground,
        other.soldOutForeground,
        t,
      )!,
      taskAction: Color.lerp(taskAction, other.taskAction, t)!,
      taskClaimedForeground: Color.lerp(
        taskClaimedForeground,
        other.taskClaimedForeground,
        t,
      )!,
      taskProgressForeground: Color.lerp(
        taskProgressForeground,
        other.taskProgressForeground,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      selectionSurface: Color.lerp(
        selectionSurface,
        other.selectionSurface,
        t,
      )!,
      selectionDisabled: Color.lerp(
        selectionDisabled,
        other.selectionDisabled,
        t,
      )!,
      priceGradientStart: Color.lerp(
        priceGradientStart,
        other.priceGradientStart,
        t,
      )!,
      priceGradientEnd: Color.lerp(
        priceGradientEnd,
        other.priceGradientEnd,
        t,
      )!,
    );
  }
}

extension GenesisGemThemeContext on BuildContext {
  GenesisGemColors get genesisGemColors => GenesisGemColors.of(this);
}
