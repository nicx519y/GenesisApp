import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../network/genesis_api.dart';
import '../../network/models/tilemap_definition.dart';
import '../world_map_avatar_logic.dart';
import '../world_map_location_action.dart';
import '../world_point.dart';
import 'tilemap_model.dart';
import 'tilemap_renderer.dart';

enum _TilemapSource { origin, world }

class Tilemap extends StatefulWidget {
  const Tilemap.origin({
    super.key,
    required String originId,
    this.locationId = 'root',
    this.locationNodes = const <WorldMapLocationNode>[],
    this.drillExitTop = 68,
    this.showVisualModeToggle = true,
    this.visualModeToggleTop,
    this.visualModeToggleRight = 9.5,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
  }) : _source = _TilemapSource.origin,
       _entityId = originId;

  const Tilemap.world({
    super.key,
    required String worldId,
    this.locationId = 'root',
    this.locationNodes = const <WorldMapLocationNode>[],
    this.drillExitTop = 68,
    this.showVisualModeToggle = true,
    this.visualModeToggleTop,
    this.visualModeToggleRight = 9.5,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
  }) : _source = _TilemapSource.world,
       _entityId = worldId;

  final _TilemapSource _source;
  final String _entityId;
  final String locationId;
  final List<WorldMapLocationNode> locationNodes;
  final double drillExitTop;
  final bool showVisualModeToggle;
  final double? visualModeToggleTop;
  final double visualModeToggleRight;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final FutureOr<void> Function(WorldPoint point)? onPointTap;

  @override
  State<Tilemap> createState() => _TilemapState();
}

class _TilemapState extends State<Tilemap> {
  GenesisApi? _api;
  final Map<String, Future<_TilemapLoadResult>> _mapRequests =
      <String, Future<_TilemapLoadResult>>{};
  final Map<String, _TilemapLoadResult> _mapResults =
      <String, _TilemapLoadResult>{};
  TilemapConfig? _currentConfig;
  Object? _mapError;
  Object? _imageError;
  late String _currentLocationId;
  final List<String> _locationTrail = <String>[];
  int _cacheGeneration = 0;
  int _rendererRevision = 0;
  TilemapVisualMode _visualMode = tilemapDefaultVisualMode;

  @override
  void initState() {
    super.initState();
    _currentLocationId = widget.locationId.trim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AppServicesScope.read(context).api;
    if (identical(_api, api)) return;
    _api = api;
    _resetMapCache();
    _loadCurrentLocation(rebuild: false);
  }

  @override
  void didUpdateWidget(covariant Tilemap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entityChanged =
        oldWidget._source != widget._source ||
        oldWidget._entityId != widget._entityId;
    final initialLocationChanged = oldWidget.locationId != widget.locationId;
    if (!entityChanged && !initialLocationChanged) return;
    _currentLocationId = widget.locationId.trim();
    _locationTrail.clear();
    if (entityChanged) _resetMapCache();
    _loadCurrentLocation(rebuild: false);
  }

  @override
  void dispose() {
    _cacheGeneration += 1;
    super.dispose();
  }

  Future<TilemapConfig> _load(
    GenesisApi api, {
    required String locationId,
  }) async {
    final source = widget._source;
    final entityId = widget._entityId.trim();
    if (entityId.isEmpty) {
      throw const TilemapConfigException('Map entity id must not be empty.');
    }
    if (locationId.isEmpty) {
      throw const TilemapConfigException('location_id must not be empty.');
    }

    final definition = switch (source) {
      _TilemapSource.origin => await api.getOriginMap(
        originId: entityId,
        locationId: locationId,
      ),
      _TilemapSource.world => await api.getWorldMap(
        worldId: entityId,
        locationId: locationId,
      ),
    };
    return _configFromDefinition(
      definition,
      mapId: '${source.name}:$entityId:$locationId',
    );
  }

  Future<_TilemapLoadResult> _loadSafely(
    GenesisApi api, {
    required String locationId,
    required bool reportFailure,
  }) async {
    try {
      return _TilemapLoadResult.success(
        await _load(api, locationId: locationId),
      );
    } catch (error) {
      if (kDebugMode && reportFailure) {
        debugPrint('[Tilemap] load failed: $error');
      }
      return _TilemapLoadResult.failure(error);
    }
  }

  Future<_TilemapLoadResult> _requestMap(
    GenesisApi api,
    String rawLocationId, {
    required bool reportFailure,
  }) {
    final locationId = rawLocationId.trim();
    final cached = _mapResults[locationId];
    if (cached != null) return Future<_TilemapLoadResult>.value(cached);

    final existing = _mapRequests[locationId];
    if (existing != null) return existing;

    final generation = _cacheGeneration;
    final request =
        _loadSafely(api, locationId: locationId, reportFailure: reportFailure)
            .then((result) {
              if (generation == _cacheGeneration) {
                _mapResults[locationId] = result;
              }
              return result;
            })
            .whenComplete(() {
              if (generation == _cacheGeneration) {
                _mapRequests.remove(locationId);
              }
            });
    _mapRequests[locationId] = request;
    return request;
  }

  void _resetMapCache() {
    _cacheGeneration += 1;
    _mapRequests.clear();
    _mapResults.clear();
    _currentConfig = null;
    _mapError = null;
    _imageError = null;
    _rendererRevision = 0;
  }

  void _loadCurrentLocation({required bool rebuild}) {
    final api = _api;
    if (api == null) return;
    final locationId = _currentLocationId.trim();
    final cached = _mapResults[locationId];

    void applyPendingOrCached() {
      _imageError = null;
      _mapError = cached?.error;
      _currentConfig = cached?.config;
    }

    if (rebuild) {
      setState(applyPendingOrCached);
    } else {
      applyPendingOrCached();
    }
    if (cached != null) return;

    final generation = _cacheGeneration;
    unawaited(
      _requestMap(api, locationId, reportFailure: true).then((result) {
        if (!mounted ||
            generation != _cacheGeneration ||
            locationId != _currentLocationId.trim()) {
          return;
        }
        setState(() {
          _mapError = result.error;
          _currentConfig = result.config;
        });
      }),
    );
  }

  TilemapConfig _configFromDefinition(
    TilemapDefinition definition, {
    required String mapId,
  }) {
    final tileTypes = definition.tileTypes;
    final mapJson = definition.mapJson;
    if (!definition.isAvailable || tileTypes == null || mapJson == null) {
      throw const TilemapConfigException('Tilemap data is unavailable.');
    }
    return TilemapConfig.fromTiles(
      id: mapId,
      width: mapJson.width,
      height: mapJson.height,
      tileTypes: tileTypes,
      tiles: definition.tiles.map(
        (tile) => TilemapCell(
          x: tile.x,
          y: tile.y,
          type: tile.type,
          locationId: tile.locationId,
        ),
      ),
    );
  }

  Future<void> _handleTileAction(TilemapCell tile) async {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return;
    final node = findWorldMapLocationNode(widget.locationNodes, locationId);
    if (node == null) return;

    final action = resolveWorldMapLocationAction(node);
    final chatTarget = action.chatTarget;
    if (chatTarget != null) {
      await widget.onPointTap?.call(chatTarget);
      return;
    }

    final drillTarget = action.drillTarget;
    if (drillTarget == null) return;
    widget.onDrillIntoLocation?.call();
    _locationTrail.add(_currentLocationId);
    _currentLocationId = drillTarget.id.trim();
    _loadCurrentLocation(rebuild: true);
  }

  String? _locationNameForTile(TilemapCell tile) {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return null;
    final node = findWorldMapLocationNode(widget.locationNodes, locationId);
    final name = node?.point.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  List<UserAvatar> _locationAvatarsForTile(TilemapCell tile) {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return const <UserAvatar>[];
    return worldMapVisibleAvatarsForLocation(
      findWorldMapLocationNode(widget.locationNodes, locationId),
    );
  }

  void _exitLocation() {
    if (_locationTrail.isEmpty) return;
    widget.onDrillIntoLocation?.call();
    _currentLocationId = _locationTrail.removeLast();
    _loadCurrentLocation(rebuild: true);
  }

  void _retry() {
    if (_imageError != null) {
      setState(() {
        _imageError = null;
        _rendererRevision += 1;
      });
      return;
    }

    final locationId = _currentLocationId.trim();
    _mapResults.remove(locationId);
    _mapRequests.remove(locationId);
    _loadCurrentLocation(rebuild: true);
  }

  void _toggleVisualMode() {
    setState(() {
      _visualMode = switch (_visualMode) {
        TilemapVisualMode.light => TilemapVisualMode.dark,
        TilemapVisualMode.dark => TilemapVisualMode.light,
      };
    });
  }

  void _handleImageError(String mapId, Object error) {
    if (!_isCurrentMapId(mapId)) return;
    if (_imageError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _imageError != null || !_isCurrentMapId(mapId)) return;
      setState(() => _imageError = error);
    });
  }

  bool _isCurrentMapId(String mapId) {
    final entityId = widget._entityId.trim();
    return mapId ==
        '${widget._source.name}:$entityId:${_currentLocationId.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    late final Widget map;
    if (_imageError != null || _mapError != null) {
      map = _TilemapError(visualMode: _visualMode, onRetry: _retry);
    } else {
      final config = _currentConfig;
      map = config == null
          ? ColoredBox(
              key: const ValueKey<String>('tilemap-loading-background'),
              color: tilemapVisualStyleFor(_visualMode).backgroundColor,
            )
          : TilemapRenderer(
              key: ValueKey<String>(
                'tilemap-renderer-${config.id}-$_rendererRevision',
              ),
              config: config,
              onTileAction: _handleTileAction,
              locationNameForTile: _locationNameForTile,
              locationAvatarsForTile: _locationAvatarsForTile,
              onMapTap: widget.onMapTap,
              onImageError: (error) => _handleImageError(config.id, error),
              visualMode: _visualMode,
            );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        if (widget.showVisualModeToggle)
          Positioned(
            right: widget.visualModeToggleRight,
            top:
                widget.visualModeToggleTop ??
                MediaQuery.paddingOf(context).top + 6,
            child: _TilemapVisualModeToggle(
              visualMode: _visualMode,
              onPressed: _toggleVisualMode,
            ),
          ),
        if (_locationTrail.isNotEmpty)
          Positioned(
            left: 12,
            top: widget.drillExitTop,
            child: _TilemapExitLocationButton(onPressed: _exitLocation),
          ),
      ],
    );
  }
}

class _TilemapVisualModeToggle extends StatelessWidget {
  const _TilemapVisualModeToggle({
    required this.visualMode,
    required this.onPressed,
  });

  final TilemapVisualMode visualMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLight = visualMode == TilemapVisualMode.light;
    final nextModeLabel = isLight ? 'dark' : 'light';
    return Tooltip(
      message: 'Switch to $nextModeLabel map mode',
      child: Material(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey<String>('tilemap-visual-mode-toggle'),
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              key: ValueKey<String>('tilemap-visual-mode-${visualMode.name}'),
              color: isLight ? const Color(0xFF37362E) : Colors.black,
              size: 20,
              semanticLabel: 'Switch to $nextModeLabel map mode',
            ),
          ),
        ),
      ),
    );
  }
}

class _TilemapExitLocationButton extends StatelessWidget {
  const _TilemapExitLocationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey<String>('tilemap-exit-location'),
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.subdirectory_arrow_left,
            color: Colors.black,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _TilemapLoadResult {
  const _TilemapLoadResult.success(this.config) : error = null;

  const _TilemapLoadResult.failure(this.error) : config = null;

  final TilemapConfig? config;
  final Object? error;
}

class _TilemapError extends StatelessWidget {
  const _TilemapError({required this.visualMode, required this.onRetry});

  final TilemapVisualMode visualMode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final visualStyle = tilemapVisualStyleFor(visualMode);
    final textColor = visualMode == TilemapVisualMode.dark
        ? Colors.white
        : Colors.black;
    return Stack(
      key: const ValueKey<String>('tilemap-error'),
      fit: StackFit.expand,
      children: [
        ColoredBox(color: visualStyle.backgroundColor),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Map failed to load', style: TextStyle(color: textColor)),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey<String>('tilemap-retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
