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

  test('processed location tree resolves leaf chat target', () {
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

    expect(processed.chatTargetFor('district')?.id, 'room');
    expect(processed.chatTargetFor('room')?.id, 'room');
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

  test('origin detail does not create synthetic root when api omits root', () {
    final detail = OriginDetail.fromJson({
      'id': 5011605,
      'oid': 'o_5011605',
      'name': 'One Bed in Okinawa',
      'map_image': 'cover.webp',
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

    expect(detail.locations.map((location) => location.locationId), [
      'loc_1',
      'loc_1_1',
    ]);
    expect(detail.locationTree.map((node) => node.id), ['loc_1']);
    expect(detail.processedLocationTree.root?.id, 'loc_1');
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'loc_1_1',
    ]);
  });

  test('world detail does not create synthetic root when api omits root', () {
    final detail = WorldDetail.fromJson({
      'id': 5011605,
      'wid': 'w_5011605',
      'name': 'One Bed in Okinawa',
      'map_image': 'cover.webp',
      'world_locations': [
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

    expect(detail.worldLocations.map((location) => location['location_id']), [
      'loc_1',
      'loc_1_1',
    ]);
    expect(detail.worldLocationTree.map((node) => node.id), ['loc_1']);
    expect(detail.processedWorldLocationTree.root?.id, 'loc_1');
    expect(
      detail.processedWorldLocationTree.renderRoots.map((node) => node.id),
      ['loc_1_1'],
    );
  });

  test('origin detail uses existing root location instead of map root', () {
    final detail = OriginDetail.fromJson({
      'id': 7,
      'oid': 'ori_live',
      'name': 'Origin Root',
      'map_image': 'map.png',
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

    expect(detail.processedLocationTree.root?.id, 'root_old');
    expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
      'district',
    ]);
    expect(
      detail.processedLocationTree.flattenedRenderNodes.map((node) => node.id),
      ['district', 'room'],
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

      expect(detail.processedLocationTree.root?.id, 'root_old');
      expect(detail.processedLocationTree.renderRoots.map((node) => node.id), [
        'district',
      ]);
      expect(
        detail.processedLocationTree.chatTargetFor('district')?.id,
        'district',
      );
    },
  );

  test('world detail uses existing root location instead of map root', () {
    final detail = WorldDetail.fromJson({
      'id': 9,
      'wid': 'world_live',
      'name': 'World Root',
      'map_image': 'map.png',
      'world_locations': [
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

    expect(detail.processedWorldLocationTree.root?.id, 'root_old');
    expect(
      detail.processedWorldLocationTree.renderRoots.map((node) => node.id),
      ['district'],
    );
    expect(
      detail.processedWorldLocationTree.flattenedRenderNodes.map(
        (node) => node.id,
      ),
      ['district', 'room'],
    );
  });

  test(
    'world detail keeps level two leaf renderable without auto level three',
    () {
      final detail = WorldDetail.fromJson({
        'id': 10,
        'wid': 'world_two_level',
        'name': 'World Root',
        'map_image': 'map.png',
        'world_locations': [
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

      expect(detail.processedWorldLocationTree.root?.id, 'root_old');
      expect(
        detail.processedWorldLocationTree.renderRoots.map((node) => node.id),
        ['district'],
      );
      expect(
        detail.processedWorldLocationTree.chatTargetFor('district')?.id,
        'district',
      );
    },
  );
}
