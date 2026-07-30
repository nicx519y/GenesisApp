import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../../world_map_location_action.dart';
import '../../world_point.dart';
import '../tilemap_model.dart';
import '../tilemap_renderer.dart';

typedef TilemapSilentMapLoader =
    Future<TilemapConfig?> Function(String locationId);
typedef TilemapPreloadImage = Future<void> Function(String assetUrl);

const int tilemapSilentPreloadMaxPendingTargets = 2;
const int tilemapSilentPreloadMaxRememberedKeys = 16;
const int tilemapBackgroundImagePreloadConcurrency = 3;

/// Owns visible-first loading and background Tilemap image preloading.
///
/// A coordinator instance represents one Tilemap session. Once the initial map
/// is revealed, [initialEntryCompleted] remains true while the user drills down
/// or returns through that Tilemap's location trail.
class TilemapLoadingCoordinator {
  TilemapLoadingCoordinator({
    required VoidCallback onChanged,
    this.onSilentMapReady,
  }) : _onChanged = onChanged;

  final VoidCallback _onChanged;
  final ValueChanged<TilemapConfig>? onSilentMapReady;

  bool _disposed = false;
  int _sessionGeneration = 0;
  int _initialLoadGeneration = 0;
  bool _initialEntryCompleted = false;
  bool _initialEntrySkipped = false;
  String? _desiredInitialLoadKey;
  String? _scheduledInitialLoadKey;
  String? _activeInitialLoadKey;
  int _loadedInitialTileCount = 0;
  int _totalInitialTileCount = 0;
  Object? _initialLoadError;

  final Map<String, Future<void>> _imageRequests = <String, Future<void>>{};
  final Set<String> _scheduledBackgroundLoadKeys = <String>{};
  final LinkedHashSet<String> _completedBackgroundLoadKeys =
      LinkedHashSet<String>();
  Future<void>? _activeBackgroundTilePreload;
  int _backgroundLoadGeneration = 0;
  final ListQueue<_TilemapSilentLoadTask> _silentLoadQueue =
      ListQueue<_TilemapSilentLoadTask>();
  final Set<String> _scheduledSilentLoadKeys = <String>{};
  final LinkedHashSet<String> _completedSilentLoadKeys =
      LinkedHashSet<String>();
  String? _silentPlanKey;
  int _silentPlanGeneration = 0;
  bool _runningSilentLoad = false;

  bool get initialEntryCompleted => _initialEntryCompleted;
  bool get initialEntrySkipped => _initialEntrySkipped;
  Object? get initialLoadError => _initialLoadError;

  double get initialProgress => tilemapImageLoadProgress(
    loadedTileCount: _loadedInitialTileCount,
    totalTileCount: _totalInitialTileCount,
  );

  void completeInitialEntryWithoutOverlay() {
    if (_disposed || _initialEntrySkipped) return;
    _initialLoadGeneration += 1;
    _initialEntryCompleted = true;
    _initialEntrySkipped = true;
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
    _initialEntrySkipped = false;
    _initialLoadError = null;
    _clearInitialLoadState();
    _imageRequests.clear();
    _scheduledBackgroundLoadKeys.clear();
    _completedBackgroundLoadKeys.clear();
    _activeBackgroundTilePreload = null;
    _backgroundLoadGeneration += 1;
    _silentLoadQueue.clear();
    _scheduledSilentLoadKeys.clear();
    _completedSilentLoadKeys.clear();
    _silentPlanKey = null;
    _silentPlanGeneration += 1;
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

    final planKey =
        '${currentConfig.id}|${displayTilePixelSize.toStringAsFixed(3)}';
    if (_silentPlanKey != planKey) {
      _silentPlanKey = planKey;
      _silentPlanGeneration += 1;
      for (final task in _silentLoadQueue) {
        _scheduledSilentLoadKeys.remove(task.loadKey);
      }
      _silentLoadQueue.clear();
    }

    final sessionGeneration = _sessionGeneration;
    final planGeneration = _silentPlanGeneration;
    for (final locationId in targetIds.take(
      tilemapSilentPreloadMaxPendingTargets,
    )) {
      final silentLoadKey = '$planKey|$locationId';
      if (_completedSilentLoadKeys.contains(silentLoadKey) ||
          !_scheduledSilentLoadKeys.add(silentLoadKey)) {
        continue;
      }
      _silentLoadQueue.addLast(
        _TilemapSilentLoadTask(
          loadKey: silentLoadKey,
          locationId: locationId,
          displayTilePixelSize: displayTilePixelSize,
          loadMap: loadMap,
          loadImage: loadImage,
          sessionGeneration: sessionGeneration,
          planGeneration: planGeneration,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drainSilentLoadQueue());
    });
  }

  void scheduleBackgroundTilePreload({
    required TilemapConfig config,
    required TilemapImageLoadPlan plan,
    required TilemapPreloadImage loadImage,
  }) {
    if (_disposed ||
        !_initialEntryCompleted ||
        plan.backgroundTileCountByAsset.isEmpty) {
      return;
    }

    final loadKey = _backgroundImageLoadKey(config, plan);
    if (_completedBackgroundLoadKeys.contains(loadKey) ||
        !_scheduledBackgroundLoadKeys.add(loadKey)) {
      return;
    }

    final backgroundLoadGeneration = ++_backgroundLoadGeneration;
    late Future<void> request;
    request =
        _loadBackgroundTiles(
          assetUrls: plan.backgroundTileCountByAsset.keys,
          loadImage: loadImage,
          sessionGeneration: _sessionGeneration,
          backgroundLoadGeneration: backgroundLoadGeneration,
          loadKey: loadKey,
        ).whenComplete(() {
          if (identical(_activeBackgroundTilePreload, request)) {
            _activeBackgroundTilePreload = null;
          }
        });
    _activeBackgroundTilePreload = request;
    unawaited(request);
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
    _initialEntrySkipped = false;
    _activeInitialLoadKey = null;
    _notifyChanged();
  }

  Future<void> _preloadLocation({
    required String locationId,
    required double displayTilePixelSize,
    required TilemapSilentMapLoader loadMap,
    required TilemapPreloadImage loadImage,
    required int sessionGeneration,
    required int planGeneration,
  }) async {
    try {
      final config = await loadMap(locationId);
      if (config == null ||
          !_isSilentPlanCurrent(
            sessionGeneration: sessionGeneration,
            planGeneration: planGeneration,
          )) {
        return;
      }

      final plan = TilemapImageLoadPlan.forConfig(
        config: config,
        displayTilePixelSize: displayTilePixelSize,
      );
      await _loadImagesWithConcurrency(
        assetUrls: plan.tileCountByAsset.keys,
        loadImage: loadImage,
        shouldContinue: () => _isSilentPlanCurrent(
          sessionGeneration: sessionGeneration,
          planGeneration: planGeneration,
        ),
      );
      if (_isSilentPlanCurrent(
        sessionGeneration: sessionGeneration,
        planGeneration: planGeneration,
      )) {
        onSilentMapReady?.call(config);
      }
    } catch (_) {
      // Silent preloading is an optimization. Interactive navigation remains
      // responsible for presenting any real map or image failure.
    }
  }

  Future<void> _loadBackgroundTiles({
    required Iterable<String> assetUrls,
    required TilemapPreloadImage loadImage,
    required int sessionGeneration,
    required int backgroundLoadGeneration,
    required String loadKey,
  }) async {
    var completed = false;
    try {
      await _loadImagesWithConcurrency(
        assetUrls: assetUrls,
        loadImage: loadImage,
        shouldContinue: () =>
            _isSessionCurrent(sessionGeneration) &&
            backgroundLoadGeneration == _backgroundLoadGeneration,
      );
      completed =
          _isSessionCurrent(sessionGeneration) &&
          backgroundLoadGeneration == _backgroundLoadGeneration;
    } catch (_) {
      // Background images are an optimization. A later viewport can retry the
      // same asset through the normal renderer request path.
    } finally {
      if (_isSessionCurrent(sessionGeneration)) {
        _scheduledBackgroundLoadKeys.remove(loadKey);
        if (completed) {
          _rememberCompletedBackgroundLoadKey(loadKey);
        }
      }
    }
  }

  Future<void> _drainSilentLoadQueue() async {
    if (_disposed || _runningSilentLoad) return;
    _runningSilentLoad = true;
    try {
      while (!_disposed && _silentLoadQueue.isNotEmpty) {
        final task = _silentLoadQueue.removeFirst();
        if (!_isSilentPlanCurrent(
          sessionGeneration: task.sessionGeneration,
          planGeneration: task.planGeneration,
        )) {
          _scheduledSilentLoadKeys.remove(task.loadKey);
          continue;
        }
        while (_activeBackgroundTilePreload != null) {
          await _activeBackgroundTilePreload;
        }
        await _preloadLocation(
          locationId: task.locationId,
          displayTilePixelSize: task.displayTilePixelSize,
          loadMap: task.loadMap,
          loadImage: task.loadImage,
          sessionGeneration: task.sessionGeneration,
          planGeneration: task.planGeneration,
        );
        _scheduledSilentLoadKeys.remove(task.loadKey);
        _rememberCompletedSilentLoadKey(task.loadKey);
      }
    } finally {
      _runningSilentLoad = false;
    }
  }

  Future<void> _loadImagesWithConcurrency({
    required Iterable<String> assetUrls,
    required TilemapPreloadImage loadImage,
    required bool Function() shouldContinue,
  }) async {
    final pendingAssets = assetUrls.toList(growable: false);
    var nextAssetIndex = 0;

    Future<void> worker() async {
      while (shouldContinue() && nextAssetIndex < pendingAssets.length) {
        final assetUrl = pendingAssets[nextAssetIndex];
        nextAssetIndex += 1;
        await _loadImageOnce(assetUrl, loadImage);
      }
    }

    final workerCount = pendingAssets.length.clamp(
      0,
      tilemapBackgroundImagePreloadConcurrency,
    );
    await Future.wait<void>([
      for (var index = 0; index < workerCount; index += 1) worker(),
    ]);
  }

  Future<void> _loadImageOnce(String assetUrl, TilemapPreloadImage loadImage) {
    final existing = _imageRequests[assetUrl];
    if (existing != null) return existing;

    late Future<void> request;
    request = Future<void>.sync(() => loadImage(assetUrl)).whenComplete(() {
      if (identical(_imageRequests[assetUrl], request)) {
        _imageRequests.remove(assetUrl);
      }
    });
    _imageRequests[assetUrl] = request;
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

  bool _isSilentPlanCurrent({
    required int sessionGeneration,
    required int planGeneration,
  }) {
    return _isSessionCurrent(sessionGeneration) &&
        planGeneration == _silentPlanGeneration;
  }

  void _rememberCompletedSilentLoadKey(String loadKey) {
    _completedSilentLoadKeys.remove(loadKey);
    _completedSilentLoadKeys.add(loadKey);
    while (_completedSilentLoadKeys.length >
        tilemapSilentPreloadMaxRememberedKeys) {
      _completedSilentLoadKeys.remove(_completedSilentLoadKeys.first);
    }
  }

  void _rememberCompletedBackgroundLoadKey(String loadKey) {
    _completedBackgroundLoadKeys.remove(loadKey);
    _completedBackgroundLoadKeys.add(loadKey);
    while (_completedBackgroundLoadKeys.length >
        tilemapSilentPreloadMaxRememberedKeys) {
      _completedBackgroundLoadKeys.remove(_completedBackgroundLoadKeys.first);
    }
  }

  String _imageLoadKey(TilemapConfig config, TilemapImageLoadPlan plan) {
    return '${config.id}|${plan.tileCountByAsset.keys.join('\u0000')}';
  }

  String _backgroundImageLoadKey(
    TilemapConfig config,
    TilemapImageLoadPlan plan,
  ) {
    return '${config.id}|background|'
        '${plan.backgroundTileCountByAsset.keys.join('\u0000')}';
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
    _silentPlanGeneration += 1;
    _backgroundLoadGeneration += 1;
    _imageRequests.clear();
    _scheduledBackgroundLoadKeys.clear();
    _completedBackgroundLoadKeys.clear();
    _activeBackgroundTilePreload = null;
    _silentLoadQueue.clear();
    _scheduledSilentLoadKeys.clear();
    _completedSilentLoadKeys.clear();
  }
}

class _TilemapSilentLoadTask {
  const _TilemapSilentLoadTask({
    required this.loadKey,
    required this.locationId,
    required this.displayTilePixelSize,
    required this.loadMap,
    required this.loadImage,
    required this.sessionGeneration,
    required this.planGeneration,
  });

  final String loadKey;
  final String locationId;
  final double displayTilePixelSize;
  final TilemapSilentMapLoader loadMap;
  final TilemapPreloadImage loadImage;
  final int sessionGeneration;
  final int planGeneration;
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
