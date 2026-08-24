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
  static ThemeData forSkin(
    GenesisSkin skin, {
    Brightness brightness = Brightness.dark,
  }) => switch ((skin, brightness)) {
    (GenesisSkin.worldoRedesign, Brightness.light) => worldoLight(),
    (GenesisSkin.worldoRedesign, Brightness.dark) => worldoDark(),
  };

  static ThemeData worldoLight() => _build(
    colors: GenesisSemanticColors.worldoLight(),
    brightness: Brightness.light,
    seedColor: GenesisPalette.redesignAccent,
    uiTheme: GenesisUiTheme.worldo(),
    skinTheme: const GenesisSkinTheme(skin: GenesisSkin.worldoRedesign),
    featureThemes: <ThemeExtension<dynamic>>[
      GenesisGemColors.worldoLight(),
      GenesisChatTheme.worldoLight(),
      GenesisOriginColors.worldoLight(),
      GenesisDiscussColors.worldoLight(),
      GenesisCreateColors.worldoLight(),
      GenesisWorldColors.worldoLight(),
      GenesisMessageColors.worldoLight(),
    ],
  );

  static ThemeData worldoDark() => _build(
    colors: GenesisSemanticColors.worldoDark(),
    brightness: Brightness.dark,
    seedColor: GenesisPalette.redesignAccent,
    uiTheme: GenesisUiTheme.worldo(),
    skinTheme: const GenesisSkinTheme(skin: GenesisSkin.worldoRedesign),
    featureThemes: <ThemeExtension<dynamic>>[
      GenesisGemColors.worldoDark(),
      GenesisChatTheme.worldoDark(),
      GenesisOriginColors.worldoDark(),
      GenesisDiscussColors.worldoDark(),
      GenesisCreateColors.worldoDark(),
      GenesisWorldColors.worldoDark(),
      GenesisMessageColors.worldoDark(),
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
    final colorScheme = generatedColorScheme.copyWith(
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
    );
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
        // Bar titles keep the full-strength foreground; see GenesisAppBar.
        foregroundColor: colors.foregroundStrong,
        systemOverlayStyle: systemOverlayStyle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(
            color: colors.foregroundStrong.withValues(
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
            color: colors.foregroundStrong.withValues(
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
      // Icons keep the full-strength foreground: pure white on dark, ink on
      // light. They do not follow textPrimary down to the soft-white tier —
      // in the canvas the stroke is #fff, not #F4F3F6.
      iconTheme: IconThemeData(color: colors.foregroundStrong),
      primaryIconTheme: IconThemeData(color: colors.foregroundStrong),
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
            color: colors.foregroundStrong.withValues(
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
          fontSize: 13,
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
