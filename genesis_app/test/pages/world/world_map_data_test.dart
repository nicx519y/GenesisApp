import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
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

  test('builds location sheet data from the current world hierarchy', () {
    final world = WorldDetail.fromJson({
      'world_id': 'w-1',
      'locations': [
        {
          'location_id': 'root',
          'location_name': 'Root',
          'image': {
            'sm_url': 'https://cdn.example.com/root-sm.webp',
            'xl_url': 'https://cdn.example.com/root-xl.webp',
          },
        },
        {
          'location_id': 'child',
          'location_pid': 'root',
          'location_name': 'Child',
          'image': '',
          'icon': 'https://cdn.example.com/child-legacy.webp',
        },
      ],
    });

    final data = worldLocationListDataFor(world, currentUid: '');

    expect(data.points.map((point) => point.sceneId), [
      '__world_root__',
      'root',
      'child',
    ]);
    final rootPoint = data.points.singleWhere(
      (point) => point.sceneId == 'root',
    );
    final childPoint = data.points.singleWhere(
      (point) => point.sceneId == 'child',
    );
    expect(rootPoint.iconUrl, 'https://cdn.example.com/root-xl.webp');
    expect(childPoint.iconUrl, 'https://cdn.example.com/child-legacy.webp');
    expect(data.locationNodes, hasLength(1));
    expect(data.locationNodes.single.id, '__world_root__');
    final rootNode = data.locationNodes.single.children.single;
    expect(rootNode.id, 'root');
    expect(rootNode.children.single.id, 'child');
  });

  test('keeps the location sheet empty without location data', () {
    final data = worldLocationListDataFor(
      WorldDetail.fromJson({'world_id': 'w-empty'}),
      currentUid: '',
    );

    expect(data.points, isEmpty);
    expect(data.locationNodes, isEmpty);
  });
}
