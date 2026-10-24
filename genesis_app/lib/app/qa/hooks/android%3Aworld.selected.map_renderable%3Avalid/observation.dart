import '../../../../network/models/tilemap_definition.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';

bool extractObservation(Map<String, dynamic> raw) {
  try {
    final map = TilemapDefinition.fromJson(raw);
    return map.isAvailable &&
        map.mapJson != null &&
        map.tiles.isNotEmpty &&
        map.tileTypes != null &&
        map.tiles.every(
          (tile) => (map.tileTypes![tile.type]?.trim().isNotEmpty ?? false),
        );
  } on ArgumentError {
    return false;
  }
}

Future<Object?> observeSelectedMapRenderable(
  Map<String, dynamic> parameters,
  bool prepared,
  bool started,
) async {
  if (parameters.isNotEmpty)
    throw ArgumentError('Selected world observation takes no parameters');
  final resource = await worldDatasetResource();
  return extractObservation(await resource.selected('map'));
}
