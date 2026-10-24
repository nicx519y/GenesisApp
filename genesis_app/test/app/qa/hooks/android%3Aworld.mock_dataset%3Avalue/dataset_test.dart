import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_registry.dart' as responses;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorldDataset dataset;
  late String owner;
  late bool current;
  late Map<String, JsonMap> seed;
  TransportRequest request(String path, {String method = 'GET'}) =>
      TransportRequest(
        method: method,
        uri: Uri.parse('https://mock/api/v1/world/$path'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 1000,
      );
  setUp(() {
    owner = 'qa_test_world_owner';
    current = true;
    seed = {
      'detail': {
        'info': {
          'world_id': 'w1',
          'world_name': 'World',
          'current_time': 'Day 1',
          'status': 20,
        },
        'relation_status': 'none',
      },
      'info': {
        'info': {'world_id': 'w1'},
      },
      'map': {
        'tile_types': {'grass': 'grass.png'},
        'map_json': {
          'width': 1,
          'height': 1,
          'tiles': [
            {'x': 0, 'y': 0, 'type': 'grass'},
          ],
        },
      },
    };
    dataset = WorldDataset(
      registerResponder: (respond) => responses.registerQaHook('test.world.dataset', respond),
      resource: 'r',
      owner: owner,
      currentOwner: () async => owner,
      currentResource: () => current,
      list: () async => {
        'list': [
          {
            'info': {'world_id': 'w1'},
          },
        ],
      },
      fetch: (endpoint, id) async {
        final response = await dataset.respond(
          request('$endpoint?world_id=$id&location_id=root'),
        );
        return response == null
            ? copyWorldJson(seed[endpoint]!)
            : jsonDecode(response.body)['data'] as JsonMap;
      },
    );
  });
  test(
    'real response override matches only acquired world and root map, then restores snapshot',
    () async {
      expect((await dataset.read())['prepared'], false);
      await expectLater(dataset.restore(), throwsStateError);
      try {
        expect((await dataset.prepare())['prepared'], true);
        expect(await dataset.respond(request('detail?world_id=other')), isNull);
        expect(
          await dataset.respond(request('map?world_id=w1&location_id=leaf')),
          isNull,
        );
        expect(
          await dataset.respond(request('detail?world_id=w1', method: 'POST')),
          isNull,
        );
        await dataset.replace('detail', ['info', 'world_name'], 'Changed');
        expect(
          (await dataset.selected('detail'))['info']['world_name'],
          'Changed',
        );
        expect(seed['detail']!['info']['world_name'], 'World');
      } finally {
        final receipt = await dataset.restore();
        expect(receipt, {
          'restored': true,
          'mapImageReleased': true,
          'matchesSnapshot': true,
          'resource': 'r',
        });
      }
      expect(await dataset.respond(request('detail?world_id=w1')), isNull);
      expect((await dataset.read())['prepared'], false);
      expect((await dataset.restore())['matchesSnapshot'], true);
      await expectLater(dataset.prepare(), throwsStateError);
    },
  );
  test(
    'identity or resource change blocks response without overwriting source',
    () async {
      await dataset.prepare();
      try {
        owner = 'foreign';
        await expectLater(
          dataset.respond(request('detail?world_id=w1')),
          throwsStateError,
        );
        await expectLater(dataset.restore(), throwsStateError);
        owner = 'qa_test_world_owner';
        current = false;
        await expectLater(dataset.selected('detail'), throwsStateError);
      } finally {
        owner = 'qa_test_world_owner';
        current = true;
        await dataset.restore();
      }
    },
  );
  test('cleanup failure retains accurate failure and can be retried', () async {
    await dataset.prepare();
    final original = copyWorldJson(seed['detail']!);
    seed['detail']!['info']['world_name'] = 'foreign change';
    await expectLater(dataset.restore(), throwsStateError);
    expect(dataset.active, false);
    expect(seed['detail']!['info']['world_name'], 'foreign change');
    seed['detail'] = original;
    expect((await dataset.restore())['matchesSnapshot'], true);
  });
  test('response registration belongs to acquired data and releases on restore', () async {
    final req = request('detail?world_id=w1');
    expect(await responses.dispatchQaMockResponders(req), isNull);
    await dataset.prepare();
    try {
      expect(await responses.dispatchQaMockResponders(req), isNotNull);
      await dataset.prepare(); // Same resource never registers twice.
      expect(await responses.dispatchQaMockResponders(req), isNotNull);
      owner = 'foreign';
      await expectLater(responses.dispatchQaMockResponders(req), throwsStateError);
    } finally {
      owner = 'qa_test_world_owner';
      await dataset.restore();
    }
    expect(await responses.dispatchQaMockResponders(req), isNull);
    await dataset.restore(); // Repeated cleanup remains safe.
  });
  test('example-domain tiles get owned bytes and restore the original map', () async {
    seed['map']!['tile_types'] = {
      'grass': 'https://cdn.example.com/tilemap/mock_tile.png',
      'other': 'https://real.example.org/map.png',
    };
    final snapshot = copyWorldJson(seed['map']!);
    await dataset.prepare();
    try {
      final map = await dataset.selected('map');
      final tiles = map['tile_types'] as Map;
      expect(Uri.parse(tiles['grass'] as String).host, '127.0.0.1');
      expect(tiles['other'], 'https://real.example.org/map.png');
      expect(map['map_json'], snapshot['map_json']);
      expect(seed['map'], snapshot);
      dataset.contractMapAvailable(false);
      expect(await dataset.selected('map'), isEmpty);
      dataset.contractMapAvailable(true);
      expect(await dataset.selected('map'), map);
      // Repeated prepare retains the same lease rather than opening another port.
      await dataset.prepare();
      expect(await dataset.selected('map'), map);
    } finally {
      final receipt = await dataset.restore();
      expect(receipt['matchesSnapshot'], isTrue);
      expect(receipt['mapImageReleased'], isTrue);
    }
    expect(await dataset.fetch('map', 'w1'), snapshot);
  });
  test('JSON equality ignores object key order but preserves list order', () {
    const equality = DeepCollectionEqualityForWorld();
    expect(
      equality.equal(
        {
          'a': 1,
          'b': [2, 3],
        },
        {
          'b': [2, 3],
          'a': 1,
        },
      ),
      true,
    );
    expect(
      equality.equal(
        {
          'a': [1, 2],
        },
        {
          'a': [2, 1],
        },
      ),
      false,
    );
  });
}
