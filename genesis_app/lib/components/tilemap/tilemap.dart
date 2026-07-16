import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../network/genesis_api.dart';
import '../../network/models/tilemap_definition.dart';
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
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final FutureOr<void> Function(WorldPoint point)? onPointTap;

  @override
  State<Tilemap> createState() => _TilemapState();
}

class _TilemapState extends State<Tilemap> {
  GenesisApi? _api;
  Future<_TilemapLoadResult>? _future;
  Object? _imageError;
  late String _currentLocationId;
  final List<String> _locationTrail = <String>[];

  @override
  void initState() {
    super.initState();
    _currentLocationId = widget.locationId.trim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AppServicesScope.read(context).api;
    if (identical(_api, api) && _future != null) return;
    _api = api;
    _future = _loadSafely(api);
    _imageError = null;
  }

  @override
  void didUpdateWidget(covariant Tilemap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._source == widget._source &&
        oldWidget._entityId == widget._entityId &&
        oldWidget.locationId == widget.locationId) {
      return;
    }
    _currentLocationId = widget.locationId.trim();
    _locationTrail.clear();
    final api = _api;
    if (api == null) return;
    _future = _loadSafely(api);
    _imageError = null;
  }

  Future<TilemapConfig> _load(GenesisApi api) async {
    final entityId = widget._entityId.trim();
    final locationId = _currentLocationId.trim();
    if (entityId.isEmpty) {
      throw const TilemapConfigException('Map entity id must not be empty.');
    }
    if (locationId.isEmpty) {
      throw const TilemapConfigException('location_id must not be empty.');
    }

    final definition = switch (widget._source) {
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
      mapId: '${widget._source.name}:$entityId:$locationId',
    );
  }

  Future<_TilemapLoadResult> _loadSafely(GenesisApi api) async {
    try {
      return _TilemapLoadResult.success(await _load(api));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Tilemap] load failed: $error');
      }
      return _TilemapLoadResult.failure(error);
    }
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
    _reloadCurrentLocation();
  }

  String? _locationNameForTile(TilemapCell tile) {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return null;
    final node = findWorldMapLocationNode(widget.locationNodes, locationId);
    final name = node?.point.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  void _exitLocation() {
    if (_locationTrail.isEmpty) return;
    widget.onDrillIntoLocation?.call();
    _currentLocationId = _locationTrail.removeLast();
    _reloadCurrentLocation();
  }

  void _reloadCurrentLocation() {
    final api = _api;
    if (api == null) return;
    setState(() {
      _imageError = null;
      _future = _loadSafely(api);
    });
  }

  void _retry() {
    final api = _api;
    if (api == null) return;
    setState(() {
      _imageError = null;
      _future = _loadSafely(api);
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
    final imageError = _imageError;
    if (imageError != null) {
      map = _TilemapError(onRetry: _retry);
    } else {
      final future = _future;
      map = future == null
          ? const _TilemapLoading()
          : FutureBuilder<_TilemapLoadResult>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _TilemapLoading();
                }
                final result = snapshot.data;
                final config = result?.config;
                if (result == null || result.error != null || config == null) {
                  return _TilemapError(onRetry: _retry);
                }
                return TilemapRenderer(
                  key: ValueKey<String>('tilemap-renderer-${config.id}'),
                  config: config,
                  onTileAction: _handleTileAction,
                  locationNameForTile: _locationNameForTile,
                  onMapTap: widget.onMapTap,
                  onImageError: (error) => _handleImageError(config.id, error),
                );
              },
            );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
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

class _TilemapLoading extends StatelessWidget {
  const _TilemapLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey<String>('tilemap-loading'),
      color: Colors.white,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _TilemapError extends StatelessWidget {
  const _TilemapError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('tilemap-error'),
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Map failed to load'),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey<String>('tilemap-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
