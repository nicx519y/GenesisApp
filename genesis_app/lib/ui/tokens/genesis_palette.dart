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
  static const Color surfaceEmpty = Color(0xFFF8F8F8);
  static const Color surfaceSoft = Color(0xFFF7F7F7);
  static const Color surfaceSubtle = Color(0xFFFAFAFA);
  static const Color surfaceInput = Color(0xFFF2F2F2);
  static const Color surfacePanel = Color(0xFFF5F5F7);
  static const Color surfaceSheet = Color(0xFFEDEDED);
  static const Color imagePlaceholder = Color(0xFFEFF1F4);
  static const Color surfaceProgress = Color(0xFFF4F4F8);
  static const Color controlMuted = Color(0xFFE1E1E3);
  static const Color controlBackground = Color(0xFFF0F0F0);

  static const Color textPrimary = Color(0xFF111111);
  static const Color textHighEmphasis = Color(0xDD000000);
  static const Color foregroundStrong = black;
  static const Color textHeading = Color(0xFF1D1D1D);
  static const Color textStrong = Color(0xFF222222);
  static const Color textBody = Color(0xFF333333);
  static const Color textCinematic = Color(0xFF2A2F33);
  static const Color textQuaternary = Color(0xFF444444);
  static const Color textMuted = Color(0xFF666666);
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color textSubtle = Color(0xFF777777);
  static const Color textTagline = Color(0xFF7A7A7A);
  static const Color textFaint = Color(0xFF888888);
  static const Color textSupporting = Color(0xFF8A8A8A);
  static const Color textTimestamp = Color(0xFF8B8B8B);
  static const Color textMetadata = Color(0xFF8A8D93);
  static const Color inputHint = Color(0xFF8C8C8C);
  static const Color textTertiary = Color(0xFF8D8D8D);
  static const Color textEmptyState = Color(0xFF94979E);
  static const Color textLabelMuted = Color(0xFF8F8F8F);
  static const Color textPlaceholder = Color(0xFF999999);
  static const Color textDisabled = Color(0xFF9E9E9E);
  static const Color accentText = Color(0xFF4B6192);
  static const Color link = Color(0xFF3E5B8A);
  static const Color iconMuted = Color(0xFFB5B5B5);
  static const Color imagePlaceholderIcon = Color(0xFF9A9A9A);
  static const Color navigationSelected = black;
  static const Color navigationUnselected = Color(0xFF666666);

  static const Color border = Color(0xFFE6E6E8);
  static const Color borderNeutral = Color(0xFFE1E1E1);
  static const Color dividerSubtle = Color(0xFFE7E7E7);
  static const Color dividerMuted = Color(0xFFEFEFEF);
  static const Color dividerAction = Color(0xFFE8E8EA);
  static const Color dragHandle = Color(0xFFD2D2D2);
  static const Color dragHandleSubtle = Color(0xFFD9D9D9);
  static const Color skeletonBase = Color(0xFFE8EBF0);
  static const Color skeletonHighlight = Color(0xFFF6F7F9);
  static const Color borderSubtle = Color(0xFFEBEBEB);
  static const Color borderStrong = Color(0xFFD9D9DF);
  static const Color inputBorder = Color(0xFFD8D8DE);
  static const Color legacyBorderStrong = Color(0xFFDCDCDC);
  static const Color surfaceDisabled = Color(0xFFE5E5E5);
  static const Color surfaceGrouped = Color(0xFFF4F4F5);
  static const Color surfaceTag = Color(0xFFF1F3F6);
  static const Color dangerControl = Color(0xFFFF4D4F);
  static const Color dangerSurface = Color(0xFFFFF4F6);
  static const Color dangerBorder = Color(0xFFFFE0E6);
  static const Color shadow = Color(0x14000000);
}
