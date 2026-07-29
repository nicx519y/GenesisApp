class TilemapConfigException implements Exception {
  const TilemapConfigException(this.message);

  final String message;

  @override
  String toString() => 'TilemapConfigException: $message';
}

class TilemapCell {
  const TilemapCell({
    required this.x,
    required this.y,
    required this.type,
    this.shadow = 0,
    this.locationId,
  });

  final int x;
  final int y;
  final String type;
  final int shadow;
  final String? locationId;

  String get cellKey => '$x,$y';
  bool get hasShadow => shadow == 1;
  bool get isLocationTile => locationId?.trim().isNotEmpty == true;
}

class TilemapConfig {
  const TilemapConfig({
    required this.id,
    required this.width,
    required this.height,
    required this.tileTypes,
    required this.tiles,
  });

  final String id;
  final int width;
  final int height;
  final Map<String, String> tileTypes;
  final List<TilemapCell> tiles;

  int get tileCount => tiles.length;

  factory TilemapConfig.fromTiles({
    required String id,
    required int width,
    required int height,
    required Map<String, String> tileTypes,
    required Iterable<TilemapCell> tiles,
  }) {
    final resolvedId = id.trim();
    if (resolvedId.isEmpty) {
      throw const TilemapConfigException('Map id must not be empty.');
    }
    if (tileTypes.isEmpty) {
      throw const TilemapConfigException('tile_types must not be empty.');
    }
    if (width <= 0 || height <= 0) {
      throw const TilemapConfigException(
        'Map width and height must be positive.',
      );
    }

    final resolvedTileTypes = <String, String>{};
    for (final entry in tileTypes.entries) {
      final type = entry.key.trim();
      final url = entry.value.trim();
      if (type.isEmpty) {
        throw const TilemapConfigException('Tile type name must not be empty.');
      }
      final baseUrl = _urlWithoutQueryOrFragment(url);
      final normalizedBaseUrl = baseUrl.toLowerCase();
      if (!normalizedBaseUrl.endsWith('.png') &&
          !normalizedBaseUrl.endsWith('.webp')) {
        throw TilemapConfigException(
          'Tile type $type must point to a .png or .webp base URL.',
        );
      }
      if (RegExp(
        r'_\d+_\d+\.(?:png|webp)$',
        caseSensitive: false,
      ).hasMatch(baseUrl)) {
        throw TilemapConfigException(
          'Tile type $type must not include a size suffix.',
        );
      }
      resolvedTileTypes[type] = url;
    }

    final resolvedTiles = <TilemapCell>[];
    final occupiedCells = <String>{};
    for (final tile in tiles) {
      if (tile.x < 0 || tile.y < 0) {
        throw TilemapConfigException(
          'Tile coordinates must be non-negative: ${tile.x},${tile.y}.',
        );
      }
      if (!resolvedTileTypes.containsKey(tile.type)) {
        throw TilemapConfigException('Unknown tile type: ${tile.type}.');
      }
      if (tile.shadow != 0 && tile.shadow != 1) {
        throw TilemapConfigException(
          'Tile shadow must be 0 or 1: ${tile.x},${tile.y}.',
        );
      }
      if (tile.x >= width || tile.y >= height) {
        throw TilemapConfigException(
          'Tile coordinate ${tile.x},${tile.y} is outside $width x $height.',
        );
      }
      if (!occupiedCells.add(tile.cellKey)) {
        throw TilemapConfigException(
          'Duplicate tile coordinate: ${tile.x},${tile.y}.',
        );
      }
      resolvedTiles.add(tile);
    }
    if (resolvedTiles.isEmpty) {
      throw const TilemapConfigException('tiles must not be empty.');
    }

    return TilemapConfig(
      id: resolvedId,
      width: width,
      height: height,
      tileTypes: Map<String, String>.unmodifiable(resolvedTileTypes),
      tiles: List<TilemapCell>.unmodifiable(resolvedTiles),
    );
  }

  String baseAssetUrlForTile(TilemapCell tile) {
    final url = tileTypes[tile.type];
    if (url == null) {
      throw TilemapConfigException('Unknown tile type: ${tile.type}.');
    }
    return url;
  }
}

String _urlWithoutQueryOrFragment(String url) {
  final queryIndex = url.indexOf('?');
  final fragmentIndex = url.indexOf('#');
  var end = url.length;
  if (queryIndex >= 0 && queryIndex < end) end = queryIndex;
  if (fragmentIndex >= 0 && fragmentIndex < end) end = fragmentIndex;
  return url.substring(0, end);
}
