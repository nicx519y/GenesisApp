import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';

void main() {
  test('buildLocationTree orders locations by parent hierarchy depth', () {
    final locations = [
      {'location_id': 'root', 'location_pid': ''},
      {'location_id': 'sibling', 'location_pid': ''},
      {'location_id': 'child', 'location_pid': 'root'},
      {'location_id': 'grandchild', 'location_pid': 'child'},
    ];

    final tree = buildLocationTree(
      locations,
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );
    final flattened = flattenLocationTree(tree);

    expect(flattened.map((node) => node.id), [
      'root',
      'child',
      'grandchild',
      'sibling',
    ]);
    expect(flattened.map((node) => node.depth), [0, 1, 2, 0]);
  });

  test('processed location tree renders from root children', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'root_world', 'location_pid': ''},
        {'location_id': 'district', 'location_pid': 'root_world'},
        {'location_id': 'room', 'location_pid': 'district'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );

    final processed = processLocationTree(tree);

    expect(processed.root?.id, 'root_world');
    expect(processed.renderRoots.map((node) => node.id), ['district']);
    expect(processed.flattenedRenderNodes.map((node) => node.id), [
      'district',
      'room',
    ]);
  });

  test(
    'processed location tree renders roots when there is no single root',
    () {
      final tree = buildLocationTree(
        [
          {'location_id': 'district', 'location_pid': ''},
          {'location_id': 'room', 'location_pid': 'district'},
          {'location_id': 'market', 'location_pid': ''},
        ],
        idOf: (location) => '${location['location_id']}',
        parentIdOf: (location) => '${location['location_pid']}',
      );

      final processed = processLocationTree(tree);

      expect(processed.root, isNull);
      expect(processed.renderRoots.map((node) => node.id), [
        'district',
        'market',
      ]);
    },
  );

  test('processed location tree resolves only leaf chat target', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'root_world', 'location_pid': ''},
        {'location_id': 'district', 'location_pid': 'root_world'},
        {'location_id': 'room', 'location_pid': 'district'},
        {'location_id': 'market', 'location_pid': 'root_world'},
        {'location_id': 'stall', 'location_pid': 'market'},
        {'location_id': 'cellar', 'location_pid': 'market'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );

    final processed = processLocationTree(tree);

    expect(processed.chatTargetFor('district'), isNull);
    expect(processed.chatTargetFor('room')?.id, 'room');
    expect(processed.shouldDrillInto('district'), isTrue);
    expect(processed.chatTargetFor('market'), isNull);
    expect(processed.shouldDrillInto('market'), isTrue);
  });

  test('processed location tree aggregates descendant values with dedupe', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'root_world', 'location_pid': ''},
        {'location_id': 'district', 'location_pid': 'root_world'},
        {'location_id': 'room', 'location_pid': 'district'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );
    final processed = processLocationTree(tree);

    final values = processed.aggregateValues<Map<String, String>>('district', {
      'district': [
        {'id': 'a', 'name': 'Ada'},
      ],
      'room': [
        {'id': 'a', 'name': 'Ada moved'},
        {'id': 'b', 'name': 'Bert'},
      ],
    }, idOf: (value) => value['id'] ?? '');

    expect(values.map((value) => value['name']), ['Ada moved', 'Bert']);
  });

  test('origin detail creates synthetic root with origin map url', () {
    final detail = OriginDetail.fromJson({
      'id': 5011605,
      'oid': 'o_5011605',
      'name': 'One Bed in Okinawa',
      'map_image': 'cover.webp',
      'map_url': 'origin-root.png',
      'owner_uid': 'u_origin_owner',
      'locations': [
        {
          'id': 103145202,
          'origin_id': 5011605,
          'location_id': 'loc_1',
          'location_pid': '',
          'name': 'Okinawa',
          'map_url': 'loc_1.png',
        },
        {
          'id': 338294308,
          'origin_id': 5011605,
          'location_id': 'loc_1_1',
          'location_pid': 'loc_1',
          'name': 'Seaside Hotel',
        },
      ],
    });

    expect(detail.allLocations.map((location) => location.locationId), [
      'loc_1',
      'loc_1_1',
    ]);
    expect(detail.locations.map((location) => location.locationId), ['loc_1']);
    expect(
      detail.locations.single.locations.map((location) => location.locationId),
      ['loc_1_1'],
    );
    expect(detail.ownerUid, 'u_origin_owner');
    expect(detail.locationTree.map((node) => node.id), [
      originSyntheticRootLocationId,
    ]);
    expect(
      detail.processedLocationTree.root?.id,
      originSyntheticRootLocationId,
    );
    expect(detail.processedLocationTree.root?.value.mapUrl, 'origin-root.png');
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'loc_1',
    ]);
  });

  test('world detail always creates synthetic root', () {
    final detail = WorldDetail.fromJson({
      'id': 5011605,
      'world_id': 'w_5011605',
      'name': 'One Bed in Okinawa',
      'map_image': 'cover.webp',
      'locations': [
        {
          'location_id': 'loc_1',
          'location_pid': '',
          'location_name': 'Okinawa',
          'map_url': 'loc_1.png',
        },
        {
          'location_id': 'loc_1_1',
          'location_pid': 'loc_1',
          'location_name': 'Seaside Hotel',
        },
      ],
    });

    expect(detail.locations.map((location) => location['location_id']), [
      'loc_1',
      'loc_1_1',
    ]);
    expect(detail.locationTree.map((node) => node.id), [
      worldSyntheticRootLocationId,
    ]);
    expect(detail.processedLocationTree.root?.id, worldSyntheticRootLocationId);
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'loc_1',
    ]);
  });

  test('world detail creates synthetic root for multiple root locations', () {
    final detail = WorldDetail.fromJson({
      'id': 5011606,
      'world_id': 'w_5011606',
      'name': 'Multi Root',
      'map_url': 'world-map.png',
      'locations': [
        {'location_id': 'loc_1', 'location_pid': '', 'location_name': 'China'},
        {
          'location_id': 'loc_1_1',
          'location_pid': 'loc_1',
          'location_name': 'Beijing',
        },
        {
          'location_id': 'loc_1_1_1',
          'location_pid': 'loc_1_1',
          'location_name': 'Zhongguancun',
        },
        {'location_id': 'loc_2', 'location_pid': '', 'location_name': 'USA'},
        {
          'location_id': 'loc_2_1',
          'location_pid': 'loc_2',
          'location_name': 'Silicon Valley',
        },
        {
          'location_id': 'loc_2_1_1',
          'location_pid': 'loc_2_1',
          'location_name': 'Palo Alto Lab',
        },
      ],
    });

    expect(detail.mapImageUrl, 'world-map.png');
    expect(detail.processedLocationTree.root?.id, worldSyntheticRootLocationId);
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'loc_1',
      'loc_2',
    ]);
    expect(
      detail.processedLocationTree.flattenedRenderNodes.map((node) => node.id),
      ['loc_1', 'loc_1_1', 'loc_1_1_1', 'loc_2', 'loc_2_1', 'loc_2_1_1'],
    );
    expect(detail.processedLocationTree.nodeById('loc_2_1_1')?.depth, 3);
  });

  test('origin detail keeps existing root under synthetic root', () {
    final detail = OriginDetail.fromJson({
      'id': 7,
      'oid': 'ori_live',
      'name': 'Origin Root',
      'map_image': 'map.png',
      'map_url': 'origin-map.png',
      'locations': [
        {
          'id': 1,
          'origin_id': 7,
          'location_id': 'root_old',
          'location_pid': '',
          'name': 'Legacy Root',
        },
        {
          'id': 2,
          'origin_id': 7,
          'location_id': 'district',
          'location_pid': 'root_old',
          'name': 'District',
        },
        {
          'id': 3,
          'origin_id': 7,
          'location_id': 'room',
          'location_pid': 'district',
          'name': 'Room',
        },
      ],
    });

    expect(
      detail.processedLocationTree.root?.id,
      originSyntheticRootLocationId,
    );
    expect(detail.processedLocationTree.root?.value.mapUrl, 'origin-map.png');
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'root_old',
    ]);
    expect(
      detail.processedLocationTree.flattenedRenderNodes.map((node) => node.id),
      ['root_old', 'district', 'room'],
    );
  });

  test(
    'origin detail keeps level two leaf renderable without auto level three',
    () {
      final detail = OriginDetail.fromJson({
        'id': 8,
        'oid': 'ori_two_level',
        'name': 'Origin Root',
        'map_image': 'map.png',
        'locations': [
          {
            'id': 1,
            'origin_id': 8,
            'location_id': 'root_old',
            'location_pid': '',
            'name': 'Legacy Root',
          },
          {
            'id': 2,
            'origin_id': 8,
            'location_id': 'district',
            'location_pid': 'root_old',
            'name': 'District',
          },
        ],
      });

      expect(
        detail.processedLocationTree.root?.id,
        originSyntheticRootLocationId,
      );
      expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
        'root_old',
      ]);
      expect(
        detail.processedLocationTree.chatTargetFor('district')?.id,
        'district',
      );
    },
  );

  test('world detail keeps existing root under synthetic root', () {
    final detail = WorldDetail.fromJson({
      'id': 9,
      'world_id': 'world_live',
      'name': 'World Root',
      'map_image': 'map.png',
      'locations': [
        {
          'location_id': 'root_old',
          'location_pid': '',
          'location_name': 'Legacy Root',
        },
        {
          'location_id': 'district',
          'location_pid': 'root_old',
          'location_name': 'District',
        },
        {
          'location_id': 'room',
          'location_pid': 'district',
          'location_name': 'Room',
        },
      ],
    });

    expect(detail.processedLocationTree.root?.id, worldSyntheticRootLocationId);
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'root_old',
    ]);
    expect(
      detail.processedLocationTree.flattenedRenderNodes.map((node) => node.id),
      ['root_old', 'district', 'room'],
    );
  });

  test(
    'world detail keeps level two leaf renderable without auto level three',
    () {
      final detail = WorldDetail.fromJson({
        'id': 10,
        'world_id': 'world_two_level',
        'name': 'World Root',
        'map_image': 'map.png',
        'locations': [
          {
            'location_id': 'root_old',
            'location_pid': '',
            'location_name': 'Legacy Root',
          },
          {
            'location_id': 'district',
            'location_pid': 'root_old',
            'location_name': 'District',
          },
        ],
      });

      expect(
        detail.processedLocationTree.root?.id,
        worldSyntheticRootLocationId,
      );
      expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
        'root_old',
      ]);
      expect(detail.processedLocationTree.chatTargetFor('root_old'), isNull);
    },
  );

  test('initial map display keeps multiple root children visible', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'root', 'location_pid': ''},
        {'location_id': 'a', 'location_pid': 'root'},
        {'location_id': 'b', 'location_pid': 'a'},
        {'location_id': 'c', 'location_pid': 'b'},
        {'location_id': 'a1', 'location_pid': 'root'},
        {'location_id': 'b1', 'location_pid': 'a1'},
        {'location_id': 'c1', 'location_pid': 'b1'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );

    final processed = processLocationTree(tree);

    expect(processed.initialMapDisplayRoots.map((node) => node.id), ['root']);
    expect(processed.initialMapRenderRoots.map((node) => node.id), ['a', 'a1']);
  });

  test('initial map display follows single chain to leaf parent', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'root', 'location_pid': ''},
        {'location_id': 'a', 'location_pid': 'root'},
        {'location_id': 'b', 'location_pid': 'a'},
        {'location_id': 'c', 'location_pid': 'b'},
        {'location_id': 'd', 'location_pid': 'c'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );

    final processed = processLocationTree(tree);

    expect(processed.initialMapDisplayRoots.map((node) => node.id), ['c']);
    expect(processed.initialMapRenderRoots.map((node) => node.id), ['d']);
  });

  test('initial map display does not drill into multiple top-level roots', () {
    final tree = buildLocationTree(
      [
        {'location_id': 'a', 'location_pid': ''},
        {'location_id': 'b', 'location_pid': 'a'},
        {'location_id': 'c', 'location_pid': 'b'},
        {'location_id': 'a1', 'location_pid': ''},
        {'location_id': 'b1', 'location_pid': 'a1'},
        {'location_id': 'c1', 'location_pid': 'b1'},
      ],
      idOf: (location) => '${location['location_id']}',
      parentIdOf: (location) => '${location['location_pid']}',
    );

    final processed = processLocationTree(tree);

    expect(processed.initialMapDisplayRoots.map((node) => node.id), [
      'a',
      'a1',
    ]);
    expect(processed.initialMapRenderRoots.map((node) => node.id), ['a', 'a1']);
  });
}
