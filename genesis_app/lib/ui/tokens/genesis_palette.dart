import 'package:flutter/material.dart';

/// Raw, theme-independent color values.
///
/// Widgets should not read this palette directly. Theme builders map these
/// physical values to the semantic roles exposed by [GenesisSemanticColors].
abstract final class GenesisPalette {
  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color brand = Color(0xFF338960);
  static const Color brandBright = Color(0xFF00C27A);
  static const Color brandSoft = Color(0xFFBFD8CD);
  static const Color create = Color(0xFFFF2442);

  static const Color surfaceMuted = Color(0xFFF9F9F9);
  static const Color surfaceSubtle = Color(0xFFFAFAFA);
  static const Color surfaceInput = Color(0xFFF2F2F2);
  static const Color surfacePanel = Color(0xFFF5F5F7);
  static const Color controlMuted = Color(0xFFE1E1E3);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color textTertiary = Color(0xFF8D8D8D);
  static const Color textDisabled = Color(0xFF9E9E9E);
  static const Color accentText = Color(0xFF4B6192);
  static const Color navigationSelected = black;
  static const Color navigationUnselected = Color(0xFF666666);

  static const Color border = Color(0xFFE6E6E8);
  static const Color borderSubtle = Color(0xFFEBEBEB);
  static const Color borderStrong = Color(0xFFD9D9DF);
  static const Color legacyBorderStrong = Color(0xFFDCDCDC);
  static const Color shadow = Color(0x14000000);
}
