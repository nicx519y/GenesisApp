import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_page.dart';

void main() {
  test('new-content snapshot signature detects location flag changes', () {
    final current = _world(
      locationIsNew: false,
      characterIsNew: false,
      characterPositionIsNew: false,
    );
    final next = _world(
      locationIsNew: true,
      characterIsNew: false,
      characterPositionIsNew: false,
    );

    expect(worldNewContentStateChangedForTesting(current, next), isTrue);
    expect(worldNewContentStateChangedForTesting(next, current), isTrue);
  });

  test('new-content snapshot signature detects character flag changes', () {
    final current = _world(
      locationIsNew: false,
      characterIsNew: false,
      characterPositionIsNew: false,
    );
    final next = _world(
      locationIsNew: false,
      characterIsNew: true,
      characterPositionIsNew: false,
    );

    expect(worldNewContentStateChangedForTesting(current, next), isTrue);
    expect(worldNewContentStateChangedForTesting(next, current), isTrue);
  });

  test(
    'new-content snapshot signature detects character-position flag changes',
    () {
      final current = _world(
        locationIsNew: false,
        characterIsNew: false,
        characterPositionIsNew: false,
      );
      final next = _world(
        locationIsNew: false,
        characterIsNew: false,
        characterPositionIsNew: true,
      );

      expect(worldNewContentStateChangedForTesting(current, next), isTrue);
      expect(worldNewContentStateChangedForTesting(next, current), isTrue);
    },
  );

  test('new-content snapshot signature normalizes equivalent true values', () {
    final current = _world(
      locationIsNew: true,
      characterIsNew: true,
      characterPositionIsNew: true,
    );
    final next = _world(
      locationIsNew: 1,
      characterIsNew: 'true',
      characterPositionIsNew: 1,
    );

    expect(worldNewContentStateChangedForTesting(current, next), isFalse);
  });
}

WorldDetail _world({
  required Object locationIsNew,
  required Object characterIsNew,
  required Object characterPositionIsNew,
}) {
  return WorldDetail.fromJson({
    'world_id': 'world-1',
    'characters': [
      {'char_id': 'character-1', 'name': 'Ada', 'is_new': characterIsNew},
    ],
    'locations': [
      {
        'location_id': 'location-1',
        'location_name': 'Library',
        'is_new': locationIsNew,
      },
    ],
    'character_positions': [
      {
        'location_id': 'location-1',
        'character': {
          'id': 'character-1',
          'name': 'Ada',
          'is_new': characterPositionIsNew,
        },
      },
    ],
  });
}
