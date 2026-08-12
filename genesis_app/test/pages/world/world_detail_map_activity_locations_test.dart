import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_detail_map_activity_locations.dart';

void main() {
  test(
    'uses non-empty world detail location paragraphs as event locations',
    () {
      expect(
        worldDetailEventLocationIds(const <Map<String, dynamic>>[
          {
            'location_id': 'loc_event_a',
            'location_paragraph': 'An event happened.',
          },
          {'location_id': 'loc_empty', 'location_paragraph': ''},
          {'location_id': 'loc_whitespace', 'location_paragraph': '   '},
          {
            'location_id': 'loc_event_b',
            'location_paragraph': 'Another event happened.',
          },
          {
            'location_id': 'loc_event_a',
            'location_paragraph': 'Duplicate location.',
          },
        ]),
        const <String>{'loc_event_a', 'loc_event_b'},
      );
    },
  );

  test('ignores event paragraphs without a location id', () {
    expect(
      worldDetailEventLocationIds(const <Map<String, dynamic>>[
        {'location_id': '', 'location_paragraph': 'Missing location.'},
        {'location_paragraph': 'Missing location key.'},
      ]),
      isEmpty,
    );
  });
}
