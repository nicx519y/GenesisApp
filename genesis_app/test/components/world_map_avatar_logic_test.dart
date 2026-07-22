import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_map_avatar_logic.dart';
import 'package:genesis_flutter_android/components/world_point.dart';

void main() {
  test('visible location avatars preserve order and remove duplicates', () {
    const first = UserAvatar('AA', id: 'char-a', name: 'Ada');
    const duplicate = UserAvatar('AX', id: 'char-a', name: 'Ada duplicate');
    const fallback = UserAvatar(
      'BB',
      name: 'Bert',
      avatarUrl: 'https://cdn.example.com/bert.png',
    );
    final node = WorldMapLocationNode(
      id: 'loc-1',
      point: const WorldPoint(
        id: 'loc-1',
        name: 'Location',
        type: WorldPointType.castle,
        position: Offset.zero,
        users: [first, duplicate, fallback],
      ),
    );

    final avatars = worldMapVisibleAvatarsForLocation(node);

    expect(avatars, [first, fallback]);
    expect(worldMapAvatarStableId(first), 'char-a');
    expect(
      worldMapAvatarStableId(fallback),
      'Bert|https://cdn.example.com/bert.png|BB',
    );
  });

  test('missing location has no visible avatars', () {
    expect(worldMapVisibleAvatarsForLocation(null), const <UserAvatar>[]);
  });
}
