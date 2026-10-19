import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../pages/chat/location_chat_scroll_coordinator.dart';
import 'chat_ui.dart';

/// Shared keyboard/composer geometry. Callers choose their own chat behavior.
class ChatKeyboardInsetLayout extends StatefulWidget {
  const ChatKeyboardInsetLayout({
    super.key,
    required this.unobscuredPanelKey,
    required this.managesKeyboardInset,
    required this.freezeKeyboardInset,
    required this.frozenKeyboardInset,
    required this.onFrozenKeyboardInsetRestored,
    required this.bottomSafeAreaInset,
    this.onKeyboardMotionTraceSettled,
    required this.messageViewport,
    required this.header,
    this.composerTopOverlay,
    this.composer,
  });

  final bool managesKeyboardInset;
  final GlobalKey unobscuredPanelKey;
  final bool freezeKeyboardInset;
  final double frozenKeyboardInset;
  final VoidCallback onFrozenKeyboardInsetRestored;
  final double bottomSafeAreaInset;
  final ValueChanged<List<Map<String, Object?>>>? onKeyboardMotionTraceSettled;
  final Widget messageViewport;
  final Widget header;
  final Widget? composerTopOverlay;
  final Widget? composer;

  @override
  State<ChatKeyboardInsetLayout> createState() =>
      ChatKeyboardInsetLayoutState();
}

class ChatKeyboardInsetLayoutState extends State<ChatKeyboardInsetLayout>
    with WidgetsBindingObserver {
  int _keyboardMetricsGeneration = 0;
  final _composerGeometryKey = GlobalKey();
  double _liveKeyboardInset = 0;
  double _frozenKeyboardInset = 0;
  List<Map<String, Object?>>? _keyboardMotionSamples;
  Stopwatch? _keyboardMotionStopwatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLiveKeyboardInset(
      widget.managesKeyboardInset || widget.freezeKeyboardInset
          ? _viewKeyboardInset()
          : 0,
    );
    if (widget.freezeKeyboardInset) {
      _frozenKeyboardInset = math.max(
        widget.frozenKeyboardInset,
        math.max(_frozenKeyboardInset, _liveKeyboardInset),
      );
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted ||
        !widget.managesKeyboardInset && !widget.freezeKeyboardInset) {
      return;
    }
    final nextInset = _viewKeyboardInset();
    if ((_liveKeyboardInset - nextInset).abs() <= precisionErrorTolerance) {
      _scheduleFrozenKeyboardInsetRestored(nextInset);
      return;
    }
    setState(() => _updateLiveKeyboardInset(nextInset));
    _scheduleFrozenKeyboardInsetRestored(nextInset);
  }

  void _scheduleFrozenKeyboardInsetRestored(double keyboardInset) {
    if (!widget.freezeKeyboardInset || widget.frozenKeyboardInset <= 0) return;
    if (keyboardInset + 0.5 < widget.frozenKeyboardInset) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.freezeKeyboardInset) return;
      if (_viewKeyboardInset() + 0.5 < widget.frozenKeyboardInset) return;
      widget.onFrozenKeyboardInsetRestored();
    });
  }

  @override
  void didUpdateWidget(covariant ChatKeyboardInsetLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onKeyboardMotionTraceSettled == null) {
      _clearKeyboardMotionTrace();
    }
    final wasTrackingInset =
        oldWidget.managesKeyboardInset || oldWidget.freezeKeyboardInset;
    final tracksInset =
        widget.managesKeyboardInset || widget.freezeKeyboardInset;
    if (tracksInset && !wasTrackingInset) {
      _updateLiveKeyboardInset(_viewKeyboardInset());
    }
    if (widget.freezeKeyboardInset && !oldWidget.freezeKeyboardInset) {
      _frozenKeyboardInset = math.max(
        widget.frozenKeyboardInset,
        math.max(_liveKeyboardInset, _viewKeyboardInset()),
      );
    } else if (widget.freezeKeyboardInset &&
        widget.frozenKeyboardInset != oldWidget.frozenKeyboardInset) {
      _frozenKeyboardInset = math.max(
        _frozenKeyboardInset,
        widget.frozenKeyboardInset,
      );
    } else if (!widget.freezeKeyboardInset && oldWidget.freezeKeyboardInset) {
      _frozenKeyboardInset = 0;
    }
    if (tracksInset) {
      return;
    }
    _keyboardMetricsGeneration += 1;
    _clearKeyboardMotionTrace();
    _liveKeyboardInset = 0;
  }

  void _updateLiveKeyboardInset(double nextInset) {
    if ((_liveKeyboardInset - nextInset).abs() <= precisionErrorTolerance) {
      return;
    }
    _liveKeyboardInset = nextInset;

    _recordKeyboardMotionSample(nextInset);
    final generation = ++_keyboardMetricsGeneration;
    _scheduleStableFrameCheck(generation, stableFrameCount: 0);
  }

  void _scheduleStableFrameCheck(
    int generation, {
    required int stableFrameCount,
  }) {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted || generation != _keyboardMetricsGeneration) return;
      final nextStableFrameCount = stableFrameCount + 1;
      if (nextStableFrameCount < 2) {
        _scheduleStableFrameCheck(
          generation,
          stableFrameCount: nextStableFrameCount,
        );
        return;
      }

      _finishKeyboardMotionTrace();
    });
  }

  void _recordKeyboardMotionSample(double rawKeyboardInset) {
    if (widget.onKeyboardMotionTraceSettled == null) return;
    final stopwatch = _keyboardMotionStopwatch ??= Stopwatch()..start();
    final samples = _keyboardMotionSamples ??= <Map<String, Object?>>[];
    if (samples.length == 120) {
      samples.removeAt(0);
    }
    final layoutKeyboardInset = widget.freezeKeyboardInset
        ? _frozenKeyboardInset
        : rawKeyboardInset;
    final effectiveKeyboardInset = _effectiveKeyboardInset(layoutKeyboardInset);
    samples.add(<String, Object?>{
      'elapsedMicros': stopwatch.elapsedMicroseconds,
      'rawInset': rawKeyboardInset,
      'effectiveInset': effectiveKeyboardInset,
      'composerTranslationY': -effectiveKeyboardInset,
    });
  }

  void _finishKeyboardMotionTrace() {
    final samples = _keyboardMotionSamples;
    final callback = widget.onKeyboardMotionTraceSettled;
    if (samples != null && samples.isNotEmpty && callback != null) {
      callback(List<Map<String, Object?>>.unmodifiable(samples));
    }
    _clearKeyboardMotionTrace();
  }

  void _clearKeyboardMotionTrace() {
    _keyboardMotionSamples = null;
    _keyboardMotionStopwatch?.stop();
    _keyboardMotionStopwatch = null;
  }

  double _viewKeyboardInset() {
    final view = View.maybeOf(context);
    if (view == null || view.devicePixelRatio <= 0) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  double _effectiveKeyboardInset(double rawKeyboardInset) {
    return math.max(0.0, rawKeyboardInset - widget.bottomSafeAreaInset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardMetricsGeneration += 1;
    _clearKeyboardMotionTrace();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layoutKeyboardInset = widget.freezeKeyboardInset
        ? _frozenKeyboardInset
        : _liveKeyboardInset;
    final liveKeyboardInset =
        widget.managesKeyboardInset || widget.freezeKeyboardInset
        ? _effectiveKeyboardInset(layoutKeyboardInset)
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: liveKeyboardInset),
      child: LocationChatKeyboardInsetScope(
        effectiveInset: liveKeyboardInset,
        referenceHeightAdjustment: () {
          final panel = widget.unobscuredPanelKey.currentContext
              ?.findRenderObject();
          final body = context.findRenderObject();
          final scaffoldReduction =
              panel is RenderBox &&
                  panel.hasSize &&
                  body is RenderBox &&
                  body.hasSize
              ? math.max(0.0, panel.size.height - body.size.height)
              : 0.0;
          return liveKeyboardInset +
              scaffoldReduction +
              ChatComposer.keyboardExpansionOf(
                _composerGeometryKey.currentContext?.findRenderObject(),
              );
        },
        child: Column(
          children: [
            widget.header,
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      key: const ValueKey<String>(
                        'location-chat-message-viewport-clip',
                      ),
                      child: RepaintBoundary(child: widget.messageViewport),
                    ),
                  ),
                  if (widget.composerTopOverlay != null)
                    Positioned(
                      key: const ValueKey<String>(
                        'location-chat-composer-top-overlay',
                      ),
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: widget.composerTopOverlay!,
                    ),
                ],
              ),
            ),
            if (widget.composer != null)
              KeyedSubtree(key: _composerGeometryKey, child: widget.composer!),
          ],
        ),
      ),
    );
  }
}
