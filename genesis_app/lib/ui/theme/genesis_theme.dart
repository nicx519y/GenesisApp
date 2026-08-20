import 'package:flutter/material.dart';

import '../../components/gems/gem_colors.dart';
import '../../components/chat/shared/chat_ui_theme.dart';
import '../../components/origin/genesis_origin_theme.dart';
import '../../components/discuss/genesis_discuss_theme.dart';
import '../../components/create/genesis_create_theme.dart';
import '../../components/world/genesis_world_theme.dart';
import '../../components/messages/genesis_message_theme.dart';
import '../components/genesis_modal_border.dart';
import '../system/genesis_system_ui.dart';
import '../tokens/genesis_palette.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_semantic_colors.dart';
import 'genesis_skin.dart';
import 'genesis_ui_theme.dart';

abstract final class GenesisTheme {
  static ThemeData forSkin(GenesisSkin skin) => switch (skin) {
    GenesisSkin.worldoRedesign => worldoRedesign(),
  };

  static ThemeData light() => _build(
    colors: GenesisSemanticColors.light(),
    brightness: Brightness.light,
    seedColor: GenesisPalette.brandBright,
    uiTheme: GenesisUiTheme.light(),
    skinTheme: const GenesisSkinTheme.unskinned(),
    featureThemes: <ThemeExtension<dynamic>>[
      GenesisGemColors.light(),
      GenesisChatTheme.light(),
      GenesisOriginColors.light(),
      GenesisDiscussColors.light(),
      GenesisCreateColors.light(),
      GenesisWorldColors.light(),
      GenesisMessageColors.light(),
    ],
  );

  static ThemeData worldoRedesign() => _build(
    colors: GenesisSemanticColors.worldoRedesign(),
    brightness: Brightness.dark,
    seedColor: GenesisPalette.redesignAccent,
    uiTheme: GenesisUiTheme.worldoRedesign(),
    skinTheme: const GenesisSkinTheme(skin: GenesisSkin.worldoRedesign),
    featureThemes: <ThemeExtension<dynamic>>[
      GenesisGemColors.worldoRedesign(),
      GenesisChatTheme.worldoRedesign(),
      GenesisOriginColors.worldoRedesign(),
      GenesisDiscussColors.worldoRedesign(),
      GenesisCreateColors.worldoRedesign(),
      GenesisWorldColors.worldoRedesign(),
      GenesisMessageColors.worldoRedesign(),
    ],
  );

  static ThemeData _build({
    required GenesisSemanticColors colors,
    required Brightness brightness,
    required Color seedColor,
    required GenesisUiTheme uiTheme,
    required GenesisSkinTheme skinTheme,
    required List<ThemeExtension<dynamic>> featureThemes,
  }) {
    final generatedColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final colorScheme = brightness == Brightness.dark
        ? generatedColorScheme.copyWith(
            primary: colors.primary,
            onPrimary: colors.onPrimary,
            surface: colors.surface,
            onSurface: colors.textPrimary,
            error: colors.danger,
            onError: colors.onDanger,
            outline: colors.border,
            outlineVariant: colors.borderSubtle,
            shadow: colors.shadow,
            scrim: colors.scrim,
          )
        : generatedColorScheme;
    final systemOverlayStyle = GenesisSystemUi.forThemeBrightness(brightness);

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      fontFamily: GenesisTypography.fontFamily,
      fontFamilyFallback: GenesisTypography.fontFamilyFallback,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      scaffoldBackgroundColor: colors.pageBackground,
      textTheme: GenesisTypography.textTheme.copyWith(
        titleMedium: GenesisTypography.pageTitle.copyWith(
          color: colors.textPrimary,
        ),
        bodyLarge: GenesisTypography.body.copyWith(color: colors.textPrimary),
        bodyMedium: GenesisTypography.body.copyWith(color: colors.textPrimary),
        bodySmall: GenesisTypography.supporting.copyWith(
          color: colors.textSecondary,
        ),
        labelSmall: GenesisTypography.tabLabel.copyWith(
          color: colors.textPrimary,
        ),
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: systemOverlayStyle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(
            color: colors.textPrimary.withValues(
              alpha: genesisModalBorderOpacity,
            ),
            width: genesisModalBorderWidth,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceSheet,
        modalBackgroundColor: colors.surfaceSheet,
        shape: RoundedRectangleBorder(
          borderRadius: GenesisRadii.sheet,
          side: BorderSide(
            color: colors.textPrimary.withValues(
              alpha: genesisModalBorderOpacity,
            ),
            width: genesisModalBorderWidth,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        shadowColor: colors.shadow,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(color: colors.divider),
      iconTheme: IconThemeData(color: colors.textPrimary),
      primaryIconTheme: IconThemeData(color: colors.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceProgress,
        circularTrackColor: colors.surfaceProgress,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.32),
        selectionHandleColor: colors.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(GenesisRadii.sm),
          side: BorderSide(
            color: colors.textPrimary.withValues(
              alpha: genesisModalBorderOpacity,
            ),
            width: genesisModalBorderWidth,
          ),
        ),
        textStyle: GenesisTypography.body.copyWith(color: colors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: GenesisTypography.body.copyWith(
          color: colors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.primaryDisabled,
          foregroundColor: colors.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          textStyle: GenesisTypography.bodyStrong,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      checkboxTheme: const CheckboxThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        splashRadius: 0,
      ),
      radioTheme: const RadioThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        splashRadius: 0,
      ),
      switchTheme: const SwitchThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        splashRadius: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        isCollapsed: true,
        hintStyle: TextStyle(
          color: colors.textDisabled,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        uiTheme,
        skinTheme,
        ...featureThemes.cast<dynamic>(),
      ],
    );
  }
}
