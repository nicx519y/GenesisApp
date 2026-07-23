import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../world_point.dart';
import 'tilemap_location_avatars.dart';
import 'tilemap_model.dart';

const double tilemapBaseTileExtent = 16;
const double tilemapPlaceholderScale = 10;
const double tilemapInitialHorizontalMargin = 16;
const double tilemapMinScale = 5;
const double tilemapMaxScale = 22;
const double tilemapInitialScaleFactorMin = 0.5;
const double tilemapInitialScaleFactorMax = 2;

typedef TilemapTileActionHandler = Future<void> Function(TilemapCell tile);
typedef TilemapLocationNameResolver = String? Function(TilemapCell tile);
typedef TilemapLocationAvatarsResolver =
    List<UserAvatar> Function(TilemapCell tile);

enum TilemapVisualMode { light, dark }

const TilemapVisualMode tilemapDefaultVisualMode = TilemapVisualMode.dark;

@immutable
class TilemapVisualStyle {
  const TilemapVisualStyle({
    required this.backgroundColor,
    required this.gridLineColor,
  });

  final Color backgroundColor;
  final Color gridLineColor;
}

const TilemapVisualStyle tilemapLightVisualStyle = TilemapVisualStyle(
  backgroundColor: Color(0xFFFAFAF8),
  gridLineColor: Color(0xFFD7D6D2),
);
const TilemapVisualStyle tilemapDarkVisualStyle = TilemapVisualStyle(
  backgroundColor: Color(0xFF37362E),
  gridLineColor: Color(0xFF2E2D26),
);

TilemapVisualStyle tilemapVisualStyleFor(TilemapVisualMode mode) {
  return switch (mode) {
    TilemapVisualMode.light => tilemapLightVisualStyle,
    TilemapVisualMode.dark => tilemapDarkVisualStyle,
  };
}

const Color tilemapLocationHighlightColor = Color(0xFFFFD54F);
// The fog reaches solid black 1.5 tile extents outside the land edge.
const double tilemapFogFadeTileExtents = 1.5;
const double tilemapFogMaxOpacity = 1;
const double tilemapFogSamplesPerTileExtent = 4;
const BlendMode tilemapFogVertexBlendMode = BlendMode.modulate;
const Color tilemapShadowZeroBorderColor = Color(0xFFFFFF00);
const double tilemapShadowZeroBorderWidth = 2;

@immutable
class TilemapFogControlPoint {
  const TilemapFogControlPoint({required this.position, required this.opacity});

  final double position;
  final double opacity;

  TilemapFogControlPoint copyWith({double? position, double? opacity}) {
    return TilemapFogControlPoint(
      position: position ?? this.position,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TilemapFogControlPoint &&
        other.position == position &&
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(position, opacity);
}

const List<TilemapFogControlPoint> tilemapDefaultFogControlPoints = [
  TilemapFogControlPoint(position: 0, opacity: 0),
  TilemapFogControlPoint(position: 0.25, opacity: 0.15625),
  TilemapFogControlPoint(position: 0.5, opacity: 0.5),
  TilemapFogControlPoint(position: 0.75, opacity: 0.84375),
  TilemapFogControlPoint(position: 1, opacity: 1),
];

double tilemapFogOpacityForDistance({
  required double distance,
  required double tileExtent,
  List<TilemapFogControlPoint> controlPoints = tilemapDefaultFogControlPoints,
}) {
  if (!distance.isFinite || distance <= 0) {
    return controlPoints.isEmpty
        ? 0
        : controlPoints.first.opacity.clamp(0, 1).toDouble();
  }
  final fadeDistance = tileExtent * tilemapFogFadeTileExtents;
  if (!fadeDistance.isFinite || fadeDistance <= 0) {
    return tilemapFogMaxOpacity;
  }
  final t = (distance / fadeDistance).clamp(0.0, 1.0);
  if (controlPoints.isEmpty) return tilemapFogMaxOpacity * t;
  if (t <= controlPoints.first.position) {
    return tilemapFogMaxOpacity *
        controlPoints.first.opacity.clamp(0, 1).toDouble();
  }
  for (var index = 1; index < controlPoints.length; index += 1) {
    final previous = controlPoints[index - 1];
    final current = controlPoints[index];
    if (t > current.position) continue;
    final span = current.position - previous.position;
    final segmentT = span <= 0
        ? 1.0
        : ((t - previous.position) / span).clamp(0.0, 1.0);
    final opacity =
        previous.opacity + (current.opacity - previous.opacity) * segmentT;
    return tilemapFogMaxOpacity * opacity.clamp(0, 1).toDouble();
  }
  return tilemapFogMaxOpacity *
      controlPoints.last.opacity.clamp(0, 1).toDouble();
}

double tilemapFogDistanceToSegment({
  required Offset point,
  required Offset start,
  required Offset end,
  required double verticalScale,
}) {
  final resolvedVerticalScale = verticalScale.isFinite && verticalScale > 0
      ? verticalScale
      : 1.0;
  final scaledPoint = Offset(point.dx, point.dy * resolvedVerticalScale);
  final scaledStart = Offset(start.dx, start.dy * resolvedVerticalScale);
  final scaledEnd = Offset(end.dx, end.dy * resolvedVerticalScale);
  final delta = scaledEnd - scaledStart;
  final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
  if (lengthSquared == 0) return (scaledPoint - scaledStart).distance;
  final relative = scaledPoint - scaledStart;
  final t = ((relative.dx * delta.dx + relative.dy * delta.dy) / lengthSquared)
      .clamp(0.0, 1.0);
  return (scaledPoint - (scaledStart + delta * t)).distance;
}

class TilemapGridBackground extends StatelessWidget {
  const TilemapGridBackground({
    super.key,
    this.visualMode = tilemapDefaultVisualMode,
  });

  final TilemapVisualMode visualMode;

  @override
  Widget build(BuildContext context) {
    final visualStyle = tilemapVisualStyleFor(visualMode);
    return ColoredBox(
      key: const ValueKey<String>('tilemap-grid-background'),
      color: visualStyle.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height,
          );
          const projection = TilemapProjection(
            mapWidth: tilemapBaseTileExtent,
            mapHeight: tilemapBaseTileExtent,
            tileExtent: tilemapBaseTileExtent,
            originX: 0,
          );
          return CustomPaint(
            painter: _TilemapInfiniteGridPainter(
              projection: projection,
              scale: tilemapPlaceholderScale,
              translation: size.center(Offset.zero),
              lineColor: visualStyle.gridLineColor,
            ),
          );
        },
      ),
    );
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

  double get tileDiamondWidth => tileExtent;
  double get tileDiamondHeight => tileExtent / 2;
  double get tileDiamondWidthToHeightRatio =>
      tileDiamondWidth / tileDiamondHeight;

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

  Offset topLeftForTile(TilemapCell tile) {
    return Offset(
      originX + (tile.x - tile.y) * tileExtent / 2,
      (tile.x + tile.y) * tileExtent / 4,
    );
  }

  Offset imageTopLeftForTile(TilemapCell tile) {
    final top = topLeftForTile(tile);
    return Offset(top.dx - tileExtent / 2, top.dy - tileExtent / 2);
  }

  List<Offset> polygonForTile(TilemapCell tile) {
    final top = topLeftForTile(tile);
    return <Offset>[
      top,
      Offset(top.dx + tileExtent / 2, top.dy + tileExtent / 4),
      Offset(top.dx, top.dy + tileExtent / 2),
      Offset(top.dx - tileExtent / 2, top.dy + tileExtent / 4),
    ];
  }

  Offset centerForTile(TilemapCell tile) {
    final polygon = polygonForTile(tile);
    final total = polygon.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + point,
    );
    return total / polygon.length.toDouble();
  }

  bool containsPointInTile(TilemapCell tile, Offset point) {
    return _containsPointInPolygon(point, polygonForTile(tile));
  }

  double tilePixelSize({
    required double scale,
    required double devicePixelRatio,
  }) {
    return tileExtent * scale * devicePixelRatio;
  }

  Rect imageBoundsForTiles(Iterable<TilemapCell> tiles) {
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
  double horizontalMargin = tilemapInitialHorizontalMargin,
  double initialScaleFactor = 1,
}) {
  final bounds = contentBounds ?? Offset.zero & mapSize;
  final scale = tilemapInitialScaleForContentWidth(
    viewportWidth: viewportSize.width,
    contentWidth: bounds.width,
    horizontalMargin: horizontalMargin,
    initialScaleFactor: initialScaleFactor,
  );
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportSize.width / 2 - bounds.center.dx * scale,
      viewportSize.height / 2 - bounds.center.dy * scale + 20,
      0,
    );
}

List<TilemapCell> tilemapInitialContentTiles(Iterable<TilemapCell> tiles) {
  final allTiles = tiles.toList(growable: false);
  final shadowZeroTiles = allTiles
      .where((tile) => !tile.hasShadow)
      .toList(growable: false);
  return shadowZeroTiles.isEmpty ? allTiles : shadowZeroTiles;
}

double tilemapInitialScaleForContentWidth({
  required double viewportWidth,
  required double contentWidth,
  double horizontalMargin = tilemapInitialHorizontalMargin,
  double initialScaleFactor = 1,
}) {
  if (!viewportWidth.isFinite ||
      viewportWidth <= 0 ||
      !contentWidth.isFinite ||
      contentWidth <= 0) {
    return tilemapMinScale;
  }
  final resolvedMargin = horizontalMargin.isFinite
      ? math.max(0.0, horizontalMargin)
      : 0.0;
  final resolvedScaleFactor = initialScaleFactor.isFinite
      ? initialScaleFactor.clamp(
          tilemapInitialScaleFactorMin,
          tilemapInitialScaleFactorMax,
        )
      : 1.0;
  final usableWidth = math.max(1.0, viewportWidth - resolvedMargin * 2);
  return (usableWidth / contentWidth * resolvedScaleFactor)
      .clamp(tilemapMinScale, tilemapMaxScale)
      .toDouble();
}

double tilemapTransformScale(Matrix4 transform) => transform.storage[0].abs();

Matrix4 tilemapGestureTransform({
  required Matrix4 startTransform,
  required Offset startFocalPoint,
  required Offset currentFocalPoint,
  required double gestureScale,
  double minScale = tilemapMinScale,
  double maxScale = tilemapMaxScale,
}) {
  final startScale = tilemapTransformScale(startTransform);
  final rawTargetScale = startScale * gestureScale;
  final targetScale = rawTargetScale.clamp(minScale, maxScale).toDouble();
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

Offset tilemapLocationBubbleSceneAnchor(
  TilemapProjection projection,
  TilemapCell tile,
) {
  return projection.centerForTile(tile) + Offset(0, projection.tileExtent / 8);
}

Rect tilemapVisibleSceneBounds({
  required Matrix4 transform,
  required Size viewportSize,
}) {
  final inverse = Matrix4.inverted(transform);
  return _boundsForOffsets([
    MatrixUtils.transformPoint(inverse, Offset.zero),
    MatrixUtils.transformPoint(inverse, Offset(viewportSize.width, 0)),
    MatrixUtils.transformPoint(
      inverse,
      Offset(viewportSize.width, viewportSize.height),
    ),
    MatrixUtils.transformPoint(inverse, Offset(0, viewportSize.height)),
  ]);
}

String resolveTilemapAssetForDisplaySize(
  String baseUrl,
  double displayTilePixelSize,
) {
  final suffixStart = _tilemapUrlSuffixStart(baseUrl);
  final path = baseUrl.substring(0, suffixStart);
  final normalizedPath = path.toLowerCase();
  if (!normalizedPath.endsWith('.png') && !normalizedPath.endsWith('.webp')) {
    throw TilemapConfigException(
      'Tile asset base URL must end with .png or .webp: $baseUrl.',
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
  return '$path?x-oss-process=image/resize,w_$resolvedSize,'
      'image/format,webp';
}

int _tilemapUrlSuffixStart(String url) {
  final queryIndex = url.indexOf('?');
  final fragmentIndex = url.indexOf('#');
  var suffixStart = url.length;
  if (queryIndex >= 0 && queryIndex < suffixStart) suffixStart = queryIndex;
  if (fragmentIndex >= 0 && fragmentIndex < suffixStart) {
    suffixStart = fragmentIndex;
  }
  return suffixStart;
}

class TilemapRenderer extends StatefulWidget {
  const TilemapRenderer({
    super.key,
    required this.config,
    this.onTileAction,
    this.locationNameForTile,
    this.locationAvatarsForTile,
    this.onMapTap,
    this.onImageError,
    this.visualMode = tilemapDefaultVisualMode,
    this.fogControlPoints = tilemapDefaultFogControlPoints,
    this.blendFogWithShadowTiles = false,
    this.showShadowZeroBorders = true,
    this.initialScaleFactor = 1,
  });

  final TilemapConfig config;
  final TilemapTileActionHandler? onTileAction;
  final TilemapLocationNameResolver? locationNameForTile;
  final TilemapLocationAvatarsResolver? locationAvatarsForTile;
  final VoidCallback? onMapTap;
  final ValueChanged<Object>? onImageError;
  final TilemapVisualMode visualMode;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool showShadowZeroBorders;
  final double initialScaleFactor;

  @override
  State<TilemapRenderer> createState() => _TilemapRendererState();
}

class _TilemapRendererState extends State<TilemapRenderer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _highlightController;
  late final Animation<double> _highlightOpacity;
  Matrix4 _gestureStartTransform = Matrix4.identity();
  Offset _gestureStartFocalPoint = Offset.zero;
  Size? _lastViewportSize;
  Size? _lastMapSize;
  Rect? _lastContentBounds;
  double? _lastInitialScaleFactor;
  TilemapConfig? _fogConfig;
  Rect? _fogBounds;
  List<TilemapFogControlPoint>? _fogControlPoints;
  _TilemapFogField? _fogField;
  bool _hasUserTransformedMap = false;
  bool _isRunningTileAction = false;
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
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final visualStyle = tilemapVisualStyleFor(widget.visualMode);
    return ColoredBox(
      key: const ValueKey<String>('tilemap-renderer-background'),
      color: visualStyle.backgroundColor,
      child: LayoutBuilder(
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
            tilemapInitialContentTiles(widget.config.tiles),
          );
          _syncInitialTransform(
            viewportSize: viewportSize,
            mapSize: mapSize,
            contentBounds: contentBounds,
            initialScaleFactor: widget.initialScaleFactor,
          );
          return SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: ClipRect(
              child: GestureDetector(
                key: const ValueKey<String>('tilemap-gesture-layer'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  _hasUserTransformedMap = true;
                  _gestureStartTransform = _transformationController.value
                      .clone();
                  _gestureStartFocalPoint = details.localFocalPoint;
                },
                onScaleUpdate: (details) {
                  _transformationController.value = tilemapGestureTransform(
                    startTransform: _gestureStartTransform,
                    startFocalPoint: _gestureStartFocalPoint,
                    currentFocalPoint: details.localFocalPoint,
                    gestureScale: details.scale,
                  );
                },
                onTapUp: (details) {
                  widget.onMapTap?.call();
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
                    final hasFogTiles = tiles.any((tile) => tile.hasShadow);
                    final hasShadowZeroTiles = tiles.any(
                      (tile) => !tile.hasShadow,
                    );
                    final fogBounds =
                        tilemapVisibleSceneBounds(
                          transform: matrix,
                          viewportSize: viewportSize,
                        ).inflate(
                          projection.tileExtent /
                              tilemapFogSamplesPerTileExtent,
                        );
                    final fogField = !hasFogTiles
                        ? null
                        : _resolveFogField(
                            projection: projection,
                            fogBounds: fogBounds,
                          );
                    final locationLabels = <_TilemapLocationLabelData>[
                      for (final tile in tiles)
                        if (tile.isLocationTile)
                          _TilemapLocationLabelData(
                            tile: tile,
                            name:
                                widget.locationNameForTile
                                    ?.call(tile)
                                    ?.trim() ??
                                '',
                            avatars:
                                widget.locationAvatarsForTile?.call(tile) ??
                                const <UserAvatar>[],
                          ),
                    ].where((label) => label.name.isNotEmpty).toList();
                    return AnimatedBuilder(
                      animation: _highlightController,
                      builder: (context, _) {
                        final highlightedTile = _highlightedTile(
                          tiles,
                          _highlightOpacity.value,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const ValueKey<String>('tilemap-grid'),
                                painter: _TilemapInfiniteGridPainter(
                                  projection: projection,
                                  scale: scale,
                                  translation: Offset(
                                    matrix.getTranslation().x,
                                    matrix.getTranslation().y,
                                  ),
                                  lineColor: visualStyle.gridLineColor,
                                ),
                              ),
                            ),
                            Transform(
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
                                        asset:
                                            resolveTilemapAssetForDisplaySize(
                                              widget.config.baseAssetUrlForTile(
                                                tile,
                                              ),
                                              tilePixelSize,
                                            ),
                                        topLeft: projection.imageTopLeftForTile(
                                          tile,
                                        ),
                                        extent: projection.tileExtent,
                                        onImageError: widget.onImageError,
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
                            if (hasFogTiles)
                              Positioned.fill(
                                child: IgnorePointer(
                                  key: const ValueKey<String>(
                                    'tilemap-fog-layer',
                                  ),
                                  child: Transform(
                                    transform: matrix,
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: projection.mapWidth,
                                      height: projection.mapHeight,
                                      child: CustomPaint(
                                        key: const ValueKey<String>(
                                          'tilemap-fog-paint',
                                        ),
                                        painter: _TilemapFogPainter(
                                          fogField!,
                                          blendWithShadowTiles:
                                              widget.blendFogWithShadowTiles,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.showShadowZeroBorders &&
                                hasShadowZeroTiles)
                              Positioned.fill(
                                child: IgnorePointer(
                                  key: const ValueKey<String>(
                                    'tilemap-shadow-zero-border-layer',
                                  ),
                                  child: Transform(
                                    transform: matrix,
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: projection.mapWidth,
                                      height: projection.mapHeight,
                                      child: CustomPaint(
                                        key: const ValueKey<String>(
                                          'tilemap-shadow-zero-border-paint',
                                        ),
                                        painter:
                                            _TilemapShadowZeroBorderPainter(
                                              projection: projection,
                                              tiles: widget.config.tiles,
                                              scale: scale,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (final label in locationLabels)
                              _TilemapLocationBubble(
                                key: ValueKey<String>(
                                  'tile-location-label-'
                                  '${label.tile.x}-${label.tile.y}',
                                ),
                                name: label.name,
                                avatars: label.avatars,
                                anchor: MatrixUtils.transformPoint(
                                  matrix,
                                  tilemapLocationBubbleSceneAnchor(
                                    projection,
                                    label.tile,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _TilemapFogField _resolveFogField({
    required TilemapProjection projection,
    required Rect fogBounds,
  }) {
    if (identical(_fogConfig, widget.config) &&
        _fogBounds == fogBounds &&
        identical(_fogControlPoints, widget.fogControlPoints) &&
        _fogField != null) {
      return _fogField!;
    }
    // The mesh lives in scene coordinates, so pan/zoom can reuse it.
    final field = _buildTilemapFogField(
      projection: projection,
      fieldBounds: fogBounds,
      tiles: widget.config.tiles,
      controlPoints: widget.fogControlPoints,
    );
    _fogConfig = widget.config;
    _fogBounds = fogBounds;
    _fogControlPoints = widget.fogControlPoints;
    _fogField = field;
    return field;
  }

  TilemapCell? _highlightedTile(List<TilemapCell> sortedTiles, double opacity) {
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
    if (_isRunningTileAction) return;
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
      if (!tile.isLocationTile) continue;
      if (!projection.containsPointInTile(tile, scenePosition)) continue;
      setState(() {
        _highlightedTileKey = tile.cellKey;
      });
      _highlightController.forward(from: 0);
      await _runTileAction(tile);
      return;
    }
  }

  Future<void> _runTileAction(TilemapCell tile) async {
    final onTileAction = widget.onTileAction;
    if (onTileAction == null) return;
    _isRunningTileAction = true;
    try {
      await onTileAction(tile);
    } finally {
      _isRunningTileAction = false;
    }
  }

  void _syncInitialTransform({
    required Size viewportSize,
    required Size mapSize,
    required Rect contentBounds,
    required double initialScaleFactor,
  }) {
    if (_lastViewportSize == viewportSize &&
        _lastMapSize == mapSize &&
        _lastContentBounds == contentBounds &&
        _lastInitialScaleFactor == initialScaleFactor) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    _lastContentBounds = contentBounds;
    _lastInitialScaleFactor = initialScaleFactor;
    if (_hasUserTransformedMap) return;
    _transformationController.value = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: mapSize,
      contentBounds: contentBounds,
      initialScaleFactor: initialScaleFactor,
    );
  }
}

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({
    required this.tile,
    required this.name,
    required this.avatars,
  });

  final TilemapCell tile;
  final String name;
  final List<UserAvatar> avatars;
}

class _TilemapInfiniteGridPainter extends CustomPainter {
  const _TilemapInfiniteGridPainter({
    required this.projection,
    required this.scale,
    required this.translation,
    required this.lineColor,
  });

  final TilemapProjection projection;
  final double scale;
  final Offset translation;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!scale.isFinite || scale <= 0 || size.isEmpty) return;

    final spacing = projection.tileExtent * scale / 2;
    if (!spacing.isFinite || spacing <= 0) return;

    final positiveSlopeBase =
        translation.dy - translation.dx / 2 - projection.originX * scale / 2;
    final negativeSlopeBase =
        translation.dy + translation.dx / 2 + projection.originX * scale / 2;
    final path = Path();

    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: -size.width / 2,
      maxIntercept: size.height,
      baseIntercept: positiveSlopeBase,
      spacing: spacing,
      slope: 0.5,
    );
    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: 0,
      maxIntercept: size.height + size.width / 2,
      baseIntercept: negativeSlopeBase,
      spacing: spacing,
      slope: -0.5,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapInfiniteGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.translation != translation ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.projection.mapWidth != projection.mapWidth ||
        oldDelegate.projection.mapHeight != projection.mapHeight ||
        oldDelegate.projection.tileExtent != projection.tileExtent ||
        oldDelegate.projection.originX != projection.originX;
  }
}

void _appendParallelGridLines({
  required Path path,
  required double width,
  required double minIntercept,
  required double maxIntercept,
  required double baseIntercept,
  required double spacing,
  required double slope,
}) {
  final firstIndex = ((minIntercept - baseIntercept) / spacing).floor() - 1;
  final lastIndex = ((maxIntercept - baseIntercept) / spacing).ceil() + 1;
  for (var index = firstIndex; index <= lastIndex; index += 1) {
    final intercept = baseIntercept + index * spacing;
    path
      ..moveTo(0, intercept)
      ..lineTo(width, slope * width + intercept);
  }
}

_TilemapFogField _buildTilemapFogField({
  required TilemapProjection projection,
  required Rect fieldBounds,
  required Iterable<TilemapCell> tiles,
  required List<TilemapFogControlPoint> controlPoints,
}) {
  final landTiles = tiles.where((tile) => !tile.hasShadow).toList();
  final shadowTiles = tiles.where((tile) => tile.hasShadow).toList();
  final boundary = _tilemapLandBoundary(projection, landTiles);
  final landPath = Path();
  for (final tile in landTiles) {
    landPath.addPolygon(projection.polygonForTile(tile), true);
  }
  final shadowPath = Path();
  for (final tile in shadowTiles) {
    shadowPath.addPolygon(projection.polygonForTile(tile), true);
  }
  final horizontalStep =
      projection.tileDiamondWidth / tilemapFogSamplesPerTileExtent;
  final verticalStep =
      projection.tileDiamondHeight / tilemapFogSamplesPerTileExtent;
  final columns = math.max(1, (fieldBounds.width / horizontalStep).ceil());
  final rows = math.max(1, (fieldBounds.height / verticalStep).ceil());
  final cellWidth = fieldBounds.width / columns;
  final cellHeight = fieldBounds.height / rows;
  final points = <Offset>[];
  final colors = <Color>[];
  final gridColors = List<Color>.filled(
    (columns + 1) * (rows + 1),
    Colors.transparent,
  );
  final maxDistance = projection.tileExtent * tilemapFogFadeTileExtents;
  final boundaryIndex = _TilemapBoundaryIndex(
    boundary,
    maxDistance: maxDistance,
    verticalScale: projection.tileDiamondWidthToHeightRatio,
  );

  int gridIndex(int column, int row) => row * (columns + 1) + column;

  for (var row = 0; row <= rows; row += 1) {
    for (var column = 0; column <= columns; column += 1) {
      final point = Offset(
        fieldBounds.left + cellWidth * column,
        fieldBounds.top + cellHeight * row,
      );
      final distance = boundaryIndex.distanceTo(point);
      final opacity = tilemapFogOpacityForDistance(
        distance: distance,
        tileExtent: projection.tileExtent,
        controlPoints: controlPoints,
      );
      gridColors[gridIndex(column, row)] = Color.fromARGB(
        (opacity * 0xFF).round(),
        0,
        0,
        0,
      );
    }
  }

  void addVertex(Offset point, Color color) {
    points.add(point);
    colors.add(color);
  }

  for (var row = 0; row < rows; row += 1) {
    for (var column = 0; column < columns; column += 1) {
      final topLeft = Offset(
        fieldBounds.left + cellWidth * column,
        fieldBounds.top + cellHeight * row,
      );
      final topRight = Offset(topLeft.dx + cellWidth, topLeft.dy);
      final bottomLeft = Offset(topLeft.dx, topLeft.dy + cellHeight);
      final bottomRight = Offset(
        topLeft.dx + cellWidth,
        topLeft.dy + cellHeight,
      );
      final topLeftColor = gridColors[gridIndex(column, row)];
      final topRightColor = gridColors[gridIndex(column + 1, row)];
      final bottomLeftColor = gridColors[gridIndex(column, row + 1)];
      final bottomRightColor = gridColors[gridIndex(column + 1, row + 1)];
      addVertex(topLeft, topLeftColor);
      addVertex(topRight, topRightColor);
      addVertex(bottomRight, bottomRightColor);
      addVertex(topLeft, topLeftColor);
      addVertex(bottomRight, bottomRightColor);
      addVertex(bottomLeft, bottomLeftColor);
    }
  }

  return _TilemapFogField(
    vertices: ui.Vertices(ui.VertexMode.triangles, points, colors: colors),
    landPath: landPath,
    shadowPath: shadowPath,
    bounds: fieldBounds,
  );
}

class _TilemapFogField {
  const _TilemapFogField({
    required this.vertices,
    required this.landPath,
    required this.shadowPath,
    required this.bounds,
  });

  final ui.Vertices vertices;
  final Path landPath;
  final Path shadowPath;
  final Rect bounds;
}

List<_TilemapBoundaryEdge> _tilemapLandBoundary(
  TilemapProjection projection,
  Iterable<TilemapCell> landTiles,
) {
  final edges = <String, _TilemapBoundaryEdge>{};
  for (final tile in landTiles) {
    final polygon = projection.polygonForTile(tile);
    for (var index = 0; index < polygon.length; index += 1) {
      final edge = _TilemapBoundaryEdge(
        polygon[index],
        polygon[(index + 1) % polygon.length],
      );
      final key = edge.canonicalKey;
      // A shared edge is internal to the land union; only unmatched edges
      // remain in the outer or hole boundary.
      if (edges.remove(key) == null) edges[key] = edge;
    }
  }
  return edges.values.toList(growable: false);
}

class _TilemapBoundaryEdge {
  const _TilemapBoundaryEdge(this.start, this.end);

  final Offset start;
  final Offset end;

  String get canonicalKey {
    final startFirst =
        start.dx < end.dx || (start.dx == end.dx && start.dy <= end.dy);
    final first = startFirst ? start : end;
    final second = startFirst ? end : start;
    return '${first.dx},${first.dy}|${second.dx},${second.dy}';
  }

  double distanceTo(Offset point, {required double verticalScale}) {
    return tilemapFogDistanceToSegment(
      point: point,
      start: start,
      end: end,
      verticalScale: verticalScale,
    );
  }
}

class _TilemapBoundaryIndex {
  _TilemapBoundaryIndex(
    Iterable<_TilemapBoundaryEdge> edges, {
    required this.maxDistance,
    required this.verticalScale,
  }) : cellSize = math.max(1, maxDistance) {
    for (final edge in edges) {
      final scaledStart = _scaleOffset(edge.start);
      final scaledEnd = _scaleOffset(edge.end);
      final bounds = Rect.fromPoints(
        scaledStart,
        scaledEnd,
      ).inflate(maxDistance);
      final left = (bounds.left / cellSize).floor();
      final right = (bounds.right / cellSize).floor();
      final top = (bounds.top / cellSize).floor();
      final bottom = (bounds.bottom / cellSize).floor();
      for (var y = top; y <= bottom; y += 1) {
        for (var x = left; x <= right; x += 1) {
          _buckets.putIfAbsent((x, y), () => []).add(edge);
        }
      }
    }
  }

  final double maxDistance;
  final double verticalScale;
  final double cellSize;
  final Map<(int, int), List<_TilemapBoundaryEdge>> _buckets = {};

  Offset _scaleOffset(Offset offset) {
    return Offset(offset.dx, offset.dy * verticalScale);
  }

  double distanceTo(Offset point) {
    final scaledPoint = _scaleOffset(point);
    final candidates =
        _buckets[(
          (scaledPoint.dx / cellSize).floor(),
          (scaledPoint.dy / cellSize).floor(),
        )];
    if (candidates == null) return maxDistance;
    var distance = maxDistance;
    for (final edge in candidates) {
      distance = math.min(
        distance,
        edge.distanceTo(point, verticalScale: verticalScale),
      );
      if (distance == 0) break;
    }
    return distance;
  }
}

class _TilemapLocationBubble extends StatelessWidget {
  const _TilemapLocationBubble({
    super.key,
    required this.name,
    required this.avatars,
    required this.anchor,
  });

  final String name;
  final List<UserAvatar> avatars;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, 0),
          child: Semantics(
            label: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  key: ValueKey<String>('tile-location-pointer-$name'),
                  size: const Size(8, 6.93),
                  painter: const _TilemapLocationBubblePointerPainter(),
                ),
                Container(
                  key: ValueKey<String>('tile-location-bubble-body-$name'),
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFF3B4E),
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3A3A3A),
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (avatars.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TilemapLocationAvatars(avatars: avatars),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TilemapLocationBubblePointerPainter extends CustomPainter {
  const _TilemapLocationBubblePointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawShadow(path, const Color(0x24000000), 3, true)
      ..drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(
    covariant _TilemapLocationBubblePointerPainter oldDelegate,
  ) {
    return false;
  }
}

class _ProjectedTileHighlight extends StatelessWidget {
  const _ProjectedTileHighlight({
    super.key,
    required this.tile,
    required this.projection,
    required this.opacity,
  });

  final TilemapCell tile;
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
            color: tilemapLocationHighlightColor.withValues(
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
    this.onImageError,
  });

  final TilemapCell tile;
  final String asset;
  final Offset topLeft;
  final double extent;
  final ValueChanged<Object>? onImageError;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: extent,
      height: extent,
      child: Image.network(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.none,
        semanticLabel: '${tile.type} ${tile.x},${tile.y}',
        errorBuilder: (context, error, stackTrace) {
          onImageError?.call(error);
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _TilemapFogPainter extends CustomPainter {
  const _TilemapFogPainter(this.field, {required this.blendWithShadowTiles});

  final _TilemapFogField field;
  final bool blendWithShadowTiles;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..saveLayer(field.bounds, Paint())
      ..drawVertices(
        field.vertices,
        tilemapFogVertexBlendMode,
        Paint()..color = Colors.white,
      )
      // Keep the standalone fog over the empty grid, but clear every tile.
      // Shadow tiles opt into fog through the Multiply pass below.
      ..drawPath(field.landPath, Paint()..blendMode = BlendMode.clear)
      ..drawPath(field.shadowPath, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    if (!blendWithShadowTiles) return;
    canvas
      ..save()
      ..clipPath(field.shadowPath)
      ..drawVertices(
        field.vertices,
        tilemapFogVertexBlendMode,
        Paint()
          ..color = Colors.white
          ..blendMode = BlendMode.multiply,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _TilemapFogPainter oldDelegate) {
    return !identical(oldDelegate.field, field) ||
        oldDelegate.blendWithShadowTiles != blendWithShadowTiles;
  }
}

class _TilemapShadowZeroBorderPainter extends CustomPainter {
  const _TilemapShadowZeroBorderPainter({
    required this.projection,
    required this.tiles,
    required this.scale,
  });

  final TilemapProjection projection;
  final List<TilemapCell> tiles;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final tile in tiles) {
      if (tile.hasShadow) continue;
      path.addPolygon(projection.polygonForTile(tile), true);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tilemapShadowZeroBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = tilemapShadowZeroBorderWidth / scale
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapShadowZeroBorderPainter oldDelegate) {
    return !identical(oldDelegate.projection, projection) ||
        !identical(oldDelegate.tiles, tiles) ||
        oldDelegate.scale != scale;
  }
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
