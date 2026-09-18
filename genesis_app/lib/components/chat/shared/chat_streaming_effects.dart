import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/debug/location_chat_bubble_layout_settings.dart';
import 'chat_scene_plate_tokens.dart';

/// The owner is a location, not the shared chat library. Cached rows still
/// receive setting changes through this inherited scope.
class ChatStreamingEffects extends StatefulWidget {
  const ChatStreamingEffects({
    super.key,
    required this.settings,
    this.presentationRevision,
    this.operationIdentity,
    required this.child,
  });
  final LocationChatBubbleLayoutSettings settings;
  final Object? presentationRevision;
  final Object? operationIdentity;
  final Widget child;

  /// True only after the current subtree has laid out and every participating
  /// bubble has drained both its text reveal and height animation.
  static bool isSettledOf(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context
              .dependOnInheritedWidgetOfExactType<_EffectsScope>()
              ?.settled ??
          true;
    }
    // An action may run after the layout callback but before the inherited
    // snapshot rebuilds. Read the owner for the current authoritative result.
    return context
            .getInheritedWidgetOfExactType<_EffectsScope>()
            ?.owner
            ._settled ??
        true;
  }

  @override
  State<ChatStreamingEffects> createState() => _ChatStreamingEffectsState();
}

class _ChatStreamingEffectsState extends State<ChatStreamingEffects> {
  final _records = <Object, _StreamRecord>{};
  final _pending = <Object, Map<Object, _StreamRecord>>{};
  final _bodies = <_RenderStreamingBody>{};
  bool _settled = false;
  bool _settlementScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleSettlement();
  }

  @override
  void didUpdateWidget(ChatStreamingEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationIdentity != widget.operationIdentity) {
      // A user-started operation retires the preceding presentation. Its old
      // bubbles stay fully visible above the new send instead of replaying.
      for (final record in _records.values) {
        record.cancelled = true;
        record.finishing = false;
      }
      _pending.clear();
      for (final body in _bodies) {
        body.markNeedsLayout();
      }
      refreshQueue();
    }
    // Invalidate before descendants build: a complete reply can arrive in one
    // frame, before any render body has had a chance to register its backlog.
    if (oldWidget.presentationRevision != widget.presentationRevision ||
        oldWidget.settings != widget.settings) {
      _settled = false;
      _scheduleSettlement();
    }
  }

  void _scheduleSettlement() {
    if (_settlementScheduled) return;
    _settlementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settlementScheduled = false;
      if (!mounted) return;
      final settled = !_bodies.any(
        (body) =>
            body.attached &&
            body._presentationActive &&
            !body._scope.record.cancelled &&
            (body._scope.streaming || body._scope.record.finishing),
      );
      if (_settled != settled) setState(() => _settled = settled);
    });
  }

  // Use display order, not chunk arrival or lazy child mounting order. A live
  // bubble retains its turn between chunks until its terminal reveal settles.
  void refreshQueue() {
    _scheduleSettlement();
    _RenderStreamingBody? first;
    for (final body in _bodies) {
      if (!body._needsRevealTurn) continue;
      if (first == null ||
          (body._scope.order?.call() ?? 0) <
              (first._scope.order?.call() ?? 0)) {
        first = body;
      }
    }
    for (final body in _bodies) {
      body._setQueueBlocked(body._needsRevealTurn && body != first);
    }
  }

  _StreamRecord record(
    Object identity,
    Object? continuation,
    bool streaming, {
    bool animateArrival = false,
  }) {
    var result = _records[identity];
    final candidates = _pending[continuation];
    // Final IDs can replace temporary stream IDs. Only migrate an unambiguous
    // same-round/sender record; never merge concurrent candidate streams.
    if (result == null && !streaming && candidates?.length == 1) {
      result = candidates!.values.single;
    }
    result ??= _StreamRecord();
    // Remember receipt even if streaming and terminal builds share a frame.
    if (!result.cancelled && (streaming || (animateArrival && !result.seen))) {
      result.finishing = true;
    }
    _records[identity] = result;
    if (continuation != null) {
      if (streaming) {
        (_pending[continuation] ??= {})[identity] = result;
      } else {
        candidates?.removeWhere((_, record) => identical(record, result));
        if (candidates?.isEmpty ?? false) _pending.remove(continuation);
      }
    }
    if (_records.length > 512) {
      final evicted = _records.remove(_records.keys.first);
      for (final pending in _pending.values) {
        pending.removeWhere((_, record) => identical(record, evicted));
      }
      _pending.removeWhere((_, pending) => pending.isEmpty);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => _EffectsScope(
    owner: this,
    settings: widget.settings,
    settled: _settled,
    child: widget.child,
  );
}

class _EffectsScope extends InheritedWidget {
  const _EffectsScope({
    required this.owner,
    required this.settings,
    required this.settled,
    required super.child,
  });
  final _ChatStreamingEffectsState owner;
  final LocationChatBubbleLayoutSettings settings;
  final bool settled;
  @override
  bool updateShouldNotify(_EffectsScope oldWidget) =>
      settings != oldWidget.settings || settled != oldWidget.settled;
}

/// Each candidate card has its own identity, even when its messages share IDs.
class ChatStreamingMessage extends StatelessWidget {
  const ChatStreamingMessage({
    super.key,
    required this.identity,
    this.continuationIdentity,
    required this.streaming,
    this.animateArrival = false,
    this.order,
    required this.child,
  });
  final Object identity;
  final Object? continuationIdentity;
  final bool streaming;
  final bool animateArrival;

  /// Resolve current display order without rebuilding cached message rows when
  /// history is prepended or a neighboring bubble is inserted.
  final ValueGetter<double>? order;
  final Widget child;

  static bool isStreamingActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MessageScope>()?.streaming ??
      false;

  @override
  Widget build(BuildContext context) {
    final effects = context.dependOnInheritedWidgetOfExactType<_EffectsScope>();
    if (effects == null) return child;
    final record = effects.owner.record(
      identity,
      continuationIdentity,
      streaming,
      animateArrival: animateArrival,
    );
    return _MessageScope(
      owner: effects.owner,
      order: order,
      settings: effects.settings,
      record: record,
      streaming: streaming,
      child: _StreamingMessageRow(record: record, child: child),
    );
  }
}

class _MessageScope extends InheritedWidget {
  const _MessageScope({
    required this.owner,
    required this.order,
    required this.settings,
    required this.record,
    required this.streaming,
    required super.child,
  });
  final LocationChatBubbleLayoutSettings settings;
  final _ChatStreamingEffectsState owner;
  final ValueGetter<double>? order;
  final _StreamRecord record;
  final bool streaming;
  @override
  bool updateShouldNotify(_MessageScope oldWidget) =>
      settings != oldWidget.settings ||
      streaming != oldWidget.streaming ||
      order != oldWidget.order ||
      owner != oldWidget.owner ||
      record != oldWidget.record;
}

/// Emitted during layout; listeners must schedule their work after layout.
class ChatStreamingLayoutNotification extends Notification {}

/// Put inside the decorated surface, so its fill and border follow the height.
class ChatStreamingBody extends StatefulWidget {
  const ChatStreamingBody({super.key, required this.child});
  final Widget child;

  @visibleForTesting
  static double revealedGraphemesOf(BuildContext context) {
    final record = context
        .getInheritedWidgetOfExactType<_MessageScope>()
        ?.record;
    return record == null
        ? 0
        : math.min(record.revealed, record.text.length.toDouble());
  }

  static bool ownsSizeAnimation(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_MessageScope>();
    return scope != null && (scope.streaming || scope.record.finishing);
  }

  @override
  State<ChatStreamingBody> createState() => _ChatStreamingBodyState();
}

class _ChatStreamingBodyState extends State<ChatStreamingBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paused =
        WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _paused = state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_MessageScope>();
    if (scope == null) return widget.child;
    return _StreamingBodyRenderWidget(
      vsync: this,
      scope: scope,
      presentationActive: TickerMode.valuesOf(context).enabled,
      paused: _paused || !TickerMode.valuesOf(context).enabled,
      onSizeChanged: () => ChatStreamingLayoutNotification().dispatch(context),
      child: widget.child,
    );
  }
}

class _StreamingBodyRenderWidget extends SingleChildRenderObjectWidget {
  const _StreamingBodyRenderWidget({
    required this.vsync,
    required this.scope,
    required this.paused,
    required this.presentationActive,
    required this.onSizeChanged,
    required super.child,
  });
  final TickerProvider vsync;
  final VoidCallback onSizeChanged;
  final _MessageScope scope;
  final bool paused;
  final bool presentationActive;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStreamingBody(vsync, scope, onSizeChanged)
        ..presentationActive = presentationActive
        ..paused = paused;
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStreamingBody renderObject,
  ) {
    renderObject.presentationActive = presentationActive;
    renderObject.paused = paused;
    renderObject.configure(scope);
  }
}

class _StreamRecord {
  List<String> text = const [];
  double revealed = 0;
  double height = 0;
  bool seen = false;
  bool wasStreaming = false;
  bool finishing = false;
  bool cancelled = false;
  bool hidden = false;
}

/// Keep queued bodies mounted for measurement/timing, but expose none of the
/// row (surface, avatar, name, date or spacing) before visible text exists.
class _StreamingMessageRow extends SingleChildRenderObjectWidget {
  const _StreamingMessageRow({required this.record, required super.child});
  final _StreamRecord record;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStreamingMessageRow(record);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStreamingMessageRow renderObject,
  ) {
    renderObject.record = record;
    renderObject.markNeedsLayout();
  }
}

class _RenderStreamingMessageRow extends RenderProxyBox {
  _RenderStreamingMessageRow(this.record);
  _StreamRecord record;
  bool _hidden = false;

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    if (_hidden != record.hidden) {
      _hidden = record.hidden;
      markNeedsSemanticsUpdate();
    }
    size = constraints.constrain(
      Size(child!.size.width, _hidden ? 0 : child!.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !_hidden && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_hidden) super.visitChildrenForSemantics(visitor);
  }
}

class _Motion {
  double from = 0, to = 0;
  Duration start = Duration.zero, duration = Duration.zero;
  Curve curve = Curves.linear;
  double value(Duration now) {
    if (duration == Duration.zero) return to;
    final t = ((now - start).inMicroseconds / duration.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    return from + (to - from) * curve.transform(t);
  }

  bool running(Duration now) => value(now) != to;
  void snap(double value) {
    from = to = value;
    duration = Duration.zero;
  }

  void target(double value, Duration now, int milliseconds, Curve easing) {
    from = this.value(now);
    to = value;
    start = now;
    duration = Duration(milliseconds: milliseconds);
    curve = easing;
  }
}

class _RenderStreamingBody extends RenderProxyBox {
  _RenderStreamingBody(
    TickerProvider vsync,
    _MessageScope scope,
    this.onSizeChanged,
  ) : _scope = scope {
    _ticker = vsync.createTicker(_tick);
    final record = scope.record;
    _reveal.snap(record.revealed);
    _height.snap(record.height);
    _laidOut = record.seen;
  }
  final VoidCallback onSizeChanged;
  late final Ticker _ticker;
  _MessageScope _scope;
  final _reveal = _Motion(), _height = _Motion();
  Duration _clock = Duration.zero, _lastTick = Duration.zero;
  bool _laidOut = false;
  bool _textWasEnabled = true;
  bool _inLayout = false;
  bool _paused = false;
  bool _presentationActive = true;
  bool _queueBlocked = false;
  int? _revealDurationMs;

  set presentationActive(bool value) {
    if (_presentationActive == value) return;
    _presentationActive = value;
    _scope.owner._scheduleSettlement();
  }

  bool get _needsRevealTurn =>
      attached &&
      !_paused &&
      _scope.settings.streamingTextReveal &&
      !_scope.record.cancelled &&
      (_scope.streaming || _scope.record.finishing);

  void _setQueueBlocked(bool value) {
    if (_queueBlocked == value) return;
    _queueBlocked = value;
    _ticker.stop();
    _lastTick = Duration.zero;
    _updateTicker();
  }

  set paused(bool value) {
    if (_paused == value) return;
    _paused = value;
    _ticker.stop();
    _lastTick = Duration.zero;
    _scope.owner.refreshQueue();
    _updateTicker();
  }

  void configure(_MessageScope value) {
    final oldOwner = _scope.owner;
    if (_scope.record != value.record) {
      _reveal.snap(value.record.revealed);
      _height.snap(value.record.height);
      _laidOut = value.record.seen;
    }
    _scope = value;
    if (attached && oldOwner != value.owner) {
      oldOwner._bodies.remove(this);
      value.owner._bodies.add(this);
      oldOwner.refreshQueue();
    }
    value.owner.refreshQueue();
    markNeedsLayout();
  }

  void _tick(Duration elapsed) {
    _clock += elapsed - _lastTick;
    _lastTick = elapsed;
    if (!_inLayout) markNeedsLayout();
  }

  void _updateTicker() {
    final running = _height.running(_clock) || _reveal.running(_clock);
    if (running &&
        !_ticker.isActive &&
        attached &&
        !_paused &&
        !_queueBlocked) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope.owner._bodies.add(this);
    _scope.owner.refreshQueue();
    _updateTicker();
  }

  @override
  void detach() {
    _ticker.stop();
    _scope.owner._bodies.remove(this);
    _scope.owner.refreshQueue();
    super.detach();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    _inLayout = true;
    child!.layout(constraints, parentUsesSize: true);
    final record = _scope.record;
    final settings = _scope.settings;
    if (!record.cancelled && record.wasStreaming && !_scope.streaming) {
      record.finishing = true;
    }
    record.wasStreaming = _scope.streaming;
    final active = !record.cancelled && (_scope.streaming || record.finishing);
    final texts = <_RenderStreamingText>[];
    bool editing = false;
    void visit(RenderObject node) {
      if (node is RenderEditable) {
        editing = true;
        return;
      }
      if (node is _RenderStreamingText) {
        texts.add(node);
        return;
      }
      // Nested surfaces own their animation independently.
      if (node is _RenderStreamingBody) return;
      node.visitChildren(visit);
    }

    visit(child!);
    final next = <String>[for (final text in texts) ...text.units];
    final changed = !_sameUnits(record.text, next);
    final animate = active && !editing && texts.isNotEmpty;
    final revealEnabled = animate && settings.streamingTextReveal;
    final end = next.length.toDouble() + (next.isEmpty ? 0 : 1);
    if (!record.seen) {
      _reveal.snap(revealEnabled ? 0 : end);
    } else if (changed) {
      var common = 0;
      while (common < record.text.length &&
          common < next.length &&
          record.text[common] == next[common]) {
        common++;
      }
      // A parser correction must not re-hide the unchanged prefix.
      _reveal.snap(math.min(_reveal.value(_clock), common.toDouble()));
    }
    if (!revealEnabled || (!_textWasEnabled && settings.streamingTextReveal)) {
      _reveal.snap(end);
    } else if (changed ||
        !record.seen ||
        _reveal.to != end ||
        _revealDurationMs != settings.streamingTextDurationMs) {
      // Duration scales with remaining graphemes, never with chunk count.
      // The extra terminal unit drains the existing soft mask at the same rate.
      final remaining = math.max(0.0, end - _reveal.value(_clock));
      _reveal.target(
        end,
        _clock,
        (remaining * settings.effectiveStreamingTextDurationMs).ceil(),
        Curves.linear,
      );
    }
    _revealDurationMs = settings.streamingTextDurationMs;
    _textWasEnabled = settings.streamingTextReveal;
    record.seen = true;
    record.text = next;
    record.revealed = _reveal.value(_clock);

    var targetHeight = child!.size.height;
    var start = 0;
    var visibleBottom = 0.0;
    for (final text in texts) {
      final local = record.revealed - start;
      text.reveal(revealEnabled ? local : double.infinity);
      if (revealEnabled && record.revealed < end && local > 0) {
        final transform = text.getTransformTo(this);
        final rect = MatrixUtils.transformRect(
          transform,
          Rect.fromLTWH(0, 0, text.layoutSize.width, text.visibleBottom),
        );
        visibleBottom = math.max(visibleBottom, rect.bottom);
      }
      start += text.units.length;
    }
    if (revealEnabled && record.revealed < end && texts.isNotEmpty) {
      targetHeight = visibleBottom.clamp(0.0, child!.size.height);
    }
    if (!_laidOut || !animate || !settings.animateStreamingHeight) {
      _height.snap(targetHeight);
    } else if (_height.to != targetHeight) {
      _height.target(
        targetHeight,
        _clock,
        settings.streamingHeightDurationMs,
        Curves.easeOutCubic,
      );
    }
    size = constraints.constrain(
      Size(child!.size.width, _height.value(_clock)),
    );
    if (_laidOut && record.height != size.height) onSizeChanged();
    record.height = size.height;
    record.hidden =
        revealEnabled &&
        next.isNotEmpty &&
        (record.revealed <= 0 || record.height <= 0);
    _laidOut = true;
    if (!_scope.streaming &&
        !_height.running(_clock) &&
        !_reveal.running(_clock)) {
      record.finishing = false;
    }
    _inLayout = false;
    _scope.owner.refreshQueue();
    _updateTicker();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      child!.getDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;
}

bool _sameUnits(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Marks only dynamic prose. Metadata and icons outside this marker stay opaque.
/// The RenderParagraph remains the source of truth, including WidgetSpans.
class ChatStreamingText extends StatelessWidget {
  const ChatStreamingText({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MessageScope>() == null
      ? child
      : _StreamingTextRenderWidget(child: child);
}

class _StreamingTextRenderWidget extends SingleChildRenderObjectWidget {
  const _StreamingTextRenderWidget({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStreamingText();
}

class _Glyph {
  const _Glyph(this.rect, this.direction);
  final Rect rect;
  final TextDirection direction;
}

class _GlyphSource {
  const _GlyphSource(this.paragraph, this.start, this.end, this.text);
  final RenderParagraph paragraph;
  final int start, end;
  final String text;
}

class _RenderStreamingText extends RenderProxyBox {
  Size layoutSize = Size.zero;
  RenderParagraph? _paragraph;
  List<String> _units = const [];
  List<_GlyphSource> _sources = const [];
  List<List<_Glyph>>? _glyphs;
  double _progress = double.infinity;
  List<String> get units => _units;

  @override
  void performLayout() {
    super.performLayout();
    layoutSize = Size(size.width, size.height);
    _paragraph = null;
    void visit(RenderObject node) {
      if (_paragraph != null) return;
      if (node is RenderParagraph) {
        _paragraph = node;
        return;
      }
      node.visitChildren(visit);
    }

    visit(child!);
    final sources = <_GlyphSource>[];
    void appendParagraph(RenderParagraph paragraph) {
      final placeholders = <RenderObject>[];
      paragraph.visitChildren(placeholders.add);
      var placeholderIndex = 0;
      var offset = 0;
      final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
      for (final unit in plain.characters) {
        final start = offset;
        offset += unit.length;
        if (unit == '\uFFFC' && placeholderIndex < placeholders.length) {
          final nested = <RenderParagraph>[];
          void findParagraphs(RenderObject node) {
            if (node is RenderParagraph) {
              nested.add(node);
              return;
            }
            node.visitChildren(findParagraphs);
          }

          findParagraphs(placeholders[placeholderIndex++]);
          if (nested.isNotEmpty) {
            for (final paragraph in nested) {
              appendParagraph(paragraph);
            }
            continue;
          }
        }
        sources.add(_GlyphSource(paragraph, start, offset, unit));
      }
    }

    if (_paragraph != null) appendParagraph(_paragraph!);
    _sources = sources;
    _units = [for (final source in sources) source.text];
    _glyphs = null;
  }

  List<List<_Glyph>> get glyphs => _glyphs ??= _measureGlyphs();
  List<List<_Glyph>> _measureGlyphs() {
    return [
      for (final source in _sources)
        (() {
          final paragraph = source.paragraph;
          final transform = paragraph.getTransformTo(this);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: source.start, extentOffset: source.end),
            boxHeightStyle: ui.BoxHeightStyle.max,
          );
          if (boxes.isEmpty) {
            final position = TextPosition(offset: source.start);
            final caret = paragraph.getOffsetForCaret(position, Rect.zero);
            return [
              _Glyph(
                MatrixUtils.transformRect(
                  transform,
                  Rect.fromLTWH(
                    caret.dx,
                    caret.dy,
                    0,
                    paragraph.getFullHeightForCaret(position),
                  ),
                ),
                paragraph.textDirection,
              ),
            ];
          }
          return [
            for (final box in boxes)
              _Glyph(
                MatrixUtils.transformRect(transform, box.toRect()),
                box.direction,
              ),
          ];
        })(),
    ];
  }

  double get visibleBottom {
    if (_progress >= units.length) return layoutSize.height;
    var bottom = 0.0;
    for (var i = 0; i < math.min(_progress.ceil(), glyphs.length); i++) {
      for (final glyph in glyphs[i]) {
        bottom = math.max(bottom, glyph.rect.bottom);
      }
    }
    return bottom;
  }

  void reveal(double progress) {
    if (_progress == progress) return;
    final wasComposited = _progress.isFinite;
    _progress = progress;
    if (wasComposited != _progress.isFinite) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _progress.isFinite && child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_progress >= units.length + 1 || units.isEmpty) {
      super.paint(context, offset);
      return;
    }
    if (_progress <= 0 || glyphs.isEmpty) return;
    final index = math.min(_progress.floor(), glyphs.length - 1);
    final current = glyphs[index].last;
    final rtl = current.direction == TextDirection.rtl;
    final fraction = (_progress - index).clamp(0.0, 1.0);
    final tail =
        math.max(0.0, _progress - units.length) *
        kChatStreamingTextFeatherWidth;
    final edge = rtl
        ? current.rect.right - current.rect.width * fraction - tail
        : current.rect.left + current.rect.width * fraction + tail;
    final path = Path();
    Rect? run;
    for (var i = 0; i <= index; i++) {
      for (final glyph in glyphs[i]) {
        final rect = glyph.rect.inflate(0.5);
        path.addRect(rect);
        if (glyph.direction == current.direction &&
            (glyph.rect.bottom - current.rect.bottom).abs() < 1) {
          run = run == null ? rect : run.expandToInclude(rect);
        }
      }
    }
    final mask = run ?? current.rect;
    final x = edge - mask.left;
    final layer = ShaderMaskLayer(
      shader: ui.Gradient.linear(
        Offset(
          rtl
              ? x + kChatStreamingTextFeatherWidth
              : x - kChatStreamingTextFeatherWidth,
          0,
        ),
        Offset(x, 0),
        const [Colors.white, Colors.transparent],
      ),
      maskRect: mask.shift(offset),
      blendMode: BlendMode.dstIn,
    );
    context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      path,
      (context, offset) => context.pushLayer(layer, super.paint, offset),
    );
  }
}
