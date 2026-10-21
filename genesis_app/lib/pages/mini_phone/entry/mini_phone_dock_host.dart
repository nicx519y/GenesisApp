import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../session/mini_phone_session.dart';
import 'mini_phone_dock_position.dart';
import 'mini_phone_entry.dart';

class _DockScene {
  const _DockScene(
    this.owner,
    this.id,
    this.rect,
    this.top,
    this.bottom,
    this.leftBottom,
    this.open,
  );
  final Object owner;
  final String id;
  final Rect rect;
  final double top, bottom;
  final double? leftBottom;
  final ValueChanged<MiniPhoneSession> open;

  bool sameLayout(_DockScene other) =>
      owner == other.owner &&
      id == other.id &&
      rect == other.rect &&
      top == other.top &&
      bottom == other.bottom &&
      leftBottom == other.leftBottom;
}

/// World-owned scene selection. Cached panels cannot select themselves.
class MiniPhoneDockController extends ChangeNotifier {
  String? _selected;
  _DockScene? _current, _display;
  bool _transitioning = false, _scheduled = false, _disposed = false;
  final _rootKey = GlobalKey();

  void _select(String? scene) {
    if (_selected == scene) return;
    _selected = scene;
    _current = null;
    _notifyAfterFrame();
  }

  void setTransitioning(bool value) {
    if (_disposed || value == _transitioning) return;
    _transitioning = value;
    if (!value && _current != null) _display = _current;
    _notifyAfterFrame();
  }

  void _report(_DockScene scene) {
    if (_disposed || scene.id != _selected) return;
    final changed = _current == null || !_current!.sameLayout(scene);
    _current = scene;
    if (!_transitioning) _display = scene;
    if (changed) _notifyAfterFrame();
  }

  void _remove(Object owner) {
    if (_disposed || _current?.owner != owner) return;
    _current = null;
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// One stable dock above World content, outside all map/chat transitions.
class MiniPhoneDockHost extends StatefulWidget {
  const MiniPhoneDockHost({
    super.key,
    required this.controller,
    required this.selectedScene,
    required this.child,
    this.visible = true,
    this.positionStore,
  });
  final MiniPhoneDockController controller;
  final String? selectedScene;
  final bool visible;
  final MiniPhoneDockPosition? positionStore;
  final Widget child;

  @override
  State<MiniPhoneDockHost> createState() => _MiniPhoneDockHostState();
}

class _MiniPhoneDockHostState extends State<MiniPhoneDockHost> {
  @override
  void initState() {
    super.initState();
    widget.controller._select(widget.selectedScene);
  }

  @override
  void didUpdateWidget(MiniPhoneDockHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller._select(widget.selectedScene);
  }

  @override
  Widget build(BuildContext context) => _MiniPhoneDockScope(
    controller: widget.controller,
    child: Stack(
      key: widget.controller._rootKey,
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;
              final scene = controller._display;
              if (scene == null) return const SizedBox.shrink();
              final visible =
                  widget.visible &&
                  widget.selectedScene != null &&
                  (ModalRoute.of(context)?.isCurrent ?? true);
              final interactive =
                  visible &&
                  !controller._transitioning &&
                  controller._current?.id == widget.selectedScene;
              return MiniPhoneEdgeDock(
                // Launch replaces the preview session after receiving its
                // World ID. Reset only the session-bound dock, never the host
                // or its chat subtree (which owns the pending first send).
                key: ObjectKey(MiniPhoneSessionScope.watch(context)?.session),
                positionStore: widget.positionStore,
                viewport: scene.rect,
                visible: visible,
                interactive: interactive,
                // Same-scene geometry changes include the keyboard's live frames.
                // They already move continuously; do not restart a snap each frame.
                layoutIdentity: scene.id,
                followViewportChanges: true,
                topInset: scene.top,
                bottomInset: scene.bottom,
                leftBottomInset: scene.leftBottom,
                onPressed: (phone) {
                  if (widget.visible &&
                      !controller._transitioning &&
                      controller._current?.id == widget.selectedScene) {
                    controller._current?.open(phone);
                  }
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _MiniPhoneDockScope extends InheritedWidget {
  const _MiniPhoneDockScope({required this.controller, required super.child});
  final MiniPhoneDockController controller;
  static MiniPhoneDockController? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_MiniPhoneDockScope>()
      ?.controller;
  @override
  bool updateShouldNotify(_MiniPhoneDockScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Reports a page's real layout bounds; outside World it retains the local dock.
class MiniPhoneDockScene extends StatefulWidget {
  const MiniPhoneDockScene({
    super.key,
    required this.sceneId,
    required this.topInset,
    required this.bottomInset,
    required this.onPressed,
    this.leftBottomInset,
    this.active = true,
    this.worldId = '',
  });
  final String sceneId, worldId;
  final bool active;
  final double topInset, bottomInset;
  final double? leftBottomInset;
  final ValueChanged<MiniPhoneSession> onPressed;

  @override
  State<MiniPhoneDockScene> createState() => _MiniPhoneDockSceneState();
}

class _MiniPhoneDockSceneState extends State<MiniPhoneDockScene> {
  MiniPhoneDockController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _MiniPhoneDockScope.of(context);
    if (next != _controller) {
      _controller?._remove(this);
      _controller = next;
    }
  }

  @override
  void didUpdateWidget(MiniPhoneDockScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.sceneId != widget.sceneId) {
      _controller?._remove(this);
    }
  }

  void _report(RenderBox box) {
    final controller = _controller;
    if (!mounted ||
        !widget.active ||
        controller == null ||
        !box.attached ||
        !box.hasSize) {
      return;
    }
    final root = controller._rootKey.currentContext?.findRenderObject();
    var offset = Offset.zero;
    RenderObject? node = box;
    // Use layout offsets, not getTransformTo/localToGlobal: route paint
    // transforms (including Android zoom) must never move the World dock.
    while (node != null && node != root) {
      final data = node.parentData;
      if (data is BoxParentData) offset += data.offset;
      node = node.parent;
    }
    if (root == null || node != root || box.size.isEmpty) return;
    controller._report(
      _DockScene(
        this,
        widget.sceneId,
        offset & box.size,
        widget.topInset,
        widget.bottomInset,
        widget.leftBottomInset,
        widget.onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return widget.active
          ? MiniPhoneEdgeDock(
              worldId: widget.worldId,
              topInset: widget.topInset,
              bottomInset: widget.bottomInset,
              leftBottomInset: widget.leftBottomInset,
              onPressed: widget.onPressed,
            )
          : const SizedBox.shrink();
    }
    return _DockLayoutReporter(onLayout: _report);
  }

  @override
  void dispose() {
    _controller?._remove(this);
    super.dispose();
  }
}

class _DockLayoutReporter extends SingleChildRenderObjectWidget {
  const _DockLayoutReporter({required this.onLayout})
    : super(child: const SizedBox.expand());
  final ValueChanged<RenderBox> onLayout;
  @override
  _DockLayoutRenderBox createRenderObject(BuildContext context) =>
      _DockLayoutRenderBox(onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    _DockLayoutRenderBox renderObject,
  ) {
    renderObject.onLayout = onLayout;
    renderObject.reportAfterLayout();
  }
}

class _DockLayoutRenderBox extends RenderProxyBox {
  _DockLayoutRenderBox(this.onLayout);
  ValueChanged<RenderBox> onLayout;
  bool _scheduled = false;
  void reportAfterLayout() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (attached && hasSize) onLayout(this);
    });
  }

  @override
  void performLayout() {
    super.performLayout();
    reportAfterLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    reportAfterLayout();
  }
}
