import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../tilemap_model.dart';

const int tilemapPrerenderMaxCachedFrames = 3;
const int tilemapPrerenderMaxKnownConfigs = 24;
const int tilemapPrerenderMaxCacheBytes = 16 * 1024 * 1024;
const int tilemapPrerenderMaxFrameBytes = 6 * 1024 * 1024;
const double tilemapPrerenderMaxPixelRatio = 2;

class TilemapPrerenderFrame {
  const TilemapPrerenderFrame({
    required this.image,
    required this.logicalSize,
    required this.environmentKey,
  });

  final ui.Image image;
  final Size logicalSize;
  final String environmentKey;

  int get estimatedByteSize => image.width * image.height * 4;
}

/// Serializes viewport-only offscreen renders and keeps a small LRU of frames.
///
/// The controller never rasterizes an entire map. Its boundary is constrained
/// to the real Tilemap viewport, while the renderer inside that boundary keeps
/// using the normal retained-scene tile culling.
class TilemapPrerenderController {
  TilemapPrerenderController({
    required VoidCallback onChanged,
    this.maxCachedFrames = tilemapPrerenderMaxCachedFrames,
    this.maxCacheBytes = tilemapPrerenderMaxCacheBytes,
    this.maxFrameBytes = tilemapPrerenderMaxFrameBytes,
  }) : assert(maxCachedFrames > 0),
       assert(maxCacheBytes > 0),
       assert(maxFrameBytes > 0),
       assert(maxFrameBytes <= maxCacheBytes),
       _onChanged = onChanged;

  final VoidCallback _onChanged;
  final int maxCachedFrames;
  final int maxCacheBytes;
  final int maxFrameBytes;

  final LinkedHashMap<String, TilemapConfig> _knownConfigs =
      LinkedHashMap<String, TilemapConfig>();
  final ListQueue<String> _pendingMapIds = ListQueue<String>();
  final Set<String> _pendingMapIdSet = <String>{};
  final Set<String> _failedMapIds = <String>{};
  final Map<String, int> _candidateCaptureFailures = <String, int>{};
  final Set<String> _activeCaptureKeys = <String>{};
  final LinkedHashMap<String, TilemapPrerenderFrame> _frames =
      LinkedHashMap<String, TilemapPrerenderFrame>();

  String _environmentKey = '';
  Size _viewportSize = Size.zero;
  double _devicePixelRatio = 1;
  String? _activeMapId;
  String? _candidateMapId;
  GlobalKey _candidateBoundaryKey = GlobalKey(
    debugLabel: 'tilemap-prerender-empty',
  );
  int _generation = 0;
  bool _capturingCandidate = false;
  bool _disposed = false;
  Future<void> _captureSerial = Future<void>.value();

  TilemapConfig? get candidateConfig {
    final mapId = _candidateMapId;
    return mapId == null ? null : _knownConfigs[mapId];
  }

  GlobalKey get candidateBoundaryKey => _candidateBoundaryKey;

  int get cachedFrameCount => _frames.length;

  int get estimatedCacheBytes => _frames.values.fold<int>(
    0,
    (total, frame) => total + frame.estimatedByteSize,
  );

  void resetSession() {
    if (_disposed) return;
    _generation += 1;
    _environmentKey = '';
    _viewportSize = Size.zero;
    _devicePixelRatio = 1;
    _activeMapId = null;
    _candidateMapId = null;
    _knownConfigs.clear();
    _pendingMapIds.clear();
    _pendingMapIdSet.clear();
    _failedMapIds.clear();
    _candidateCaptureFailures.clear();
    _activeCaptureKeys.clear();
    _clearFrames();
  }

  void clearInactiveFrames() {
    if (_disposed) return;
    final inactiveMapIds = _frames.keys
        .where((mapId) => mapId != _activeMapId)
        .toList(growable: false);
    for (final mapId in inactiveMapIds) {
      final frame = _frames.remove(mapId);
      if (frame != null) _disposeFrameAfterPaint(frame);
    }
    if (inactiveMapIds.isNotEmpty) _notifyChanged();
  }

  void handleMemoryPressure() {
    if (_disposed) return;
    final hadBackgroundWork =
        _candidateMapId != null ||
        _capturingCandidate ||
        _pendingMapIds.isNotEmpty;
    if (hadBackgroundWork) _generation += 1;
    _candidateMapId = null;
    _pendingMapIds.clear();
    _pendingMapIdSet.clear();
    _failedMapIds.clear();
    _candidateCaptureFailures.clear();
    _knownConfigs.removeWhere((mapId, _) => mapId != _activeMapId);

    final inactiveMapIds = _frames.keys
        .where((mapId) => mapId != _activeMapId)
        .toList(growable: false);
    for (final mapId in inactiveMapIds) {
      final frame = _frames.remove(mapId);
      if (frame != null) _disposeFrameAfterPaint(frame);
    }
    if (hadBackgroundWork || inactiveMapIds.isNotEmpty) _notifyChanged();
  }

  void configure({
    required String environmentKey,
    required Size viewportSize,
    required double devicePixelRatio,
    required String? activeMapId,
  }) {
    if (_disposed) return;

    final environmentChanged =
        _environmentKey != environmentKey ||
        _viewportSize != viewportSize ||
        _devicePixelRatio != devicePixelRatio;
    final previousActiveMapId = _activeMapId;
    _activeMapId = activeMapId;
    if (environmentChanged) {
      _generation += 1;
      _environmentKey = environmentKey;
      _viewportSize = viewportSize;
      _devicePixelRatio = devicePixelRatio;
      _candidateMapId = null;
      _pendingMapIds.clear();
      _pendingMapIdSet.clear();
      _failedMapIds.clear();
      _candidateCaptureFailures.clear();
      _clearFrames();
      for (final mapId in _knownConfigs.keys) {
        _enqueueMapId(mapId);
      }
    } else if (previousActiveMapId != activeMapId) {
      _enqueueMapId(previousActiveMapId);
    }

    if (_candidateMapId == activeMapId) {
      _candidateMapId = null;
      _generation += 1;
    }
    if (activeMapId != null) {
      if (_pendingMapIdSet.remove(activeMapId)) {
        _pendingMapIds.remove(activeMapId);
      }
      _touchFrame(activeMapId);
    }
    _selectNextCandidate();
  }

  void rememberConfig(TilemapConfig config) {
    if (_disposed) return;
    final previous = _knownConfigs[config.id];
    if (previous != null && !identical(previous, config)) {
      final staleFrame = _frames.remove(config.id);
      if (staleFrame != null) _disposeFrameAfterPaint(staleFrame);
      _failedMapIds.remove(config.id);
      _candidateCaptureFailures.remove(config.id);
      if (_pendingMapIdSet.remove(config.id)) {
        _pendingMapIds.remove(config.id);
      }
      if (_candidateMapId == config.id) {
        _candidateMapId = null;
        _generation += 1;
      }
    }
    _knownConfigs.remove(config.id);
    _knownConfigs[config.id] = config;
    _pruneKnownConfigs();
    _enqueueMapId(config.id);
    final hadCandidate = _candidateMapId != null;
    _selectNextCandidate();
    if (!hadCandidate && _candidateMapId != null) _notifyChanged();
  }

  void activateMap(String mapId) {
    if (_disposed) return;
    final previousActiveMapId = _activeMapId;
    _activeMapId = mapId;
    _enqueueMapId(previousActiveMapId);
    if (_pendingMapIdSet.remove(mapId)) {
      _pendingMapIds.remove(mapId);
    }
    _touchFrame(mapId);
    if (_candidateMapId == mapId) {
      _candidateMapId = null;
      _generation += 1;
    }
    _selectNextCandidate();
  }

  TilemapPrerenderFrame? frameFor(String? mapId) {
    if (_disposed || mapId == null) return null;
    final frame = _frames.remove(mapId);
    if (frame == null) return null;
    if (frame.environmentKey != _environmentKey) {
      _disposeFrameAfterPaint(frame);
      return null;
    }
    _frames[mapId] = frame;
    return frame;
  }

  void rejectCandidate({
    required String mapId,
    required GlobalKey boundaryKey,
  }) {
    if (_disposed || _capturingCandidate) return;
    if (_candidateMapId != mapId ||
        !identical(_candidateBoundaryKey, boundaryKey)) {
      return;
    }
    _candidateMapId = null;
    _failedMapIds.add(mapId);
    _selectNextCandidate();
    _notifyChanged();
  }

  Future<void> captureCandidate({
    String? expectedMapId,
    GlobalKey? expectedBoundaryKey,
  }) async {
    if (_disposed || _capturingCandidate) return;
    final mapId = _candidateMapId;
    if (mapId == null || mapId == _activeMapId) return;
    if ((expectedMapId != null && expectedMapId != mapId) ||
        (expectedBoundaryKey != null &&
            !identical(expectedBoundaryKey, _candidateBoundaryKey))) {
      return;
    }

    _capturingCandidate = true;
    final generation = _generation;
    final boundaryKey = _candidateBoundaryKey;
    await _serializeCapture(() async {
      final frame = await _captureBoundary(
        boundaryKey: boundaryKey,
        generation: generation,
      );
      if (_disposed ||
          generation != _generation ||
          mapId != _candidateMapId ||
          mapId == _activeMapId) {
        frame?.image.dispose();
        _capturingCandidate = false;
        _selectNextCandidate();
        _notifyChanged();
        return;
      }

      _capturingCandidate = false;
      _candidateMapId = null;
      if (frame == null) {
        final failures = (_candidateCaptureFailures[mapId] ?? 0) + 1;
        _candidateCaptureFailures[mapId] = failures;
        if (failures >= 2) {
          _failedMapIds.add(mapId);
        } else {
          _enqueueMapId(mapId);
        }
      } else {
        _candidateCaptureFailures.remove(mapId);
        _storeFrame(mapId, frame);
      }
      _selectNextCandidate();
      _notifyChanged();
    });
  }

  Future<void> captureActive({
    required String mapId,
    required GlobalKey boundaryKey,
  }) async {
    if (_disposed || _frames.containsKey(mapId)) return;
    final generation = _generation;
    final captureKey = '$generation|$mapId';
    if (!_activeCaptureKeys.add(captureKey)) return;
    await _serializeCapture(() async {
      try {
        if (_disposed ||
            generation != _generation ||
            _frames.containsKey(mapId)) {
          return;
        }
        final frame = await _captureBoundary(
          boundaryKey: boundaryKey,
          generation: generation,
        );
        if (_disposed ||
            generation != _generation ||
            mapId != _activeMapId ||
            frame == null) {
          frame?.image.dispose();
          return;
        }
        _storeFrame(mapId, frame);
        _notifyChanged();
      } finally {
        _activeCaptureKeys.remove(captureKey);
      }
    });
  }

  Future<void> _serializeCapture(Future<void> Function() operation) {
    final queued = _captureSerial.then<void>((_) async {
      try {
        await operation();
      } catch (_) {
        // A failed optimization must not break subsequent captures.
      }
    });
    _captureSerial = queued;
    return queued;
  }

  Future<TilemapPrerenderFrame?> _captureBoundary({
    required GlobalKey boundaryKey,
    required int generation,
  }) async {
    if (_viewportSize.isEmpty ||
        !_viewportSize.width.isFinite ||
        !_viewportSize.height.isFinite) {
      return null;
    }

    for (var attempt = 0; attempt < 2; attempt += 1) {
      await _waitForPaint();
      if (_disposed || generation != _generation) return null;
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null ||
          !boundary.attached ||
          !boundary.hasSize ||
          !_matchesViewportSize(boundary.size)) {
        continue;
      }

      try {
        final image = await boundary.toImage(
          pixelRatio: _snapshotPixelRatio(boundary.size),
        );
        if (image.width * image.height * 4 > maxFrameBytes) {
          image.dispose();
          return null;
        }
        return TilemapPrerenderFrame(
          image: image,
          logicalSize: boundary.size,
          environmentKey: _environmentKey,
        );
      } catch (_) {
        // The boundary can still be between paint and compositing. Retry once
        // on a fresh frame without consulting debug-only render flags.
      }
    }
    return null;
  }

  bool _matchesViewportSize(Size size) {
    return (size.width - _viewportSize.width).abs() <= 0.01 &&
        (size.height - _viewportSize.height).abs() <= 0.01;
  }

  Future<void> _waitForPaint() async {
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
  }

  double _snapshotPixelRatio(Size logicalSize) {
    final logicalPixels = logicalSize.width * logicalSize.height;
    if (logicalPixels <= 0 || !logicalPixels.isFinite) return 1;
    final byteLimitedRatio = math.sqrt(maxFrameBytes / (logicalPixels * 4));
    return math
        .min(
          _devicePixelRatio,
          math.min(tilemapPrerenderMaxPixelRatio, byteLimitedRatio),
        )
        .clamp(0.1, tilemapPrerenderMaxPixelRatio)
        .toDouble();
  }

  void _enqueueMapId(String? mapId) {
    if (mapId == null ||
        mapId == _activeMapId ||
        mapId == _candidateMapId ||
        _frames.containsKey(mapId) ||
        _failedMapIds.contains(mapId) ||
        !_knownConfigs.containsKey(mapId) ||
        !_pendingMapIdSet.add(mapId)) {
      return;
    }
    _pendingMapIds.addLast(mapId);
  }

  void _selectNextCandidate() {
    if (_candidateMapId != null || _capturingCandidate || _disposed) return;
    while (_pendingMapIds.isNotEmpty) {
      final mapId = _pendingMapIds.removeFirst();
      _pendingMapIdSet.remove(mapId);
      if (mapId == _activeMapId ||
          _frames.containsKey(mapId) ||
          _failedMapIds.contains(mapId) ||
          !_knownConfigs.containsKey(mapId)) {
        continue;
      }
      _candidateMapId = mapId;
      _candidateBoundaryKey = GlobalKey(debugLabel: 'tilemap-prerender-$mapId');
      return;
    }
  }

  void _pruneKnownConfigs() {
    while (_knownConfigs.length > tilemapPrerenderMaxKnownConfigs) {
      String? oldestRemovableMapId;
      for (final mapId in _knownConfigs.keys) {
        if (mapId != _activeMapId && mapId != _candidateMapId) {
          oldestRemovableMapId = mapId;
          break;
        }
      }
      if (oldestRemovableMapId == null) return;
      _knownConfigs.remove(oldestRemovableMapId);
      if (_pendingMapIdSet.remove(oldestRemovableMapId)) {
        _pendingMapIds.remove(oldestRemovableMapId);
      }
      _failedMapIds.remove(oldestRemovableMapId);
      _candidateCaptureFailures.remove(oldestRemovableMapId);
    }
  }

  void _storeFrame(String mapId, TilemapPrerenderFrame frame) {
    final previous = _frames.remove(mapId);
    if (previous != null) _disposeFrameAfterPaint(previous);
    _frames[mapId] = frame;
    _evictFramesToBudget();
  }

  void _touchFrame(String mapId) {
    final frame = _frames.remove(mapId);
    if (frame != null) _frames[mapId] = frame;
  }

  void _evictFramesToBudget() {
    while (_frames.length > maxCachedFrames ||
        estimatedCacheBytes > maxCacheBytes) {
      String? evictionMapId;
      for (final mapId in _frames.keys) {
        if (mapId != _activeMapId) {
          evictionMapId = mapId;
          break;
        }
      }
      if (evictionMapId == null) return;
      final evicted = _frames.remove(evictionMapId);
      if (evicted != null) _disposeFrameAfterPaint(evicted);
    }
  }

  void _clearFrames() {
    final frames = _frames.values.toList(growable: false);
    _frames.clear();
    for (final frame in frames) {
      _disposeFrameAfterPaint(frame);
    }
  }

  void _disposeFrameAfterPaint(TilemapPrerenderFrame frame) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frame.image.dispose();
    });
  }

  void _notifyChanged() {
    if (!_disposed) _onChanged();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    for (final frame in _frames.values) {
      frame.image.dispose();
    }
    _frames.clear();
    _knownConfigs.clear();
    _pendingMapIds.clear();
    _pendingMapIdSet.clear();
    _failedMapIds.clear();
    _candidateCaptureFailures.clear();
    _activeCaptureKeys.clear();
  }
}

class TilemapPrerenderSurface extends StatelessWidget {
  const TilemapPrerenderSurface({
    super.key,
    required this.boundaryKey,
    required this.child,
  });

  final GlobalKey boundaryKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ClipRect(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: TickerMode(
              enabled: false,
              child: RepaintBoundary(key: boundaryKey, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class TilemapPrerenderFrameView extends StatelessWidget {
  const TilemapPrerenderFrameView({super.key, required this.frame});

  final TilemapPrerenderFrame frame;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: RawImage(
        image: frame.image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}
