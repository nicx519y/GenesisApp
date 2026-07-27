import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/theme/genesis_color_token.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

Color get kGenesisModalBarrierColor =>
    GenesisColorRuntime.color(GenesisColorToken.surfaceOverlay);

Color get kGenesisSubtleModalBarrierColor =>
    GenesisColorRuntime.color(GenesisColorToken.surfaceOverlaySubtle);

SystemUiOverlayStyle get kGenesisDefaultSystemUiOverlayStyle =>
    GenesisSystemUiChrome.defaultStyle;

class GenesisSystemUiChrome {
  GenesisSystemUiChrome._();

  static SystemUiOverlayStyle _currentStyle = defaultStyle;
  static final List<SystemUiOverlayStyle> _styleStack =
      <SystemUiOverlayStyle>[];

  static SystemUiOverlayStyle get defaultStyle =>
      _surfaceStyle(GenesisColorRuntime.color(GenesisColorToken.surface));

  static void applyDefault() {
    _apply(defaultStyle);
  }

  static Future<T> runWithModalChrome<T>(
    Color color,
    Future<T> Function() action, {
    SystemUiOverlayStyle? restoreOverrideStyle,
  }) async {
    final previousStyle = _currentStyle;
    _styleStack.add(previousStyle);
    _apply(_modalStyle(color));
    try {
      return await action();
    } finally {
      final previousStyle = _styleStack.isNotEmpty
          ? _styleStack.removeLast()
          : defaultStyle;
      _apply(restoreOverrideStyle ?? previousStyle);
    }
  }

  static void _apply(SystemUiOverlayStyle style) {
    _currentStyle = style;
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  static SystemUiOverlayStyle _modalStyle(Color color, [Color? baseColor]) {
    final systemBarColor = color.a < 1
        ? Color.alphaBlend(
            color,
            baseColor ?? GenesisColorRuntime.color(GenesisColorToken.surface),
          )
        : color;
    return _surfaceStyle(systemBarColor);
  }

  static SystemUiOverlayStyle _surfaceStyle(Color systemBarColor) {
    final useDarkIcons = systemBarColor.computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: systemBarColor,
      statusBarIconBrightness: useDarkIcons
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: useDarkIcons ? Brightness.light : Brightness.dark,
    );
  }
}

Future<T?> showGenesisModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  Color? systemBarColor,
  SystemUiOverlayStyle? restoreSystemUiOverlayStyle,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
}) {
  final colors = GenesisSemanticColors.of(context);
  final resolvedBarrierColor =
      barrierColor ?? colors.color(GenesisColorToken.surfaceOverlay);
  final chromeColor = systemBarColor ?? resolvedBarrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(
    chromeColor,
    () => showModalBottomSheet<T>(
      context: context,
      builder: builder,
      barrierColor: resolvedBarrierColor,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      sheetAnimationStyle: sheetAnimationStyle,
    ),
    restoreOverrideStyle: restoreSystemUiOverlayStyle,
  );
}

Future<T?> showGenesisDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  Color? systemBarColor,
  bool applySystemUiOverlay = true,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  final colors = GenesisSemanticColors.of(context);
  final resolvedBarrierColor =
      barrierColor ?? colors.color(GenesisColorToken.surfaceOverlay);
  Future<T?> showDialogRoute() {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierColor: resolvedBarrierColor,
      barrierDismissible: barrierDismissible,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
    );
  }

  if (!applySystemUiOverlay) return showDialogRoute();

  final chromeColor = systemBarColor ?? resolvedBarrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(chromeColor, showDialogRoute);
}

Future<T?> showGenesisGeneralDialog<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  Color? barrierColor,
  Color? systemBarColor,
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
}) {
  final colors = GenesisSemanticColors.of(context);
  final resolvedBarrierColor =
      barrierColor ?? colors.color(GenesisColorToken.surfaceOverlay);
  final chromeColor = systemBarColor ?? resolvedBarrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(
    chromeColor,
    () => showGeneralDialog<T>(
      context: context,
      pageBuilder: pageBuilder,
      barrierColor: resolvedBarrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      transitionDuration: transitionDuration,
      transitionBuilder: transitionBuilder,
      useRootNavigator: useRootNavigator,
    ),
  );
}
