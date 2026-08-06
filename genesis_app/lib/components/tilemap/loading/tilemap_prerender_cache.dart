import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../tilemap_model.dart';

const int tilemapPrerenderMaxWarmInstances = 3;
const int tilemapPrerenderMaxResidentInstances =
    tilemapPrerenderMaxWarmInstances + 1;
const int tilemapPrerenderMaxKnownConfigs = 8;
const int tilemapPrerenderMaxPendingTargets = 3;

/// Keeps a bounded pool of mounted, viewport-sized Tilemap renderer instances.
///
/// The controller stores no raster snapshots. A resident map is rendered by a
/// stable widget subtree in the Tilemap's real viewport, so promoting a warm
/// map only changes paint order and interaction state.
class TilemapPrerenderController {
  TilemapPrerenderController({
    required VoidCallback onChanged,
    this.maxWarmInstances = tilemapPrerenderMaxWarmInstances,
    this.maxKnownConfigs = tilemapPrerenderMaxKnownConfigs,
    this.maxPendingTargets = tilemapPrerenderMaxPendingTargets,
    bool warmupSuspended = false,
  }) : assert(maxWarmInstances > 0),
       assert(maxKnownConfigs >= maxWarmInstances + 1),
       assert(maxPendingTargets > 0),
       _warmupSuspended = warmupSuspended,
       _onChanged = onChanged;

  final VoidCallback _onChanged;
  final int maxWarmInstances;
  final int maxKnownConfigs;
  final int maxPendingTargets;

  final LinkedHashMap<String, TilemapConfig> _knownConfigs =
      LinkedHashMap<String, TilemapConfig>();
  final LinkedHashSet<String> _residentMapIds = LinkedHashSet<String>();
  final Set<String> _readyMapIds = <String>{};
  final Set<String> _failedMapIds = <String>{};
  final ListQueue<String> _pendingMapIds = ListQueue<String>();
  final Set<String> _pendingMapIdSet = <String>{};
  final List<String> _preferredMapIds = <String>[];
  final Set<String> _protectedMapIds = <String>{};

  String _environmentKey = '';
  String? _activeMapId;
  String? _warmingMapId;
  bool _warmupSuspended;
  bool _disposed = false;

  int get maxResidentInstances => maxWarmInstances + 1;

  int get residentInstanceCount => _residentMapIds.length;

  int get readyInstanceCount => _readyMapIds.length;

  String? get activeMapId => _activeMapId;

  String? get warmingMapId => _warmingMapId;

  bool get warmupSuspended => _warmupSuspended;

  List<String> get residentMapIds => List<String>.unmodifiable(_residentMapIds);

  List<String> get pendingMapIds => List<String>.unmodifiable(_pendingMapIds);

  List<TilemapConfig> get residentConfigs => List<TilemapConfig>.unmodifiable(
    _residentMapIds.map((mapId) => _knownConfigs[mapId]).whereType(),
  );

  bool isResident(String? mapId) =>
      mapId != null && _residentMapIds.contains(mapId);

  bool isReady(String? mapId) =>
      mapId != null &&
      _residentMapIds.contains(mapId) &&
      _readyMapIds.contains(mapId);

  /// Keeps existing warm residents mounted, but defers mounting the next
  /// non-foreground renderer until warmup resumes.
  void setWarmupSuspended(bool suspended) {
    if (_disposed || _warmupSuspended == suspended) return;
    _warmupSuspended = suspended;
    if (!suspended) {
      _selectNextWarmingMap();
    }
  }

  void resetSession() {
    if (_disposed) return;
    _environmentKey = '';
    _activeMapId = null;
    _warmingMapId = null;
    _knownConfigs.clear();
    _residentMapIds.clear();
    _readyMapIds.clear();
    _failedMapIds.clear();
    _pendingMapIds.clear();
    _pendingMapIdSet.clear();
    _preferredMapIds.clear();
    _protectedMapIds.clear();
  }

  void configure({
    required String environmentKey,
    required String? activeMapId,
    Iterable<String> protectedMapIds = const <String>[],
    Iterable<String> preferredMapIds = const <String>[],
  }) {
    if (_disposed) return;

    _activeMapId = activeMapId;
    _protectedMapIds
      ..clear()
      ..addAll(
        protectedMapIds.where(
          (mapId) => mapId.isNotEmpty && mapId != activeMapId,
        ),
      );
    _preferredMapIds
      ..clear()
      ..addAll(
        preferredMapIds.where(
          (mapId) => mapId.isNotEmpty && mapId != activeMapId,
        ),
      );

    final environmentChanged = _environmentKey != environmentKey;
    _environmentKey = environmentKey;
    if (environmentChanged) {
      _readyMapIds.clear();
      _failedMapIds.clear();
      _warmingMapId = null;
      _clearPending();
      _residentMapIds.removeWhere(
        (mapId) => mapId != _activeMapId && !_protectedMapIds.contains(mapId),
      );
    }

    _retainDesiredResidents();
    _ensureRequiredResidents();
    _pruneResidentsToBudget();
    _selectNextWarmingMap();
  }

  void rememberConfig(TilemapConfig config) {
    if (_disposed) return;
    final previous = _knownConfigs.remove(config.id);
    _knownConfigs[config.id] = config;
    if (previous != null && !identical(previous, config)) {
      _readyMapIds.remove(config.id);
      _failedMapIds.remove(config.id);
      if (_residentMapIds.contains(config.id)) {
        _warmingMapId ??= config.id;
      }
    }
    _pruneKnownConfigs();
    _refillPending();
    _selectNextWarmingMap();
    _notifyChanged();
  }

  /// Makes [config] the desired foreground map while preserving any outgoing
  /// map IDs supplied in [protectedMapIds].
  ///
  /// Returns true when the exact mounted instance is already ready and can be
  /// promoted in the same state update.
  bool activateMap(
    TilemapConfig config, {
    Iterable<String> protectedMapIds = const <String>[],
    Iterable<String> preferredMapIds = const <String>[],
  }) {
    if (_disposed) return false;

    final previous = _knownConfigs.remove(config.id);
    _knownConfigs[config.id] = config;
    if (previous != null && !identical(previous, config)) {
      _readyMapIds.remove(config.id);
      _failedMapIds.remove(config.id);
    }

    _activeMapId = config.id;
    _protectedMapIds
      ..clear()
      ..addAll(
        protectedMapIds.where(
          (mapId) => mapId.isNotEmpty && mapId != config.id,
        ),
      );
    _preferredMapIds
      ..clear()
      ..addAll(
        preferredMapIds.where(
          (mapId) => mapId.isNotEmpty && mapId != config.id,
        ),
      );

    _retainDesiredResidents();
    final previousWarmingMapId = _warmingMapId;
    if (previousWarmingMapId != null &&
        previousWarmingMapId != config.id &&
        !_readyMapIds.contains(previousWarmingMapId) &&
        !_protectedMapIds.contains(previousWarmingMapId)) {
      _residentMapIds.remove(previousWarmingMapId);
      _enqueueMapId(previousWarmingMapId);
      _warmingMapId = null;
    }

    _ensureResident(config.id, required: true);
    for (final mapId in _protectedMapIds) {
      _ensureResident(mapId, required: true);
    }
    _touchResident(config.id);
    _pruneResidentsToBudget();

    if (!_readyMapIds.contains(config.id)) {
      _warmingMapId = config.id;
    } else {
      _selectNextWarmingMap();
    }
    _pruneKnownConfigs();
    return isReady(config.id);
  }

  bool markReady(String mapId) {
    if (_disposed || !_residentMapIds.contains(mapId)) return false;
    final changed = _readyMapIds.add(mapId);
    _failedMapIds.remove(mapId);
    _touchResident(mapId);
    if (_warmingMapId == mapId) {
      _warmingMapId = null;
    }
    _selectNextWarmingMap();
    if (changed) _notifyChanged();
    return changed;
  }

  void invalidateMap(String mapId) {
    if (_disposed) return;
    final wasReady = _readyMapIds.remove(mapId);
    _failedMapIds.remove(mapId);
    if (_residentMapIds.contains(mapId)) {
      if (mapId == _activeMapId || _protectedMapIds.contains(mapId)) {
        _warmingMapId = mapId;
      } else {
        _residentMapIds.remove(mapId);
        if (_warmingMapId == mapId) _warmingMapId = null;
        _enqueueMapId(mapId);
      }
    }
    _selectNextWarmingMap();
    if (wasReady) _notifyChanged();
  }

  /// Drops cached configs and renderer state outside the refreshed preload
  /// plan. The active and transition-protected maps are always retained.
  void retainKnownMapIds(Iterable<String> mapIds) {
    if (_disposed) return;
    final retainedMapIds = <String>{
      ...mapIds.map((mapId) => mapId.trim()).where((mapId) => mapId.isNotEmpty),
      if (_activeMapId case final mapId?) mapId,
      ..._protectedMapIds,
    };
    final removedMapIds = _knownConfigs.keys
        .where((mapId) => !retainedMapIds.contains(mapId))
        .toList(growable: false);
    if (removedMapIds.isEmpty) return;

    for (final mapId in removedMapIds) {
      _knownConfigs.remove(mapId);
      _residentMapIds.remove(mapId);
      _readyMapIds.remove(mapId);
      _failedMapIds.remove(mapId);
      _pendingMapIdSet.remove(mapId);
      _pendingMapIds.remove(mapId);
      _preferredMapIds.remove(mapId);
      if (_warmingMapId == mapId) _warmingMapId = null;
    }
    _selectNextWarmingMap();
    _notifyChanged();
  }

  void rejectMap(String mapId) {
    if (_disposed) return;
    _failedMapIds.add(mapId);
    _readyMapIds.remove(mapId);
    if (_warmingMapId == mapId) _warmingMapId = null;
    if (mapId != _activeMapId && !_protectedMapIds.contains(mapId)) {
      _residentMapIds.remove(mapId);
    }
    if (_pendingMapIdSet.remove(mapId)) {
      _pendingMapIds.remove(mapId);
    }
    _selectNextWarmingMap();
    _notifyChanged();
  }

  void handleMemoryPressure() {
    if (_disposed) return;
    final retainedMapIds = <String>{
      if (_activeMapId case final mapId?) mapId,
      ..._protectedMapIds,
    };
    final changed =
        _residentMapIds.any((mapId) => !retainedMapIds.contains(mapId)) ||
        _pendingMapIds.isNotEmpty;
    _residentMapIds.removeWhere((mapId) => !retainedMapIds.contains(mapId));
    _readyMapIds.removeWhere((mapId) => !_residentMapIds.contains(mapId));
    _knownConfigs.removeWhere((mapId, _) => !retainedMapIds.contains(mapId));
    _failedMapIds.clear();
    _clearPending();
    if (_warmingMapId != null && !_residentMapIds.contains(_warmingMapId)) {
      _warmingMapId = null;
    }
    if (changed) _notifyChanged();
  }

  void _ensureRequiredResidents() {
    final activeMapId = _activeMapId;
    if (activeMapId != null) {
      _ensureResident(activeMapId, required: true);
      if (!_readyMapIds.contains(activeMapId)) {
        _warmingMapId = activeMapId;
      }
    }
    for (final mapId in _protectedMapIds) {
      _ensureResident(mapId, required: true);
    }
  }

  void _ensureResident(String mapId, {required bool required}) {
    if (!_knownConfigs.containsKey(mapId)) return;
    if (_residentMapIds.contains(mapId)) {
      if (required) _touchResident(mapId);
      return;
    }
    if (required && _residentMapIds.length >= maxResidentInstances) {
      _evictOneResident(
        excluding: <String>{
          mapId,
          if (_activeMapId case final activeMapId?) activeMapId,
          ..._protectedMapIds,
        },
      );
    }
    if (_residentMapIds.length < maxResidentInstances) {
      _residentMapIds.add(mapId);
      if (_pendingMapIdSet.remove(mapId)) {
        _pendingMapIds.remove(mapId);
      }
    }
  }

  void _selectNextWarmingMap() {
    if (_disposed || _warmingMapId != null) return;

    final activeMapId = _activeMapId;
    if (activeMapId != null &&
        _residentMapIds.contains(activeMapId) &&
        !_readyMapIds.contains(activeMapId) &&
        !_failedMapIds.contains(activeMapId)) {
      _warmingMapId = activeMapId;
      return;
    }

    if (_warmupSuspended) return;

    _refillPending();
    while (_pendingMapIds.isNotEmpty &&
        _residentMapIds.length < maxResidentInstances) {
      final mapId = _pendingMapIds.removeFirst();
      _pendingMapIdSet.remove(mapId);
      if (!_knownConfigs.containsKey(mapId) ||
          _residentMapIds.contains(mapId) ||
          _failedMapIds.contains(mapId)) {
        continue;
      }
      _residentMapIds.add(mapId);
      _warmingMapId = mapId;
      return;
    }
  }

  void _refillPending() {
    if (_disposed || _pendingMapIds.length >= maxPendingTargets) return;
    for (final mapId in _preferredMapIds) {
      if (_pendingMapIds.length >= maxPendingTargets) return;
      _enqueueMapId(mapId);
    }
  }

  void _retainDesiredResidents() {
    final desiredMapIds = <String>{
      if (_activeMapId case final mapId?) mapId,
      ..._protectedMapIds,
      ..._preferredMapIds,
    };
    for (final mapId in _residentMapIds.toList(growable: false)) {
      if (desiredMapIds.contains(mapId)) continue;
      _residentMapIds.remove(mapId);
      _readyMapIds.remove(mapId);
      if (_warmingMapId == mapId) _warmingMapId = null;
    }
    for (final mapId in _pendingMapIds.toList(growable: false)) {
      if (_preferredMapIds.contains(mapId)) continue;
      _pendingMapIds.remove(mapId);
      _pendingMapIdSet.remove(mapId);
    }
  }

  void _enqueueMapId(String mapId) {
    if (mapId == _activeMapId ||
        _protectedMapIds.contains(mapId) ||
        !_knownConfigs.containsKey(mapId) ||
        _residentMapIds.contains(mapId) ||
        _failedMapIds.contains(mapId) ||
        !_pendingMapIdSet.add(mapId)) {
      return;
    }
    if (_pendingMapIds.length >= maxPendingTargets) {
      _pendingMapIdSet.remove(mapId);
      return;
    }
    _pendingMapIds.addLast(mapId);
  }

  void _pruneResidentsToBudget() {
    while (_residentMapIds.length > maxResidentInstances) {
      if (!_evictOneResident(
        excluding: <String>{
          if (_activeMapId case final activeMapId?) activeMapId,
          ..._protectedMapIds,
        },
      )) {
        return;
      }
    }
    _readyMapIds.removeWhere((mapId) => !_residentMapIds.contains(mapId));
  }

  bool _evictOneResident({required Set<String> excluding}) {
    for (final mapId in _residentMapIds.toList(growable: false)) {
      if (excluding.contains(mapId)) continue;
      _residentMapIds.remove(mapId);
      _readyMapIds.remove(mapId);
      if (_warmingMapId == mapId) _warmingMapId = null;
      return true;
    }
    return false;
  }

  void _touchResident(String mapId) {
    if (_residentMapIds.remove(mapId)) {
      _residentMapIds.add(mapId);
    }
  }

  void _pruneKnownConfigs() {
    while (_knownConfigs.length > maxKnownConfigs) {
      String? evictionMapId;
      for (final mapId in _knownConfigs.keys) {
        if (!_residentMapIds.contains(mapId) &&
            mapId != _activeMapId &&
            !_protectedMapIds.contains(mapId)) {
          evictionMapId = mapId;
          break;
        }
      }
      if (evictionMapId == null) return;
      _knownConfigs.remove(evictionMapId);
      _failedMapIds.remove(evictionMapId);
      if (_pendingMapIdSet.remove(evictionMapId)) {
        _pendingMapIds.remove(evictionMapId);
      }
    }
  }

  void _clearPending() {
    _pendingMapIds.clear();
    _pendingMapIdSet.clear();
  }

  void _notifyChanged() {
    if (!_disposed) _onChanged();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _knownConfigs.clear();
    _residentMapIds.clear();
    _readyMapIds.clear();
    _failedMapIds.clear();
    _clearPending();
    _preferredMapIds.clear();
    _protectedMapIds.clear();
  }
}

/// A viewport-sized real renderer surface.
///
/// Inactive surfaces cannot receive input, expose semantics, or advance
/// tickers. They can also be kept offstage while retaining their renderer state
/// when the owning page temporarily prioritizes another composited surface.
class TilemapPrerenderSurface extends StatelessWidget {
  const TilemapPrerenderSurface({
    super.key,
    required this.interactive,
    this.suspended = false,
    required this.child,
  });

  final bool interactive;
  final bool suspended;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Offstage(
        offstage: suspended && !interactive,
        child: ClipRect(
          child: IgnorePointer(
            ignoring: !interactive,
            child: ExcludeSemantics(
              excluding: !interactive,
              child: TickerMode(
                enabled: interactive,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
