import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.selected.map_renderable%253Avalid/observation.dart';

void main() {
  test(
    'extracts real field and preserves missing or invalid negative observations',
    () {
      expect(extractObservation({}), false);
      expect(
        extractObservation({
          'tile_types': {'grass': 'grass.png'},
          'map_json': {
            'width': 1,
            'height': 1,
            'tiles': [
              {'x': 0, 'y': 0, 'type': 'grass'},
            ],
          },
        }),
        true,
      );
      expect(
        extractObservation({
          'tile_types': {},
          'map_json': {
            'width': 1,
            'height': 1,
            'tiles': [
              {'x': 0, 'y': 0, 'type': 'unknown'},
            ],
          },
        }),
        false,
      );
      expect(
        extractObservation({
          'tile_types': {},
          'map_json': {'width': 0, 'height': 1, 'tiles': []},
        }),
        false,
      );
    },
  );
}
