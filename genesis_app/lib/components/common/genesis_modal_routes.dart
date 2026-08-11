import 'package:flutter/material.dart';

export '../../ui/system/genesis_system_ui.dart';

const Color kGenesisModalBarrierColor = Color(0x8A000000);
const Color kGenesisSubtleModalBarrierColor = Color(0x61000000);

Future<T?> showGenesisModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = kGenesisModalBarrierColor,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
}) {
  return showModalBottomSheet<T>(
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
  );
}

Future<T?> showGenesisDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = kGenesisModalBarrierColor,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
  );
}

Future<T?> showGenesisGeneralDialog<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  Color barrierColor = kGenesisModalBarrierColor,
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: pageBuilder,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    transitionDuration: transitionDuration,
    transitionBuilder: transitionBuilder,
    useRootNavigator: useRootNavigator,
  );
}
