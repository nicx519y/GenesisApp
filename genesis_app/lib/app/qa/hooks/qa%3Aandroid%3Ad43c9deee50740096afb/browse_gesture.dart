import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class BrowseGestureResult {
  const BrowseGestureResult(
    this.from,
    this.to,
    this.scrollRequired,
    this.succeeded,
  );
  final double from, to;
  final bool scrollRequired, succeeded;
}

bool _inside(RenderObject child, RenderObject ancestor) {
  for (
    RenderObject? current = child;
    current != null;
    current = current.parent
  ) {
    if (identical(current, ancestor)) return true;
  }
  return false;
}

int _pointer = 94500;

// A visible event can still be inside a driven PageView. Flutter deliberately
// ignores pointers to its children until that activity ends. Observe that
// activity; never stop it, move its position, or remove an input blocker.
Future<void> _waitForMotion(ScrollableState scrollable) async {
  for (var frame = 0; frame < 120; frame++) {
    if (!scrollable.mounted) {
      throw StateError('Event viewport detached before touch');
    }
    var moving = scrollable.position.isScrollingNotifier.value;
    scrollable.context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        moving |= (element.state as ScrollableState)
            .position.isScrollingNotifier.value;
      }
      return true;
    });
    final route = ModalRoute.of(scrollable.context);
    final animation = route?.animation;
    moving |= animation != null &&
        (animation.status == AnimationStatus.forward ||
            animation.status == AnimationStatus.reverse);
    if (!moving) return;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await WidgetsBinding.instance.endOfFrame;
  }
  throw StateError('Event viewport motion did not settle before touch');
}

/// Dispatch through Flutter's hit testing and gesture arena. Never drive the
/// ScrollPosition directly: that would bypass touch blockers and scroll physics.
Future<BrowseGestureResult> browseByTouch(ScrollableState scrollable) async {
  await _waitForMotion(scrollable);
  final position = scrollable.position;
  if (!scrollable.mounted ||
      !position.hasContentDimensions ||
      position.axis != Axis.vertical) {
    throw StateError('Mounted vertical event scrollable required');
  }
  final box = scrollable.context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) {
    throw StateError('Rendered event viewport required');
  }
  final before = position.pixels;
  final scrollRequired =
      position.maxScrollExtent - position.minScrollExtent > 1;
  final bounds = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  final screen =
      Offset.zero &
      (View.of(scrollable.context).physicalSize /
          View.of(scrollable.context).devicePixelRatio);
  final visibleBounds = bounds.intersect(screen);
  if (visibleBounds.width < 8 || visibleBounds.height < 24) {
    throw StateError('Visible event viewport required');
  }
  final start = visibleBounds.center;
  final hit = HitTestResult();
  WidgetsBinding.instance.hitTestInView(
    hit,
    start,
    View.of(scrollable.context).viewId,
  );
  final reachable = hit.path.any(
    (entry) =>
        entry.target is RenderObject &&
        _inside(entry.target as RenderObject, box),
  );
  if (!reachable) {
    return BrowseGestureResult(before, before, scrollRequired, false);
  }
  final up = position.maxScrollExtent - before > 1;
  final distance = (visibleBounds.height / 3).clamp(8.0, 100.0) * (up ? -1 : 1);
  final id = _pointer++;
  final binding = WidgetsBinding.instance;
  binding.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      position: start,
      kind: PointerDeviceKind.touch,
    ),
  );
  var previous = start;
  try {
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final next = start + Offset(0, distance * i / 10);
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: id,
          position: next,
          delta: next - previous,
          kind: PointerDeviceKind.touch,
        ),
      );
      previous = next;
    }
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: id,
        position: previous,
        kind: PointerDeviceKind.touch,
      ),
    );
  } catch (_) {
    binding.handlePointerEvent(
      PointerCancelEvent(
        pointer: id,
        position: previous,
        kind: PointerDeviceKind.touch,
      ),
    );
    rethrow;
  }
  await WidgetsBinding.instance.endOfFrame;
  final after = position.pixels;
  return BrowseGestureResult(
    before,
    after,
    scrollRequired,
    scrollable.mounted && (!scrollRequired || (after - before).abs() > 1),
  );
}
