part of 'tilemap_renderer_library.dart';

@immutable
class TilemapImageLoadPlan {
  const TilemapImageLoadPlan._({
    required this.tileCountByAsset,
    required this.backgroundTileCountByAsset,
    required this.totalTileCount,
  });

  factory TilemapImageLoadPlan.forConfig({
    required TilemapConfig config,
    required double displayTilePixelSize,
    Size? viewportSize,
    double initialScale = tilemapDefaultInitialScale,
    double dragBoundaryPaddingTiles = tilemapDefaultDragBoundaryPaddingTiles,
    TilemapLocationAvatarsResolver? locationAvatarsForTile,
    String preferredLocationId = '',
    bool centerInitialViewport = false,
    double initialViewportVerticalOffsetFraction = 0,
  }) {
    // Flutter coalesces identical NetworkImage requests. Keep one request per
    // resolved asset, but weight its completion by every tile that becomes
    // renderable when that shared image finishes loading.
    final resolvedTiles = <(TilemapCell, String)>[];
    final allTileCountByAsset = <String, int>{};
    for (final tile in config.tiles) {
      final asset = resolveTilemapAssetForDisplaySize(
        config.baseAssetUrlForTile(tile),
        displayTilePixelSize,
      );
      resolvedTiles.add((tile, asset));
      allTileCountByAsset.update(
        asset,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    if (viewportSize == null ||
        viewportSize.isEmpty ||
        !viewportSize.width.isFinite ||
        !viewportSize.height.isFinite) {
      return TilemapImageLoadPlan._(
        tileCountByAsset: Map<String, int>.unmodifiable(allTileCountByAsset),
        backgroundTileCountByAsset: const <String, int>{},
        totalTileCount: config.tileCount,
      );
    }

    final projection = TilemapProjection.fixed(
      mapWidth: config.width,
      mapHeight: config.height,
    );
    final mapSize = Size(projection.mapWidth, projection.mapHeight);
    final contentBounds = projection.imageBoundsForTiles(
      tilemapInitialContentTiles(config.tiles),
    );
    final initialFocusTile = centerInitialViewport
        ? null
        : tilemapInitialFocusLocationTile(
            tiles: config.tiles,
            locationAvatarsForTile: locationAvatarsForTile,
            preferredLocationId: preferredLocationId,
          );
    final initialFocus = centerInitialViewport
        ? contentBounds.center
        : initialFocusTile == null
        ? null
        : projection.centerForTile(initialFocusTile);
    final dragBoundary = tilemapDragBoundaryForShadowTiles(
      projection: projection,
      tiles: config.tiles,
      paddingTiles: dragBoundaryPaddingTiles,
    );
    final initialTransform = tilemapConstrainTransformToBoundary(
      transform: tilemapInitialTransform(
        viewportSize: viewportSize,
        mapSize: mapSize,
        contentBounds: contentBounds,
        focus: initialFocus,
        initialScale: initialScale,
        viewportVerticalOffset:
            viewportSize.height *
            initialViewportVerticalOffsetFraction.clamp(-0.25, 0.25),
      ),
      viewportSize: viewportSize,
      sceneBoundary: dragBoundary,
    );
    final visibleSceneBounds = tilemapVisibleSceneBounds(
      transform: initialTransform,
      viewportSize: viewportSize,
    );
    final visibleTileCountByAsset = <String, int>{};
    for (final (tile, asset) in resolvedTiles) {
      final imageTopLeft = projection.imageTopLeftForTile(tile);
      final intersection = (imageTopLeft & Size.square(projection.tileExtent))
          .intersect(visibleSceneBounds);
      if (intersection.width <= 0 || intersection.height <= 0) continue;
      visibleTileCountByAsset.update(
        asset,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    // Defensive fallback: a malformed layout must not reveal an entirely blank
    // first viewport while every tile is treated as background work.
    if (visibleTileCountByAsset.isEmpty && allTileCountByAsset.isNotEmpty) {
      return TilemapImageLoadPlan._(
        tileCountByAsset: Map<String, int>.unmodifiable(allTileCountByAsset),
        backgroundTileCountByAsset: const <String, int>{},
        totalTileCount: config.tileCount,
      );
    }

    final backgroundTileCountByAsset = <String, int>{
      for (final entry in allTileCountByAsset.entries)
        if (!visibleTileCountByAsset.containsKey(entry.key))
          entry.key: entry.value,
    };
    return TilemapImageLoadPlan._(
      tileCountByAsset: Map<String, int>.unmodifiable(visibleTileCountByAsset),
      backgroundTileCountByAsset: Map<String, int>.unmodifiable(
        backgroundTileCountByAsset,
      ),
      totalTileCount: visibleTileCountByAsset.values.fold(
        0,
        (total, count) => total + count,
      ),
    );
  }

  /// Assets required for the initial visible viewport.
  final Map<String, int> tileCountByAsset;

  /// Assets used only outside the initial viewport.
  final Map<String, int> backgroundTileCountByAsset;

  /// Visible tile count used to weight the foreground loading progress.
  final int totalTileCount;
}

double tilemapImageLoadProgress({
  required int loadedTileCount,
  required int totalTileCount,
}) {
  if (totalTileCount <= 0) return 0;
  return loadedTileCount.clamp(0, totalTileCount) / totalTileCount;
}
