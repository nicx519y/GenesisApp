import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_update_push_target.dart';

void main() {
  test('location notice resolves a leaf by its entity id', () {
    final leaf = _node('leaf');
    final notice = _notice(
      kind: WorldContentUpdateKind.location,
      entityId: 'leaf',
      targetLocationId: 'stale_target',
    );

    final target = resolveWorldUpdatePushChatTarget(
      notice: notice,
      world: _world(),
      locationNodes: [leaf],
    );

    expect(target, same(leaf.point));
  });

  test('branching location is not directly eligible for a notice', () {
    final branch = _node(
      'branch',
      children: [_node('leaf_a'), _node('leaf_b')],
    );

    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(
        kind: WorldContentUpdateKind.location,
        entityId: 'branch',
      ),
      world: _world(),
      locationNodes: [branch],
    );

    expect(target, isNull);
  });

  test('single descendant chain resolves to its leaf like a map click', () {
    final leaf = _node('leaf');
    final root = _node(
      'root',
      children: [
        _node('middle', children: [leaf]),
      ],
    );

    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(kind: WorldContentUpdateKind.location, entityId: 'root'),
      world: _world(),
      locationNodes: [root],
    );

    expect(target, same(leaf.point));
  });

  test('character current position overrides stale notice target', () {
    final currentLeaf = _node('current_leaf');
    final staleLeaf = _node('stale_leaf');
    final world = _world(
      characterPositions: const [
        <String, dynamic>{
          'location_id': 'current_leaf',
          'character': <String, dynamic>{'char_id': 'char_1'},
        },
      ],
    );

    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char_1',
        targetLocationId: 'stale_leaf',
      ),
      world: world,
      locationNodes: [currentLeaf, staleLeaf],
    );

    expect(target, same(currentLeaf.point));
  });

  test('character without a current position is not eligible', () {
    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char_1',
        targetLocationId: 'stale_leaf',
      ),
      world: _world(),
      locationNodes: [_node('stale_leaf')],
    );

    expect(target, isNull);
  });

  test('character fallback ignores initial-location-only data', () {
    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char_1',
      ),
      world: _world(
        characters: const [
          <String, dynamic>{
            'char_id': 'char_1',
            'initial_location_id': 'initial_leaf',
          },
        ],
      ),
      locationNodes: [_node('initial_leaf')],
    );

    expect(target, isNull);
  });

  test('character falls back to its current location on world characters', () {
    final fallbackLeaf = _node('fallback_leaf');
    final target = resolveWorldUpdatePushChatTarget(
      notice: _notice(
        kind: WorldContentUpdateKind.character,
        entityId: 'char_1',
      ),
      world: _world(
        characters: const [
          <String, dynamic>{
            'character_id': 'char_1',
            'current_location_id': 'fallback_leaf',
            'initial_location_id': 'ignored_initial_leaf',
          },
        ],
      ),
      locationNodes: [fallbackLeaf, _node('ignored_initial_leaf')],
    );

    expect(target, same(fallbackLeaf.point));
  });
}

WorldContentUpdateNotice _notice({
  required WorldContentUpdateKind kind,
  required String entityId,
  String targetLocationId = '',
}) {
  return WorldContentUpdateNotice(
    kind: kind,
    entityId: entityId,
    name: entityId,
    targetLocationId: targetLocationId,
    avatarUrl: '',
    tickCount: 1,
  );
}

WorldMapLocationNode _node(
  String id, {
  List<WorldMapLocationNode> children = const <WorldMapLocationNode>[],
}) {
  return WorldMapLocationNode(id: id, point: _point(id), children: children);
}

WorldPoint _point(String id) {
  return WorldPoint(
    id: id,
    name: id,
    type: WorldPointType.portal,
    position: Offset.zero,
    users: const <UserAvatar>[],
  );
}

WorldDetail _world({
  List<Map<String, dynamic>> characters = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> characterPositions =
      const <Map<String, dynamic>>[],
}) {
  return WorldDetail(
    id: 1,
    worldId: 'w_test',
    originId: 1,
    ownerUid: 'u_self',
    name: 'Test World',
    tickCount: 1,
    connectCount: 0,
    characterCount: characters.length,
    playerCount: 1,
    currentTime: 'Day 1, 08:00',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'owner',
    metric: const <String, dynamic>{},
    inviteToken: '',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'o_test',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: characters,
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: characterPositions,
    userPositions: const <Map<String, dynamic>>[],
  );
}
