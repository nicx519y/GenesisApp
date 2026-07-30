part of 'tilemap_renderer_library.dart';

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

  Rect polygonBoundsForTiles(Iterable<TilemapCell> tiles) {
    return _boundsForOffsets([
      for (final tile in tiles) ...polygonForTile(tile),
    ]);
  }
}

Matrix4 tilemapInitialTransform({
  required Size viewportSize,
  required Size mapSize,
  Rect? contentBounds,
  Offset? focus,
  double initialScale = tilemapDefaultInitialScale,
}) {
  final bounds = contentBounds ?? Offset.zero & mapSize;
  final scale = tilemapResolvedInitialScale(initialScale);
  final sceneCenter = focus ?? bounds.center;
  final verticalOffset = focus == null ? 20.0 : 0.0;
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportSize.width / 2 - sceneCenter.dx * scale,
      viewportSize.height / 2 - sceneCenter.dy * scale + verticalOffset,
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

Rect? tilemapDragBoundaryForShadowTiles({
  required TilemapProjection projection,
  required Iterable<TilemapCell> tiles,
  double paddingTiles = tilemapDefaultDragBoundaryPaddingTiles,
}) {
  final shadowTiles = tiles
      .where((tile) => tile.hasShadow)
      .toList(growable: false);
  if (shadowTiles.isEmpty) return null;
  final resolvedPaddingTiles = paddingTiles.isFinite
      ? paddingTiles.clamp(
          tilemapDragBoundaryPaddingTilesMin,
          tilemapDragBoundaryPaddingTilesMax,
        )
      : tilemapDefaultDragBoundaryPaddingTiles;
  return projection
      .polygonBoundsForTiles(shadowTiles)
      .inflate(resolvedPaddingTiles * projection.tileExtent);
}

double tilemapResolvedInitialScale(double initialScale) {
  if (!initialScale.isFinite) return tilemapDefaultInitialScale;
  return initialScale
      .clamp(tilemapInitialScaleMin, tilemapInitialScaleMax)
      .toDouble();
}

TilemapCell? tilemapInitialFocusLocationTile({
  required Iterable<TilemapCell> tiles,
  TilemapLocationAvatarsResolver? locationAvatarsForTile,
}) {
  TilemapCell? selectedTile;
  var selectedAvatarCount = -1;
  for (final tile in tiles) {
    if (!tile.isLocationTile) continue;
    final avatarCount = locationAvatarsForTile?.call(tile).length ?? 0;
    if (avatarCount <= selectedAvatarCount) continue;
    selectedTile = tile;
    selectedAvatarCount = avatarCount;
  }
  return selectedTile;
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

Matrix4 tilemapConstrainTransformToBoundary({
  required Matrix4 transform,
  required Size viewportSize,
  required Rect? sceneBoundary,
}) {
  if (sceneBoundary == null ||
      sceneBoundary.isEmpty ||
      viewportSize.isEmpty ||
      !viewportSize.width.isFinite ||
      !viewportSize.height.isFinite) {
    return transform;
  }
  final scale = tilemapTransformScale(transform);
  if (!scale.isFinite || scale <= 0) return transform;
  final translation = transform.getTranslation();
  final constrainedX = _tilemapConstrainedTranslation(
    current: translation.x,
    viewportExtent: viewportSize.width,
    boundaryStart: sceneBoundary.left,
    boundaryEnd: sceneBoundary.right,
    scale: scale,
  );
  final constrainedY = _tilemapConstrainedTranslation(
    current: translation.y,
    viewportExtent: viewportSize.height,
    boundaryStart: sceneBoundary.top,
    boundaryEnd: sceneBoundary.bottom,
    scale: scale,
  );
  if ((constrainedX - translation.x).abs() < 0.000001 &&
      (constrainedY - translation.y).abs() < 0.000001) {
    return transform;
  }
  return transform.clone()
    ..setTranslationRaw(constrainedX, constrainedY, translation.z);
}

double _tilemapConstrainedTranslation({
  required double current,
  required double viewportExtent,
  required double boundaryStart,
  required double boundaryEnd,
  required double scale,
}) {
  final scaledExtent = (boundaryEnd - boundaryStart) * scale;
  if (scaledExtent <= viewportExtent) {
    return viewportExtent / 2 - (boundaryStart + boundaryEnd) * scale / 2;
  }
  final minimum = viewportExtent - boundaryEnd * scale;
  final maximum = -boundaryStart * scale;
  return current.clamp(minimum, maximum).toDouble();
}

Offset tilemapLocationBubbleSceneAnchor(
  TilemapProjection projection,
  TilemapCell tile,
) {
  return projection.centerForTile(tile) - Offset(0, projection.tileExtent / 8);
}

double tilemapLocationImageFlowPhase(TilemapCell tile) {
  final hash = (tile.x * 73856093) ^ (tile.y * 19349663);
  return (hash & 0xFFFF) / 0x10000;
}

double? tilemapLocationImageFlowProgress({
  required double animationValue,
  required double phase,
}) {
  final cycle = (animationValue + phase) % 1;
  if (cycle >= tilemapLocationImageFlowActiveFraction) return null;
  return cycle / tilemapLocationImageFlowActiveFraction;
}

Duration tilemapLocationImageFlowDurationForSeconds(double seconds) {
  final resolved =
      (seconds.isFinite
              ? seconds
              : tilemapDefaultLocationImageFlowDurationSeconds)
          .clamp(
            tilemapLocationImageFlowDurationSecondsMin,
            tilemapLocationImageFlowDurationSecondsMax,
          )
          .toDouble();
  return Duration(
    microseconds: (resolved * Duration.microsecondsPerSecond).round(),
  );
}

BlendMode tilemapLocationImageFlowCanvasBlendMode(
  TilemapLocationImageFlowBlendMode mode,
) {
  return switch (mode) {
    TilemapLocationImageFlowBlendMode.normal => BlendMode.srcATop,
    TilemapLocationImageFlowBlendMode.screen => BlendMode.screen,
    TilemapLocationImageFlowBlendMode.overlay => BlendMode.overlay,
    TilemapLocationImageFlowBlendMode.plus => BlendMode.plus,
  };
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

Rect tilemapRetainedSceneBounds(Rect visibleSceneBounds) {
  return Rect.fromLTRB(
    visibleSceneBounds.left - visibleSceneBounds.width / 2,
    visibleSceneBounds.top - visibleSceneBounds.height / 2,
    visibleSceneBounds.right + visibleSceneBounds.width / 2,
    visibleSceneBounds.bottom + visibleSceneBounds.height / 2,
  );
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
