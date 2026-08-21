import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_palette.dart';

/// Colors shared by create and editor forms.
@immutable
class GenesisCreateColors extends ThemeExtension<GenesisCreateColors> {
  const GenesisCreateColors({
    required this.accent,
    required this.fieldFill,
    required this.hint,
    required this.text,
    required this.muted,
    required this.note,
    required this.border,
    required this.dash,
    required this.danger,
    required this.fieldOverlay,
    required this.fieldOverlaySoft,
    required this.inputBorder,
    required this.previewBackground,
    required this.accentBorder,
    required this.selectedFill,
    required this.successText,
    required this.divider,
    required this.selectedOptionSurface,
    required this.selectedOptionText,
  });

  factory GenesisCreateColors.worldoLight() => const GenesisCreateColors(
    accent: GenesisPalette.redesignAccent,
    fieldFill: Color(0xFFF4F4F6),
    hint: Color(0xFFA8A8AD),
    text: Color(0xFF111111),
    muted: Color(0xFF6F6F6F),
    note: Color(0xFF888888),
    border: Color(0xFFE1E1E6),
    dash: GenesisPalette.redesignAccent30,
    danger: GenesisPalette.redesignAccent,
    fieldOverlay: Color(0xE6F4F4F6),
    fieldOverlaySoft: Color(0x6BF4F4F6),
    inputBorder: Color(0xFFD8D8DE),
    previewBackground: Color(0xFFEFEFF2),
    accentBorder: GenesisPalette.dangerBorder,
    selectedFill: GenesisPalette.dangerSurface,
    successText: GenesisPalette.redesignAccentDark,
    divider: Color(0xFFEAEAEA),
    selectedOptionSurface: GenesisPalette.redesignPaper,
    selectedOptionText: GenesisPalette.redesignInk,
  );

  factory GenesisCreateColors.worldoDark() => const GenesisCreateColors(
    accent: GenesisPalette.redesignAccent,
    fieldFill: GenesisPalette.redesignWhite07,
    hint: GenesisPalette.redesignWhite45,
    text: GenesisPalette.white,
    muted: GenesisPalette.redesignWhite72,
    note: GenesisPalette.redesignWhite55,
    border: GenesisPalette.redesignWhite12,
    dash: GenesisPalette.redesignWhite32,
    danger: GenesisPalette.redesignAccent,
    fieldOverlay: GenesisPalette.redesignBackground90,
    fieldOverlaySoft: GenesisPalette.redesignBackground42,
    inputBorder: GenesisPalette.redesignWhite18,
    previewBackground: GenesisPalette.redesignRaised,
    accentBorder: GenesisPalette.redesignAccent40,
    selectedFill: GenesisPalette.redesignAccent14,
    successText: GenesisPalette.redesignAccentSoft,
    divider: GenesisPalette.redesignWhite07,
    selectedOptionSurface: GenesisPalette.redesignPaper,
    selectedOptionText: GenesisPalette.redesignInk,
  );

  final Color accent;
  final Color fieldFill;
  final Color hint;
  final Color text;
  final Color muted;
  final Color note;
  final Color border;
  final Color dash;
  final Color danger;
  final Color fieldOverlay;
  final Color fieldOverlaySoft;
  final Color inputBorder;
  final Color previewBackground;
  final Color accentBorder;
  final Color selectedFill;
  final Color successText;
  final Color divider;
  final Color selectedOptionSurface;
  final Color selectedOptionText;

  static GenesisCreateColors of(BuildContext context) =>
      Theme.of(context).extension<GenesisCreateColors>() ??
      GenesisCreateColors.worldoLight();

  @override
  GenesisCreateColors copyWith({
    Color? accent,
    Color? fieldFill,
    Color? hint,
    Color? text,
    Color? muted,
    Color? note,
    Color? border,
    Color? dash,
    Color? danger,
    Color? fieldOverlay,
    Color? fieldOverlaySoft,
    Color? inputBorder,
    Color? previewBackground,
    Color? accentBorder,
    Color? selectedFill,
    Color? successText,
    Color? divider,
    Color? selectedOptionSurface,
    Color? selectedOptionText,
  }) => GenesisCreateColors(
    accent: accent ?? this.accent,
    fieldFill: fieldFill ?? this.fieldFill,
    hint: hint ?? this.hint,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    note: note ?? this.note,
    border: border ?? this.border,
    dash: dash ?? this.dash,
    danger: danger ?? this.danger,
    fieldOverlay: fieldOverlay ?? this.fieldOverlay,
    fieldOverlaySoft: fieldOverlaySoft ?? this.fieldOverlaySoft,
    inputBorder: inputBorder ?? this.inputBorder,
    previewBackground: previewBackground ?? this.previewBackground,
    accentBorder: accentBorder ?? this.accentBorder,
    selectedFill: selectedFill ?? this.selectedFill,
    successText: successText ?? this.successText,
    divider: divider ?? this.divider,
    selectedOptionSurface: selectedOptionSurface ?? this.selectedOptionSurface,
    selectedOptionText: selectedOptionText ?? this.selectedOptionText,
  );

  @override
  GenesisCreateColors lerp(
    covariant ThemeExtension<GenesisCreateColors>? other,
    double t,
  ) {
    if (other is! GenesisCreateColors) return this;
    return GenesisCreateColors(
      accent: Color.lerp(accent, other.accent, t)!,
      fieldFill: Color.lerp(fieldFill, other.fieldFill, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      note: Color.lerp(note, other.note, t)!,
      border: Color.lerp(border, other.border, t)!,
      dash: Color.lerp(dash, other.dash, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      fieldOverlay: Color.lerp(fieldOverlay, other.fieldOverlay, t)!,
      fieldOverlaySoft: Color.lerp(
        fieldOverlaySoft,
        other.fieldOverlaySoft,
        t,
      )!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      previewBackground: Color.lerp(
        previewBackground,
        other.previewBackground,
        t,
      )!,
      accentBorder: Color.lerp(accentBorder, other.accentBorder, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      selectedOptionSurface: Color.lerp(
        selectedOptionSurface,
        other.selectedOptionSurface,
        t,
      )!,
      selectedOptionText: Color.lerp(
        selectedOptionText,
        other.selectedOptionText,
        t,
      )!,
    );
  }
}

extension GenesisCreateThemeContext on BuildContext {
  GenesisCreateColors get genesisCreateColors => GenesisCreateColors.of(this);
}
