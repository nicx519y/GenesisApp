import 'package:flutter/material.dart';

import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_color_token.dart';
import 'genesis_semantic_colors.dart';
import 'genesis_ui_theme.dart';

abstract final class GenesisTheme {
  static ThemeData light({
    GenesisSemanticColorConfig? config,
    int revision = 0,
  }) {
    return _build(
      brightness: Brightness.light,
      config: config ?? GenesisColorDefaults.light,
      revision: revision,
    );
  }

  static ThemeData dark({
    GenesisSemanticColorConfig? config,
    int revision = 0,
  }) {
    return _build(
      brightness: Brightness.dark,
      config: config ?? GenesisColorDefaults.dark,
      revision: revision,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required GenesisSemanticColorConfig config,
    required int revision,
  }) {
    Color value(GenesisColorToken token) => config.color(token);

    final baseScheme = ColorScheme.fromSeed(
      seedColor: value(GenesisColorToken.brandBright),
      brightness: brightness,
    );
    final colorScheme = baseScheme.copyWith(
      primary: value(GenesisColorToken.brand),
      onPrimary: value(GenesisColorToken.textInverse),
      secondary: value(GenesisColorToken.create),
      onSecondary: value(GenesisColorToken.textInverse),
      surface: value(GenesisColorToken.surface),
      onSurface: value(GenesisColorToken.textPrimary),
      error: value(GenesisColorToken.danger),
      onError: value(GenesisColorToken.textInverse),
      outline: value(GenesisColorToken.border),
      outlineVariant: value(GenesisColorToken.borderStrong),
      surfaceContainerHighest: value(GenesisColorToken.surfacePanel),
      surfaceContainerHigh: value(GenesisColorToken.surfaceElevated),
      surfaceContainer: value(GenesisColorToken.surfacePanel),
      surfaceContainerLow: value(GenesisColorToken.surfaceMuted),
      scrim: value(GenesisColorToken.surfaceOverlay),
    );
    final textTheme = GenesisTypography.textThemeFor(
      primary: value(GenesisColorToken.textPrimary),
      secondary: value(GenesisColorToken.textSecondary),
    );

    final theme = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: value(GenesisColorToken.surface),
      canvasColor: value(GenesisColorToken.surface),
      cardColor: value(GenesisColorToken.surfaceElevated),
      dividerColor: value(GenesisColorToken.border),
      disabledColor: value(GenesisColorToken.textDisabled),
      iconTheme: IconThemeData(color: value(GenesisColorToken.iconPrimary)),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: value(GenesisColorToken.surface),
        foregroundColor: value(GenesisColorToken.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: value(GenesisColorToken.surfaceElevated),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: value(GenesisColorToken.surfaceElevated),
        modalBackgroundColor: value(GenesisColorToken.surfaceElevated),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: value(GenesisColorToken.surfaceElevated),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: value(GenesisColorToken.border),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: value(GenesisColorToken.brand),
          disabledBackgroundColor: value(GenesisColorToken.brandDisabled),
          foregroundColor: value(GenesisColorToken.textInverse),
          disabledForegroundColor: value(
            GenesisColorToken.actionDisabledForeground,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          textStyle: GenesisTypography.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: value(GenesisColorToken.brand),
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: value(GenesisColorToken.textPrimary),
          side: BorderSide(color: value(GenesisColorToken.borderStrong)),
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: value(GenesisColorToken.surfaceElevated),
          foregroundColor: value(GenesisColorToken.textPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        isCollapsed: true,
        filled: true,
        fillColor: value(GenesisColorToken.surfaceInput),
        hintStyle: TextStyle(
          color: value(GenesisColorToken.textDisabled),
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        GenesisSemanticColors(config: config, revision: revision),
        brightness == Brightness.dark
            ? GenesisUiTheme.dark(config)
            : GenesisUiTheme.light(config),
      ],
    );
    return theme.copyWith(textTheme: textTheme);
  }
}
