import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/pages/world/world_map_data.dart';

void main() {
  test('uses first root location map image', () {
    final roots = [
      const LocationTreeNode<Map<String, dynamic>>(
        id: 'root-1',
        parentId: '',
        depth: 0,
        value: {'map_url': 'assets/maps/root.webp'},
        children: [],
      ),
    ];

    expect(worldRootMapImageUrl(roots), 'assets/maps/root.webp');
  });

  test('filters current user avatars from map occupants', () {
    final avatars = worldAvatarsByLocationFromCharacterPositions([
      {
        'location_id': 'loc-1',
        'character': {
          'character_id': 'char-self',
          'name': 'Self',
          'player_uid': 'uid-self',
          'avatar': 'assets/self.webp',
        },
      },
      {
        'location_id': 'loc-1',
        'character': {
          'character_id': 'char-other',
          'name': 'Other',
          'player_uid': 'uid-other',
          'avatar': 'assets/other.webp',
        },
      },
    ], currentUid: 'uid-self');

    expect(avatars['loc-1'], hasLength(1));
    expect(avatars['loc-1']?.single.name, 'Other');
    expect(avatars['loc-1']?.single.isPlayerControlledRole, isTrue);
  });

  test('builds fallback map points from location ids', () {
    final points = worldPointsFromLocationIds(['b', 'a', 'a', ''], const {});

    expect(points.map((point) => point.id), ['a', 'b']);
    expect(points.every((point) => point.sceneId == point.id), isTrue);
    expect(points.every((point) => point.isLeafLocation), isTrue);
  });
}
