part of 'tilemap_renderer_library.dart';

@immutable
class TilemapImageLoadPlan {
  const TilemapImageLoadPlan._({
    required this.tileCountByAsset,
    required this.totalTileCount,
  });

  factory TilemapImageLoadPlan.forConfig({
    required TilemapConfig config,
    required double displayTilePixelSize,
  }) {
    // Flutter coalesces identical NetworkImage requests. Keep one request per
    // resolved asset, but weight its completion by every tile that becomes
    // renderable when that shared image finishes loading.
    final tileCountByAsset = <String, int>{};
    for (final tile in config.tiles) {
      final asset = resolveTilemapAssetForDisplaySize(
        config.baseAssetUrlForTile(tile),
        displayTilePixelSize,
      );
      tileCountByAsset.update(asset, (count) => count + 1, ifAbsent: () => 1);
    }
    return TilemapImageLoadPlan._(
      tileCountByAsset: Map<String, int>.unmodifiable(tileCountByAsset),
      totalTileCount: config.tileCount,
    );
  }

  final Map<String, int> tileCountByAsset;
  final int totalTileCount;
}

double tilemapImageLoadProgress({
  required int loadedTileCount,
  required int totalTileCount,
}) {
  if (totalTileCount <= 0) return 0;
  return loadedTileCount.clamp(0, totalTileCount) / totalTileCount;
}
