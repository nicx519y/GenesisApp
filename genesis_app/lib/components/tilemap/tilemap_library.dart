import 'dart:async';
import 'dart:collection';
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
import '../../ui/components/genesis_static_network_image.dart';
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

class TilemapRestorationController {
  String _scopeKey = '';
  String _initialLocationId = '';
  String _currentLocationId = '';
  final List<String> _locationTrail = <String>[];
  final Map<String, Matrix4> _viewportTransforms = <String, Matrix4>{};

  void clear() {
    _scopeKey = '';
    _initialLocationId = '';
    _currentLocationId = '';
    _locationTrail.clear();
    _viewportTransforms.clear();
  }

  void _ensureScope({
    required String scopeKey,
    required String initialLocationId,
  }) {
    if (_scopeKey == scopeKey && _initialLocationId == initialLocationId) {
      return;
    }
    clear();
    _scopeKey = scopeKey;
    _initialLocationId = initialLocationId;
    _currentLocationId = initialLocationId;
  }

  void _saveNavigation({
    required String scopeKey,
    required String initialLocationId,
    required String currentLocationId,
    required List<String> locationTrail,
  }) {
    _ensureScope(scopeKey: scopeKey, initialLocationId: initialLocationId);
    _currentLocationId = currentLocationId;
    _locationTrail
      ..clear()
      ..addAll(locationTrail);
  }

  Matrix4? _viewportTransform({
    required String scopeKey,
    required String initialLocationId,
    required String mapId,
  }) {
    _ensureScope(scopeKey: scopeKey, initialLocationId: initialLocationId);
    return _viewportTransforms[mapId]?.clone();
  }

  void _saveViewportTransform({
    required String scopeKey,
    required String initialLocationId,
    required String mapId,
    required Matrix4 transform,
  }) {
    _ensureScope(scopeKey: scopeKey, initialLocationId: initialLocationId);
    _viewportTransforms[mapId] = transform.clone();
  }
}

String resolveTilemapPreferredVisibleLocationId({
  required String preferredLocationId,
  required Iterable<String> visibleLocationIds,
  required List<WorldMapLocationNode> locationNodes,
}) {
  final preferredId = preferredLocationId.trim();
  if (preferredId.isEmpty) return '';
  final visibleIds = visibleLocationIds
      .map((locationId) => locationId.trim())
      .where((locationId) => locationId.isNotEmpty)
      .toSet();
  if (visibleIds.contains(preferredId)) return preferredId;

  String? resolvedId;
  bool visit(WorldMapLocationNode node) {
    var containsPreferred = node.id.trim() == preferredId;
    for (final child in node.children) {
      containsPreferred = visit(child) || containsPreferred;
    }
    final nodeId = node.id.trim();
    if (containsPreferred &&
        resolvedId == null &&
        visibleIds.contains(nodeId)) {
      resolvedId = nodeId;
    }
    return containsPreferred;
  }

  for (final node in locationNodes) {
    if (visit(node)) break;
  }
  return resolvedId ?? '';
}

class Tilemap extends StatefulWidget {
  const Tilemap.origin({
    super.key,
    required String originId,
    this.locationId = 'root',
    this.locationNodes = const <WorldMapLocationNode>[],
    this.preferredFocusLocationId = '',
    this.drillExitTop = 68,
    this.showVisualModeToggle = true,
    this.visualModeToggleTop,
    this.visualModeToggleRight = 9.5,
    this.recentChatLocationIds = const <String>{},
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
    this.tileImageLoader,
    this.restorationController,
    this.onDisplayReadinessChanged,
    this.onDisplayError,
  }) : _source = _TilemapSource.origin,
       _entityId = originId;

  const Tilemap.world({
    super.key,
    required String worldId,
    this.locationId = 'root',
    this.locationNodes = const <WorldMapLocationNode>[],
    this.preferredFocusLocationId = '',
    this.drillExitTop = 68,
    this.showVisualModeToggle = true,
    this.visualModeToggleTop,
    this.visualModeToggleRight = 9.5,
    this.recentChatLocationIds = const <String>{},
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
    this.tileImageLoader,
    this.restorationController,
    this.onDisplayReadinessChanged,
    this.onDisplayError,
  }) : _source = _TilemapSource.world,
       _entityId = worldId;

  final _TilemapSource _source;
  final String _entityId;
  final String locationId;
  final List<WorldMapLocationNode> locationNodes;
  final String preferredFocusLocationId;
  final double drillExitTop;
  final bool showVisualModeToggle;
  final double? visualModeToggleTop;
  final double visualModeToggleRight;
  final Set<String> recentChatLocationIds;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final FutureOr<void> Function(WorldPoint point)? onPointTap;
  final TilemapTileImageLoader? tileImageLoader;
  final TilemapRestorationController? restorationController;
  final ValueChanged<bool>? onDisplayReadinessChanged;
  final ValueChanged<Object>? onDisplayError;

  @override
  State<Tilemap> createState() => _TilemapState();
}

class _TilemapState extends State<Tilemap> with WidgetsBindingObserver {
  static const Duration _settingsSaveDelay = Duration(milliseconds: 250);
  static const String _loadPerformanceTraceName = 'tilemap_load';
  static const int _maxCachedMapResults = 8;

  GenesisApi? _api;
  final TilemapSettingsStore _settingsStore = const TilemapSettingsStore();
  final Map<String, Future<_TilemapLoadResult>> _mapRequests =
      <String, Future<_TilemapLoadResult>>{};
  final LinkedHashMap<String, _TilemapLoadResult> _mapResults =
      LinkedHashMap<String, _TilemapLoadResult>();
  TilemapConfig? _currentConfig;
  Object? _mapError;
  Object? _imageError;
  late String _currentLocationId;
  final List<String> _locationTrail = <String>[];
  int _cacheGeneration = 0;
  final Map<String, int> _rendererRevisionByMapId = <String, int>{};
  late final TilemapLoadingCoordinator _loadingCoordinator;
  late final TilemapPrerenderController _prerenderController;
  final Map<String, VoidCallback> _liveViewportReadyCallbacks =
      <String, VoidCallback>{};
  int _prerenderEnvironmentGeneration = 0;
  bool _hasRevealedInitialMap = false;
  String? _configuredPrerenderEnvironmentKey;
  Size? _configuredPrerenderViewportSize;
  double? _configuredPrerenderDevicePixelRatio;
  bool? _reportedDisplayReady;
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
    WidgetsBinding.instance.addObserver(this);
    final initialLocationId = widget.locationId.trim();
    final restorationController = widget.restorationController;
    restorationController?._ensureScope(
      scopeKey: _restorationScopeKey,
      initialLocationId: initialLocationId,
    );
    _currentLocationId =
        restorationController?._currentLocationId ?? initialLocationId;
    _locationTrail.addAll(
      restorationController?._locationTrail ?? const <String>[],
    );
    _loadingCoordinator = TilemapLoadingCoordinator(
      onChanged: _handleLoadingCoordinatorChanged,
      onSilentMapReady: _handleSilentMapReady,
    );
    _prerenderController = TilemapPrerenderController(
      onChanged: _handlePrerenderControllerChanged,
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
    if (oldWidget.onDisplayReadinessChanged !=
        widget.onDisplayReadinessChanged) {
      _reportedDisplayReady = null;
      _reportDisplayReadiness(_isCurrentDisplayReady);
    }
    final entityChanged =
        oldWidget._source != widget._source ||
        oldWidget._entityId != widget._entityId;
    final initialLocationChanged = oldWidget.locationId != widget.locationId;
    if (!entityChanged && !initialLocationChanged) return;
    _currentLocationId = widget.locationId.trim();
    _locationTrail.clear();
    widget.restorationController?._ensureScope(
      scopeKey: _restorationScopeKey,
      initialLocationId: _currentLocationId,
    );
    _saveRestorationNavigation();
    if (entityChanged) {
      _resetMapCache();
    } else {
      _loadingCoordinator.retargetInitialEntry();
    }
    _loadCurrentLocation(rebuild: false);
  }

  @override
  void dispose() {
    _saveRestorationNavigation();
    _cacheGeneration += 1;
    _loadingCoordinator.dispose();
    _prerenderController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didHaveMemoryPressure() {
    _prerenderController.handleMemoryPressure();
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
    final settings = (await _settingsStore.load()).resolveForRuntime(
      releaseMode: kReleaseMode,
    );
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
    final error = _loadingCoordinator.initialLoadError;
    if (error != null) {
      _reportDisplayReadiness(false);
      _reportDisplayError(error);
    }
    setState(() {});
  }

  void _handlePrerenderControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSilentMapReady(TilemapConfig config) {
    if (!mounted) return;
    _prerenderController.rememberConfig(config);
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
    final cached = _cachedMapResult(locationId);
    if (cached != null) return Future<_TilemapLoadResult>.value(cached);

    final existing = _mapRequests[locationId];
    if (existing != null) return existing;

    final generation = _cacheGeneration;
    final request =
        _loadSafely(api, locationId: locationId, reportFailure: reportFailure)
            .then((result) {
              if (generation == _cacheGeneration) {
                _storeMapResult(locationId, result);
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

  _TilemapLoadResult? _cachedMapResult(String locationId) {
    final result = _mapResults.remove(locationId);
    if (result != null) _mapResults[locationId] = result;
    return result;
  }

  void _storeMapResult(String locationId, _TilemapLoadResult result) {
    _mapResults.remove(locationId);
    _mapResults[locationId] = result;
    _pruneMapResults();
  }

  void _pruneMapResults() {
    final protectedMapIds = <String>{
      ..._prerenderController.residentMapIds,
      if (_currentConfig case final config?) config.id,
    };
    while (_mapResults.length > _maxCachedMapResults) {
      String? evictionLocationId;
      for (final entry in _mapResults.entries) {
        final mapId = entry.value.config?.id;
        if (entry.key != _currentLocationId &&
            (mapId == null || !protectedMapIds.contains(mapId))) {
          evictionLocationId = entry.key;
          break;
        }
      }
      if (evictionLocationId == null) return;
      _mapResults.remove(evictionLocationId);
    }
  }

  void _resetMapCache() {
    _reportDisplayReadiness(false);
    _cacheGeneration += 1;
    _loadingCoordinator.resetSession();
    _prerenderController.resetSession();
    if (_settingsReady && _loadingStyle == TilemapLoadingStyle.disabled) {
      _loadingCoordinator.completeInitialEntryWithoutOverlay();
    }
    _mapRequests.clear();
    _mapResults.clear();
    _currentConfig = null;
    _mapError = null;
    _imageError = null;
    _rendererRevisionByMapId.clear();
    _hasRevealedInitialMap = false;
    _configuredPrerenderEnvironmentKey = null;
    _configuredPrerenderViewportSize = null;
    _configuredPrerenderDevicePixelRatio = null;
    _liveViewportReadyCallbacks.clear();
    _prerenderEnvironmentGeneration += 1;
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
    _reportDisplayReadiness(false);
    final locationId = _currentLocationId.trim();
    final cached = _cachedMapResult(locationId);
    final cachedConfig = cached?.config;
    if (cachedConfig != null) _activateConfig(cachedConfig);

    void applyPendingOrCached() {
      _imageError = null;
      _mapError = cached?.error;
      _currentConfig = cachedConfig;
      final error = cached?.error;
      if (error != null) _reportDisplayError(error);
    }

    if (rebuild) {
      setState(applyPendingOrCached);
    } else {
      applyPendingOrCached();
    }
    if (cached != null) {
      return;
    }

    final generation = _cacheGeneration;
    unawaited(
      _requestMap(api, locationId, reportFailure: true).then((result) {
        if (!mounted ||
            generation != _cacheGeneration ||
            locationId != _currentLocationId.trim()) {
          return;
        }
        final config = result.config;
        if (config != null) _activateConfig(config);
        final error = result.error;
        if (error != null) _reportDisplayError(error);
        setState(() {
          _mapError = error;
          _currentConfig = config;
        });
      }),
    );
  }

  bool _activateConfig(TilemapConfig config) {
    return _prerenderController.activateMap(
      config,
      preferredMapIds: _preferredPrerenderMapIds(config),
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
    _saveRestorationNavigation();
    _loadCurrentLocation(rebuild: true);
  }

  String? _locationNameForTile(TilemapCell tile) {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return null;
    final node = findWorldMapLocationNode(widget.locationNodes, locationId);
    final name = node?.point.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  bool _showRecentChatForTile(TilemapCell tile) {
    final recentLocationIds = widget.recentChatLocationIds;
    if (recentLocationIds.isEmpty) return false;
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return false;
    if (recentLocationIds.contains(locationId)) return true;
    final node = findWorldMapLocationNode(widget.locationNodes, locationId);
    final sceneId = node?.point.sceneId.trim() ?? '';
    return sceneId.isNotEmpty && recentLocationIds.contains(sceneId);
  }

  List<UserAvatar> _locationAvatarsForTile(TilemapCell tile) {
    final locationId = tile.locationId?.trim() ?? '';
    if (locationId.isEmpty) return const <UserAvatar>[];
    return worldMapVisibleAvatarsForLocation(
      findWorldMapLocationNode(widget.locationNodes, locationId),
    );
  }

  String _preferredVisibleFocusLocationId(TilemapConfig config) {
    return resolveTilemapPreferredVisibleLocationId(
      preferredLocationId: widget.preferredFocusLocationId,
      visibleLocationIds: config.tiles
          .map((tile) => tile.locationId?.trim() ?? '')
          .where((locationId) => locationId.isNotEmpty),
      locationNodes: widget.locationNodes,
    );
  }

  void _exitLocation() {
    if (_locationTrail.isEmpty) return;
    widget.onDrillIntoLocation?.call();
    _currentLocationId = _locationTrail.removeLast();
    _saveRestorationNavigation();
    _loadCurrentLocation(rebuild: true);
  }

  String get _restorationScopeKey =>
      '${widget._source.name}:${widget._entityId.trim()}';

  void _saveRestorationNavigation() {
    widget.restorationController?._saveNavigation(
      scopeKey: _restorationScopeKey,
      initialLocationId: widget.locationId.trim(),
      currentLocationId: _currentLocationId,
      locationTrail: _locationTrail,
    );
  }

  void _retry() {
    if (_loadingCoordinator.initialLoadError != null) {
      _bumpCurrentRendererRevision();
      _loadingCoordinator.retryInitialTileLoad();
      return;
    }

    if (_imageError != null) {
      setState(() {
        _imageError = null;
        _bumpCurrentRendererRevision();
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
      _reportDisplayReadiness(false);
      _reportDisplayError(error);
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
      GenesisStaticNetworkImageProvider(imageUrl: assetUrl),
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

  TilemapImageLoadPlan _imageLoadPlanForViewport({
    required TilemapConfig config,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    return TilemapImageLoadPlan.forConfig(
      config: config,
      displayTilePixelSize:
          tilemapBaseTileExtent *
          _initialScale *
          tilemapImageDevicePixelRatio(devicePixelRatio),
      viewportSize: viewportSize,
      initialScale: _initialScale,
      dragBoundaryPaddingTiles: _dragBoundaryPaddingTiles,
      locationAvatarsForTile: _locationAvatarsForTile,
      preferredLocationId: _preferredVisibleFocusLocationId(config),
    );
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

  Widget _buildRenderer(
    TilemapConfig config, {
    required Key rendererKey,
    required bool interactive,
    required VoidCallback? onViewportReady,
    bool foreground = true,
    bool includeLiveContent = true,
    ValueChanged<Object>? backgroundImageError,
  }) {
    return TilemapRenderer(
      key: rendererKey,
      config: config,
      initialTransform: widget.restorationController?._viewportTransform(
        scopeKey: _restorationScopeKey,
        initialLocationId: widget.locationId.trim(),
        mapId: config.id,
      ),
      onTransformChanged: widget.restorationController == null
          ? null
          : (transform) {
              widget.restorationController?._saveViewportTransform(
                scopeKey: _restorationScopeKey,
                initialLocationId: widget.locationId.trim(),
                mapId: config.id,
                transform: transform,
              );
            },
      onTileAction: interactive ? _handleTileAction : null,
      locationNameForTile: _locationNameForTile,
      locationAvatarsForTile: _locationAvatarsForTile,
      showRecentChatForTile: _showRecentChatForTile,
      preferredFocusLocationId: _preferredVisibleFocusLocationId(config),
      messageBubbles: includeLiveContent
          ? widget.messageBubbles
          : const <WorldMapMessageBubble>[],
      messageBubblePlaybackPaused:
          !interactive ||
          !includeLiveContent ||
          widget.messageBubblePlaybackPaused,
      onMapTap: interactive ? widget.onMapTap : null,
      onImageError:
          backgroundImageError ??
          ((interactive || onViewportReady != null) &&
                  widget.tileImageLoader == null
              ? (error) => _handleImageError(config.id, error)
              : null),
      onViewportReady: onViewportReady,
      waitForVisibleTileImageFrames: widget.tileImageLoader == null,
      isForeground: foreground,
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

  int _rendererRevisionFor(TilemapConfig config) {
    return _rendererRevisionByMapId[config.id] ?? 0;
  }

  void _bumpCurrentRendererRevision() {
    final mapId = _currentConfig?.id;
    if (mapId != null) {
      _rendererRevisionByMapId[mapId] =
          (_rendererRevisionByMapId[mapId] ?? 0) + 1;
      _prerenderController.invalidateMap(mapId);
    }
  }

  String _mapIdForLocation(String rawLocationId) {
    return '${widget._source.name}:'
        '${widget._entityId.trim()}:'
        '${rawLocationId.trim()}';
  }

  List<String> _preferredPrerenderMapIds([TilemapConfig? config]) {
    final currentConfig = config ?? _currentConfig;
    final drillTargetIds = currentConfig == null
        ? const <String>[]
        : tilemapDrillTargetLocationIds(
            config: currentConfig,
            locationNodes: widget.locationNodes,
          ).take(tilemapSilentPreloadMaxPendingTargets).toList(growable: false);
    return <String>[
      if (_locationTrail.isNotEmpty) _mapIdForLocation(_locationTrail.last),
      for (final locationId in drillTargetIds) _mapIdForLocation(locationId),
    ];
  }

  VoidCallback _liveReadyCallbackFor(TilemapConfig config) {
    final environmentGeneration = _prerenderEnvironmentGeneration;
    final key =
        '${config.id}|${_rendererRevisionFor(config)}|$environmentGeneration';
    return _liveViewportReadyCallbacks.putIfAbsent(
      key,
      () =>
          () => _handleLiveViewportReady(config.id, environmentGeneration),
    );
  }

  Widget _buildLiveRendererSurface(
    TilemapConfig config, {
    required bool interactive,
    required bool foreground,
    required bool reportViewportReady,
  }) {
    final revision = _rendererRevisionFor(config);
    return TilemapPrerenderSurface(
      key: ValueKey<String>('tilemap-renderer-surface-${config.id}-$revision'),
      interactive: interactive,
      child: _buildRenderer(
        config,
        rendererKey: ValueKey<String>(
          'tilemap-live-renderer-${config.id}-$revision',
        ),
        interactive: interactive,
        foreground: foreground,
        includeLiveContent: foreground,
        onViewportReady: reportViewportReady
            ? _liveReadyCallbackFor(config)
            : null,
        backgroundImageError: widget.tileImageLoader != null
            ? null
            : (error) {
                if (_isCurrentMapId(config.id)) {
                  _handleImageError(config.id, error);
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _prerenderController.rejectMap(config.id);
                });
              },
      ),
    );
  }

  void _handleLiveViewportReady(String mapId, int environmentGeneration) {
    if (!mounted || environmentGeneration != _prerenderEnvironmentGeneration) {
      return;
    }

    final isCurrentTarget = _currentConfig?.id == mapId;
    if (isCurrentTarget) {
      _hasRevealedInitialMap = true;
      final config = _currentConfig;
      final viewportSize = _configuredPrerenderViewportSize;
      final devicePixelRatio = _configuredPrerenderDevicePixelRatio;
      if (config != null && viewportSize != null && devicePixelRatio != null) {
        _loadingCoordinator.scheduleBackgroundTilePreload(
          config: config,
          plan: _imageLoadPlanForViewport(
            config: config,
            viewportSize: viewportSize,
            devicePixelRatio: devicePixelRatio,
          ),
          loadImage: _loadTileImage,
        );
      }
    }
    _prerenderController.markReady(mapId);
    if (isCurrentTarget && _isCurrentDisplayReady) {
      _reportDisplayReadiness(true);
    }
  }

  bool get _isCurrentDisplayReady {
    return _settingsReady &&
        _currentConfig != null &&
        _hasRevealedInitialMap &&
        (_loadingCoordinator.initialEntryCompleted ||
            _loadingStyle == TilemapLoadingStyle.disabled) &&
        _imageError == null &&
        _mapError == null &&
        _loadingCoordinator.initialLoadError == null;
  }

  void _reportDisplayReadiness(bool ready) {
    if (_reportedDisplayReady == ready) return;
    _reportedDisplayReady = ready;
    if (widget.onDisplayReadinessChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reportedDisplayReady != ready) return;
      widget.onDisplayReadinessChanged?.call(ready);
    });
  }

  void _reportDisplayError(Object error) {
    if (widget.onDisplayError == null) return;
    final environmentGeneration = _prerenderEnvironmentGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          environmentGeneration != _prerenderEnvironmentGeneration) {
        return;
      }
      widget.onDisplayError?.call(error);
    });
  }

  int _userAvatarEnvironmentHash(UserAvatar avatar) {
    return Object.hash(
      avatar.id,
      avatar.initials,
      avatar.name,
      avatar.avatarUrl,
      avatar.showStar,
      avatar.isPlayerControlledRole,
    );
  }

  int _worldPointEnvironmentHash(WorldPoint point) {
    return Object.hashAll(<Object?>[
      point.id,
      point.name,
      point.type,
      point.position.dx,
      point.position.dy,
      point.sceneId,
      point.pointId,
      point.iconUrl,
      point.mapImageUrl,
      point.description,
      point.locationDescription,
      point.depth,
      point.isLeafLocation,
      Object.hashAll(point.users.map(_userAvatarEnvironmentHash)),
    ]);
  }

  int _locationNodeEnvironmentHash(WorldMapLocationNode node) {
    return Object.hashAll(<Object?>[
      node.id,
      _worldPointEnvironmentHash(node.point),
      node.mapImageUrl,
      node.isRoot,
      node.chatTargetPoint == null
          ? null
          : _worldPointEnvironmentHash(node.chatTargetPoint!),
      Object.hashAll(node.children.map(_locationNodeEnvironmentHash)),
    ]);
  }

  int _messageBubbleEnvironmentHash(WorldMapMessageBubble bubble) {
    return Object.hash(
      bubble.characterId,
      bubble.content,
      bubble.preservePageWidth,
    );
  }

  String _prerenderEnvironmentKey(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final renderSettings = _currentSettings.toJson()..remove('loading_style');
    return <Object?>[
      widget._source.name,
      widget._entityId,
      _cacheGeneration,
      renderSettings,
      Object.hashAll(widget.locationNodes.map(_locationNodeEnvironmentHash)),
      widget.preferredFocusLocationId,
      Object.hashAll(widget.messageBubbles.map(_messageBubbleEnvironmentHash)),
      widget.messageBubblePlaybackPaused,
      locale,
      textScale,
    ].join('|');
  }

  void _syncPrerenderEnvironment({
    required String environmentKey,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    final changed =
        _configuredPrerenderEnvironmentKey != null &&
        (_configuredPrerenderEnvironmentKey != environmentKey ||
            _configuredPrerenderViewportSize != viewportSize ||
            _configuredPrerenderDevicePixelRatio != devicePixelRatio);
    _configuredPrerenderEnvironmentKey = environmentKey;
    _configuredPrerenderViewportSize = viewportSize;
    _configuredPrerenderDevicePixelRatio = devicePixelRatio;
    if (!changed) return;

    _reportDisplayReadiness(false);
    _prerenderEnvironmentGeneration += 1;
    _liveViewportReadyCallbacks.clear();
  }

  Widget _buildMapViewport(BuildContext context, Size viewportSize) {
    if (!_settingsReady) {
      return ColoredBox(
        key: const ValueKey<String>('tilemap-settings-loading-background'),
        color: tilemapVisualStyleFor(_visualMode).backgroundColor,
      );
    }
    if (_imageError != null ||
        _mapError != null ||
        _loadingCoordinator.initialLoadError != null) {
      return _TilemapError(visualMode: _visualMode, onRetry: _retry);
    }

    final config = _currentConfig;
    final showInitialLoading =
        !_loadingCoordinator.initialEntryCompleted &&
        _loadingStyle != TilemapLoadingStyle.disabled;
    final environmentKey = _prerenderEnvironmentKey(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    _syncPrerenderEnvironment(
      environmentKey: environmentKey,
      viewportSize: viewportSize,
      devicePixelRatio: devicePixelRatio,
    );
    _prerenderController.configure(
      environmentKey:
          '$environmentKey|generation=$_prerenderEnvironmentGeneration',
      activeMapId: config?.id,
      preferredMapIds: _preferredPrerenderMapIds(config),
    );

    if (config != null && showInitialLoading) {
      _loadingCoordinator.ensureInitialMapReady(
        config: config,
        plan: _imageLoadPlanForViewport(
          config: config,
          viewportSize: viewportSize,
          devicePixelRatio: devicePixelRatio,
        ),
        loadImage: _loadTileImage,
      );
    }

    final displayMapId = config?.id;
    final liveReady =
        config != null && _hasRevealedInitialMap && !showInitialLoading;
    final children = <Widget>[];

    if (!showInitialLoading) {
      final residentConfigs = _prerenderController.residentConfigs;
      for (final residentConfig in residentConfigs) {
        if (residentConfig.id == displayMapId) continue;
        children.add(
          _buildLiveRendererSurface(
            residentConfig,
            interactive: false,
            foreground: false,
            reportViewportReady: !_prerenderController.isReady(
              residentConfig.id,
            ),
          ),
        );
      }
      for (final residentConfig in residentConfigs) {
        if (residentConfig.id != displayMapId) continue;
        children.add(
          _buildLiveRendererSurface(
            residentConfig,
            interactive: residentConfig.id == displayMapId,
            foreground: true,
            reportViewportReady: !_prerenderController.isReady(
              residentConfig.id,
            ),
          ),
        );
      }
    }

    if (showInitialLoading &&
        !_hasRevealedInitialMap &&
        !_loadingCoordinator.initialEntrySkipped) {
      children.add(
        TilemapLoadingOverlay(
          style: _loadingStyle,
          progress: _loadingCoordinator.initialProgress,
          visualMode: _visualMode,
          backgroundKey: const ValueKey<String>('tilemap-loading-background'),
        ),
      );
    } else if (displayMapId == null) {
      children.add(
        ColoredBox(
          key: ValueKey<String>(
            _hasRevealedInitialMap
                ? 'tilemap-transition-background'
                : 'tilemap-loading-background',
          ),
          color: tilemapVisualStyleFor(_visualMode).backgroundColor,
        ),
      );
    }

    if (liveReady) {
      final displayTilePixelSize =
          tilemapBaseTileExtent *
          _initialScale *
          tilemapImageDevicePixelRatio(MediaQuery.devicePixelRatioOf(context));
      _scheduleSilentDrillDownPreload(
        config,
        displayTilePixelSize: displayTilePixelSize,
      );
    }
    return Stack(fit: StackFit.expand, children: children);
  }

  @override
  Widget build(BuildContext context) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final viewportSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : mediaSize.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : mediaSize.height,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildMapViewport(context, viewportSize),
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
                  constraints: BoxConstraints(
                    maxHeight: settingsPanelMaxHeight,
                  ),
                  child: _TilemapSettingsPanel(
                    visualMode: _visualMode,
                    loadingStyle: _loadingStyle,
                    fogControlPoints: _fogControlPoints,
                    blendFogWithShadowTiles: _blendFogWithShadowTiles,
                    showShadowZeroBorders: _showShadowZeroBorders,
                    showLocationImageFlow: _showLocationImageFlow,
                    locationImageFlowAngleDegrees:
                        _locationImageFlowAngleDegrees,
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
                    onBlendFogWithShadowTilesChanged:
                        _setBlendFogWithShadowTiles,
                    onShowShadowZeroBordersChanged: _setShowShadowZeroBorders,
                    onShowLocationImageFlowChanged: _setShowLocationImageFlow,
                    onLocationImageFlowAngleDegreesChanged:
                        _setLocationImageFlowAngleDegrees,
                    onLocationImageFlowGradientPointsChanged:
                        _setLocationImageFlowGradientPoints,
                    onLocationImageFlowOpacityChanged:
                        _setLocationImageFlowOpacity,
                    onLocationImageFlowDurationSecondsChanged:
                        _setLocationImageFlowDurationSeconds,
                    onLocationImageFlowBlendModeChanged:
                        _setLocationImageFlowBlendMode,
                    onInitialScaleChanged: _setInitialScale,
                    onDragBoundaryPaddingTilesChanged:
                        _setDragBoundaryPaddingTiles,
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
      },
    );
  }
}
