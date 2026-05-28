import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('sync latest writes messages sorted by created_at asc', () async {
    final transport = _DmMessageTransport({
      1: [_message('m2', minutesAgo: 1), _message('m1', minutesAgo: 2)],
    }, total: 2);
    final store = await _store(transport);

    await store.syncLatest('peer_1');

    expect(store.orderedMessageIds.value, ['m1', 'm2']);
    expect(transport.requests.single.uri.queryParameters['pn'], '1');
    expect(transport.requests.single.uri.queryParameters['rn'], '20');
  });

  test('load older requests next pages and merges without clearing', () async {
    final transport = _DmMessageTransport({
      1: [_message('m3', minutesAgo: 1)],
      2: [_message('m1', minutesAgo: 3), _message('m2', minutesAgo: 2)],
    }, total: 40);
    final store = await _store(transport);

    await store.syncLatest('peer_1');
    await store.loadOlder('peer_1');

    expect(store.orderedMessageIds.value, ['m1', 'm2', 'm3']);
    expect(transport.requests.last.uri.queryParameters['pn'], '2');
  });

  test(
    'optimistic local message can be replaced or deleted after failure',
    () async {
      final store = await _store(_DmMessageTransport({}, total: 0));

      final localId = await store.insertLocalMessage(
        peerUid: 'peer_1',
        senderUid: 'me',
        content: 'hello',
      );
      expect(store.orderedMessageIds.value, [localId]);
      expect(
        store.rowListenable(localId)!.value.sendStatus,
        DirectMessageSendStatus.sending,
      );

      await store.deleteMessage(peerUid: 'peer_1', messageId: localId);
      expect(store.orderedMessageIds.value, isEmpty);
      expect(store.rowListenable(localId), isNull);

      final secondLocalId = await store.insertLocalMessage(
        peerUid: 'peer_1',
        senderUid: 'me',
        content: 'hello',
      );
      await store.replaceLocalMessage(
        peerUid: 'peer_1',
        localMessageId: secondLocalId,
        serverMessage: _message('server_1', minutesAgo: 0, content: 'hello'),
      );
      expect(store.orderedMessageIds.value, ['server_1']);
      expect(store.rowListenable(secondLocalId), isNull);
      expect(
        store.rowListenable('server_1')!.value.sendStatus,
        DirectMessageSendStatus.sent,
      );
      expect(store.rowListenable('server_1')!.value.content, 'hello');
    },
  );

  test('replace local message overwrites instead of duplicating', () async {
    final store = await _store(_DmMessageTransport({}, total: 0));

    final localId = await store.insertLocalMessage(
      peerUid: 'peer_1',
      senderUid: 'me',
      content: 'draft',
    );
    await store.replaceLocalMessage(
      peerUid: 'peer_1',
      localMessageId: localId,
      serverMessage: _message('server_2', minutesAgo: 0, content: 'server'),
    );

    expect(store.orderedMessageIds.value, ['server_2']);
    expect(store.rowListenable(localId), isNull);
    expect(store.rowListenable('server_2')!.value.content, 'server');
  });

  test('clear cache removes active peer messages', () async {
    final store = await _store(
      _DmMessageTransport({
        1: [_message('m1', minutesAgo: 1)],
      }, total: 1),
    );

    await store.syncLatest('peer_1');
    expect(store.orderedMessageIds.value, ['m1']);

    await store.clearCache();

    expect(store.orderedMessageIds.value, isEmpty);
    expect(store.rowListenable('m1'), isNull);
  });
}

Future<DirectMessageMessageStore> _store(HttpTransport transport) async {
  final sessionStore = MemoryUserSessionStore();
  await sessionStore.saveUid('me');
  return DirectMessageMessageStore(
    api: GenesisApi(
      useMock: false,
      transport: transport,
      platformConfig: const DefaultPlatformConfig(),
      deviceIdService: const _FakeDeviceIdService(),
      sessionStore: sessionStore,
    ),
    sessionStore: sessionStore,
    storage: MemoryDirectMessageMessageStorage(),
  );
}

Map<String, dynamic> _message(
  String id, {
  required int minutesAgo,
  String content = 'hello',
}) {
  final now = DateTime.now().subtract(Duration(minutes: minutesAgo));
  return {
    'msg_id': id,
    'conv_id': 'conv_1',
    'sender_uid': id == 'server_1' ? 'me' : 'peer_1',
    'receiver_uid': id == 'server_1' ? 'peer_1' : 'me',
    'content': content,
    'created_at': now.millisecondsSinceEpoch ~/ 1000,
  };
}

class _DmMessageTransport implements HttpTransport {
  _DmMessageTransport(this.pages, {required this.total});

  final Map<int, List<Map<String, dynamic>>> pages;
  final int total;
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final page = int.tryParse(request.uri.queryParameters['pn'] ?? '') ?? 1;
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'list': pages[page] ?? const <Map<String, dynamic>>[],
          'total': total,
          'pn': page,
          'rn': 20,
        },
      }),
    );
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device';
}
