import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/firebase_performance_monitoring.dart';
import '../../network/genesis_api.dart';
import '../../network/models/tilemap_definition.dart';
import '../world_map_avatar_logic.dart';
import '../world_map_contract.dart';
import '../world_map_location_action.dart';
import '../world_point.dart';
import 'loading/tilemap_loading.dart';
import 'tilemap_model.dart';
import 'tilemap_renderer.dart';
import 'tilemap_settings_button_visibility.dart';
import 'tilemap_settings_store.dart';

part 'tilemap_settings_panel.dart';
part 'tilemap_fog_editor.dart';
part 'tilemap_image_flow_editor.dart';
part 'tilemap_controls_feedback.dart';

enum _TilemapSource { origin, world }

typedef TilemapTileImageLoader = Future<void> Function(String assetUrl);

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
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
    this.tileImageLoader,
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
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
    this.tileImageLoader,
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
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final FutureOr<void> Function(WorldPoint point)? onPointTap;
  final TilemapTileImageLoader? tileImageLoader;

  @override
  State<Tilemap> createState() => _TilemapState();
}

class _TilemapState extends State<Tilemap> {
  static const Duration _settingsSaveDelay = Duration(milliseconds: 250);
  static const String _loadPerformanceTraceName = 'tilemap_load';

  GenesisApi? _api;
  final TilemapSettingsStore _settingsStore = const TilemapSettingsStore();
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
  late final TilemapLoadingCoordinator _loadingCoordinator;
  TilemapVisualMode _visualMode = tilemapDefaultVisualMode;
  TilemapLoadingStyle _loadingStyle = tilemapDefaultLoadingStyle;
  List<TilemapFogControlPoint> _fogControlPoints =
      tilemapDefaultFogControlPoints;
  bool _blendFogWithShadowTiles = tilemapDefaultBlendFogWithShadowTiles;
  bool _showShadowZeroBorders = tilemapDefaultShowShadowZeroBorders;
  bool _showLocationImageFlow = tilemapDefaultShowLocationImageFlow;
  double _locationImageFlowAngleDegrees =
      tilemapDefaultLocationImageFlowAngleDegrees;
  List<TilemapLocationImageFlowGradientPoint> _locationImageFlowGradientPoints =
      tilemapDefaultLocationImageFlowGradientPoints;
  double _locationImageFlowOpacity = tilemapDefaultLocationImageFlowOpacity;
  double _locationImageFlowDurationSeconds =
      tilemapDefaultLocationImageFlowDurationSeconds;
  TilemapLocationImageFlowBlendMode _locationImageFlowBlendMode =
      tilemapDefaultLocationImageFlowBlendMode;
  double _initialScale = tilemapDefaultInitialScale;
  double _dragBoundaryPaddingTiles = tilemapDefaultDragBoundaryPaddingTiles;
  bool _showSettings = false;
  bool _settingsReady = false;
  Timer? _settingsSaveTimer;
  Future<void> _settingsPersistence = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _currentLocationId = widget.locationId.trim();
    _loadingCoordinator = TilemapLoadingCoordinator(
      onChanged: _handleLoadingCoordinatorChanged,
    );
    tilemapSettingsButtonVisibility.listenable.addListener(
      _handleSettingsButtonVisibilityChanged,
    );
    unawaited(tilemapSettingsButtonVisibility.load());
    unawaited(_loadCachedSettings());
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
    if (entityChanged) {
      _resetMapCache();
    } else {
      _loadingCoordinator.retargetInitialEntry();
    }
    _loadCurrentLocation(rebuild: false);
  }

  @override
  void dispose() {
    _cacheGeneration += 1;
    _loadingCoordinator.dispose();
    tilemapSettingsButtonVisibility.listenable.removeListener(
      _handleSettingsButtonVisibilityChanged,
    );
    final shouldFlushSettings = _settingsSaveTimer?.isActive ?? false;
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = null;
    if (_settingsReady && shouldFlushSettings) {
      unawaited(_persistSettings(_currentSettings));
    }
    super.dispose();
  }

  TilemapRenderSettings get _currentSettings {
    return TilemapRenderSettings(
      visualMode: _visualMode,
      loadingStyle: _loadingStyle,
      fogControlPoints: _fogControlPoints,
      blendFogWithShadowTiles: _blendFogWithShadowTiles,
      showShadowZeroBorders: _showShadowZeroBorders,
      showLocationImageFlow: _showLocationImageFlow,
      locationImageFlowAngleDegrees: _locationImageFlowAngleDegrees,
      locationImageFlowGradientPoints: _locationImageFlowGradientPoints,
      locationImageFlowOpacity: _locationImageFlowOpacity,
      locationImageFlowDurationSeconds: _locationImageFlowDurationSeconds,
      locationImageFlowBlendMode: _locationImageFlowBlendMode,
      initialScale: _initialScale,
      dragBoundaryPaddingTiles: _dragBoundaryPaddingTiles,
    );
  }

  Future<void> _loadCachedSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) return;
    if (settings.loadingStyle == TilemapLoadingStyle.disabled) {
      _loadingCoordinator.completeInitialEntryWithoutOverlay();
    }
    setState(() {
      _visualMode = settings.visualMode;
      _loadingStyle = settings.loadingStyle;
      _fogControlPoints = settings.fogControlPoints;
      _blendFogWithShadowTiles = settings.blendFogWithShadowTiles;
      _showShadowZeroBorders = settings.showShadowZeroBorders;
      _showLocationImageFlow = settings.showLocationImageFlow;
      _locationImageFlowAngleDegrees = settings.locationImageFlowAngleDegrees;
      _locationImageFlowGradientPoints =
          settings.locationImageFlowGradientPoints;
      _locationImageFlowOpacity = settings.locationImageFlowOpacity;
      _locationImageFlowDurationSeconds =
          settings.locationImageFlowDurationSeconds;
      _locationImageFlowBlendMode = settings.locationImageFlowBlendMode;
      _initialScale = settings.initialScale;
      _dragBoundaryPaddingTiles = settings.dragBoundaryPaddingTiles;
      _settingsReady = true;
    });
  }

  void _handleLoadingCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSettingsButtonVisibilityChanged() {
    if (!mounted) return;
    final wasOpen = _showSettings;
    setState(() {
      if (!tilemapSettingsButtonVisibility.value) {
        _showSettings = false;
      }
    });
    if (wasOpen && !_showSettings) {
      _flushSettingsSave();
    }
  }

  void _scheduleSettingsSave() {
    if (!_settingsReady) return;
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = Timer(_settingsSaveDelay, () {
      _settingsSaveTimer = null;
      unawaited(_persistSettings(_currentSettings));
    });
  }

  void _flushSettingsSave() {
    if (!_settingsReady || _settingsSaveTimer == null) return;
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = null;
    unawaited(_persistSettings(_currentSettings));
  }

  Future<void> _persistSettings(TilemapRenderSettings settings) {
    final operation = _settingsPersistence.then((_) async {
      try {
        await _settingsStore.save(settings);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[Tilemap] settings save failed: $error');
        }
      }
    });
    _settingsPersistence = operation;
    return operation;
  }

  Future<void> _copySettingsToClipboard() async {
    await Clipboard.setData(
      ClipboardData(text: _currentSettings.toSerializedJson()),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tilemap settings JSON copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _resetSettings() async {
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = null;
    await _settingsPersistence;
    try {
      await _settingsStore.clear();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Tilemap] settings reset failed: $error');
      }
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Tilemap settings reset failed'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    if (!mounted) return;
    final defaults = TilemapRenderSettings.defaults();
    setState(() {
      _visualMode = defaults.visualMode;
      _loadingStyle = defaults.loadingStyle;
      _fogControlPoints = defaults.fogControlPoints;
      _blendFogWithShadowTiles = defaults.blendFogWithShadowTiles;
      _showShadowZeroBorders = defaults.showShadowZeroBorders;
      _showLocationImageFlow = defaults.showLocationImageFlow;
      _locationImageFlowAngleDegrees = defaults.locationImageFlowAngleDegrees;
      _locationImageFlowGradientPoints =
          defaults.locationImageFlowGradientPoints;
      _locationImageFlowOpacity = defaults.locationImageFlowOpacity;
      _locationImageFlowDurationSeconds =
          defaults.locationImageFlowDurationSeconds;
      _locationImageFlowBlendMode = defaults.locationImageFlowBlendMode;
      _initialScale = defaults.initialScale;
      _dragBoundaryPaddingTiles = defaults.dragBoundaryPaddingTiles;
    });
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tilemap settings reset'),
          duration: Duration(seconds: 2),
        ),
      );
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
    final trace = await FirebasePerformanceMonitoring.startTrace(
      _loadPerformanceTraceName,
      attributes: <String, String>{'source': widget._source.name},
    );
    try {
      final config = await _load(api, locationId: locationId);
      unawaited(
        FirebasePerformanceMonitoring.stopTrace(
          trace,
          attributes: const <String, String>{'result': 'success'},
          metrics: <String, int>{
            'tile_count': config.tiles.length,
            'map_width': config.width,
            'map_height': config.height,
          },
        ),
      );
      return _TilemapLoadResult.success(config);
    } catch (error) {
      unawaited(
        FirebasePerformanceMonitoring.stopTrace(
          trace,
          attributes: const <String, String>{'result': 'failure'},
        ),
      );
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
    _loadingCoordinator.resetSession();
    if (_settingsReady && _loadingStyle == TilemapLoadingStyle.disabled) {
      _loadingCoordinator.completeInitialEntryWithoutOverlay();
    }
    _mapRequests.clear();
    _mapResults.clear();
    _currentConfig = null;
    _mapError = null;
    _imageError = null;
    _rendererRevision = 0;
  }

  Future<TilemapConfig?> _preloadMap(String locationId) async {
    final api = _api;
    if (api == null) return null;

    final generation = _cacheGeneration;
    final result = await _requestMap(api, locationId, reportFailure: false);
    if (!mounted || generation != _cacheGeneration) return null;

    final config = result.config;
    if (config != null) return config;

    // A silent optimization must not leave a negative cache entry that would
    // prevent the user's later interactive navigation from retrying.
    if (_currentLocationId.trim() != locationId &&
        identical(_mapResults[locationId], result)) {
      _mapResults.remove(locationId);
    }
    return null;
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
          shadow: tile.shadow,
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
    if (_loadingCoordinator.initialLoadError != null) {
      _rendererRevision += 1;
      _loadingCoordinator.retryInitialTileLoad();
      return;
    }

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

  void _setVisualMode(TilemapVisualMode visualMode) {
    if (_visualMode == visualMode) return;
    setState(() => _visualMode = visualMode);
    _scheduleSettingsSave();
  }

  void _setLoadingStyle(TilemapLoadingStyle loadingStyle) {
    if (_loadingStyle == loadingStyle) return;
    if (loadingStyle == TilemapLoadingStyle.disabled) {
      _loadingCoordinator.completeInitialEntryWithoutOverlay();
    }
    setState(() => _loadingStyle = loadingStyle);
    _scheduleSettingsSave();
  }

  void _setFogControlPoints(List<TilemapFogControlPoint> controlPoints) {
    setState(() {
      _fogControlPoints = List<TilemapFogControlPoint>.unmodifiable(
        controlPoints,
      );
    });
    _scheduleSettingsSave();
  }

  void _setBlendFogWithShadowTiles(bool value) {
    if (_blendFogWithShadowTiles == value) return;
    setState(() => _blendFogWithShadowTiles = value);
    _scheduleSettingsSave();
  }

  void _setShowShadowZeroBorders(bool value) {
    if (_showShadowZeroBorders == value) return;
    setState(() => _showShadowZeroBorders = value);
    _scheduleSettingsSave();
  }

  void _setShowLocationImageFlow(bool value) {
    if (_showLocationImageFlow == value) return;
    setState(() => _showLocationImageFlow = value);
    _scheduleSettingsSave();
  }

  void _setLocationImageFlowAngleDegrees(double value) {
    final resolved = value.clamp(0.0, 360.0).toDouble();
    if (_locationImageFlowAngleDegrees == resolved) return;
    setState(() => _locationImageFlowAngleDegrees = resolved);
    _scheduleSettingsSave();
  }

  void _setLocationImageFlowGradientPoints(
    List<TilemapLocationImageFlowGradientPoint> value,
  ) {
    setState(() {
      _locationImageFlowGradientPoints =
          List<TilemapLocationImageFlowGradientPoint>.unmodifiable(value);
    });
    _scheduleSettingsSave();
  }

  void _setLocationImageFlowOpacity(double value) {
    final resolved = value.clamp(0.0, 1.0).toDouble();
    if (_locationImageFlowOpacity == resolved) return;
    setState(() => _locationImageFlowOpacity = resolved);
    _scheduleSettingsSave();
  }

  void _setLocationImageFlowDurationSeconds(double value) {
    final resolved = value
        .clamp(
          tilemapLocationImageFlowDurationSecondsMin,
          tilemapLocationImageFlowDurationSecondsMax,
        )
        .toDouble();
    if (_locationImageFlowDurationSeconds == resolved) return;
    setState(() => _locationImageFlowDurationSeconds = resolved);
    _scheduleSettingsSave();
  }

  void _setLocationImageFlowBlendMode(TilemapLocationImageFlowBlendMode value) {
    if (_locationImageFlowBlendMode == value) return;
    setState(() => _locationImageFlowBlendMode = value);
    _scheduleSettingsSave();
  }

  void _setInitialScale(double value) {
    final resolved = value
        .roundToDouble()
        .clamp(tilemapInitialScaleMin, tilemapInitialScaleMax)
        .toDouble();
    if (_initialScale == resolved) return;
    setState(() {
      _initialScale = resolved;
      _loadingCoordinator.invalidateInitialTilePlan();
    });
    _scheduleSettingsSave();
  }

  void _setDragBoundaryPaddingTiles(double value) {
    final resolved = value
        .roundToDouble()
        .clamp(
          tilemapDragBoundaryPaddingTilesMin,
          tilemapDragBoundaryPaddingTilesMax,
        )
        .toDouble();
    if (_dragBoundaryPaddingTiles == resolved) return;
    setState(() => _dragBoundaryPaddingTiles = resolved);
    _scheduleSettingsSave();
  }

  void _toggleSettings() {
    final willClose = _showSettings;
    setState(() => _showSettings = !_showSettings);
    if (willClose) _flushSettingsSave();
  }

  void _closeSettings() {
    if (!_showSettings) return;
    setState(() => _showSettings = false);
    _flushSettingsSave();
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

  Future<void> _loadTileImage(String assetUrl) async {
    final customLoader = widget.tileImageLoader;
    if (customLoader != null) {
      await customLoader(assetUrl);
      return;
    }

    Object? precacheError;
    StackTrace? precacheStackTrace;
    await precacheImage(
      NetworkImage(assetUrl),
      context,
      onError: (error, stackTrace) {
        precacheError = error;
        precacheStackTrace = stackTrace;
      },
    );
    final error = precacheError;
    if (error != null) {
      Error.throwWithStackTrace(
        error,
        precacheStackTrace ?? StackTrace.current,
      );
    }
  }

  void _scheduleSilentDrillDownPreload(
    TilemapConfig config, {
    required double displayTilePixelSize,
  }) {
    _loadingCoordinator.scheduleSilentDrillDownPreload(
      currentConfig: config,
      locationNodes: widget.locationNodes,
      displayTilePixelSize: displayTilePixelSize,
      loadMap: _preloadMap,
      loadImage: _loadTileImage,
    );
  }

  Widget _buildRenderer(TilemapConfig config) {
    return TilemapRenderer(
      key: ValueKey<String>('tilemap-renderer-${config.id}-$_rendererRevision'),
      config: config,
      onTileAction: _handleTileAction,
      locationNameForTile: _locationNameForTile,
      locationAvatarsForTile: _locationAvatarsForTile,
      messageBubbles: widget.messageBubbles,
      messageBubblePlaybackPaused: widget.messageBubblePlaybackPaused,
      onMapTap: widget.onMapTap,
      onImageError: widget.tileImageLoader == null
          ? (error) => _handleImageError(config.id, error)
          : null,
      visualMode: _visualMode,
      fogControlPoints: _fogControlPoints,
      blendFogWithShadowTiles: _blendFogWithShadowTiles,
      showShadowZeroBorders: _showShadowZeroBorders,
      showLocationImageFlow: _showLocationImageFlow,
      locationImageFlowAngleDegrees: _locationImageFlowAngleDegrees,
      locationImageFlowGradientPoints: _locationImageFlowGradientPoints,
      locationImageFlowOpacity: _locationImageFlowOpacity,
      locationImageFlowDurationSeconds: _locationImageFlowDurationSeconds,
      locationImageFlowBlendMode: _locationImageFlowBlendMode,
      initialScale: _initialScale,
      dragBoundaryPaddingTiles: _dragBoundaryPaddingTiles,
    );
  }

  @override
  Widget build(BuildContext context) {
    late final Widget map;
    if (!_settingsReady) {
      map = ColoredBox(
        key: const ValueKey<String>('tilemap-settings-loading-background'),
        color: tilemapVisualStyleFor(_visualMode).backgroundColor,
      );
    } else if (_imageError != null ||
        _mapError != null ||
        _loadingCoordinator.initialLoadError != null) {
      map = _TilemapError(visualMode: _visualMode, onRetry: _retry);
    } else {
      final config = _currentConfig;
      final showInitialLoading =
          !_loadingCoordinator.initialEntryCompleted &&
          _loadingStyle != TilemapLoadingStyle.disabled;
      if (config == null) {
        map = showInitialLoading
            ? TilemapLoadingOverlay(
                style: _loadingStyle,
                progress: 0,
                visualMode: _visualMode,
                backgroundKey: const ValueKey<String>(
                  'tilemap-loading-background',
                ),
              )
            : ColoredBox(
                key: const ValueKey<String>('tilemap-loading-background'),
                color: tilemapVisualStyleFor(_visualMode).backgroundColor,
              );
      } else if (showInitialLoading) {
        final displayTilePixelSize =
            tilemapBaseTileExtent *
            _initialScale *
            MediaQuery.devicePixelRatioOf(context);
        final imageLoadPlan = TilemapImageLoadPlan.forConfig(
          config: config,
          displayTilePixelSize: displayTilePixelSize,
        );
        _loadingCoordinator.ensureInitialMapReady(
          config: config,
          plan: imageLoadPlan,
          loadImage: _loadTileImage,
        );
        map = TilemapLoadingOverlay(
          style: _loadingStyle,
          progress: _loadingCoordinator.initialProgress,
          visualMode: _visualMode,
          backgroundKey: const ValueKey<String>('tilemap-loading-background'),
        );
      } else {
        final displayTilePixelSize =
            tilemapBaseTileExtent *
            _initialScale *
            MediaQuery.devicePixelRatioOf(context);
        _scheduleSilentDrillDownPreload(
          config,
          displayTilePixelSize: displayTilePixelSize,
        );
        map = _buildRenderer(config);
      }
    }
    final settingsButtonTop =
        widget.visualModeToggleTop ?? MediaQuery.paddingOf(context).top + 6;
    final settingsPanelMaxHeight =
        (MediaQuery.sizeOf(context).height - settingsButtonTop - 58)
            .clamp(220.0, 500.0)
            .toDouble();
    final showSettingsButton =
        widget.showVisualModeToggle &&
        tilemapSettingsButtonVisibility.value &&
        _settingsReady;
    final showSettings = showSettingsButton && _showSettings;
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
        if (showSettings)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('tilemap-settings-dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: _closeSettings,
            ),
          ),
        if (showSettings)
          Positioned(
            left: 0,
            right: 0,
            top: settingsButtonTop + 46,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: settingsPanelMaxHeight),
              child: _TilemapSettingsPanel(
                visualMode: _visualMode,
                loadingStyle: _loadingStyle,
                fogControlPoints: _fogControlPoints,
                blendFogWithShadowTiles: _blendFogWithShadowTiles,
                showShadowZeroBorders: _showShadowZeroBorders,
                showLocationImageFlow: _showLocationImageFlow,
                locationImageFlowAngleDegrees: _locationImageFlowAngleDegrees,
                locationImageFlowGradientPoints:
                    _locationImageFlowGradientPoints,
                locationImageFlowOpacity: _locationImageFlowOpacity,
                locationImageFlowDurationSeconds:
                    _locationImageFlowDurationSeconds,
                locationImageFlowBlendMode: _locationImageFlowBlendMode,
                initialScale: _initialScale,
                dragBoundaryPaddingTiles: _dragBoundaryPaddingTiles,
                onVisualModeChanged: _setVisualMode,
                onLoadingStyleChanged: _setLoadingStyle,
                onFogControlPointsChanged: _setFogControlPoints,
                onBlendFogWithShadowTilesChanged: _setBlendFogWithShadowTiles,
                onShowShadowZeroBordersChanged: _setShowShadowZeroBorders,
                onShowLocationImageFlowChanged: _setShowLocationImageFlow,
                onLocationImageFlowAngleDegreesChanged:
                    _setLocationImageFlowAngleDegrees,
                onLocationImageFlowGradientPointsChanged:
                    _setLocationImageFlowGradientPoints,
                onLocationImageFlowOpacityChanged: _setLocationImageFlowOpacity,
                onLocationImageFlowDurationSecondsChanged:
                    _setLocationImageFlowDurationSeconds,
                onLocationImageFlowBlendModeChanged:
                    _setLocationImageFlowBlendMode,
                onInitialScaleChanged: _setInitialScale,
                onDragBoundaryPaddingTilesChanged: _setDragBoundaryPaddingTiles,
                onCopySettings: _copySettingsToClipboard,
                onResetSettings: _resetSettings,
                onClose: _closeSettings,
              ),
            ),
          ),
        if (showSettingsButton)
          Positioned(
            right: widget.visualModeToggleRight,
            top: settingsButtonTop,
            child: _TilemapSettingsButton(
              isOpen: showSettings,
              onPressed: _toggleSettings,
            ),
          ),
      ],
    );
  }
}
