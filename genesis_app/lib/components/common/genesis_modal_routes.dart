import 'package:flutter/material.dart';

import '../../ui/theme/genesis_semantic_colors.dart';

export '../../ui/system/genesis_system_ui.dart';

Color genesisModalBarrierColor(BuildContext context, {bool subtle = false}) =>
    context.genesisColors.scrim.withValues(alpha: subtle ? 0.38 : 0.54);

Future<T?> showGenesisModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
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
    barrierColor: barrierColor ?? genesisModalBarrierColor(context),
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
  Color? barrierColor,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierColor: barrierColor ?? genesisModalBarrierColor(context),
    barrierDismissible: barrierDismissible,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
  );
}

Future<T?> showGenesisGeneralDialog<T>({
  required BuildContext context,
  required RoutePageBuilder pageBuilder,
  Color? barrierColor,
  bool barrierDismissible = false,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 200),
  RouteTransitionsBuilder? transitionBuilder,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: pageBuilder,
    barrierColor: barrierColor ?? genesisModalBarrierColor(context),
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    transitionDuration: transitionDuration,
    transitionBuilder: transitionBuilder,
    useRootNavigator: useRootNavigator,
  );
}
