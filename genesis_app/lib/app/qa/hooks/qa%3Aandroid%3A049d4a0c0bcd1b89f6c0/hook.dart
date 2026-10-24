import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart'
    show targetHitTestable;
import '../qa%253Aandroid%253A5b3990fd6789b5efbe42/hook.dart';
import '../qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';

Element? tickTarget() {
  final w = worldElement();
  if (w == null) return null;
  final found = elements(w)
      .where(
        (e) =>
            e.widget.key ==
                const ValueKey<String>('world-header-action-button') &&
            visible(e),
      )
      .toList();
  return found.length == 1 ? found.single : null;
}

bool canTouch() {
  final t = tickTarget();
  return t != null &&
      actionForText('Tick now', worldElement()!) != null &&
      targetHitTestable(t);
}

int pointer = 96800;
void dispatchSingleTap(Element target) {
  if (!targetHitTestable(target))
    throw StateError('Tick button touch intercepted');
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.hasSize)
    throw StateError('Rendered tick button required');
  final point = box.localToGlobal(box.size.center(Offset.zero)),
      view = View.of(target),
      id = pointer++;
  final binding = WidgetsBinding.instance;
  binding.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      position: point,
      viewId: view.viewId,
      kind: PointerDeviceKind.touch,
    ),
  );
  try {
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: id,
        position: point,
        viewId: view.viewId,
        kind: PointerDeviceKind.touch,
      ),
    );
  } catch (_) {
    binding.handlePointerEvent(
      PointerCancelEvent(pointer: id, position: point, viewId: view.viewId),
    );
    rethrow;
  }
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final f = fault();
  await f.owner.requireOwner();
  final b = baseline();
  if (!f.active || b.continuity()['samePageInstance'] != true || !canTouch())
    throw StateError('Uncovered enabled original tick target required');
  final before = f.requests;
  dispatchSingleTap(tickTarget()!);
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (f.requests == before && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  if (f.requests != before + 1)
    throw StateError('This touch did not produce exactly one tick request');
  return {
    'clicked': true,
    ...b.continuity(),
    'requestId': f.requestId(f.requests),
  };
}
