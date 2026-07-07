import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/page_header.dart';

const String tilemapDemoConfigAsset =
    'lib/pages/tilemap_demo/tilemap_demo_map.json';
const String tilemapDemoMap2RoomsConfigAsset =
    'lib/pages/tilemap_demo/tilemap_demo_map2_rooms.json';
const double tilemapBaseTileExtent = 16;
const double tilemapInitialScale = 8;
const double tilemapMinScale = 4;
const double tilemapMaxScale = 32;
const double tilemapScaleBoundaryResistance = 0.35;
const double tilemapMaxElasticScaleFactor = 1.25;
const double tilemapTransitionZoomTargetScale = 40;

const List<TilemapDemoMapOption> tilemapDemoMapOptions = <TilemapDemoMapOption>[
  TilemapDemoMapOption(label: 'Map1 demo', assetPath: tilemapDemoConfigAsset),
  TilemapDemoMapOption(
    label: 'Map2 rooms',
    assetPath: tilemapDemoMap2RoomsConfigAsset,
  ),
];

typedef TilemapDemoConfigLoader = Future<TilemapDemoConfig> Function();
typedef TilemapDemoAssetConfigLoader =
    Future<TilemapDemoConfig> Function(String assetPath);
typedef TilemapDemoTileActionHandler =
    Future<void> Function(TilemapDemoTile tile);

class TilemapDemoMapOption {
  const TilemapDemoMapOption({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class TilemapConfigException implements Exception {
  const TilemapConfigException(this.message);

  final String message;

  @override
  String toString() => 'TilemapConfigException: $message';
}

class TilemapDemoTile {
  const TilemapDemoTile({
    required this.x,
    required this.y,
    required this.type,
    this.interaction = const TilemapTileInteraction.none(),
  });

  final int x;
  final int y;
  final String type;
  final TilemapTileInteraction interaction;

  String get cellKey => '$x,$y';
}

class TilemapTileInteraction {
  const TilemapTileInteraction({
    required this.clickable,
    required this.highlightColor,
    this.transitionToMapAsset,
  });

  const TilemapTileInteraction.none()
    : clickable = false,
      highlightColor = const Color(0xFFFFD54F),
      transitionToMapAsset = null;

  final bool clickable;
  final Color highlightColor;
  final String? transitionToMapAsset;
}

class TilemapDemoConfig {
  const TilemapDemoConfig({
    required this.protocolVersion,
    required this.id,
    required this.width,
    required this.height,
    required this.tileTypes,
    required this.tiles,
  });

  final int protocolVersion;
  final String id;
  final int width;
  final int height;
  final Map<String, String> tileTypes;
  final List<TilemapDemoTile> tiles;

  int get tileCount => tiles.length;

  static Future<TilemapDemoConfig> loadDefault() {
    return loadAsset(tilemapDemoConfigAsset);
  }

  static Future<TilemapDemoConfig> loadAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return fromJsonString(raw);
  }

  static TilemapDemoConfig fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const TilemapConfigException('Root config must be a JSON object.');
    }
    return fromJsonMap(decoded);
  }

  static TilemapDemoConfig fromJsonMap(Map<String, dynamic> json) {
    final protocolVersion = _readInt(json, 'protocolVersion');
    if (protocolVersion != 1) {
      throw TilemapConfigException(
        'Unsupported protocolVersion: $protocolVersion.',
      );
    }

    final map = _readObject(json, 'map');
    final id = _readString(map, 'id');
    final width = _readInt(map, 'width');
    final height = _readInt(map, 'height');
    if (width <= 0 || height <= 0) {
      throw const TilemapConfigException('Map width and height must be > 0.');
    }

    final tileTypes = _readStringMap(json, 'tileTypes');
    if (tileTypes.isEmpty) {
      throw const TilemapConfigException('tileTypes must not be empty.');
    }
    for (final entry in tileTypes.entries) {
      if (entry.key.trim().isEmpty) {
        throw const TilemapConfigException('Tile type name must not be empty.');
      }
      if (!entry.value.endsWith('.png')) {
        throw TilemapConfigException(
          'Tile type ${entry.key} must point to a .png logical path.',
        );
      }
      if (RegExp(r'_\d+_\d+\.png$').hasMatch(entry.value)) {
        throw TilemapConfigException(
          'Tile type ${entry.key} must not include a size suffix.',
        );
      }
    }

    final rawTiles = _readList(json, 'tiles');
    if (rawTiles.isEmpty) {
      throw const TilemapConfigException('tiles must not be empty.');
    }

    final cells = <String, TilemapDemoTile>{};
    final tiles = <TilemapDemoTile>[];
    for (final rawTile in rawTiles) {
      if (rawTile is! Map<String, dynamic>) {
        throw const TilemapConfigException('Each tile must be a JSON object.');
      }
      final x = _readInt(rawTile, 'x');
      final y = _readInt(rawTile, 'y');
      final type = _readString(rawTile, 'type');
      if (x < 0 || x >= width || y < 0 || y >= height) {
        throw TilemapConfigException('Tile coordinate out of bounds: $x,$y.');
      }
      if (!tileTypes.containsKey(type)) {
        throw TilemapConfigException('Unknown tile type: $type.');
      }
      final cellKey = '$x,$y';
      if (cells.containsKey(cellKey)) {
        throw TilemapConfigException('Duplicate tile coordinate: $x,$y.');
      }
      final tile = TilemapDemoTile(
        x: x,
        y: y,
        type: type,
        interaction: _readTileInteraction(rawTile),
      );
      cells[cellKey] = tile;
      tiles.add(tile);
    }

    return TilemapDemoConfig(
      protocolVersion: protocolVersion,
      id: id,
      width: width,
      height: height,
      tileTypes: Map.unmodifiable(tileTypes),
      tiles: List<TilemapDemoTile>.unmodifiable(tiles),
    );
  }

  String assetForTile(TilemapDemoTile tile, double displayTilePixelSize) {
    final logicalPath = tileTypes[tile.type];
    if (logicalPath == null) {
      throw TilemapConfigException('Unknown tile type: ${tile.type}.');
    }
    return resolveTilemapAssetForDisplaySize(logicalPath, displayTilePixelSize);
  }
}

class TilemapProjection {
  const TilemapProjection({
    required this.mapWidth,
    required this.mapHeight,
    required this.tileExtent,
    required this.originX,
  });

  final double mapWidth;
  final double mapHeight;
  final double tileExtent;
  final double originX;

  static TilemapProjection fit({
    required int mapWidth,
    required int mapHeight,
    required double viewportWidth,
    required double viewportHeight,
    double viewportMargin = 16,
  }) {
    final usableWidth = math.max(1.0, viewportWidth - viewportMargin * 2);
    final usableHeight = math.max(1.0, viewportHeight - viewportMargin * 2);
    final tileExtentByWidth = usableWidth * 2 / (mapWidth + mapHeight);
    final heightUnits = 1 + (mapWidth + mapHeight - 2) / 4;
    final tileExtentByHeight = usableHeight / heightUnits;
    final tileExtent = math.max(
      1.0,
      math.min(tileExtentByWidth, tileExtentByHeight),
    );

    return TilemapProjection(
      mapWidth: (mapWidth + mapHeight) * tileExtent / 2,
      mapHeight: heightUnits * tileExtent,
      tileExtent: tileExtent,
      originX: (mapHeight - 1) * tileExtent / 2,
    );
  }

  static TilemapProjection fixed({
    required int mapWidth,
    required int mapHeight,
    double tileExtent = tilemapBaseTileExtent,
  }) {
    final heightUnits = 1 + (mapWidth + mapHeight - 2) / 4;
    return TilemapProjection(
      mapWidth: (mapWidth + mapHeight) * tileExtent / 2,
      mapHeight: heightUnits * tileExtent,
      tileExtent: tileExtent,
      originX: (mapHeight - 1) * tileExtent / 2,
    );
  }

  Offset topLeftForTile(TilemapDemoTile tile) {
    return Offset(
      originX + (tile.x - tile.y) * tileExtent / 2,
      (tile.x + tile.y) * tileExtent / 4,
    );
  }

  Offset imageTopLeftForTile(TilemapDemoTile tile) {
    final top = topLeftForTile(tile);
    return Offset(top.dx - tileExtent / 2, top.dy - tileExtent / 2);
  }

  List<Offset> polygonForTile(TilemapDemoTile tile) {
    final top = topLeftForTile(tile);
    return <Offset>[
      top,
      Offset(top.dx + tileExtent / 2, top.dy + tileExtent / 4),
      Offset(top.dx, top.dy + tileExtent / 2),
      Offset(top.dx - tileExtent / 2, top.dy + tileExtent / 4),
    ];
  }

  Offset centerForTile(TilemapDemoTile tile) {
    final polygon = polygonForTile(tile);
    final total = polygon.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + point,
    );
    return total / polygon.length.toDouble();
  }

  bool containsPointInTile(TilemapDemoTile tile, Offset point) {
    return _containsPointInPolygon(point, polygonForTile(tile));
  }

  double tilePixelSize({
    required double scale,
    required double devicePixelRatio,
  }) {
    return tileExtent * scale * devicePixelRatio;
  }

  Rect imageBoundsForTiles(Iterable<TilemapDemoTile> tiles) {
    final points = <Offset>[];
    for (final tile in tiles) {
      final topLeft = imageTopLeftForTile(tile);
      points
        ..add(topLeft)
        ..add(Offset(topLeft.dx + tileExtent, topLeft.dy + tileExtent));
    }
    return _boundsForOffsets(points);
  }
}

Matrix4 tilemapInitialTransform({
  required Size viewportSize,
  required Size mapSize,
  Rect? contentBounds,
  double scale = tilemapInitialScale,
}) {
  final bounds = contentBounds ?? Offset.zero & mapSize;
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportSize.width / 2 - bounds.center.dx * scale,
      viewportSize.height / 2 - bounds.center.dy * scale,
      0,
    );
}

double tilemapTransformScale(Matrix4 transform) => transform.storage[0].abs();

Matrix4 tilemapGestureTransform({
  required Matrix4 startTransform,
  required Offset startFocalPoint,
  required Offset currentFocalPoint,
  required double gestureScale,
  double minScale = tilemapMinScale,
  double maxScale = tilemapMaxScale,
  bool allowElasticBoundary = false,
}) {
  final startScale = tilemapTransformScale(startTransform);
  final rawTargetScale = startScale * gestureScale;
  final targetScale = allowElasticBoundary
      ? tilemapElasticScale(
          rawTargetScale,
          minScale: minScale,
          maxScale: maxScale,
        )
      : rawTargetScale.clamp(minScale, maxScale).toDouble();
  final sceneFocalPoint = MatrixUtils.transformPoint(
    Matrix4.inverted(startTransform),
    startFocalPoint,
  );
  return tilemapTransformForSceneFocalPoint(
    sceneFocalPoint: sceneFocalPoint,
    viewportFocalPoint: currentFocalPoint,
    scale: targetScale,
  );
}

double tilemapElasticScale(
  double rawScale, {
  double minScale = tilemapMinScale,
  double maxScale = tilemapMaxScale,
  double boundaryResistance = tilemapScaleBoundaryResistance,
  double maxElasticScaleFactor = tilemapMaxElasticScaleFactor,
}) {
  if (rawScale > maxScale) {
    final elasticMaxScale = maxScale * maxElasticScaleFactor;
    return (maxScale + (rawScale - maxScale) * boundaryResistance)
        .clamp(maxScale, elasticMaxScale)
        .toDouble();
  }
  if (rawScale < minScale) {
    final elasticMinScale = minScale / maxElasticScaleFactor;
    return (minScale - (minScale - rawScale) * boundaryResistance)
        .clamp(elasticMinScale, minScale)
        .toDouble();
  }
  return rawScale;
}

Matrix4 tilemapTransformForSceneFocalPoint({
  required Offset sceneFocalPoint,
  required Offset viewportFocalPoint,
  required double scale,
}) {
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportFocalPoint.dx - sceneFocalPoint.dx * scale,
      viewportFocalPoint.dy - sceneFocalPoint.dy * scale,
      0,
    );
}

Matrix4 tilemapBoundedScaleTransform({
  required Matrix4 currentTransform,
  required Offset focalPoint,
  double minScale = tilemapMinScale,
  double maxScale = tilemapMaxScale,
}) {
  final currentScale = tilemapTransformScale(currentTransform);
  final boundedScale = currentScale.clamp(minScale, maxScale).toDouble();
  if (boundedScale == currentScale) {
    return currentTransform.clone();
  }
  final sceneFocalPoint = MatrixUtils.transformPoint(
    Matrix4.inverted(currentTransform),
    focalPoint,
  );
  return tilemapTransformForSceneFocalPoint(
    sceneFocalPoint: sceneFocalPoint,
    viewportFocalPoint: focalPoint,
    scale: boundedScale,
  );
}

Matrix4 tilemapZoomTowardScenePoint({
  required Matrix4 currentTransform,
  required Offset scenePoint,
  required Offset viewportPoint,
  double targetScale = tilemapTransitionZoomTargetScale,
}) {
  return tilemapTransformForSceneFocalPoint(
    sceneFocalPoint: scenePoint,
    viewportFocalPoint: viewportPoint,
    scale: targetScale,
  );
}

String resolveTilemapAssetForDisplaySize(
  String logicalPath,
  double displayTilePixelSize,
) {
  if (!logicalPath.endsWith('.png')) {
    throw TilemapConfigException(
      'Tile asset logical path must end with .png: $logicalPath.',
    );
  }
  final requestedSize =
      displayTilePixelSize.isFinite && displayTilePixelSize > 0
      ? displayTilePixelSize.ceil()
      : 128;
  const availableSizes = <int>[128, 256, 512, 1024];
  final resolvedSize = availableSizes.firstWhere(
    (size) => size >= requestedSize,
    orElse: () => availableSizes.last,
  );
  return logicalPath.replaceFirst(
    RegExp(r'\.png$'),
    '_${resolvedSize}_$resolvedSize.png',
  );
}

class TilemapDemoPage extends StatefulWidget {
  const TilemapDemoPage({
    super.key,
    this.configLoader,
    this.configAssetLoader,
    this.mapOptions = tilemapDemoMapOptions,
  });

  final TilemapDemoConfigLoader? configLoader;
  final TilemapDemoAssetConfigLoader? configAssetLoader;
  final List<TilemapDemoMapOption> mapOptions;

  @override
  State<TilemapDemoPage> createState() => _TilemapDemoPageState();
}

class _TilemapDemoPageState extends State<TilemapDemoPage> {
  late Future<TilemapDemoConfig> _configFuture;
  late TilemapDemoMapOption _selectedMapOption;
  TilemapDemoConfig? _lastLoadedConfig;

  @override
  void initState() {
    super.initState();
    _selectedMapOption = widget.mapOptions.first;
    _configFuture = _loadSelectedConfig();
  }

  @override
  void didUpdateWidget(covariant TilemapDemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configLoader == widget.configLoader &&
        oldWidget.configAssetLoader == widget.configAssetLoader &&
        oldWidget.mapOptions == widget.mapOptions) {
      return;
    }
    if (!widget.mapOptions.contains(_selectedMapOption)) {
      _selectedMapOption = widget.mapOptions.first;
    }
    _configFuture = _loadSelectedConfig();
  }

  Future<TilemapDemoConfig> _loadSelectedConfig() {
    return widget.configLoader?.call() ??
        widget.configAssetLoader?.call(_selectedMapOption.assetPath) ??
        TilemapDemoConfig.loadAsset(_selectedMapOption.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'Tilemap demo'),
      body: SafeArea(
        child: FutureBuilder<TilemapDemoConfig>(
          future: _configFuture,
          builder: (context, snapshot) {
            final config = snapshot.data ?? _lastLoadedConfig;
            if (snapshot.connectionState != ConnectionState.done &&
                config == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || config == null) {
              return _TilemapErrorState(error: snapshot.error);
            }
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data != null) {
              _lastLoadedConfig = snapshot.data;
            }
            final canSelectMap =
                widget.configLoader == null && widget.mapOptions.length > 1;
            return _TilemapDemoContent(
              config: config,
              canSelectMap: canSelectMap,
              onSelectMap: canSelectMap ? _showMapPicker : null,
              onTileAction: _handleTileAction,
            );
          },
        ),
      ),
    );
  }

  Future<void> _showMapPicker() async {
    final selected = await showDialog<TilemapDemoMapOption>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择地图'),
          children: [
            for (final option in widget.mapOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(option),
                child: Row(
                  children: [
                    Expanded(child: Text(option.label)),
                    if (option.assetPath == _selectedMapOption.assetPath)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
          ],
        );
      },
    );
    if (selected == null ||
        selected.assetPath == _selectedMapOption.assetPath ||
        !mounted) {
      return;
    }
    setState(() {
      _selectedMapOption = selected;
      _configFuture = _loadSelectedConfig();
    });
  }

  Future<void> _handleTileAction(TilemapDemoTile tile) async {
    final targetAssetPath = tile.interaction.transitionToMapAsset;
    if (targetAssetPath == null || !mounted) return;
    TilemapDemoMapOption? matchingOption;
    for (final option in widget.mapOptions) {
      if (option.assetPath == targetAssetPath) {
        matchingOption = option;
        break;
      }
    }
    if (matchingOption == null ||
        matchingOption.assetPath == _selectedMapOption.assetPath) {
      return;
    }
    final targetOption = matchingOption;
    setState(() {
      _selectedMapOption = targetOption;
      _configFuture = _loadSelectedConfig();
    });
  }
}

class _TilemapErrorState extends StatelessWidget {
  const _TilemapErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Tilemap config failed to load.\n${error ?? 'Unknown error'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFFB42318)),
        ),
      ),
    );
  }
}

class _TilemapDemoContent extends StatelessWidget {
  const _TilemapDemoContent({
    required this.config,
    required this.canSelectMap,
    required this.onSelectMap,
    required this.onTileAction,
  });

  final TilemapDemoConfig config;
  final bool canSelectMap;
  final VoidCallback? onSelectMap;
  final TilemapDemoTileActionHandler? onTileAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: _TilemapDemoHeader(
            config: config,
            canSelectMap: canSelectMap,
            onSelectMap: onSelectMap,
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: _TilemapGrid(
              key: ValueKey(config.id),
              config: config,
              onTileAction: onTileAction,
            ),
          ),
        ),
      ],
    );
  }
}

class _TilemapDemoHeader extends StatelessWidget {
  const _TilemapDemoHeader({
    required this.config,
    required this.canSelectMap,
    required this.onSelectMap,
  });

  final TilemapDemoConfig config;
  final bool canSelectMap;
  final VoidCallback? onSelectMap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: const ValueKey<String>('tilemap-demo-map-selector'),
              borderRadius: BorderRadius.circular(6),
              onTap: canSelectMap ? onSelectMap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        config.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (canSelectMap)
                      const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: Color(0xFF555555),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${config.width} x ${config.height} / ${config.tileCount} tiles',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TilemapGrid extends StatefulWidget {
  const _TilemapGrid({
    super.key,
    required this.config,
    required this.onTileAction,
  });

  final TilemapDemoConfig config;
  final TilemapDemoTileActionHandler? onTileAction;

  @override
  State<_TilemapGrid> createState() => _TilemapGridState();
}

class _TilemapGridState extends State<_TilemapGrid>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _highlightController;
  late final AnimationController _scaleBoundaryController;
  late final AnimationController _tileActionZoomController;
  late final Animation<double> _highlightOpacity;
  late final Animation<double> _tileActionOpacity;
  Animation<Matrix4>? _scaleBoundaryAnimation;
  Animation<Matrix4>? _tileActionZoomAnimation;
  Matrix4 _gestureStartTransform = Matrix4.identity();
  Offset _gestureStartFocalPoint = Offset.zero;
  Offset _lastGestureFocalPoint = Offset.zero;
  Offset _scaleBoundaryFocalPoint = Offset.zero;
  bool _hasScaleBoundaryFocalPoint = false;
  Size? _lastViewportSize;
  Size? _lastMapSize;
  Rect? _lastContentBounds;
  bool _hasUserTransformedMap = false;
  bool _isRunningTileActionTransition = false;
  String? _highlightedTileKey;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _highlightOpacity = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOutCubic,
    ).drive(Tween<double>(begin: 0.48, end: 0));
    _scaleBoundaryController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _scaleBoundaryAnimation;
          if (animation == null) return;
          _transformationController.value = animation.value;
        });
    _tileActionZoomController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 210),
        )..addListener(() {
          final animation = _tileActionZoomAnimation;
          if (animation == null) return;
          _transformationController.value = animation.value;
        });
    _tileActionOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _tileActionZoomController,
        curve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _tileActionZoomController.dispose();
    _scaleBoundaryController.dispose();
    _highlightController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final projection = TilemapProjection.fixed(
          mapWidth: widget.config.width,
          mapHeight: widget.config.height,
        );
        final viewportSize = Size(viewportWidth, viewportHeight);
        final mapSize = Size(projection.mapWidth, projection.mapHeight);
        final contentBounds = projection.imageBoundsForTiles(
          widget.config.tiles,
        );
        _syncInitialTransform(
          viewportSize: viewportSize,
          mapSize: mapSize,
          contentBounds: contentBounds,
        );
        return SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: ClipRect(
            child: GestureDetector(
              key: const ValueKey<String>('tilemap-demo-gesture-layer'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _scaleBoundaryController.stop();
                _tileActionZoomController.stop();
                _hasUserTransformedMap = true;
                _gestureStartTransform = _transformationController.value
                    .clone();
                _gestureStartFocalPoint = details.localFocalPoint;
                _lastGestureFocalPoint = details.localFocalPoint;
                _scaleBoundaryFocalPoint = details.localFocalPoint;
                _hasScaleBoundaryFocalPoint = false;
              },
              onScaleUpdate: (details) {
                _lastGestureFocalPoint = details.localFocalPoint;
                final rawTargetScale =
                    tilemapTransformScale(_gestureStartTransform) *
                    details.scale;
                _updateScaleBoundaryFocalPoint(
                  rawTargetScale: rawTargetScale,
                  focalPoint: details.localFocalPoint,
                );
                final transformFocalPoint = _hasScaleBoundaryFocalPoint
                    ? _scaleBoundaryFocalPoint
                    : details.localFocalPoint;
                _transformationController.value = tilemapGestureTransform(
                  startTransform: _gestureStartTransform,
                  startFocalPoint: _gestureStartFocalPoint,
                  currentFocalPoint: transformFocalPoint,
                  gestureScale: details.scale,
                  allowElasticBoundary: true,
                );
              },
              onScaleEnd: (_) {
                _settleScaleBoundary();
              },
              onTapUp: (details) {
                unawaited(_handleTap(details.localPosition, projection));
              },
              child: ValueListenableBuilder<Matrix4>(
                valueListenable: _transformationController,
                builder: (context, matrix, _) {
                  final scale = tilemapTransformScale(matrix);
                  final tilePixelSize = projection.tilePixelSize(
                    scale: scale,
                    devicePixelRatio: devicePixelRatio,
                  );
                  final tiles = widget.config.tiles.toList(growable: false)
                    ..sort((a, b) {
                      final diagonal = (a.x + a.y).compareTo(b.x + b.y);
                      if (diagonal != 0) return diagonal;
                      return a.x.compareTo(b.x);
                    });
                  return AnimatedBuilder(
                    animation: Listenable.merge([
                      _highlightController,
                      _tileActionZoomController,
                    ]),
                    builder: (context, _) {
                      final highlightedTile = _highlightedTile(
                        tiles,
                        _highlightOpacity.value,
                      );
                      return Opacity(
                        opacity: _tileActionOpacity.value,
                        child: Transform(
                          transform: matrix,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: projection.mapWidth,
                            height: projection.mapHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (final tile in tiles)
                                  _ProjectedTile(
                                    key: ValueKey<String>(
                                      'tile-${tile.x}-${tile.y}',
                                    ),
                                    tile: tile,
                                    asset: widget.config.assetForTile(
                                      tile,
                                      tilePixelSize,
                                    ),
                                    topLeft: projection.imageTopLeftForTile(
                                      tile,
                                    ),
                                    extent: projection.tileExtent,
                                  ),
                                if (highlightedTile != null)
                                  _ProjectedTileHighlight(
                                    key: ValueKey<String>(
                                      'tile-highlight-${highlightedTile.x}-${highlightedTile.y}',
                                    ),
                                    tile: highlightedTile,
                                    projection: projection,
                                    opacity: _highlightOpacity.value,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  TilemapDemoTile? _highlightedTile(
    List<TilemapDemoTile> sortedTiles,
    double opacity,
  ) {
    final highlightedTileKey = _highlightedTileKey;
    if (highlightedTileKey == null || opacity <= 0.001) return null;
    for (final tile in sortedTiles) {
      if (tile.cellKey == highlightedTileKey) return tile;
    }
    return null;
  }

  Future<void> _handleTap(
    Offset localPosition,
    TilemapProjection projection,
  ) async {
    if (_isRunningTileActionTransition) return;
    final scenePosition = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformationController.value),
      localPosition,
    );
    final tiles = widget.config.tiles.toList(growable: false)
      ..sort((a, b) {
        final diagonal = (a.x + a.y).compareTo(b.x + b.y);
        if (diagonal != 0) return diagonal;
        return a.x.compareTo(b.x);
      });
    for (final tile in tiles.reversed) {
      if (!tile.interaction.clickable) continue;
      if (!projection.containsPointInTile(tile, scenePosition)) continue;
      setState(() {
        _highlightedTileKey = tile.cellKey;
      });
      _highlightController.forward(from: 0);
      if (tile.interaction.transitionToMapAsset != null) {
        await _runTileActionTransition(
          tile: tile,
          scenePosition: scenePosition,
          localPosition: localPosition,
        );
      }
      return;
    }
  }

  Future<void> _runTileActionTransition({
    required TilemapDemoTile tile,
    required Offset scenePosition,
    required Offset localPosition,
  }) async {
    final onTileAction = widget.onTileAction;
    if (onTileAction == null) return;
    _isRunningTileActionTransition = true;
    _scaleBoundaryController.stop();
    try {
      _tileActionZoomAnimation =
          Matrix4Tween(
            begin: _transformationController.value.clone(),
            end: tilemapZoomTowardScenePoint(
              currentTransform: _transformationController.value,
              scenePoint: scenePosition,
              viewportPoint: localPosition,
            ),
          ).animate(
            CurvedAnimation(
              parent: _tileActionZoomController,
              curve: Curves.easeOutCubic,
            ),
          );
      await _tileActionZoomController.forward(from: 0);
      if (!mounted) return;
      await onTileAction(tile);
    } finally {
      _isRunningTileActionTransition = false;
    }
  }

  void _syncInitialTransform({
    required Size viewportSize,
    required Size mapSize,
    required Rect contentBounds,
  }) {
    if (_lastViewportSize == viewportSize &&
        _lastMapSize == mapSize &&
        _lastContentBounds == contentBounds) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    _lastContentBounds = contentBounds;
    if (_hasUserTransformedMap) return;
    _transformationController.value = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: mapSize,
      contentBounds: contentBounds,
    );
  }

  void _settleScaleBoundary() {
    final currentTransform = _transformationController.value;
    final targetTransform = tilemapBoundedScaleTransform(
      currentTransform: currentTransform,
      focalPoint: _hasScaleBoundaryFocalPoint
          ? _scaleBoundaryFocalPoint
          : _lastGestureFocalPoint,
    );
    if (_nearlySameScaleAndTranslation(currentTransform, targetTransform)) {
      return;
    }
    _scaleBoundaryAnimation =
        Matrix4Tween(
          begin: currentTransform.clone(),
          end: targetTransform,
        ).animate(
          CurvedAnimation(
            parent: _scaleBoundaryController,
            curve: Curves.easeOutBack,
          ),
        );
    _scaleBoundaryController.forward(from: 0);
  }

  void _updateScaleBoundaryFocalPoint({
    required double rawTargetScale,
    required Offset focalPoint,
  }) {
    final isOutsideScaleBoundary =
        rawTargetScale > tilemapMaxScale || rawTargetScale < tilemapMinScale;
    if (isOutsideScaleBoundary) {
      if (!_hasScaleBoundaryFocalPoint) {
        _scaleBoundaryFocalPoint = focalPoint;
        _hasScaleBoundaryFocalPoint = true;
      }
      return;
    }
    _scaleBoundaryFocalPoint = focalPoint;
    _hasScaleBoundaryFocalPoint = false;
  }

  bool _nearlySameScaleAndTranslation(Matrix4 a, Matrix4 b) {
    const epsilon = 0.001;
    return (tilemapTransformScale(a) - tilemapTransformScale(b)).abs() <
            epsilon &&
        (a.getTranslation().x - b.getTranslation().x).abs() < epsilon &&
        (a.getTranslation().y - b.getTranslation().y).abs() < epsilon;
  }
}

class _ProjectedTileHighlight extends StatelessWidget {
  const _ProjectedTileHighlight({
    super.key,
    required this.tile,
    required this.projection,
    required this.opacity,
  });

  final TilemapDemoTile tile;
  final TilemapProjection projection;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final polygon = projection.polygonForTile(tile);
    final bounds = _boundsForOffsets(polygon);
    return Positioned.fromRect(
      rect: bounds,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TileHighlightPainter(
            polygon: polygon
                .map((point) => point - bounds.topLeft)
                .toList(growable: false),
            color: tile.interaction.highlightColor.withValues(
              alpha: opacity.clamp(0, 1).toDouble(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileHighlightPainter extends CustomPainter {
  const _TileHighlightPainter({required this.polygon, required this.color});

  final List<Offset> polygon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 3 || color.a <= 0) return;
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TileHighlightPainter oldDelegate) {
    return oldDelegate.polygon != polygon || oldDelegate.color != color;
  }
}

class _ProjectedTile extends StatelessWidget {
  const _ProjectedTile({
    super.key,
    required this.tile,
    required this.asset,
    required this.topLeft,
    required this.extent,
  });

  final TilemapDemoTile tile;
  final String asset;
  final Offset topLeft;
  final double extent;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: extent,
      height: extent,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.none,
        semanticLabel: '${tile.type} ${tile.x},${tile.y}',
      ),
    );
  }
}

TilemapTileInteraction _readTileInteraction(Map<String, dynamic> tileJson) {
  final value = tileJson['interaction'];
  if (value == null) return const TilemapTileInteraction.none();
  if (value is! Map<String, dynamic>) {
    throw const TilemapConfigException('interaction must be a JSON object.');
  }
  final clickable = _readBool(value, 'clickable');
  final highlightColor = value.containsKey('highlightColor')
      ? _readHexColor(value, 'highlightColor')
      : const Color(0xFFFFD54F);
  final transitionToMapAsset = value.containsKey('transitionToMapAsset')
      ? _readString(value, 'transitionToMapAsset')
      : null;
  return TilemapTileInteraction(
    clickable: clickable,
    highlightColor: highlightColor,
    transitionToMapAsset: transitionToMapAsset,
  );
}

Rect _boundsForOffsets(List<Offset> points) {
  if (points.isEmpty) return Rect.zero;
  var left = points.first.dx;
  var top = points.first.dy;
  var right = points.first.dx;
  var bottom = points.first.dy;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _containsPointInPolygon(Offset point, List<Offset> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects =
        (pi.dy > point.dy) != (pj.dy > point.dy) &&
        point.dx <
            (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
    if (intersects) inside = !inside;
  }
  return inside;
}

Map<String, dynamic> _readObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw TilemapConfigException('$key must be a JSON object.');
}

List<dynamic> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List<dynamic>) return value;
  throw TilemapConfigException('$key must be a JSON array.');
}

Map<String, String> _readStringMap(Map<String, dynamic> json, String key) {
  final value = _readObject(json, key);
  return value.map((rawKey, rawValue) {
    if (rawValue is! String) {
      throw TilemapConfigException('$key.$rawKey must be a string.');
    }
    return MapEntry(rawKey, rawValue);
  });
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw TilemapConfigException('$key must be a non-empty string.');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw TilemapConfigException('$key must be an integer.');
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw TilemapConfigException('$key must be a boolean.');
}

Color _readHexColor(Map<String, dynamic> json, String key) {
  final value = _readString(json, key);
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(normalized)) {
    throw TilemapConfigException('$key must be a #RRGGBB or #RRGGBBAA color.');
  }
  final rgba = normalized.length == 6 ? '${normalized}FF' : normalized;
  final red = int.parse(rgba.substring(0, 2), radix: 16);
  final green = int.parse(rgba.substring(2, 4), radix: 16);
  final blue = int.parse(rgba.substring(4, 6), radix: 16);
  final alpha = int.parse(rgba.substring(6, 8), radix: 16);
  return Color.fromARGB(alpha, red, green, blue);
}
