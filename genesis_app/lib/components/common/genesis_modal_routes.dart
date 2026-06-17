import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kGenesisModalBarrierColor = Color(0x8A000000);
const Color kGenesisSubtleModalBarrierColor = Color(0x61000000);
const Color _kGenesisSystemBarBaseColor = Color(0xFFFFFFFF);

const SystemUiOverlayStyle kGenesisDefaultSystemUiOverlayStyle =
    SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFFFFFF),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    );

class GenesisSystemUiChrome {
  GenesisSystemUiChrome._();

  static SystemUiOverlayStyle _currentStyle =
      kGenesisDefaultSystemUiOverlayStyle;
  static final List<SystemUiOverlayStyle> _styleStack =
      <SystemUiOverlayStyle>[];

  static void applyDefault() {
    _apply(kGenesisDefaultSystemUiOverlayStyle);
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
          : kGenesisDefaultSystemUiOverlayStyle;
      _apply(restoreOverrideStyle ?? previousStyle);
    }
  }

  static void _apply(SystemUiOverlayStyle style) {
    _currentStyle = style;
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  static SystemUiOverlayStyle _modalStyle(Color color) {
    final systemBarColor = color.a < 1
        ? Color.alphaBlend(color, _kGenesisSystemBarBaseColor)
        : color;
    final useDarkIcons = systemBarColor.computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: systemBarColor,
      statusBarIconBrightness: useDarkIcons
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: useDarkIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: systemBarColor,
      systemNavigationBarIconBrightness: useDarkIcons
          ? Brightness.dark
          : Brightness.light,
    );
  }
}

Future<T?> showGenesisModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = kGenesisModalBarrierColor,
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
  final chromeColor = systemBarColor ?? barrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(
    chromeColor,
    () => showModalBottomSheet<T>(
      context: context,
      builder: builder,
      barrierColor: barrierColor,
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
  Color barrierColor = kGenesisModalBarrierColor,
  Color? systemBarColor,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  final chromeColor = systemBarColor ?? barrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(
    chromeColor,
    () => showDialog<T>(
      context: context,
      builder: builder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
    ),
  );
}

Future<T?> showGenesisGeneralDialog<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  Color barrierColor = kGenesisModalBarrierColor,
  Color? systemBarColor,
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
}) {
  final chromeColor = systemBarColor ?? barrierColor;
  return GenesisSystemUiChrome.runWithModalChrome(
    chromeColor,
    () => showGeneralDialog<T>(
      context: context,
      pageBuilder: pageBuilder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      transitionDuration: transitionDuration,
      transitionBuilder: transitionBuilder,
      useRootNavigator: useRootNavigator,
    ),
  );
}
