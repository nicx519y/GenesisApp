import '../json_utils.dart';

class TilemapDefinition {
  const TilemapDefinition({
    required this.isAvailable,
    this.tileTypes,
    this.mapJson,
  });

  const TilemapDefinition.empty()
    : isAvailable = false,
      tileTypes = null,
      mapJson = null;

  final bool isAvailable;
  final Map<String, String>? tileTypes;
  final TilemapMapJson? mapJson;

  List<TilemapTile> get tiles => mapJson?.tiles ?? const <TilemapTile>[];

  factory TilemapDefinition.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const TilemapDefinition.empty();

    final tileTypes = _readTileTypes(json['tile_types']);
    final mapJson = json['map_json'] == null
        ? null
        : TilemapMapJson.fromJson(asJsonMap(json['map_json']));

    if (tileTypes != null && mapJson != null) {
      for (final tile in mapJson.tiles) {
        if (!tileTypes.containsKey(tile.type)) {
          throw ArgumentError(
            'map_json tile type "${tile.type}" is missing from tile_types',
          );
        }
      }
    }

    return TilemapDefinition(
      isAvailable: true,
      tileTypes: tileTypes,
      mapJson: mapJson,
    );
  }
}

class TilemapMapJson {
  const TilemapMapJson({
    required this.width,
    required this.height,
    required this.tiles,
  });

  final int width;
  final int height;
  final List<TilemapTile> tiles;

  factory TilemapMapJson.fromJson(Map<String, dynamic> json) {
    final width = json['width'];
    final height = json['height'];
    final rawTiles = json['tiles'];
    if (width is! int || width <= 0) {
      throw ArgumentError('map_json.width must be a positive integer');
    }
    if (height is! int || height <= 0) {
      throw ArgumentError('map_json.height must be a positive integer');
    }
    if (rawTiles is! List) {
      throw ArgumentError('map_json.tiles must be an array');
    }
    final tiles = List<TilemapTile>.unmodifiable(
      rawTiles.map((tile) => TilemapTile.fromJson(asJsonMap(tile))),
    );
    for (final tile in tiles) {
      if (tile.x >= width || tile.y >= height) {
        throw ArgumentError(
          'map_json tile coordinate ${tile.x},${tile.y} is outside '
          '$width x $height',
        );
      }
    }
    return TilemapMapJson(width: width, height: height, tiles: tiles);
  }
}

class TilemapTile {
  const TilemapTile({
    required this.x,
    required this.y,
    required this.type,
    this.locationId,
  });

  final int x;
  final int y;
  final String type;
  final String? locationId;

  factory TilemapTile.fromJson(Map<String, dynamic> json) {
    final x = json['x'];
    final y = json['y'];
    final type = json['type'];
    final locationId = json['location_id'];
    if (x is! int || x < 0) {
      throw ArgumentError('map_json.tiles[].x must be a non-negative integer');
    }
    if (y is! int || y < 0) {
      throw ArgumentError('map_json.tiles[].y must be a non-negative integer');
    }
    if (type is! String || type.isEmpty) {
      throw ArgumentError('map_json.tiles[].type must be a non-empty string');
    }
    if (locationId != null && locationId is! String) {
      throw ArgumentError('map_json.tiles[].location_id must be a string');
    }
    final resolvedLocationId = locationId is String ? locationId.trim() : '';
    return TilemapTile(
      x: x,
      y: y,
      type: type,
      locationId: resolvedLocationId.isEmpty ? null : resolvedLocationId,
    );
  }
}

Map<String, String>? _readTileTypes(Object? value) {
  if (value == null) return null;
  final rawMap = asJsonMap(value);
  return Map<String, String>.unmodifiable(
    rawMap.map((type, assetUrl) {
      if (type.isEmpty) {
        throw ArgumentError('tile_types keys must not be empty');
      }
      if (assetUrl is! String || assetUrl.isEmpty) {
        throw ArgumentError('tile_types.$type must be a non-empty URL string');
      }
      return MapEntry(type, assetUrl);
    }),
  );
}
