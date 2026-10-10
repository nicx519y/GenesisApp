import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/world_recent_summary.dart';

class Transport implements HttpTransport {
  final requests = <TransportRequest>[];
  Map<String, Object?> response = {
    'err_no': 0,
    'data': {'items': [], 'has_more': false, 'cursor': ''},
  };
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(response),
    );
  }
}

void main() {
  test(
    'facade requests exact endpoint, trims world and preserves opaque cursor',
    () async {
      final transport = Transport();
      final api = GenesisApi(
        apiClient: ApiClient(
          baseUrl: 'http://localhost/api/',
          transport: transport,
        ),
      );
      final first = await api.getWorldRecentSummary(worldId: ' w1 ');
      expect(first.items, isEmpty);
      expect(first.hasMore, isFalse);
      expect(
        transport.requests.single.uri.path,
        '/api/v1/world/recent_summary',
      );
      expect(transport.requests.single.method, 'GET');
      expect(transport.requests.single.uri.queryParameters, {'world_id': 'w1'});
      const cursor = ' +/=opaque cursor ';
      await api.getWorldRecentSummary(worldId: 'w1', cursor: cursor);
      expect(transport.requests.last.uri.queryParameters, {
        'world_id': 'w1',
        'cursor': cursor,
      });
      await expectLater(
        api.getWorldRecentSummary(worldId: ' '),
        throwsArgumentError,
      );
      expect(transport.requests.length, 2);
    },
  );

  test('nonzero business errors never become successful empty pages', () async {
    final transport = Transport();
    final api = GenesisApi(
      apiClient: ApiClient(
        baseUrl: 'http://localhost/api/',
        transport: transport,
      ),
    );
    for (final code in [4004, 20201, 3103, 5000]) {
      transport.response = {
        'err_no': code,
        'err_msg': 'backend message',
        'data': {},
      };
      await expectLater(
        api.getWorldRecentSummary(worldId: 'w1'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.message, 'message', 'backend message'),
        ),
      );
    }
  });

  test('parsing preserves order, duplicates, tick zero and full body', () {
    final page = WorldRecentSummaryPage.fromJson({
      'items': [
        {'body': 'first\nsecond. Still one body.', 'tick_no': 9},
        {'body': 'same', 'tick_no': 9},
        {'body': 'same', 'tick_no': 9},
        {'body': 'unheaded', 'tick_no': 0},
        {'body': 'older', 'tick_no': 7},
      ],
      'has_more': true,
      'cursor': 'opaque',
    });
    expect(page.items.map((e) => e.tickNo), [9, 9, 9, 0, 7]);
    expect(page.items.first.body, 'first\nsecond. Still one body.');
    expect(page.items.where((e) => e.body == 'same').length, 2);
  });

  test(
    'malformed successful response is a failure rather than empty state',
    () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'items': [], 'has_more': true, 'cursor': ''},
        {
          'items': [
            {'body': 'text'},
          ],
          'has_more': false,
          'cursor': '',
        },
      ]) {
        expect(
          () => WorldRecentSummaryPage.fromJson(json),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mock supplies ten items and continues the same tick across cursor pages',
    () async {
      final api = GenesisApi(useMock: true);
      final worlds = await api.v1.world.list();
      final list = worlds['list'] as List;
      final id = (list.first as Map)['info']['world_id'] as String;
      final first = await api.getWorldRecentSummary(worldId: id);
      final second = await api.getWorldRecentSummary(
        worldId: id,
        cursor: first.cursor,
      );
      expect(first.items.length, 10);
      expect(first.hasMore, isTrue);
      expect(second.items.first.tickNo, first.items.last.tickNo);
      expect(second.items.map((e) => e.tickNo), [9, 9, 0, 7]);
      expect(second.hasMore, isFalse);
      expect(second.cursor, '');
      await expectLater(
        api.getWorldRecentSummary(worldId: id, cursor: 'invalid'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 4004)),
      );
    },
  );
}
