import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../network/genesis_api.dart';
import '../../network/models/tilemap_definition.dart';
import '../world_map_avatar_logic.dart';
import '../world_map_location_action.dart';
import '../world_point.dart';
import 'tilemap_model.dart';
import 'tilemap_renderer.dart';
import 'tilemap_settings_store.dart';

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
  static const Duration _settingsSaveDelay = Duration(milliseconds: 250);

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
  TilemapVisualMode _visualMode = tilemapDefaultVisualMode;
  List<TilemapFogControlPoint> _fogControlPoints =
      tilemapDefaultFogControlPoints;
  bool _blendFogWithShadowTiles = false;
  bool _showShadowZeroBorders = true;
  double _initialScaleFactor = 1;
  bool _showSettings = false;
  bool _settingsReady = false;
  Timer? _settingsSaveTimer;

  @override
  void initState() {
    super.initState();
    _currentLocationId = widget.locationId.trim();
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
    if (entityChanged) _resetMapCache();
    _loadCurrentLocation(rebuild: false);
  }

  @override
  void dispose() {
    _cacheGeneration += 1;
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
      fogControlPoints: _fogControlPoints,
      blendFogWithShadowTiles: _blendFogWithShadowTiles,
      showShadowZeroBorders: _showShadowZeroBorders,
      initialScaleFactor: _initialScaleFactor,
    );
  }

  Future<void> _loadCachedSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) return;
    setState(() {
      _visualMode = settings.visualMode;
      _fogControlPoints = settings.fogControlPoints;
      _blendFogWithShadowTiles = settings.blendFogWithShadowTiles;
      _showShadowZeroBorders = settings.showShadowZeroBorders;
      _initialScaleFactor = settings.initialScaleFactor;
      _settingsReady = true;
    });
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

  Future<void> _persistSettings(TilemapRenderSettings settings) async {
    try {
      await _settingsStore.save(settings);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Tilemap] settings save failed: $error');
      }
    }
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

  void _setInitialScaleFactor(double value) {
    final resolved = value
        .clamp(tilemapInitialScaleFactorMin, tilemapInitialScaleFactorMax)
        .toDouble();
    if (_initialScaleFactor == resolved) return;
    setState(() => _initialScaleFactor = resolved);
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

  @override
  Widget build(BuildContext context) {
    late final Widget map;
    if (!_settingsReady) {
      map = ColoredBox(
        key: const ValueKey<String>('tilemap-settings-loading-background'),
        color: tilemapVisualStyleFor(_visualMode).backgroundColor,
      );
    } else if (_imageError != null || _mapError != null) {
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
              fogControlPoints: _fogControlPoints,
              blendFogWithShadowTiles: _blendFogWithShadowTiles,
              showShadowZeroBorders: _showShadowZeroBorders,
              initialScaleFactor: _initialScaleFactor,
            );
    }
    final settingsButtonTop =
        widget.visualModeToggleTop ?? MediaQuery.paddingOf(context).top + 6;
    final settingsPanelWidth =
        (MediaQuery.sizeOf(context).width - widget.visualModeToggleRight - 12)
            .clamp(260.0, 340.0)
            .toDouble();
    final settingsPanelMaxHeight =
        (MediaQuery.sizeOf(context).height - settingsButtonTop - 58)
            .clamp(220.0, 400.0)
            .toDouble();
    final showSettings =
        widget.showVisualModeToggle && _settingsReady && _showSettings;
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
            right: widget.visualModeToggleRight,
            top: settingsButtonTop + 46,
            child: SizedBox(
              width: settingsPanelWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: settingsPanelMaxHeight),
                child: _TilemapSettingsPanel(
                  visualMode: _visualMode,
                  fogControlPoints: _fogControlPoints,
                  blendFogWithShadowTiles: _blendFogWithShadowTiles,
                  showShadowZeroBorders: _showShadowZeroBorders,
                  initialScaleFactor: _initialScaleFactor,
                  onVisualModeChanged: _setVisualMode,
                  onFogControlPointsChanged: _setFogControlPoints,
                  onBlendFogWithShadowTilesChanged: _setBlendFogWithShadowTiles,
                  onShowShadowZeroBordersChanged: _setShowShadowZeroBorders,
                  onInitialScaleFactorChanged: _setInitialScaleFactor,
                  onCopySettings: _copySettingsToClipboard,
                  onClose: _closeSettings,
                ),
              ),
            ),
          ),
        if (widget.showVisualModeToggle && _settingsReady)
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

class _TilemapSettingsButton extends StatelessWidget {
  const _TilemapSettingsButton({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOpen ? 'Close map settings' : 'Open map settings',
      child: Material(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey<String>('tilemap-settings-button'),
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.settings_outlined,
              key: ValueKey<String>('tilemap-settings-icon'),
              color: Colors.black,
              size: 20,
              semanticLabel: 'Map settings',
            ),
          ),
        ),
      ),
    );
  }
}

class _TilemapSettingsPanel extends StatelessWidget {
  const _TilemapSettingsPanel({
    required this.visualMode,
    required this.fogControlPoints,
    required this.blendFogWithShadowTiles,
    required this.showShadowZeroBorders,
    required this.initialScaleFactor,
    required this.onVisualModeChanged,
    required this.onFogControlPointsChanged,
    required this.onBlendFogWithShadowTilesChanged,
    required this.onShowShadowZeroBordersChanged,
    required this.onInitialScaleFactorChanged,
    required this.onCopySettings,
    required this.onClose,
  });

  final TilemapVisualMode visualMode;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool showShadowZeroBorders;
  final double initialScaleFactor;
  final ValueChanged<TilemapVisualMode> onVisualModeChanged;
  final ValueChanged<List<TilemapFogControlPoint>> onFogControlPointsChanged;
  final ValueChanged<bool> onBlendFogWithShadowTilesChanged;
  final ValueChanged<bool> onShowShadowZeroBordersChanged;
  final ValueChanged<double> onInitialScaleFactorChanged;
  final VoidCallback onCopySettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = visualMode == TilemapVisualMode.dark;
    final backgroundColor = isDark
        ? const Color(0xF224241F)
        : const Color(0xF7FFFFFF);
    final foregroundColor = isDark ? Colors.white : const Color(0xFF25251F);
    final secondaryColor = foregroundColor.withValues(alpha: 0.68);
    final dividerColor = foregroundColor.withValues(alpha: 0.14);

    return Material(
      key: const ValueKey<String>('tilemap-settings-panel'),
      elevation: 12,
      color: backgroundColor,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Map settings',
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('tilemap-settings-copy-json'),
                  tooltip: 'Copy settings JSON',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopySettings,
                  icon: Icon(
                    Icons.copy_all_outlined,
                    color: foregroundColor,
                    size: 19,
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('tilemap-settings-close'),
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: foregroundColor, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Appearance',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TilemapModeChoice(
                    key: const ValueKey<String>('tilemap-settings-mode-light'),
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                    selected: visualMode == TilemapVisualMode.light,
                    foregroundColor: foregroundColor,
                    onTap: () => onVisualModeChanged(TilemapVisualMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TilemapModeChoice(
                    key: const ValueKey<String>('tilemap-settings-mode-dark'),
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                    selected: visualMode == TilemapVisualMode.dark,
                    foregroundColor: foregroundColor,
                    onTap: () => onVisualModeChanged(TilemapVisualMode.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Initial zoom adjustment',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Applied after fitting the shadow == 0 tile bounds.',
              style: TextStyle(color: secondaryColor, fontSize: 10),
            ),
            _TilemapSettingsSlider(
              label: 'Scale',
              value: initialScaleFactor,
              min: tilemapInitialScaleFactorMin,
              max: tilemapInitialScaleFactorMax,
              valueLabel: '${initialScaleFactor.toStringAsFixed(2)}×',
              sliderKey: const ValueKey<String>(
                'tilemap-settings-initial-scale',
              ),
              foregroundColor: foregroundColor,
              secondaryColor: secondaryColor,
              onChanged: onInitialScaleFactorChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: dividerColor),
            ),
            Text(
              'Fog gradient control points',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Drag points horizontally for position and vertically for opacity.',
              style: TextStyle(color: secondaryColor, fontSize: 11),
            ),
            const SizedBox(height: 8),
            _FogCurveEditor(
              points: fogControlPoints,
              foregroundColor: foregroundColor,
              secondaryColor: secondaryColor,
              onChanged: onFogControlPointsChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'Opacity fine tuning',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            for (var index = 0; index < fogControlPoints.length; index += 1)
              _FogOpacityEditor(
                index: index,
                points: fogControlPoints,
                foregroundColor: foregroundColor,
                secondaryColor: secondaryColor,
                onChanged: onFogControlPointsChanged,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: dividerColor),
            ),
            _TilemapSettingsSwitch(
              label: 'Blend fog with shadow == 1 tiles',
              value: blendFogWithShadowTiles,
              switchKey: const ValueKey<String>('tilemap-settings-fog-blend'),
              foregroundColor: foregroundColor,
              onChanged: onBlendFogWithShadowTilesChanged,
            ),
            _TilemapSettingsSwitch(
              label: 'Show shadow == 0 wireframe',
              value: showShadowZeroBorders,
              switchKey: const ValueKey<String>('tilemap-settings-wireframe'),
              foregroundColor: foregroundColor,
              onChanged: onShowShadowZeroBordersChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TilemapModeChoice extends StatelessWidget {
  const _TilemapModeChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFF7C6CF2).withValues(alpha: 0.26)
          : foregroundColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FogCurveEditor extends StatefulWidget {
  const _FogCurveEditor({
    required this.points,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final List<TilemapFogControlPoint> points;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<List<TilemapFogControlPoint>> onChanged;

  @override
  State<_FogCurveEditor> createState() => _FogCurveEditorState();
}

class _FogCurveEditorState extends State<_FogCurveEditor> {
  static const _plotPadding = EdgeInsets.fromLTRB(34, 12, 14, 24);

  int? _activePointIndex;

  Rect _plotRect(Size size) {
    return Rect.fromLTRB(
      _plotPadding.left,
      _plotPadding.top,
      size.width - _plotPadding.right,
      size.height - _plotPadding.bottom,
    );
  }

  Offset _offsetForPoint(TilemapFogControlPoint point, Rect plotRect) {
    return Offset(
      plotRect.left + plotRect.width * point.position,
      plotRect.bottom - plotRect.height * point.opacity,
    );
  }

  int? _closestPoint(Offset localPosition, Rect plotRect) {
    if (widget.points.isEmpty) return null;
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < widget.points.length; index += 1) {
      final distance =
          (_offsetForPoint(widget.points[index], plotRect) - localPosition)
              .distanceSquared;
      if (distance >= closestDistance) continue;
      closestIndex = index;
      closestDistance = distance;
    }
    return closestIndex;
  }

  void _startDrag(DragStartDetails details, Size size) {
    final index = _closestPoint(details.localPosition, _plotRect(size));
    setState(() => _activePointIndex = index);
    _updateDrag(details.localPosition, size);
  }

  void _updateDrag(Offset localPosition, Size size) {
    final index = _activePointIndex;
    if (index == null) return;
    final plotRect = _plotRect(size);
    final rawPosition = ((localPosition.dx - plotRect.left) / plotRect.width)
        .clamp(0.0, 1.0);
    final minPosition = index == 0
        ? 0.0
        : widget.points[index - 1].position + 0.01;
    final maxPosition = index == widget.points.length - 1
        ? 1.0
        : widget.points[index + 1].position - 0.01;
    final opacity = (1 - (localPosition.dy - plotRect.top) / plotRect.height)
        .clamp(0.0, 1.0);
    final updatedPoints = widget.points.toList(growable: false);
    updatedPoints[index] = updatedPoints[index].copyWith(
      position: rawPosition.clamp(minPosition, maxPosition).toDouble(),
      opacity: opacity.toDouble(),
    );
    widget.onChanged(updatedPoints);
  }

  void _endDrag() {
    if (_activePointIndex == null) return;
    setState(() => _activePointIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('tilemap-settings-fog-curve'),
      height: 160,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _FogCurveDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_FogCurveDragRecognizer>(
                    _FogCurveDragRecognizer.new,
                    (recognizer) {
                      recognizer.onStart = (details) {
                        _startDrag(details, size);
                      };
                      recognizer.onUpdate = (details) {
                        _updateDrag(details.localPosition, size);
                      };
                      recognizer.onEnd = (_) {
                        _endDrag();
                      };
                      recognizer.onCancel = _endDrag;
                    },
                  ),
            },
            child: CustomPaint(
              key: const ValueKey<String>('tilemap-settings-fog-curve-paint'),
              painter: _FogCurvePainter(
                points: widget.points,
                plotRect: _plotRect(size),
                foregroundColor: widget.foregroundColor,
                secondaryColor: widget.secondaryColor,
                activePointIndex: _activePointIndex,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FogCurveDragRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _FogCurvePainter extends CustomPainter {
  const _FogCurvePainter({
    required this.points,
    required this.plotRect,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.activePointIndex,
  });

  final List<TilemapFogControlPoint> points;
  final Rect plotRect;
  final Color foregroundColor;
  final Color secondaryColor;
  final int? activePointIndex;

  Offset _offsetForPoint(TilemapFogControlPoint point) {
    return Offset(
      plotRect.left + plotRect.width * point.position,
      plotRect.bottom - plotRect.height * point.opacity,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step += 1) {
      final fraction = step / 4;
      final x = plotRect.left + plotRect.width * fraction;
      final y = plotRect.top + plotRect.height * fraction;
      canvas
        ..drawLine(
          Offset(x, plotRect.top),
          Offset(x, plotRect.bottom),
          gridPaint,
        )
        ..drawLine(
          Offset(plotRect.left, y),
          Offset(plotRect.right, y),
          gridPaint,
        );
    }

    for (final label in const [
      (value: '100%', fraction: 0.0),
      (value: '0%', fraction: 1.0),
    ]) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label.value,
          style: TextStyle(color: secondaryColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          plotRect.left - textPainter.width - 5,
          plotRect.top +
              plotRect.height * label.fraction -
              textPainter.height / 2,
        ),
      );
    }

    if (points.isEmpty) return;
    const accentColor = Color(0xFF7C6CF2);
    final offsets = points.map(_offsetForPoint).toList(growable: false);
    final curvePath = Path()
      ..moveTo(plotRect.left, offsets.first.dy)
      ..lineTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      curvePath.lineTo(offset.dx, offset.dy);
    }
    curvePath.lineTo(plotRect.right, offsets.last.dy);

    final fillPath = Path.from(curvePath)
      ..lineTo(plotRect.right, plotRect.bottom)
      ..lineTo(plotRect.left, plotRect.bottom)
      ..close();
    canvas
      ..drawPath(fillPath, Paint()..color = accentColor.withValues(alpha: 0.12))
      ..drawPath(
        curvePath,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );

    for (var index = 0; index < offsets.length; index += 1) {
      final offset = offsets[index];
      final isActive = activePointIndex == index;
      canvas
        ..drawCircle(
          offset,
          isActive ? 8 : 6,
          Paint()..color = accentColor.withValues(alpha: 0.22),
        )
        ..drawCircle(offset, isActive ? 5 : 4, Paint()..color = accentColor);
      final positionLabel = TextPainter(
        text: TextSpan(
          text: '${(points[index].position * 100).round()}%',
          style: TextStyle(color: foregroundColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelLeft = (offset.dx - positionLabel.width / 2).clamp(
        0.0,
        size.width - positionLabel.width,
      );
      positionLabel.paint(
        canvas,
        Offset(labelLeft.toDouble(), plotRect.bottom + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FogCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.plotRect != plotRect ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.activePointIndex != activePointIndex;
  }
}

class _FogOpacityEditor extends StatelessWidget {
  const _FogOpacityEditor({
    required this.index,
    required this.points,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final int index;
  final List<TilemapFogControlPoint> points;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<List<TilemapFogControlPoint>> onChanged;

  @override
  Widget build(BuildContext context) {
    final point = points[index];

    void updatePoint(TilemapFogControlPoint updatedPoint) {
      final updatedPoints = points.toList(growable: false);
      updatedPoints[index] = updatedPoint;
      onChanged(updatedPoints);
    }

    return _TilemapSettingsSlider(
      label: 'P${index + 1} · ${(point.position * 100).round()}%',
      value: point.opacity,
      min: 0,
      max: 1,
      valueLabel: '${(point.opacity * 100).round()}%',
      sliderKey: ValueKey<String>('tilemap-settings-fog-opacity-$index'),
      foregroundColor: foregroundColor,
      secondaryColor: secondaryColor,
      onChanged: (value) => updatePoint(point.copyWith(opacity: value)),
    );
  }
}

class _TilemapSettingsSlider extends StatelessWidget {
  const _TilemapSettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.sliderKey,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final Key sliderKey;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: TextStyle(color: secondaryColor, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TilemapSettingsSwitch extends StatelessWidget {
  const _TilemapSettingsSwitch({
    required this.label,
    required this.value,
    required this.switchKey,
    required this.foregroundColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Key switchKey;
  final Color foregroundColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(key: switchKey, value: value, onChanged: onChanged),
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
