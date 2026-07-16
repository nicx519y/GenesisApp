import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tilemap_model.dart';

const double tilemapBaseTileExtent = 16;
const double tilemapInitialScale = 8;
const double tilemapMinScale = 4;
const double tilemapMaxScale = 32;
const double tilemapTransitionZoomTargetScale = 40;

typedef TilemapTileActionHandler = Future<void> Function(TilemapCell tile);
typedef TilemapLocationNameResolver = String? Function(TilemapCell tile);

const Color tilemapLocationHighlightColor = Color(0xFFFFD54F);
const Color tilemapGridLineColor = Color(0xFFD6D6D6);

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

Offset tilemapLocationBubbleSceneAnchor(
  TilemapProjection projection,
  TilemapCell tile,
) {
  return projection.centerForTile(tile) + Offset(0, projection.tileExtent / 8);
}

String resolveTilemapAssetForDisplaySize(
  String baseUrl,
  double displayTilePixelSize,
) {
  final suffixStart = _tilemapUrlSuffixStart(baseUrl);
  final path = baseUrl.substring(0, suffixStart);
  if (!path.toLowerCase().endsWith('.png')) {
    throw TilemapConfigException(
      'Tile asset base URL must end with .png: $baseUrl.',
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
    this.onMapTap,
    this.onImageError,
  });

  final TilemapConfig config;
  final TilemapTileActionHandler? onTileAction;
  final TilemapLocationNameResolver? locationNameForTile;
  final VoidCallback? onMapTap;
  final ValueChanged<Object>? onImageError;

  @override
  State<TilemapRenderer> createState() => _TilemapRendererState();
}

class _TilemapRendererState extends State<TilemapRenderer>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _highlightController;
  late final AnimationController _tileActionZoomController;
  late final Animation<double> _highlightOpacity;
  late final Animation<double> _tileActionOpacity;
  Animation<Matrix4>? _tileActionZoomAnimation;
  Matrix4 _gestureStartTransform = Matrix4.identity();
  Offset _gestureStartFocalPoint = Offset.zero;
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
              key: const ValueKey<String>('tilemap-gesture-layer'),
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _tileActionZoomController.stop();
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
                  final locationLabels = <_TilemapLocationLabelData>[
                    for (final tile in tiles)
                      if (tile.isLocationTile)
                        _TilemapLocationLabelData(
                          tile: tile,
                          name:
                              widget.locationNameForTile?.call(tile)?.trim() ??
                              '',
                        ),
                  ].where((label) => label.name.isNotEmpty).toList();
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
                        child: Stack(
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
                            for (final label in locationLabels)
                              _TilemapLocationBubble(
                                key: ValueKey<String>(
                                  'tile-location-label-'
                                  '${label.tile.x}-${label.tile.y}',
                                ),
                                name: label.name,
                                anchor: MatrixUtils.transformPoint(
                                  matrix,
                                  tilemapLocationBubbleSceneAnchor(
                                    projection,
                                    label.tile,
                                  ),
                                ),
                              ),
                          ],
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
      if (!tile.isLocationTile) continue;
      if (!projection.containsPointInTile(tile, scenePosition)) continue;
      setState(() {
        _highlightedTileKey = tile.cellKey;
      });
      _highlightController.forward(from: 0);
      await _runTileActionTransition(
        tile: tile,
        scenePosition: scenePosition,
        localPosition: localPosition,
      );
      return;
    }
  }

  Future<void> _runTileActionTransition({
    required TilemapCell tile,
    required Offset scenePosition,
    required Offset localPosition,
  }) async {
    final onTileAction = widget.onTileAction;
    if (onTileAction == null) return;
    _isRunningTileActionTransition = true;
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
      if (mounted) {
        await _tileActionZoomController.reverse();
      }
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
}

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({required this.tile, required this.name});

  final TilemapCell tile;
  final String name;
}

class _TilemapInfiniteGridPainter extends CustomPainter {
  const _TilemapInfiniteGridPainter({
    required this.projection,
    required this.scale,
    required this.translation,
  });

  final TilemapProjection projection;
  final double scale;
  final Offset translation;

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
        ..color = tilemapGridLineColor
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

class _TilemapLocationBubble extends StatelessWidget {
  const _TilemapLocationBubble({
    super.key,
    required this.name,
    required this.anchor,
  });

  final String name;
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
