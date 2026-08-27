import 'package:flutter/material.dart';

import '../system/genesis_system_ui.dart';
import '../tokens/genesis_colors.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_ui_theme.dart';

// GenesisTheme is the single entry point for app-level ThemeData.
// This class connects the Flutter Material theme with the custom Genesis UI component theme.
abstract final class GenesisTheme {
  // Only the light theme is currently defined. A future dark theme can add dark() and reuse the same token and extension structure.
  static ThemeData light() {
    // The base palette for Material components; seedColor determines derived Material colors such as default button and state colors.
    final colorScheme = ColorScheme.fromSeed(
      // Use the bright brand green as the seed color for the Material ColorScheme.
      seedColor: GenesisColors.brandBright,
      // The current product uses light backgrounds, so Brightness.light is fixed here.
      brightness: Brightness.light,
    );

    return ThemeData(
      // The standard color system consumed by Flutter Material components.
      colorScheme: colorScheme,
      // Product interactions use state changes rather than Material ripple,
      // pressed, hover, or focus overlays.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      // The default page background color, used when a Scaffold does not set one explicitly.
      scaffoldBackgroundColor: GenesisColors.surface,
      // The standard app TextTheme, available to regular Text widgets through Theme.of(context).textTheme.
      textTheme: GenesisTypography.textTheme,
      // Keep Material 3 enabled to avoid mixing legacy and current Material defaults.
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: kGenesisDefaultSystemUiOverlayStyle,
      ),
      // The global default FilledButton style, also inherited by GenesisPrimaryButton.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Primary button background color when enabled.
          backgroundColor: GenesisColors.brand,
          // Primary button background color when disabled.
          disabledBackgroundColor: GenesisColors.brandSoft,
          // Primary button text and icon foreground color.
          foregroundColor: GenesisColors.surface,
          // Use an 8dp radius for all buttons; locally sized buttons should follow the same radius rule.
          shape: const RoundedRectangleBorder(
            borderRadius: GenesisRadii.button,
          ),
          // Default primary button text style.
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
      // The default TextField and InputDecorator style; editable GenesisSearchField instances reuse part of it.
      inputDecorationTheme: const InputDecorationTheme(
        // Do not draw a Material border by default; the outer container provides the background and radius.
        border: InputBorder.none,
        // Collapse the default TextField height so Material padding does not make the search field too tall.
        isCollapsed: true,
        // Default input placeholder style.
        hintStyle: TextStyle(
          color: GenesisColors.textDisabled,
          fontSize: 14,
          letterSpacing: 0,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: GenesisColors.textPrimary,
        selectionColor: GenesisColors.create.withValues(alpha: 0.32),
        selectionHandleColor: GenesisColors.create,
      ),
      // Theme extension for custom Genesis UI components.
      // SearchField, PageTitle, BottomNavigation, TabBar, and similar components read styles from this extension first.
      extensions: <ThemeExtension<dynamic>>[GenesisUiTheme.light()],
    );
  }
}
