import 'package:flutter/material.dart';

import 'genesis_palette.dart';

/// Compatibility aliases for code that has not yet migrated to semantic
/// theme roles. New widgets should use `context.genesisColors` instead.
abstract final class GenesisColors {
  static const Color brand = GenesisPalette.brand;
  static const Color brandBright = GenesisPalette.brandBright;
  static const Color brandSoft = GenesisPalette.brandSoft;
  static const Color create = GenesisPalette.create;

  static const Color surface = GenesisPalette.white;
  static const Color surfaceMuted = GenesisPalette.surfaceMuted;
  static const Color surfaceInput = GenesisPalette.surfaceInput;
  static const Color surfacePanel = GenesisPalette.surfacePanel;

  static const Color textPrimary = GenesisPalette.textPrimary;
  static const Color textSecondary = GenesisPalette.textSecondary;
  static const Color textTertiary = GenesisPalette.textTertiary;
  static const Color textDisabled = GenesisPalette.textDisabled;
  static const Color tabSelected = GenesisPalette.navigationSelected;
  static const Color tabUnselected = GenesisPalette.navigationUnselected;

  static const Color border = GenesisPalette.border;
  static const Color borderStrong = GenesisPalette.legacyBorderStrong;
  static const Color danger = GenesisPalette.create;
}
