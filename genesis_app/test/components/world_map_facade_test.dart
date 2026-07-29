import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/legacy_world_map/legacy_world_map.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap.dart';
import 'package:genesis_flutter_android/components/world_map.dart';

void main() {
  const common = WorldMapCommonConfig();
  const legacy = LegacyWorldMapConfig(points: <WorldPoint>[]);

  test('Origin v1 and unknown versions use LegacyWorldMap', () {
    for (final version in <int?>[1, null, 3]) {
      final map = WorldMap.origin(
        definitionVersion: version,
        originId: 'o_1',
        common: common,
        legacy: legacy,
      );

      expect(map.build(_FakeBuildContext()), isA<LegacyWorldMap>());
    }
  });

  test('World v1 and unknown versions use LegacyWorldMap', () {
    for (final version in <int?>[1, null, 3]) {
      final map = WorldMap.world(
        definitionVersion: version,
        worldId: 'w_1',
        common: common,
        legacy: legacy,
      );

      expect(map.build(_FakeBuildContext()), isA<LegacyWorldMap>());
    }
  });

  test('Origin v2 uses Tilemap and forwards Tilemap options', () {
    var mapTapCount = 0;
    const tilemapLocationNode = WorldMapLocationNode(
      id: 'loc_1',
      point: WorldPoint(
        id: 'loc_1',
        name: 'Location 1',
        type: WorldPointType.portal,
        position: Offset.zero,
        users: <UserAvatar>[],
      ),
    );
    final map = WorldMap.origin(
      definitionVersion: 2,
      originId: 'o_1',
      common: WorldMapCommonConfig(
        drillExitTop: 91,
        messageBubbles: const [
          WorldMapMessageBubble(characterId: 'char_1', content: 'Hello'),
        ],
        onMapTap: () => mapTapCount += 1,
      ),
      legacy: legacy,
      tilemap: const WorldMapTilemapOptions(
        locationId: 'root',
        locationNodes: <WorldMapLocationNode>[tilemapLocationNode],
        showVisualModeToggle: false,
        visualModeToggleTop: 17,
        visualModeToggleRight: 12,
      ),
    );

    final result = map.build(_FakeBuildContext());
    expect(result, isA<Stack>());
    final children = (result as Stack).children;
    expect(children, hasLength(1));
    final tilemap = children.single as Tilemap;
    expect(tilemap.locationId, 'root');
    expect(tilemap.locationNodes, <WorldMapLocationNode>[tilemapLocationNode]);
    expect(tilemap.drillExitTop, 91);
    expect(tilemap.showVisualModeToggle, isFalse);
    expect(tilemap.visualModeToggleTop, 17);
    expect(tilemap.visualModeToggleRight, 12);
    expect(tilemap.messageBubbles.single.content, 'Hello');
    expect(tilemap.messageBubblePlaybackPaused, isFalse);
    tilemap.onMapTap?.call();
    expect(mapTapCount, 1);
  });

  test(
    'Origin v2 list overlays LegacyWorldMap while keeping Tilemap mounted',
    () {
      final map = WorldMap.origin(
        definitionVersion: 2,
        originId: 'o_1',
        common: common,
        legacy: const LegacyWorldMapConfig(
          points: <WorldPoint>[],
          showPointsList: true,
        ),
      );

      final result = map.build(_FakeBuildContext());
      expect(result, isA<Stack>());
      final children = (result as Stack).children;
      expect(children.first, isA<Tilemap>());
      expect((children.first as Tilemap).messageBubblePlaybackPaused, isTrue);
      expect(children.last, isA<Positioned>());
      expect((children.last as Positioned).child, isA<LegacyWorldMap>());
    },
  );

  test('World v2 uses Tilemap except in list mode', () {
    final map = WorldMap.world(
      definitionVersion: 2,
      worldId: 'w_1',
      common: common,
      legacy: legacy,
    );
    final listMap = WorldMap.world(
      definitionVersion: 2,
      worldId: 'w_1',
      common: common,
      legacy: const LegacyWorldMapConfig(
        points: <WorldPoint>[],
        showPointsList: true,
      ),
    );

    expect(map.build(_FakeBuildContext()), isA<Tilemap>());
    expect(listMap.build(_FakeBuildContext()), isA<LegacyWorldMap>());
  });
}

class _FakeBuildContext extends Fake implements BuildContext {}
