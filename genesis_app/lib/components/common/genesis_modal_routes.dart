import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

export '../../ui/system/genesis_system_ui.dart';

const Color kGenesisModalBarrierColor = Color(0x8A000000);
const Color kGenesisSubtleModalBarrierColor = Color(0x61000000);

class GenesisBottomSheetDragDismissArea extends StatefulWidget {
  const GenesisBottomSheetDragDismissArea({
    super.key,
    required this.onDismiss,
    required this.child,
    this.dismissDistance = 48,
    this.dismissVelocity = 650,
  });

  final VoidCallback onDismiss;
  final Widget child;
  final double dismissDistance;
  final double dismissVelocity;

  @override
  State<GenesisBottomSheetDragDismissArea> createState() =>
      _GenesisBottomSheetDragDismissAreaState();
}

class _GenesisBottomSheetDragDismissAreaState
    extends State<GenesisBottomSheetDragDismissArea> {
  var _contentAtTop = true;
  var _horizontalDragDistance = 0.0;
  var _downwardDragDistance = 0.0;
  VelocityTracker? _velocityTracker;

  void _handlePointerDown(PointerDownEvent event) {
    _horizontalDragDistance = 0;
    _downwardDragDistance = 0;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
    _horizontalDragDistance += event.delta.dx.abs();
    if (!_contentAtTop || event.delta.dy <= 0) {
      if (event.delta.dy < 0) _downwardDragDistance = 0;
      return;
    }
    _downwardDragDistance += event.delta.dy;
  }

  void _handlePointerUp(PointerUpEvent event) {
    _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
    final downwardVelocity =
        _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final isVerticalDrag =
        _downwardDragDistance > 0 &&
        _downwardDragDistance >= _horizontalDragDistance * 1.2;
    final shouldDismiss =
        _contentAtTop &&
        isVerticalDrag &&
        (_downwardDragDistance >= widget.dismissDistance ||
            downwardVelocity >= widget.dismissVelocity);
    _resetDrag();
    if (shouldDismiss) widget.onDismiss();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetDrag();
  }

  void _resetDrag() {
    _horizontalDragDistance = 0;
    _downwardDragDistance = 0;
    _velocityTracker = null;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    _contentAtTop = notification.metrics.extentBefore <= 0.5;
    if (!_contentAtTop) _downwardDragDistance = 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: widget.child,
      ),
    );
  }
}

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
