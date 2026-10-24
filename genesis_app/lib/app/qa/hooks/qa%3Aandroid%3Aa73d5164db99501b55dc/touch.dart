import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    show targetHitTestable;

int _pointer = 95600;

/// Two pointer sequences at one screen position in the same event turn. The
/// second hit test is intentionally normal: the App owns duplicate protection.
int dispatchRapidTaps(Element target) {
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) {
    throw StateError('Rendered tick button required');
  }
  final point = box.localToGlobal(box.size.center(Offset.zero));
  final view = View.of(target);
  if (!(Offset.zero & (view.physicalSize / view.devicePixelRatio)).contains(point)) {
    throw StateError('Tick button outside viewport');
  }
  final binding = WidgetsBinding.instance;
  if (!targetHitTestable(target)) {
    throw StateError('Tick button touch intercepted');
  }
  var dispatched = 0;
  for (var i = 0; i < 2; i++) {
    final pointer = _pointer++;
    binding.handlePointerEvent(PointerDownEvent(
      pointer: pointer, position: point, viewId: view.viewId,
      kind: PointerDeviceKind.touch,
    ));
    try {
      binding.handlePointerEvent(PointerUpEvent(
        pointer: pointer, position: point, viewId: view.viewId,
        kind: PointerDeviceKind.touch,
      ));
      dispatched++;
    } catch (_) {
      binding.handlePointerEvent(PointerCancelEvent(
        pointer: pointer, position: point, viewId: view.viewId,
        kind: PointerDeviceKind.touch,
      ));
      rethrow;
    }
  }
  return dispatched;
}
