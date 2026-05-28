import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('full sync requests rn 100 pages until the last partial page', () async {
    final transport = _DmConversationTransport((request) {
      final page = request.uri.queryParameters['pn'];
      final count = page == '1' ? 100 : 1;
      return _ok({
        'list': List.generate(
          count,
          (index) => _conversation(
            convId: 'conv_${page}_$index',
            messageId: 'msg_${page}_$index',
            minutesAgo: page == '1' ? index + 5 : 1,
          ),
        ),
        'total': 101,
        'pn': int.parse(page ?? '1'),
        'rn': 100,
        'next_after_message_id': 'cursor_full',
      });
    });
    final store = await _store(transport);

    await store.syncConversations();

    expect(transport.requests, hasLength(2));
    expect(transport.requests[0].uri.queryParameters['pn'], '1');
    expect(transport.requests[0].uri.queryParameters['rn'], '100');
    expect(transport.requests[1].uri.queryParameters['pn'], '2');
    expect(transport.requests[1].uri.queryParameters['rn'], '100');
    expect(store.orderedConversationIds.value.first, 'conv_2_0');
  });

  test(
    'delta sync sends only after_message_id and merges by conv_id',
    () async {
      var requestCount = 0;
      final transport = _DmConversationTransport((request) {
        requestCount += 1;
        if (requestCount == 1) {
          return _ok({
            'list': [
              _conversation(
                convId: 'conv_existing',
                messageId: 'msg_old',
                message: 'old',
                minutesAgo: 20,
              ),
            ],
            'next_after_message_id': 'cursor_1',
          });
        }
        return _ok({
          'list': [
            _conversation(
              convId: 'conv_existing',
              messageId: 'msg_new',
              message: 'updated',
              minutesAgo: 1,
            ),
            _conversation(
              convId: 'conv_new',
              messageId: 'msg_insert',
              message: 'inserted',
              minutesAgo: 2,
            ),
          ],
          'next_after_message_id': 'cursor_2',
        });
      });
      final store = await _store(transport);

      await store.syncConversations();
      final existingNotifier = store.rowListenable('conv_existing')!;
      await store.syncConversations();

      final deltaRequest = transport.requests.last;
      expect(deltaRequest.uri.queryParameters['after_message_id'], 'cursor_1');
      expect(deltaRequest.uri.queryParameters.containsKey('pn'), isFalse);
      expect(deltaRequest.uri.queryParameters.containsKey('rn'), isFalse);
      expect(existingNotifier.value.lastMessage, 'updated');
      expect(store.rowListenable('conv_existing'), same(existingNotifier));
      expect(store.orderedConversationIds.value, ['conv_existing', 'conv_new']);
    },
  );

  test('empty delta keeps row notifiers and ordered ids unchanged', () async {
    var requestCount = 0;
    final transport = _DmConversationTransport((request) {
      requestCount += 1;
      if (requestCount == 1) {
        return _ok({
          'list': [
            _conversation(convId: 'conv_1', messageId: 'msg_1', minutesAgo: 1),
          ],
          'next_after_message_id': 'cursor_1',
        });
      }
      return _ok({
        'list': <Map<String, dynamic>>[],
        'next_after_message_id': 'cursor_1',
      });
    });
    final store = await _store(transport);

    await store.syncConversations();
    final ids = store.orderedConversationIds.value;
    final notifier = store.rowListenable('conv_1');
    await store.syncConversations();

    expect(store.orderedConversationIds.value, same(ids));
    expect(store.rowListenable('conv_1'), same(notifier));
  });

  test('clear cache removes conversations and sync cursor', () async {
    final transport = _DmConversationTransport((request) {
      return _ok({
        'list': [
          _conversation(convId: 'conv_1', messageId: 'msg_1', minutesAgo: 1),
        ],
        'next_after_message_id': 'cursor_1',
      });
    });
    final store = await _store(transport);

    await store.syncConversations();
    expect(store.orderedConversationIds.value, ['conv_1']);

    await store.clearCache();

    expect(store.orderedConversationIds.value, isEmpty);
    expect(store.rowListenable('conv_1'), isNull);
    await store.syncConversations();
    expect(transport.requests.last.uri.queryParameters['pn'], '1');
    expect(
      transport.requests.last.uri.queryParameters.containsKey(
        'after_message_id',
      ),
      isFalse,
    );
  });
}

Future<DirectMessageConversationStore> _store(HttpTransport transport) async {
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('u_test');
  return DirectMessageConversationStore(
    api: GenesisApi(
      useMock: false,
      transport: transport,
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
    ),
    sessionStore: sessionStore,
    storage: MemoryDirectMessageConversationStorage(),
  );
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device';
}

Map<String, dynamic> _conversation({
  required String convId,
  required String messageId,
  String message = 'hello',
  int minutesAgo = 1,
}) {
  final now = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return {
    'conv_id': convId,
    'peer': {
      'uid': 'peer_$convId',
      'name': 'Peer $convId',
      'avatar': '',
      'last_login_at':
          DateTime.utc(2026, 5, 20, 10).millisecondsSinceEpoch ~/ 1000,
      'create_at': DateTime.utc(2026, 5, 2, 8).millisecondsSinceEpoch ~/ 1000,
    },
    'last_message_id': messageId,
    'last_message': message,
    'last_message_at': now.millisecondsSinceEpoch ~/ 1000,
    'last_sender_uid': 'peer_$convId',
    'unread_cnt': 0,
    'is_friend': true,
    'i_blocked_peer': false,
    'peer_blocked_me': false,
    'can_send_next_message': true,
  };
}

TransportResponse _ok(Map<String, dynamic> data) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
  );
}

class _DmConversationTransport implements HttpTransport {
  _DmConversationTransport(this.handler);

  final TransportResponse Function(TransportRequest request) handler;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return handler(request);
  }
}
