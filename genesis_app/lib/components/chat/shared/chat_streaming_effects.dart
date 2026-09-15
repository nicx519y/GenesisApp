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
    required this.child,
  });
  final LocationChatBubbleLayoutSettings settings;
  final Widget child;

  @override
  State<ChatStreamingEffects> createState() => _ChatStreamingEffectsState();
}

class _ChatStreamingEffectsState extends State<ChatStreamingEffects> {
  final _records = <Object, _StreamRecord>{};
  final _pending = <Object, Map<Object, _StreamRecord>>{};

  _StreamRecord record(Object identity, Object? continuation, bool streaming) {
    var result = _records[identity];
    final candidates = _pending[continuation];
    // Final IDs can replace temporary stream IDs. Only migrate an unambiguous
    // same-round/sender record; never merge concurrent candidate streams.
    if (result == null && !streaming && candidates?.length == 1) {
      result = candidates!.values.single;
    }
    result ??= _StreamRecord();
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
    child: widget.child,
  );
}

class _EffectsScope extends InheritedWidget {
  const _EffectsScope({
    required this.owner,
    required this.settings,
    required super.child,
  });
  final _ChatStreamingEffectsState owner;
  final LocationChatBubbleLayoutSettings settings;
  @override
  bool updateShouldNotify(_EffectsScope oldWidget) =>
      settings != oldWidget.settings;
}

/// Each candidate card has its own identity, even when its messages share IDs.
class ChatStreamingMessage extends StatelessWidget {
  const ChatStreamingMessage({
    super.key,
    required this.identity,
    this.continuationIdentity,
    required this.streaming,
    required this.child,
  });
  final Object identity;
  final Object? continuationIdentity;
  final bool streaming;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effects = context.dependOnInheritedWidgetOfExactType<_EffectsScope>();
    if (effects == null) return child;
    return _MessageScope(
      settings: effects.settings,
      record: effects.owner.record(identity, continuationIdentity, streaming),
      streaming: streaming,
      child: child,
    );
  }
}

class _MessageScope extends InheritedWidget {
  const _MessageScope({
    required this.settings,
    required this.record,
    required this.streaming,
    required super.child,
  });
  final LocationChatBubbleLayoutSettings settings;
  final _StreamRecord record;
  final bool streaming;
  @override
  bool updateShouldNotify(_MessageScope oldWidget) =>
      settings != oldWidget.settings ||
      streaming != oldWidget.streaming ||
      record != oldWidget.record;
}

/// Emitted during layout; listeners must schedule their work after layout.
class ChatStreamingLayoutNotification extends Notification {}

/// Put inside the decorated surface, so its fill and border follow the height.
class ChatStreamingBody extends StatefulWidget {
  const ChatStreamingBody({super.key, required this.child});
  final Widget child;

  static bool ownsSizeAnimation(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_MessageScope>();
    return scope != null && (scope.streaming || scope.record.finishing);
  }

  @override
  State<ChatStreamingBody> createState() => _ChatStreamingBodyState();
}

class _ChatStreamingBodyState extends State<ChatStreamingBody>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_MessageScope>();
    if (scope == null) return widget.child;
    return _StreamingBodyRenderWidget(
      vsync: this,
      scope: scope,
      onSizeChanged: () => ChatStreamingLayoutNotification().dispatch(context),
      child: widget.child,
    );
  }
}

class _StreamingBodyRenderWidget extends SingleChildRenderObjectWidget {
  const _StreamingBodyRenderWidget({
    required this.vsync,
    required this.scope,
    required this.onSizeChanged,
    required super.child,
  });
  final TickerProvider vsync;
  final VoidCallback onSizeChanged;
  final _MessageScope scope;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStreamingBody(vsync, scope, onSizeChanged);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStreamingBody renderObject,
  ) => renderObject.configure(scope);
}

class _StreamRecord {
  List<String> text = const [];
  double revealed = 0;
  double height = 0;
  bool seen = false;
  bool wasStreaming = false;
  bool finishing = false;
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
    _reveal.snap(
      record.seen && scope.streaming
          ? record.text.length.toDouble() + 1
          : record.revealed,
    );
    _height.snap(record.height);
    _laidOut = record.seen && record.wasStreaming && !scope.streaming;
  }
  final VoidCallback onSizeChanged;
  late final Ticker _ticker;
  _MessageScope _scope;
  final _reveal = _Motion(), _height = _Motion();
  Duration _clock = Duration.zero, _lastTick = Duration.zero;
  bool _laidOut = false;
  bool _textWasEnabled = true;
  bool _inLayout = false;

  void configure(_MessageScope value) {
    if (_scope.record != value.record) {
      _reveal.snap(
        value.record.seen && value.streaming
            ? value.record.text.length.toDouble() + 1
            : value.record.revealed,
      );
      _height.snap(value.record.height);
      _laidOut = false;
    }
    _scope = value;
    markNeedsLayout();
  }

  void _tick(Duration elapsed) {
    _clock += elapsed - _lastTick;
    _lastTick = elapsed;
    if (!_inLayout) markNeedsLayout();
  }

  void _updateTicker() {
    final running = _height.running(_clock) || _reveal.running(_clock);
    if (running && !_ticker.isActive && attached) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _updateTicker();
  }

  @override
  void detach() {
    _ticker.stop();
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
    if (record.wasStreaming && !_scope.streaming) record.finishing = true;
    record.wasStreaming = _scope.streaming;
    final active = _scope.streaming || record.finishing;
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
    } else if (changed || !record.seen) {
      _reveal.target(
        end,
        _clock,
        settings.streamingTextDurationMs,
        Curves.linear,
      );
    }
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
    _laidOut = true;
    if (!_scope.streaming &&
        !_height.running(_clock) &&
        !_reveal.running(_clock)) {
      record.finishing = false;
    }
    _inLayout = false;
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
