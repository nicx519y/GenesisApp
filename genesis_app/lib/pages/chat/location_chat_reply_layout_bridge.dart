import 'package:flutter/widgets.dart';

/// Carries one reply-height transaction through layout, without scheduling a
/// widget rebuild or a post-frame scroll. Heights are absolute so repeated
/// viewport layouts cannot apply a delta twice.
class LocationChatReplyLayoutBridge {
  double? _height;
  double _controlsHeight = 0;
  double _startControlsHeight = 0;
  bool _followControlsHeight = false;
  double? _sliverExtent;
  double? _startHeight;
  double? _startPixels;
  double? _startMaxScrollExtent;
  double? _startSliverExtent;
  int? _generation;
  ValueGetter<int>? _currentGeneration;
  ScrollPosition? _position;

  bool get isActive {
    if (_generation != null && _generation != _currentGeneration?.call()) {
      cancel();
    }
    return _startHeight != null;
  }

  void reportHeight(double height) {
    if (height.isFinite) _height = height;
  }

  void reportControlsHeight(double height) {
    if (height.isFinite) _controlsHeight = height;
  }

  void reportSliverExtent(double extent) {
    if (extent.isFinite) _sliverExtent = extent;
  }

  void begin({
    required ScrollPosition position,
    bool followControlsHeight = false,
    required int commandGeneration,
    required ValueGetter<int> currentGeneration,
  }) {
    if (isActive || _height == null) return;
    _position = position;
    _startControlsHeight = _controlsHeight;
    _followControlsHeight = followControlsHeight;
    _startHeight = _height;
    _startPixels = position.pixels;
    _startMaxScrollExtent = position.maxScrollExtent;
    _startSliverExtent = _sliverExtent;
    _generation = commandGeneration;
    _currentGeneration = currentGeneration;
  }

  double? get estimatedSliverExtent {
    if (!isActive || _startSliverExtent == null) return null;
    return (_startSliverExtent! + layoutExtentDelta).clamp(0, double.infinity);
  }

  /// Height change owned by the active card-layout transaction.
  ///
  /// A retained waiting tail uses this to keep its blank extent unchanged
  /// while cards of different heights slide through the same bottom anchor.
  double get layoutExtentDelta {
    if (!isActive) return 0;
    return _height! - _startHeight! + _controlsHeight - _startControlsHeight;
  }

  // When the original content fits the viewport, its unused space is absent
  // from maxScrollExtent. Let viewport physics clamp the target after all
  // slivers are laid out; an early sliver correction can otherwise fight the
  // viewport's zero scroll boundary indefinitely as a stream grows.
  bool get beganWithoutScrollExtent =>
      isActive &&
      _position != null &&
      _startMaxScrollExtent! <= _position!.minScrollExtent;

  double? get correction {
    if (!isActive || _position == null) return null;
    final controlsDelta = _controlsHeight - _startControlsHeight;
    final deckDelta = _height! - _startHeight!;
    final delta = deckDelta + (_followControlsHeight ? controlsDelta : 0);
    final target = (_startPixels! + delta).clamp(
      _position!.minScrollExtent,
      (_startMaxScrollExtent! + deckDelta + controlsDelta).clamp(
        _position!.minScrollExtent,
        double.infinity,
      ),
    );
    return target - _position!.pixels;
  }

  void cancel({bool clearMeasurements = false}) {
    _startHeight = null;
    _startPixels = null;
    _startMaxScrollExtent = null;
    _startSliverExtent = null;
    _generation = null;
    _currentGeneration = null;
    _position = null;
    if (clearMeasurements) {
      _height = null;
      _controlsHeight = 0;
      _sliverExtent = null;
    }
  }
}
