import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_value_helpers.dart';

void main() {
  test('allows delete when only real user is current user', () {
    final world = _world(characters: _characters(['', 'u_self', '']));

    expect(worldCanDeleteLaunchedOnlyBySelf(world, 'u_self'), isTrue);
  });

  test('disallows delete when another real user exists', () {
    final world = _world(characters: _characters(['u_self', 'u_other', '']));

    expect(worldCanDeleteLaunchedOnlyBySelf(world, 'u_self'), isFalse);
  });

  test('disallows delete when no real user exists', () {
    final world = _world(characters: _characters(['', '']));

    expect(worldCanDeleteLaunchedOnlyBySelf(world, 'u_self'), isFalse);
  });
}

WorldDetail _world({required List<Map<String, dynamic>> characters}) {
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
      deleted: false,
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
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}

List<Map<String, dynamic>> _characters(List<String> playerUids) {
  return [
    for (var index = 0; index < playerUids.length; index += 1)
      <String, dynamic>{
        'char_id': 'c_$index',
        'name': 'Character $index',
        'player_uid': playerUids[index],
      },
  ];
}
