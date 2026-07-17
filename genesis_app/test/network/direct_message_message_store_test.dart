import 'dart:async';
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

  test('stale sync response does not replace the active peer list', () async {
    final transport = _ControlledDmMessageTransport();
    final storage = MemoryDirectMessageMessageStorage();
    final store = await _store(transport, storage: storage);
    await storage.mergeMessages(
      ownerUid: 'me',
      peerUid: 'peer_2',
      messages: [_message('peer2_cached', minutesAgo: 1)],
    );

    final firstSync = store.syncLatest('peer_1');
    await transport.waitForRequest('peer_1');
    await store.loadFromDb('peer_2');

    expect(store.orderedMessageIds.value, ['peer2_cached']);

    transport.complete('peer_1', [_message('peer1_late', minutesAgo: 0)]);
    await firstSync;

    expect(store.orderedMessageIds.value, ['peer2_cached']);
    expect(store.rowListenable('peer2_cached'), isNotNull);
    expect(store.rowListenable('peer1_late'), isNull);
  });

  test('load from db keeps only the latest local page visible', () async {
    final storage = MemoryDirectMessageMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'me',
      peerUid: 'peer_1',
      messages: _cachedMessages(25),
    );
    final store = await _store(
      _DmMessageTransport({}, total: 0),
      storage: storage,
    );

    await store.loadFromDb('peer_1');

    expect(
      store.orderedMessageIds.value,
      List.generate(
        20,
        (index) => 'cached_${(index + 5).toString().padLeft(2, '0')}',
      ),
    );
    expect(store.rowListenable('cached_00'), isNull);
    expect(store.hasMoreOlder, isTrue);
  });

  test(
    'load older reads previous local page before requesting network',
    () async {
      final storage = MemoryDirectMessageMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'me',
        peerUid: 'peer_1',
        messages: _cachedMessages(25),
      );
      final transport = _DmMessageTransport({}, total: 0);
      final store = await _store(transport, storage: storage);

      await store.loadFromDb('peer_1');
      await store.loadOlder('peer_1');

      expect(
        store.orderedMessageIds.value,
        List.generate(
          25,
          (index) => 'cached_${index.toString().padLeft(2, '0')}',
        ),
      );
      expect(transport.requests, isEmpty);
      expect(store.hasMoreOlder, isFalse);
    },
  );

  test('cached full pages advance the remote older cursor', () async {
    final storage = MemoryDirectMessageMessageStorage();
    final cachedMessages = _cachedMessages(60);
    await storage.mergeMessages(
      ownerUid: 'me',
      peerUid: 'peer_1',
      messages: cachedMessages,
    );
    final transport = _DmMessageTransport({
      1: cachedMessages.skip(40).toList(growable: false),
    }, total: 60);
    final store = await _store(transport, storage: storage);

    await store.loadFromDb('peer_1');
    await store.syncLatest('peer_1');
    await store.loadOlder('peer_1');
    await store.loadOlder('peer_1');
    await store.loadOlder('peer_1');

    expect(store.orderedMessageIds.value, hasLength(60));
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.uri.queryParameters['pn'], '1');
    expect(store.hasMoreOlder, isFalse);
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
      final localNotifier = store.rowListenable(secondLocalId);
      final replacementNotifications = <List<String>>[];
      void recordReplacementNotification() {
        replacementNotifications.add([...store.orderedMessageIds.value]);
      }

      store.orderedMessageIds.addListener(recordReplacementNotification);
      await store.replaceLocalMessage(
        peerUid: 'peer_1',
        localMessageId: secondLocalId,
        serverMessage: {
          ..._message('server_1', minutesAgo: 0, content: 'server hello'),
          'sender_uid': '',
        },
      );
      store.orderedMessageIds.removeListener(recordReplacementNotification);
      expect(store.orderedMessageIds.value, ['server_1']);
      expect(replacementNotifications, [
        ['server_1'],
      ]);
      expect(store.rowListenable(secondLocalId), isNull);
      expect(identical(store.rowListenable('server_1'), localNotifier), isTrue);
      expect(
        store.rowListenable('server_1')!.value.sendStatus,
        DirectMessageSendStatus.sent,
      );
      expect(store.rowListenable('server_1')!.value.localId, secondLocalId);
      expect(store.rowListenable('server_1')!.value.senderUid, 'me');
      expect(store.rowListenable('server_1')!.value.content, 'hello');
    },
  );

  test(
    'ack keeps optimistic presentation while persisting server data',
    () async {
      final storage = MemoryDirectMessageMessageStorage();
      final store = await _store(
        _DmMessageTransport({}, total: 0),
        storage: storage,
      );

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
      expect(store.rowListenable('server_2')!.value.content, 'draft');
      final persisted = await storage.loadMessages(
        ownerUid: 'me',
        peerUid: 'peer_1',
      );
      expect(persisted.single.messageId, 'server_2');
      expect(persisted.single.content, 'server');
    },
  );

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

  test(
    'drafts are scoped by owner and peer, and empty content clears',
    () async {
      final storage = MemoryDirectMessageMessageStorage();
      final store = await _store(
        _DmMessageTransport({}, total: 0),
        storage: storage,
      );

      await store.saveDraft(peerUid: 'peer_1', content: 'hello draft');
      await store.saveDraft(peerUid: 'peer_2', content: 'other draft');

      expect(await store.loadDraft('peer_1'), 'hello draft');
      expect(await store.loadDraft('peer_2'), 'other draft');
      expect(
        await storage.loadDraft(ownerUid: 'someone_else', peerUid: 'peer_1'),
        '',
      );

      await store.saveDraft(peerUid: 'peer_1', content: '   ');

      expect(await store.loadDraft('peer_1'), '');
      expect(await store.loadDraft('peer_2'), 'other draft');
    },
  );

  test('clear draft removes only the selected conversation draft', () async {
    final store = await _store(_DmMessageTransport({}, total: 0));

    await store.saveDraft(peerUid: 'peer_1', content: 'first draft');
    await store.saveDraft(peerUid: 'peer_2', content: 'second draft');

    await store.clearDraft('peer_1');

    expect(await store.loadDraft('peer_1'), '');
    expect(await store.loadDraft('peer_2'), 'second draft');
  });
}

List<Map<String, dynamic>> _cachedMessages(int count) {
  final baseTime = DateTime.utc(2026, 5, 30, 12);
  return List.generate(count, (index) {
    return {
      'msg_id': 'cached_${index.toString().padLeft(2, '0')}',
      'conv_id': 'conv_1',
      'sender_uid': 'peer_1',
      'receiver_uid': 'me',
      'content': 'cached $index',
      'created_at':
          baseTime.add(Duration(minutes: index)).millisecondsSinceEpoch ~/ 1000,
    };
  });
}

Future<DirectMessageMessageStore> _store(
  HttpTransport transport, {
  DirectMessageMessageStorage? storage,
}) async {
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
    storage: storage ?? MemoryDirectMessageMessageStorage(),
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

class _ControlledDmMessageTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  final Map<String, Completer<List<Map<String, dynamic>>>> _completers = {};

  Future<void> waitForRequest(String peerUid) async {
    while (!_completers.containsKey(peerUid)) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void complete(String peerUid, List<Map<String, dynamic>> messages) {
    _completers[peerUid]!.complete(messages);
  }

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final peerUid = request.uri.queryParameters['peer_uid'] ?? '';
    final completer = _completers.putIfAbsent(
      peerUid,
      () => Completer<List<Map<String, dynamic>>>(),
    );
    final messages = await completer.future;
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {'list': messages, 'total': messages.length, 'pn': 1, 'rn': 20},
      }),
    );
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device';
}
