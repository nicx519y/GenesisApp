import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../world_map_location_action.dart';
import '../../world_point.dart';
import '../tilemap_model.dart';
import '../tilemap_renderer.dart';

typedef TilemapSilentMapLoader =
    Future<TilemapConfig?> Function(String locationId);
typedef TilemapPreloadImage = Future<void> Function(String assetUrl);

/// Owns the one-time foreground loading gate and one-level-ahead tile preload.
///
/// A coordinator instance represents one Tilemap session. Once the initial map
/// is revealed, [initialEntryCompleted] remains true while the user drills down
/// or returns through that Tilemap's location trail.
class TilemapLoadingCoordinator {
  TilemapLoadingCoordinator({required VoidCallback onChanged})
    : _onChanged = onChanged;

  final VoidCallback _onChanged;

  bool _disposed = false;
  int _sessionGeneration = 0;
  int _initialLoadGeneration = 0;
  bool _initialEntryCompleted = false;
  String? _desiredInitialLoadKey;
  String? _scheduledInitialLoadKey;
  String? _activeInitialLoadKey;
  int _loadedInitialTileCount = 0;
  int _totalInitialTileCount = 0;
  Object? _initialLoadError;

  final Map<String, Future<void>> _imageRequests = <String, Future<void>>{};
  final Set<String> _scheduledSilentLoadKeys = <String>{};

  bool get initialEntryCompleted => _initialEntryCompleted;
  Object? get initialLoadError => _initialLoadError;

  double get initialProgress => tilemapImageLoadProgress(
    loadedTileCount: _loadedInitialTileCount,
    totalTileCount: _totalInitialTileCount,
  );

  void completeInitialEntryWithoutOverlay() {
    if (_disposed || _initialEntryCompleted) return;
    _initialLoadGeneration += 1;
    _initialEntryCompleted = true;
    _initialLoadError = null;
    _clearInitialLoadState();
  }

  /// Keeps the same Tilemap session but redirects an unfinished first entry.
  void retargetInitialEntry() {
    if (_disposed || _initialEntryCompleted) return;
    _initialLoadGeneration += 1;
    _initialLoadError = null;
    _clearInitialLoadState();
  }

  void invalidateInitialTilePlan() {
    if (_disposed || _initialEntryCompleted) return;
    _initialLoadGeneration += 1;
    _initialLoadError = null;
    _clearInitialLoadState();
  }

  void retryInitialTileLoad() {
    if (_disposed || _initialEntryCompleted) return;
    _initialLoadGeneration += 1;
    _initialLoadError = null;
    _clearInitialLoadState();
    _notifyChanged();
  }

  void resetSession() {
    if (_disposed) return;
    _sessionGeneration += 1;
    _initialLoadGeneration += 1;
    _initialEntryCompleted = false;
    _initialLoadError = null;
    _clearInitialLoadState();
    _imageRequests.clear();
    _scheduledSilentLoadKeys.clear();
  }

  void ensureInitialMapReady({
    required TilemapConfig config,
    required TilemapImageLoadPlan plan,
    required TilemapPreloadImage loadImage,
  }) {
    if (_disposed || _initialEntryCompleted || _initialLoadError != null) {
      return;
    }

    final loadKey = _imageLoadKey(config, plan);
    if (_desiredInitialLoadKey != loadKey) {
      _initialLoadGeneration += 1;
      _desiredInitialLoadKey = loadKey;
      _scheduledInitialLoadKey = null;
      _activeInitialLoadKey = null;
      _loadedInitialTileCount = 0;
      _totalInitialTileCount = 0;
    }
    if (_activeInitialLoadKey == loadKey ||
        _scheduledInitialLoadKey == loadKey) {
      return;
    }

    _scheduledInitialLoadKey = loadKey;
    final sessionGeneration = _sessionGeneration;
    final loadGeneration = _initialLoadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isScheduledInitialLoadCurrent(
        sessionGeneration: sessionGeneration,
        loadGeneration: loadGeneration,
        loadKey: loadKey,
      )) {
        return;
      }
      _activeInitialLoadKey = loadKey;
      _scheduledInitialLoadKey = null;
      unawaited(
        _loadInitialMapTiles(
          config: config,
          plan: plan,
          loadImage: loadImage,
          sessionGeneration: sessionGeneration,
          loadGeneration: loadGeneration,
          loadKey: loadKey,
        ),
      );
    });
  }

  void scheduleSilentDrillDownPreload({
    required TilemapConfig currentConfig,
    required List<WorldMapLocationNode> locationNodes,
    required double displayTilePixelSize,
    required TilemapSilentMapLoader loadMap,
    required TilemapPreloadImage loadImage,
  }) {
    if (_disposed || !_initialEntryCompleted) return;

    final targetIds = tilemapDrillTargetLocationIds(
      config: currentConfig,
      locationNodes: locationNodes,
    );
    if (targetIds.isEmpty) return;

    final sessionGeneration = _sessionGeneration;
    for (final locationId in targetIds) {
      final silentLoadKey =
          '${currentConfig.id}|$locationId|'
          '${displayTilePixelSize.toStringAsFixed(3)}';
      if (!_scheduledSilentLoadKeys.add(silentLoadKey)) continue;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isSessionCurrent(sessionGeneration)) return;
        unawaited(
          _preloadLocation(
            locationId: locationId,
            silentLoadKey: silentLoadKey,
            displayTilePixelSize: displayTilePixelSize,
            loadMap: loadMap,
            loadImage: loadImage,
            sessionGeneration: sessionGeneration,
          ),
        );
      });
    }
  }

  Future<void> _loadInitialMapTiles({
    required TilemapConfig config,
    required TilemapImageLoadPlan plan,
    required TilemapPreloadImage loadImage,
    required int sessionGeneration,
    required int loadGeneration,
    required String loadKey,
  }) async {
    if (!_isScheduledInitialLoadCurrent(
      sessionGeneration: sessionGeneration,
      loadGeneration: loadGeneration,
      loadKey: loadKey,
    )) {
      return;
    }

    _activeInitialLoadKey = loadKey;
    _loadedInitialTileCount = 0;
    _totalInitialTileCount = plan.totalTileCount;
    _notifyChanged();

    Object? firstError;
    await Future.wait<void>([
      for (final entry in plan.tileCountByAsset.entries)
        () async {
          try {
            await _loadImageOnce(entry.key, loadImage);
          } catch (error) {
            if (_isActiveInitialLoadCurrent(
                  sessionGeneration: sessionGeneration,
                  loadGeneration: loadGeneration,
                  loadKey: loadKey,
                ) &&
                firstError == null) {
              firstError = error;
              _initialLoadError = error;
              _notifyChanged();
            }
            return;
          }
          if (!_isActiveInitialLoadCurrent(
                sessionGeneration: sessionGeneration,
                loadGeneration: loadGeneration,
                loadKey: loadKey,
              ) ||
              firstError != null) {
            return;
          }
          _loadedInitialTileCount = (_loadedInitialTileCount + entry.value)
              .clamp(0, _totalInitialTileCount);
          _notifyChanged();
        }(),
    ]);

    if (firstError != null ||
        !_isActiveInitialLoadCurrent(
          sessionGeneration: sessionGeneration,
          loadGeneration: loadGeneration,
          loadKey: loadKey,
        )) {
      return;
    }

    _loadedInitialTileCount = _totalInitialTileCount;
    _initialEntryCompleted = true;
    _activeInitialLoadKey = null;
    _notifyChanged();
  }

  Future<void> _preloadLocation({
    required String locationId,
    required String silentLoadKey,
    required double displayTilePixelSize,
    required TilemapSilentMapLoader loadMap,
    required TilemapPreloadImage loadImage,
    required int sessionGeneration,
  }) async {
    var succeeded = false;
    try {
      final config = await loadMap(locationId);
      if (config == null || !_isSessionCurrent(sessionGeneration)) return;

      final plan = TilemapImageLoadPlan.forConfig(
        config: config,
        displayTilePixelSize: displayTilePixelSize,
      );
      await Future.wait<void>([
        for (final assetUrl in plan.tileCountByAsset.keys)
          _loadImageOnce(assetUrl, loadImage),
      ]);
      succeeded = _isSessionCurrent(sessionGeneration);
    } catch (_) {
      // Silent preloading is an optimization. Interactive navigation remains
      // responsible for presenting any real map or image failure.
    } finally {
      if (!succeeded && _isSessionCurrent(sessionGeneration)) {
        _scheduledSilentLoadKeys.remove(silentLoadKey);
      }
    }
  }

  Future<void> _loadImageOnce(String assetUrl, TilemapPreloadImage loadImage) {
    final existing = _imageRequests[assetUrl];
    if (existing != null) return existing;

    final completer = Completer<void>();
    final request = completer.future;
    _imageRequests[assetUrl] = request;
    Future<void>.sync(() => loadImage(assetUrl)).then(
      completer.complete,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_imageRequests[assetUrl], request)) {
          _imageRequests.remove(assetUrl);
        }
        completer.completeError(error, stackTrace);
      },
    );
    return request;
  }

  bool _isScheduledInitialLoadCurrent({
    required int sessionGeneration,
    required int loadGeneration,
    required String loadKey,
  }) {
    return !_disposed &&
        !_initialEntryCompleted &&
        _initialLoadError == null &&
        sessionGeneration == _sessionGeneration &&
        loadGeneration == _initialLoadGeneration &&
        _desiredInitialLoadKey == loadKey &&
        (_scheduledInitialLoadKey == loadKey ||
            _activeInitialLoadKey == loadKey);
  }

  bool _isActiveInitialLoadCurrent({
    required int sessionGeneration,
    required int loadGeneration,
    required String loadKey,
  }) {
    return _isScheduledInitialLoadCurrent(
          sessionGeneration: sessionGeneration,
          loadGeneration: loadGeneration,
          loadKey: loadKey,
        ) &&
        _activeInitialLoadKey == loadKey;
  }

  bool _isSessionCurrent(int generation) {
    return !_disposed && generation == _sessionGeneration;
  }

  String _imageLoadKey(TilemapConfig config, TilemapImageLoadPlan plan) {
    return '${config.id}|${plan.tileCountByAsset.keys.join('\u0000')}';
  }

  void _clearInitialLoadState() {
    _desiredInitialLoadKey = null;
    _scheduledInitialLoadKey = null;
    _activeInitialLoadKey = null;
    _loadedInitialTileCount = 0;
    _totalInitialTileCount = 0;
  }

  void _notifyChanged() {
    if (!_disposed) _onChanged();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessionGeneration += 1;
    _initialLoadGeneration += 1;
    _imageRequests.clear();
    _scheduledSilentLoadKeys.clear();
  }
}

Set<String> tilemapDrillTargetLocationIds({
  required TilemapConfig config,
  required List<WorldMapLocationNode> locationNodes,
}) {
  final locationIds = <String>{};
  for (final tile in config.tiles) {
    final tileLocationId = tile.locationId?.trim() ?? '';
    if (tileLocationId.isEmpty) continue;

    final node = findWorldMapLocationNode(locationNodes, tileLocationId);
    if (node == null) continue;

    final targetId =
        resolveWorldMapLocationAction(node).drillTarget?.id.trim() ?? '';
    if (targetId.isNotEmpty) locationIds.add(targetId);
  }
  return Set<String>.unmodifiable(locationIds);
}
