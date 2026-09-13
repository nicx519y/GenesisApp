import 'package:flutter/widgets.dart';

/// Carries one reply-height transaction through layout, without scheduling a
/// widget rebuild or a post-frame scroll. Heights are absolute so repeated
/// viewport layouts cannot apply a delta twice.
class LocationChatReplyLayoutBridge {
  double? _height;
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

  void reportSliverExtent(double extent) {
    if (extent.isFinite) _sliverExtent = extent;
  }

  void begin({
    required ScrollPosition position,
    required int commandGeneration,
    required ValueGetter<int> currentGeneration,
  }) {
    if (isActive || _height == null) return;
    _position = position;
    _startHeight = _height;
    _startPixels = position.pixels;
    _startMaxScrollExtent = position.maxScrollExtent;
    _startSliverExtent = _sliverExtent;
    _generation = commandGeneration;
    _currentGeneration = currentGeneration;
  }

  double? get estimatedSliverExtent {
    if (!isActive || _startSliverExtent == null) return null;
    return (_startSliverExtent! + _height! - _startHeight!).clamp(
      0,
      double.infinity,
    );
  }

  double? get correction {
    if (!isActive || _position == null) return null;
    final delta = _height! - _startHeight!;
    final target = (_startPixels! + delta).clamp(
      _position!.minScrollExtent,
      (_startMaxScrollExtent! + delta).clamp(
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
      _sliverExtent = null;
    }
  }
}
