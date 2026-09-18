import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../components/chat/shared/chat_ui.dart';
import 'location_chat_reply_layout_bridge.dart';
import 'location_chat_reply_render_snapshot.dart';

const replyCardSwitchDuration = Duration(milliseconds: 500);
const _replyCardRegenerateCollapseDuration = Duration(milliseconds: 800);
const _replyCardRegenerateFadeRampFraction = 60 / 800;
const _replyCardRegenerateFadeExtent = 48.0;

class LocationChatReplyCard {
  const LocationChatReplyCard({
    required this.id,
    required List<ChatMessageVm> messages,
    this.status,
    this.contentIdentity,
  }) : _messages = messages,
       _resolveMessages = null;

  const LocationChatReplyCard.lazy({
    required this.id,
    required List<ChatMessageVm> Function() resolveMessages,
    this.status,
    this.contentIdentity,
  }) : _messages = null,
       _resolveMessages = resolveMessages;

  final int id;
  final List<ChatMessageVm>? _messages;
  final List<ChatMessageVm> Function()? _resolveMessages;
  List<ChatMessageVm> get messages => _messages ?? _resolveMessages!();
  final Object? contentIdentity;
  final Widget? status;
}

/// Owns presentation-only card transitions. Business state stays with the
/// parent and is committed only after the relevant interaction settles.
class LocationChatReplyCardSwitcher extends StatefulWidget {
  const LocationChatReplyCardSwitcher({
    super.key,
    required this.identity,
    required this.cards,
    required this.currentCardId,
    required this.cardBuilder,
    required this.onCommit,
    required this.onBusyChanged,
    required this.onWillChangeLayout,
    this.enabled = true,
    this.regenerationInProgress = false,
    this.layoutBridge,
    this.cardBuilderIdentity,
  });
  final String identity;
  final List<LocationChatReplyCard> cards;
  final int currentCardId;
  final Widget Function(LocationChatReplyCard card) cardBuilder;
  final bool Function(int cardId) onCommit;
  final ValueChanged<bool> onBusyChanged;

  /// Captures the viewport once per switch/drag. Animation ticks are handled
  /// by the render layout bridge and never invoke this callback.
  final VoidCallback onWillChangeLayout;
  final bool enabled;
  final bool regenerationInProgress;
  final LocationChatReplyLayoutBridge? layoutBridge;
  final Object? cardBuilderIdentity;

  @override
  State<LocationChatReplyCardSwitcher> createState() =>
      LocationChatReplyCardSwitcherState();
}

class LocationChatReplyCardSwitcherState
    extends State<LocationChatReplyCardSwitcher>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // The one displayed deck must survive shrinking out of the lazy cache;
  // otherwise its collapse state is lost before replacement content arrives.
  @override
  bool get wantKeepAlive => true;
  late final AnimationController _animation;
  late final AnimationController _regenerateCollapseAnimation;
  late int _displayedId;
  final _CardMotion _motion = _CardMotion();
  final Map<
    int,
    ({Object identity, List<ChatMessageVm> snapshot, Widget child})
  >
  _cardChildren = {};
  int? _targetId;
  LocationChatReplyCard? _regenerateOriginalCard;
  Widget? _regenerateSnapshotChild;
  int? _regenerateSourceId;
  int _delta = 0, _generation = 0;
  double _progress = 0, _dragDistance = 0, _width = 1;
  bool _busy = false, _dragging = false;
  bool _showRegenerateSnapshot = false;
  bool _regenerateReplacementObserved = false;
  bool _regenerateTransitionUpdateScheduled = false;
  bool _regenerateAwaitingPosition = false;
  double _from = 0, _to = 0;

  LocationChatReplyCard? _card(int? id) =>
      widget.cards.where((card) => card.id == id).firstOrNull;
  int get _index => widget.cards.indexWhere((card) => card.id == _displayedId);
  LocationChatReplyCard? _neighbor(int delta) {
    final index = _index + delta;
    return _index >= 0 && index >= 0 && index < widget.cards.length
        ? widget.cards[index]
        : null;
  }

  bool get _regenerateReplacementReady {
    if (!_regenerateReplacementObserved) return false;
    final replacement = _card(widget.currentCardId);
    return replacement != null &&
        replacement.messages.any(
          (message) => message.text.trim().isNotEmpty || message.isImage,
        );
  }

  @override
  void initState() {
    super.initState();
    _displayedId = widget.currentCardId;
    _animation =
        AnimationController(vsync: this, duration: replyCardSwitchDuration)
          ..addListener(() {
            _progress =
                _from +
                (_to - _from) * Curves.easeOutCubic.transform(_animation.value);
            _motion.update(_progress, _delta);
          });
    _regenerateCollapseAnimation = AnimationController(
      vsync: this,
      duration: _replyCardRegenerateCollapseDuration,
    )..addStatusListener(_handleRegenerateCollapseStatus);
  }

  @override
  void didUpdateWidget(LocationChatReplyCardSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardBuilderIdentity != oldWidget.cardBuilderIdentity ||
        (widget.cardBuilderIdentity == null &&
            widget.cardBuilder != oldWidget.cardBuilder)) {
      _cardChildren.clear();
    }
    if (widget.identity != oldWidget.identity) {
      _cardChildren.clear();
      _cancelRegenerateCollapse(deferred: true);
      _reset(deferred: true);
      _displayedId = widget.currentCardId;
      return;
    }
    if (_regenerateOriginalCard != null) {
      _syncRegenerateCollapse();
      return;
    }
    if (widget.currentCardId != oldWidget.currentCardId ||
        !widget.enabled ||
        (_targetId != null && _card(_targetId) == null)) {
      _reset(deferred: true);
      _displayedId = widget.currentCardId;
    }
  }

  /// Identifies the displayed card's start, even if new data replaced its ID.
  LocationChatReplyCard? get regenerateSourceCard =>
      _regenerateOriginalCard ?? _card(_displayedId);

  /// Starts a presentation-only collapse. The owner must invoke Regenerate
  /// first so this transition's busy callback cannot block its own request.
  bool beginRegenerateCollapse({
    bool deferBusyNotification = false,
    bool deferAnimation = false,
  }) {
    if (_busy || _regenerateOriginalCard != null) return false;
    final current = _card(_displayedId);
    if (current == null ||
        (current.messages.isEmpty && current.status == null) ||
        (!deferAnimation && MediaQuery.disableAnimationsOf(context))) {
      return false;
    }
    final snapshot = LocationChatReplyCard(
      id: current.id,
      messages: freezeLocationChatReplyMessages(current.messages),
      status: current.status,
    );
    _regenerateOriginalCard = snapshot;
    // Keep the exact rendered card that was on screen when Regenerate began.
    // The live current-card id immediately changes to the empty pending card,
    // which also changes compact row spacing and builder identity. Rebuilding
    // the old card from that new state adds a few pixels for one frame and is
    // visible as a small jump against the bubble above it.
    _regenerateSnapshotChild =
        _cardChildren[current.id]?.child ??
        RepaintBoundary(child: widget.cardBuilder(snapshot));
    _regenerateSourceId = current.id;
    _showRegenerateSnapshot = true;
    _regenerateReplacementObserved = false;
    _regenerateAwaitingPosition = deferAnimation;
    _setBusy(true, deferred: deferBusyNotification);
    setState(() {});
    if (!deferAnimation) _regenerateCollapseAnimation.forward(from: 0);
    return true;
  }

  void resumeRegenerateCollapse() {
    if (!_regenerateAwaitingPosition || _regenerateOriginalCard == null) return;
    _regenerateAwaitingPosition = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _regenerateCollapseAnimation.value = 1;
    } else {
      _regenerateCollapseAnimation.forward(from: 0);
    }
  }

  void _syncRegenerateCollapse() {
    final sourceId = _regenerateSourceId;
    if (sourceId == null) return;
    if (widget.currentCardId != sourceId) {
      _regenerateReplacementObserved = true;
      if (_regenerateReplacementReady) {
        _displayedId = widget.currentCardId;
        // The collapsed source stays mounted at zero height until real
        // replacement content exists. Swapping it for the empty pending card
        // on the completion tick can produce a one-frame visual jump.
        if (_regenerateCollapseAnimation.isCompleted) {
          _showRegenerateSnapshot = false;
        }
      }
    }
    if (!widget.regenerationInProgress && widget.currentCardId == sourceId) {
      _scheduleRegenerateTransitionUpdate();
      return;
    }
    if (!widget.regenerationInProgress &&
        widget.currentCardId != sourceId &&
        _regenerateCollapseAnimation.isCompleted) {
      _scheduleRegenerateTransitionUpdate();
    }
  }

  void _scheduleRegenerateTransitionUpdate() {
    if (_regenerateTransitionUpdateScheduled) return;
    _regenerateTransitionUpdateScheduled = true;
    scheduleMicrotask(() {
      _regenerateTransitionUpdateScheduled = false;
      if (!mounted || _regenerateOriginalCard == null) return;
      if (!widget.regenerationInProgress &&
          widget.currentCardId == _regenerateSourceId) {
        _recoverRegenerateSource();
      } else if (!widget.regenerationInProgress &&
          _regenerateCollapseAnimation.isCompleted) {
        _finishRegenerateTransition();
      }
    });
  }

  void _handleRegenerateCollapseStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      if (_regenerateReplacementReady) {
        setState(() {
          _displayedId = widget.currentCardId;
          _showRegenerateSnapshot = false;
        });
      }
      _setBusy(false);
      if (!widget.regenerationInProgress) {
        if (widget.currentCardId == _regenerateSourceId) {
          _recoverRegenerateSource();
        } else {
          _finishRegenerateTransition();
        }
      }
      return;
    }
    if (status == AnimationStatus.dismissed &&
        _regenerateOriginalCard != null) {
      _finishRegenerateTransition();
    }
  }

  void _recoverRegenerateSource() {
    if (_regenerateOriginalCard == null) return;
    _regenerateCollapseAnimation.stop();
    if (_regenerateAwaitingPosition) {
      _regenerateAwaitingPosition = false;
      _finishRegenerateTransition();
      return;
    }
    setState(() {
      _displayedId = _regenerateSourceId!;
      _showRegenerateSnapshot = true;
    });
    _setBusy(true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _finishRegenerateTransition();
    } else {
      _regenerateCollapseAnimation.reverse();
    }
  }

  void _finishRegenerateTransition() {
    _regenerateAwaitingPosition = false;
    _regenerateCollapseAnimation.stop();
    setState(() {
      _regenerateOriginalCard = null;
      _regenerateSnapshotChild = null;
      _regenerateSourceId = null;
      _showRegenerateSnapshot = false;
      _regenerateReplacementObserved = false;
      _regenerateTransitionUpdateScheduled = false;
      _displayedId = widget.currentCardId;
    });
    _regenerateCollapseAnimation.value = 0;
    _setBusy(false);
  }

  void _cancelRegenerateCollapse({bool deferred = false}) {
    _regenerateAwaitingPosition = false;
    if (_regenerateOriginalCard == null) return;
    _regenerateCollapseAnimation.stop();
    _regenerateOriginalCard = null;
    _regenerateSnapshotChild = null;
    _regenerateSourceId = null;
    _showRegenerateSnapshot = false;
    _regenerateReplacementObserved = false;
    _regenerateTransitionUpdateScheduled = false;
    _regenerateCollapseAnimation.value = 0;
    _setBusy(false, deferred: deferred);
  }

  void _setBusy(bool value, {bool deferred = false}) {
    if (_busy == value) return;
    _busy = value;
    final callback = widget.onBusyChanged;
    if (deferred) {
      scheduleMicrotask(() => callback(value));
    } else {
      callback(value);
    }
  }

  void _reset({bool deferred = false}) {
    _generation++;
    _animation.stop();
    _dragging = false;
    _progress = 0;
    _targetId = null;
    _delta = 0;
    _motion.update(0, 0);
    _setBusy(false, deferred: deferred);
  }

  void switchBy(int delta) {
    if (!widget.enabled || _busy || _neighbor(delta) == null) return;
    widget.onWillChangeLayout();
    setState(() {
      _delta = delta;
      _targetId = _neighbor(delta)!.id;
    });
    _setBusy(true);
    unawaited(_settle(commit: true));
  }

  Future<void> _settle({required bool commit}) async {
    final generation = ++_generation;
    final target = _targetId;
    _dragging = false;
    _from = _progress;
    _to = commit ? 1 : 0;
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _animation.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted || generation != _generation || !widget.enabled) return;
    if (commit &&
        target != null &&
        _card(target) != null &&
        widget.onCommit(target)) {
      _displayedId = target;
    }
    setState(_reset);
  }

  void _startDrag(DragStartDetails details) {
    if (_busy || !widget.enabled) return;
    _dragging = true;
    _dragDistance = 0;
    widget.onWillChangeLayout();
    _setBusy(true);
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragDistance = (_dragDistance + details.delta.dx).clamp(-_width, _width);
    final delta = _dragDistance < 0 ? 1 : -1;
    final neighbor = _neighbor(delta);
    final targetChanged = _targetId != neighbor?.id;
    _delta = delta;
    _targetId = neighbor?.id;
    final distance = _dragDistance.abs() / _width;
    _progress = neighbor == null ? math.min(0.12, distance * 0.25) : distance;
    _motion.update(_progress, _delta);
    if (targetChanged) setState(() {});
  }

  void _endDrag(DragEndDetails details) {
    if (!_dragging) return;
    final velocity = details.primaryVelocity ?? 0;
    final fast = velocity * -_delta >= 650;
    unawaited(
      _settle(commit: _targetId != null && (_progress >= 0.25 || fast)),
    );
  }

  @override
  void dispose() {
    _generation++;
    _animation.dispose();
    _motion.dispose();
    _cardChildren.clear();
    _regenerateCollapseAnimation
      ..removeStatusListener(_handleRegenerateCollapseStatus)
      ..dispose();
    _setBusy(false, deferred: true);
    super.dispose();
  }

  bool _sameMessages(List<ChatMessageVm> first, List<ChatMessageVm> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (!locationChatReplyMessagesEqual(first[i], second[i])) return false;
    }
    return true;
  }

  Widget _childFor(LocationChatReplyCard card) {
    final identity = (
      card.contentIdentity ?? card.messages,
      card.status,
      card.id == widget.currentCardId,
      widget.cardBuilderIdentity,
    );
    final cached = _cardChildren[card.id];
    final messages = card.messages;
    if (cached != null &&
        cached.identity == identity &&
        (card.contentIdentity != null ||
            _sameMessages(cached.snapshot, messages))) {
      return cached.child;
    }
    final child = RepaintBoundary(child: widget.cardBuilder(card));
    _cardChildren[card.id] = (
      identity: identity,
      snapshot: card.contentIdentity == null
          ? freezeLocationChatReplyMessages(messages)
          : const [],
      child: child,
    );
    return child;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final current = _showRegenerateSnapshot
        ? _regenerateOriginalCard
        : _regenerateOriginalCard != null && !_regenerateReplacementReady
        ? null
        : _card(_displayedId);
    if (current == null) {
      _cardChildren.clear();
      return const SizedBox.shrink();
    }
    final target = _card(_targetId);
    _cardChildren.removeWhere((id, _) => id != current.id && id != target?.id);
    final currentChild = _showRegenerateSnapshot
        ? TickerMode(enabled: false, child: _regenerateSnapshotChild!)
        : _childFor(current);
    final targetChild = target == null ? null : _childFor(target);
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = math.max(1, constraints.maxWidth);
        Widget deck = ClipRect(
          child: _SlidingCardLayout(
            motion: _motion,
            bridge: _showRegenerateSnapshot ? null : widget.layoutBridge,
            children: [
              IgnorePointer(
                key: ValueKey('reply-card-page-${current.id}'),
                ignoring: _busy,
                child: currentChild,
              ),
              if (target != null)
                ExcludeSemantics(
                  key: ValueKey('reply-card-page-${target.id}'),
                  child: IgnorePointer(child: targetChild),
                ),
            ],
          ),
        );
        if (_showRegenerateSnapshot) {
          deck = KeyedSubtree(
            key: const ValueKey('reply-card-regenerate-gradient'),
            child: _RegenerateCollapseViewport(
              key: const ValueKey('reply-card-regenerate-collapse-viewport'),
              animation: _regenerateCollapseAnimation,
              child: deck,
            ),
          );
        }
        return Listener(
          onPointerCancel: (_) {
            if (_dragging) unawaited(_settle(commit: false));
          },
          child: GestureDetector(
            key: const ValueKey('reply-card-gesture'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: widget.enabled ? _startDrag : null,
            onHorizontalDragUpdate: widget.enabled ? _updateDrag : null,
            onHorizontalDragEnd: widget.enabled ? _endDrag : null,
            onHorizontalDragCancel: widget.enabled
                ? () {
                    if (_dragging) unawaited(_settle(commit: false));
                  }
                : null,
            child: deck,
          ),
        );
      },
    );
  }
}

class _RegenerateCollapseViewport extends SingleChildRenderObjectWidget {
  const _RegenerateCollapseViewport({
    super.key,
    required this.animation,
    required super.child,
  });
  final Animation<double> animation;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRegenerateCollapseViewport(animation);
}

class _RenderRegenerateCollapseViewport extends RenderProxyBox {
  _RenderRegenerateCollapseViewport(this.animation);
  final Animation<double> animation;
  final LayerHandle<ShaderMaskLayer> _shaderLayer =
      LayerHandle<ShaderMaskLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    animation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    animation.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void dispose() {
    _shaderLayer.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    final factor = 1 - Curves.easeInOutCubic.transform(animation.value);
    size = constraints.constrain(
      Size(child!.size.width, child!.size.height * factor),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.height <= 0) return;
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      offset,
    ) {
      final strength = math.min(
        1.0,
        animation.value / _replyCardRegenerateFadeRampFraction,
      );
      if (strength <= 0) {
        super.paint(context, offset);
        return;
      }
      final extent = math.min(
        size.height,
        _replyCardRegenerateFadeExtent * strength,
      );
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, ((size.height - extent) / size.height).clamp(0.0, 1.0), 1],
      ).createShader(Offset.zero & size);
      final layer = _shaderLayer.layer ??= ShaderMaskLayer();
      layer
        ..shader = shader
        ..maskRect = offset & size
        ..blendMode = BlendMode.dstIn;
      context.pushLayer(layer, super.paint, offset);
    });
  }
}

class _CardMotion extends ChangeNotifier {
  double progress = 0;
  int delta = 0;
  void update(double value, int direction) {
    if (progress == value && delta == direction) return;
    progress = value;
    delta = direction;
    notifyListeners();
  }
}

class _SlidingCardLayout extends MultiChildRenderObjectWidget {
  const _SlidingCardLayout({
    required this.motion,
    required this.bridge,
    required super.children,
  });
  final _CardMotion motion;
  final LocationChatReplyLayoutBridge? bridge;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlidingCards(motion, bridge);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlidingCards renderObject,
  ) {
    renderObject.bridge = bridge;
  }
}

class _CardParentData extends ContainerBoxParentData<RenderBox> {}

/// Measures both variable-height pages in one layout pass; no post-frame jump.
class _RenderSlidingCards extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardParentData> {
  _RenderSlidingCards(this.motion, this.bridge);
  final _CardMotion motion;
  LocationChatReplyLayoutBridge? bridge;
  double get progress => motion.progress;
  int get delta => motion.delta;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    motion.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    motion.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardParentData) {
      child.parentData = _CardParentData();
    }
  }

  @override
  void performLayout() {
    final first = firstChild!;
    final second = childAfter(first);
    final childConstraints = BoxConstraints.tightFor(
      width: constraints.maxWidth,
    );
    first.layout(childConstraints, parentUsesSize: true);
    second?.layout(childConstraints, parentUsesSize: true);
    final height =
        first.size.height +
        ((second?.size.height ?? first.size.height) - first.size.height) *
            progress;
    size = constraints.constrain(Size(constraints.maxWidth, height));
    bridge?.reportHeight(size.height);
    (first.parentData! as _CardParentData).offset = Offset(
      -delta * progress * size.width,
      size.height - first.size.height,
    );
    if (second != null) {
      (second.parentData! as _CardParentData).offset = Offset(
        delta * (1 - progress) * size.width,
        size.height - second.size.height,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as _CardParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
