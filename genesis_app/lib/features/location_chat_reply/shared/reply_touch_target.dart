import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Receives taps in reply buttons' extra padding without enlarging their layout.
/// Place inside the message viewport, so sheets and other routes retain priority.
class LocationChatReplyTouchScope extends StatefulWidget {
  const LocationChatReplyTouchScope({super.key, required this.child});

  final Widget child;

  @override
  State<LocationChatReplyTouchScope> createState() => _ReplyTouchScopeState();
}

class _ReplyTouchScopeState extends State<LocationChatReplyTouchScope> {
  final targets = <_ReplyTouchTargetState>{};

  _ReplyTouchTargetState? _targetAt(Offset position) {
    for (final target in targets) {
      if (target.contains(position)) return target;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => _ReplyTouchRegistry(
    scope: this,
    child: RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      gestures: {
        _ReplyPaddingTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_ReplyPaddingTapRecognizer>(
              () => _ReplyPaddingTapRecognizer(debugOwner: this),
              (recognizer) => recognizer.targetAt = _targetAt,
            ),
      },
      child: widget.child,
    ),
  );
}

class _ReplyTouchRegistry extends InheritedWidget {
  const _ReplyTouchRegistry({required this.scope, required super.child});

  final _ReplyTouchScopeState scope;

  @override
  bool updateShouldNotify(_ReplyTouchRegistry oldWidget) =>
      oldWidget.scope != scope;
}

/// Normal taps still belong to the button. Only padding outside its layout box
/// joins the ancestor's gesture arena, preserving scrolling and child gestures.
class _ReplyPaddingTapRecognizer extends TapGestureRecognizer {
  _ReplyPaddingTapRecognizer({super.debugOwner}) {
    onTap = () {
      final target = _target;
      _target = null;
      if (target != null && target.contains(_downPosition)) {
        target.widget.onTap?.call();
      }
    };
    onTapCancel = () => _target = null;
  }

  late _ReplyTouchTargetState? Function(Offset) targetAt;
  _ReplyTouchTargetState? _target;
  Offset _downPosition = Offset.zero;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      state == GestureRecognizerState.ready &&
      super.isPointerAllowed(event) &&
      targetAt(event.position) != null;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downPosition = event.position;
    _target = targetAt(event.position);
    super.addAllowedPointer(event);
  }
}

class LocationChatReplyTouchTarget extends StatefulWidget {
  const LocationChatReplyTouchTarget({
    super.key,
    required this.onTap,
    required this.touchSize,
    required this.child,
  });

  final VoidCallback? onTap;
  final double touchSize;
  final Widget child;

  @override
  State<LocationChatReplyTouchTarget> createState() => _ReplyTouchTargetState();
}

class _ReplyTouchTargetState extends State<LocationChatReplyTouchTarget> {
  _ReplyTouchScopeState? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope?.targets.remove(this);
    _scope = context
        .dependOnInheritedWidgetOfExactType<_ReplyTouchRegistry>()
        ?.scope;
    _scope?.targets.add(this);
  }

  bool contains(Offset globalPosition) {
    if (!mounted || widget.onTap == null) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    final layoutBounds = Offset.zero & box.size;
    if (layoutBounds.contains(local) ||
        !Rect.fromCenter(
          center: layoutBounds.center,
          width: widget.touchSize,
          height: widget.touchSize,
        ).contains(local)) {
      return false;
    }
    // Respect transitions, input blockers and viewport clipping even though the
    // ancestor recognizer, rather than the button, receives these padding taps.
    RenderObject child = box;
    for (var parent = child.parent; parent != null; parent = child.parent) {
      if (parent is RenderIgnorePointer && parent.ignoring ||
          parent is RenderAbsorbPointer && parent.absorbing ||
          parent is RenderOffstage && parent.offstage) {
        return false;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        final transform = parent.getTransformTo(null);
        if (transform.invert() == 0 ||
            !clip.contains(
              MatrixUtils.transformPoint(transform, globalPosition),
            )) {
          return false;
        }
      }
      child = parent;
    }
    return true;
  }

  @override
  void dispose() {
    _scope?.targets.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
