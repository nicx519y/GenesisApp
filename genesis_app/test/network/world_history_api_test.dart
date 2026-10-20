import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import '../pages/world/history/history_fixtures.dart';

class Backend implements HttpTransport {
  final requests = <TransportRequest>[];
  Object? data = {
    'world_id': 'w',
    'messages': [],
    'has_more': false,
    'cursor': '',
  };
  int errNo = 0;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode({
        'err_no': errNo,
        'err_msg': 'original backend message',
        'data': data,
      }),
    );
  }
}

void main() {
  test(
    'v1.1 requires stored tick/sub_tick on every message type, preserving int64 and zero',
    () {
      for (final type in ['user', 'character', 'narrator', 'tick']) {
        final zero = WorldHistoryMessage.fromJson(
          historyJson('zero', type: type),
        );
        expect((zero.tickNo, zero.subTickNo), (0, 0));
        final large = WorldHistoryMessage.fromJson({
          ...historyJson(
            'large',
            type: type,
            tick: 9007199254740993,
            subTick: 3,
          ),
          'tick_no': 99,
          'sub_tick_no': 88,
          'subtick_no': 77,
        });
        expect((large.tickNo, large.subTickNo), (9007199254740993, 3));
        for (final key in ['tick', 'sub_tick']) {
          final missing = historyJson('missing', type: type)..remove(key);
          expect(
            () => WorldHistoryMessage.fromJson(missing),
            throwsFormatException,
          );
          for (final invalid in [null, '7', 7.5]) {
            expect(
              () => WorldHistoryMessage.fromJson({
                ...historyJson('bad', type: type),
                key: invalid,
              }),
              throwsFormatException,
            );
          }
        }
      }
    },
  );

  test(
    'facade uses chatroom client auth/interceptor, opaque cursor, string ID',
    () async {
      final b = Backend();
      var intercepted = 0;
      final client = ApiClient(
        baseUrl: 'https://history.invalid/',
        transport: b,
        requestHeaderProvider: () async => {'Authorization': 'Bearer session'},
        requestInterceptor: (request, send) {
          intercepted++;
          return send(request);
        },
      );
      final api = GenesisApi(
        useMock: false,
        apiClient: client,
        chatroomHttpClient: client,
      );
      b.data = {
        'world_id': 'w',
        'messages': [
          historyJson('9007199254740993123123', tick: 7, subTick: 3),
        ],
        'has_more': true,
        'cursor': ' opaque+/=中文 ',
      };
      final page = await api.getWorldHistory(worldId: 'w');
      expect(page.messages.single.id, '9007199254740993123123');
      expect(
        (page.messages.single.tickNo, page.messages.single.subTickNo),
        (7, 3),
      );
      expect(b.requests.single.uri.path, '/aitown-chat/api/v1/world/history');
      expect(b.requests.single.uri.queryParameters, {
        'world_id': 'w',
        'limit': '20',
      });
      expect(b.requests.single.headers['Authorization'], 'Bearer session');
      b.data = {
        'world_id': 'w',
        'messages': [],
        'has_more': false,
        'cursor': '',
      };
      await api.getWorldHistory(worldId: 'w', cursor: page.cursor);
      expect(b.requests.last.uri.queryParameters['cursor'], page.cursor);
      expect(intercepted, 2);
    },
  );
  test(
    'business errors and invalid response never become empty success',
    () async {
      final b = Backend();
      final client = ApiClient(
        baseUrl: 'https://history.invalid/',
        transport: b,
      );
      final api = GenesisApi(
        useMock: false,
        apiClient: client,
        chatroomHttpClient: client,
      );
      b.errNo = 403;
      await expectLater(
        api.getWorldHistory(worldId: 'w'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'original backend message',
          ),
        ),
      );
      b.errNo = 0;
      for (final data in [
        null,
        {},
        {'world_id': 'other', 'messages': [], 'has_more': false, 'cursor': ''},
        {'world_id': 'w', 'messages': [], 'has_more': 'false', 'cursor': ''},
        {'world_id': 'w', 'messages': [], 'has_more': true, 'cursor': ''},
        {'world_id': 'w', 'messages': [], 'has_more': true, 'cursor': 'same'},
        {
          'world_id': 'w',
          'messages': [
            {...historyJson('1'), 'global_message_id': 123},
          ],
          'has_more': false,
          'cursor': '',
        },
      ]) {
        b.data = data;
        await expectLater(
          api.getWorldHistory(worldId: 'w', cursor: 'same'),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
  test(
    'mock provides independent canonical Tick and reloadable world pages',
    () async {
      final client = ApiClient(
        baseUrl: 'https://mock.invalid/',
        transport: LocalMockGenesisTransport.instance,
      );
      final api = GenesisApi(
        useMock: false,
        apiClient: client,
        chatroomHttpClient: client,
      );
      final first = await api.getWorldHistory(worldId: 'w');
      final second = await api.getWorldHistory(
        worldId: 'w',
        cursor: first.cursor,
      );
      final replay = await api.getWorldHistory(
        worldId: 'w',
        cursor: first.cursor,
      );
      final last = await api.getWorldHistory(
        worldId: 'w',
        cursor: second.cursor,
      );
      expect(first.messages.length, 20);
      expect(second.messages.length, 20);
      expect(last.messages.length, 5);
      expect(last.hasMore, isFalse);
      expect(last.cursor, isEmpty);
      expect(
        replay.messages.map((m) => m.id),
        second.messages.map((m) => m.id),
      );
      expect(first.messages.map((m) => m.id), [
        for (var i = 19; i >= 0; i--) '9007199254740993$i',
      ]);
      expect(second.messages.map((m) => m.id), [
        for (var i = 39; i >= 20; i--) '9007199254740993$i',
      ]);
      expect(first.messages.last.tick, isNotNull);
    },
  );
}
