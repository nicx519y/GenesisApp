import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_connection_controller.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_socket_transport.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('connect hydrates world detail and user locations', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    expect(service.identity?.senderId, 'user-1');
    expect(service.identity?.senderName, 'Player One');
    expect(service.state.world?.worldId, 'world-1');
    expect(service.state.world?.name, 'World One');
    expect(service.state.locationTree, hasLength(1));
    expect(service.state.entitiesById['char-1']?.locationId, 'loc-1');
    expect(service.state.entitiesById['user-1']?.locationId, 'loc-2');
    expect(service.state.entitiesById['user-1']?.name, 'Role One');
    expect(
      service.state.entitiesByLocation['loc-1']!.map((entity) => entity.id),
      contains('char-1'),
    );
    expect(
      service.state.entitiesByLocation['loc-2']!.map((entity) => entity.id),
      contains('user-1'),
    );
    expect(service.state.messagesByLocation['loc-1'], hasLength(1));
    expect(service.state.messagesByLocation['loc-2'], hasLength(1));
    expect(http.detailRequests, 1);
    expect(http.userLocationRequests, 1);
    expect(http.messagesRequestsByLocation['loc-1'], 1);
    expect(http.messagesRequestsByLocation['loc-2'], 1);
    expect(http.messagesRequestsByLocation.containsKey('loc-root'), isFalse);

    await service.dispose();
  });

  test(
    'connect loads cached messages before refreshing latest history',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport();
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          _httpMessageJson(
            messageId: 1,
            locationId: 'loc-1',
            content: 'cached',
          ),
        ],
      );
      http.messagesByLocation['loc-1'] = [
        _httpMessageJson(messageId: 2, locationId: 'loc-1', content: 'remote'),
      ];
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());

      expect(
        service.state.messagesByLocation['loc-1']!
            .map((message) => message.content)
            .toList(),
        ['cached', 'remote'],
      );
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.map((message) => message['content']).toList(), [
        'cached',
        'remote',
      ]);
      await service.dispose();
    },
  );

  test(
    'connect keeps hydrating when a location history request fails',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..failedMessageLocationIds.add('loc-1');
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
      );
      final failures = <ChatroomFailureEvent>[];
      final failureSub = service.failures.listen(failures.add);

      await service.connect(worldId: 'world-1', identity: _identity());

      expect(http.messagesRequestsByLocation['loc-1'], 1);
      expect(http.messagesRequestsByLocation['loc-2'], 1);
      expect(http.messagesRequestsByLocation.containsKey('loc-root'), isFalse);
      expect(http.userLocationRequests, 1);
      expect(
        failures.where((failure) => failure.code == 'snapshot_failed'),
        isEmpty,
      );
      await failureSub.cancel();
      await service.dispose();
    },
  );

  test(
    'history messages use requested location when response omits location id',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-1'] = [
          _httpMessageJson(
            messageId: 11,
            locationId: '',
            content: 'without location',
          ),
        ]
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final storage = MemoryChatroomMessageStorage();
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
        messageStorage: storage,
      );

      await service.connect(worldId: 'world-1', identity: _identity());

      final message = service.state.messagesByLocation['loc-1']!.singleWhere(
        (message) => message.messageId == 11,
      );
      expect(message.locationId, 'loc-1');
      final cached = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );
      expect(cached.single['location_id'], 'loc-1');
      await service.dispose();
    },
  );

  test(
    'chatroom message storage prunes each location to 200 messages',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: [
          for (var id = 1; id <= 205; id += 1)
            _httpMessageJson(
              messageId: id,
              locationId: 'loc-1',
              content: 'message-$id',
            ),
        ],
      );

      final records = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 250,
      );

      expect(records, hasLength(200));
      expect(records.first['msg_id'], 6);
      expect(records.last['msg_id'], 205);
    },
  );

  test('chatroom message storage loads messages before cursor', () async {
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: [
        for (var id = 1; id <= 5; id += 1)
          _httpMessageJson(
            messageId: id,
            locationId: 'loc-1',
            content: 'message-$id',
          ),
      ],
    );

    final records = await storage.loadMessagesBefore(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      beforeMessageId: 4,
      limit: 2,
    );

    expect(records.map((message) => message['msg_id']).toList(), [2, 3]);
  });

  test('loadOlderMessages requests remote history before cursor', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = [
        _httpMessageJson(
          messageId: 1,
          locationId: 'loc-1',
          content: 'remote-old',
        ),
        _httpMessageJson(
          messageId: 2,
          locationId: 'loc-1',
          content: 'remote-new',
        ),
      ]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    final page = await service.loadOlderMessages(
      locationId: 'loc-1',
      beforeMessageId: 2,
      limit: 20,
    );

    expect(page.loadedCount, 1);
    expect(page.hasMore, isFalse);
    expect(http.messageSinceByLocation['loc-1']?.last, 2);
    expect(
      service.state.messagesByLocation['loc-1']!
          .map((message) => message.content)
          .toList(),
      ['remote-old', 'remote-new'],
    );
    await service.dispose();
  });

  test('user message keeps user id when sender id is omitted', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'user_id': 'user-1',
      'sender_name': 'Player One',
      'msg_id': 61,
      'conversation_round_id': 1280,
      'payload': {'content': '你是谁', 'client_msg_id': 'client-1'},
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 61,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 61,
    );
    expect(message.userId, 'user-1');
    expect(message.senderId, isEmpty);
    expect(message.clientMsgId, 'client-1');
    await service.dispose();
  });

  test('narrator push with top-level fields enters location queue', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('nar_new_message', {
      'ts': 1780840607650,
      'world_id': 'world-1',
      'payload': {'content': '*黑暗中，芯片脉冲与数据卡蓝光交织*'},
      'msg_id': 155,
      'conversation_round_id': 1349,
      'sender_id': 'nar',
      'sender_name': '旁白',
      'location_id': 'loc-1',
      'broadcast': true,
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 155,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 155,
    );
    expect(message.conversationRoundId, '1349');
    expect(message.locationId, 'loc-1');
    expect(message.senderType, 'narrator');
    expect(message.senderId, 'nar');
    expect(message.senderName, '旁白');
    expect(message.content, '*黑暗中，芯片脉冲与数据卡蓝光交织*');
    await service.dispose();
  });

  test('narrator push from non-nar sender enters queue as character', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport()
      ..messagesByLocation['loc-1'] = const <Map<String, dynamic>>[]
      ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('nar_new_message', {
      'world_id': 'world-1',
      'payload': {'content': '角色旁白式发言'},
      'msg_id': 156,
      'conversation_round_id': 1350,
      'sender_id': 'char-1',
      'sender_name': 'Alice',
      'location_id': 'loc-1',
      'broadcast': true,
    });

    await _waitFor(
      () =>
          service.state.messagesByLocation['loc-1']?.any(
            (message) => message.messageId == 156,
          ) ==
          true,
    );
    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.messageId == 156,
    );
    expect(message.conversationRoundId, '1350');
    expect(message.senderId, 'char-1');
    expect(message.senderType, 'character');
    expect(message.content, '角色旁白式发言');
    await service.dispose();
  });

  test('active disconnect does not reconnect', () async {
    final socket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([socket]);
    final service = await _service(
      socketTransport: transport,
      heartbeatInterval: const Duration(milliseconds: 5),
      reconnectInterval: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await service.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(transport.connectCount, 1);
    expect(service.state.reconnecting, false);
    await service.dispose();
  });

  test('socket close reconnects when it was not user initiated', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final service = await _service(
      socketTransport: transport,
      reconnectInterval: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    await firstSocket.serverClose();

    await _waitFor(() => transport.connectCount == 2);
    expect(service.state.reconnecting, false);
    await service.dispose();
  });

  test('heartbeat ack failure reconnects', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final service = await _service(
      socketTransport: transport,
      heartbeatInterval: const Duration(milliseconds: 5),
      reconnectInterval: const Duration(milliseconds: 5),
      ackTimeout: const Duration(milliseconds: 5),
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    await _waitFor(() => transport.connectCount == 2);
    expect(
      firstSocket.sentTypes.where((type) => type == 'heartbeat').length,
      3,
    );
    await service.dispose();
  });

  test('world_change and user_location_change refresh snapshots', () async {
    final socket = _FakeChatroomSocket();
    final http = _WorldChatroomHttpTransport();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
      httpTransport: http,
    );

    await service.connect(worldId: 'world-1', identity: _identity());

    http.worldName = 'World Changed';
    socket.serverFrame('world_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'world_change'},
    });
    await _waitFor(() => service.state.world?.name == 'World Changed');

    http.userLocationId = 'loc-1';
    socket.serverFrame('user_location_change', {
      'world_id': 'world-1',
      'payload': {'event_type': 'user_location_change'},
    });
    await _waitFor(
      () => service.state.entitiesById['user-1']?.locationId == 'loc-1',
    );

    expect(http.detailRequests, 2);
    expect(http.userLocationRequests, 2);
    await service.dispose();
  });

  test(
    'message id gaps fetch missing messages and keep queues sorted',
    () async {
      final socket = _FakeChatroomSocket();
      final http = _WorldChatroomHttpTransport()
        ..messagesByLocation['loc-2'] = const <Map<String, dynamic>>[];
      final service = await _service(
        socketTransport: _FakeChatroomTransport(socket),
        httpTransport: http,
      );

      await service.connect(worldId: 'world-1', identity: _identity());
      socket.serverUserMessage(messageId: 1, roundId: 1, content: 'first');
      await _waitFor(
        () =>
            service.state.messagesByLocation['loc-1']?.any(
              (message) => message.messageId == 1,
            ) ==
            true,
      );

      socket.serverUserMessage(messageId: 3, roundId: 3, content: 'third');
      await _waitFor(
        () =>
            service.state.messagesByLocation['loc-1']?.any(
              (message) => message.messageId == 3,
            ) ==
            true,
      );

      expect(
        service.state.messagesByLocation['loc-1']!
            .map((message) => message.messageId)
            .toList(),
        [1, 2, 3],
      );
      expect(
        service.state.worldMessages.map((message) => message.content).toList(),
        ['first', 'gap', 'third'],
      );
      await service.dispose();
    },
  );

  test('llm stream updates are matched by location and round id', () async {
    final socket = _FakeChatroomSocket();
    final service = await _service(
      socketTransport: _FakeChatroomTransport(socket),
    );

    await service.connect(worldId: 'world-1', identity: _identity());
    socket.serverFrame('llm_stream_start', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': 10,
      'conversation_round_id': 8,
      'payload': {
        'sender_id': 'char-1',
        'sender_name': 'Alice',
        'round_order': 1,
      },
    });
    await _waitFor(
      () => service.state.streamMessagesByKey.containsKey('loc-1|8'),
    );

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-2',
      'msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'chunk': 'wrong'},
    });
    await _waitFor(() => service.state.lastFailure?.code == 'stream_missing');

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'chunk': 'hel'},
    });
    await _waitFor(
      () => service.state.streamMessagesByKey['loc-1|8']?.content == 'hel',
    );

    socket.serverFrame('llm_stream_end', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': 10,
      'conversation_round_id': 8,
      'payload': {'sender_id': 'char-1', 'content': 'hello'},
    });
    await _waitFor(
      () => !service.state.streamMessagesByKey.containsKey('loc-1|8'),
    );

    final message = service.state.messagesByLocation['loc-1']!.singleWhere(
      (message) => message.conversationRoundId == '8',
    );
    expect(message.content, 'hello');
    expect(message.streaming, false);
    await service.dispose();
  });
}

Future<WorldChatroomService> _service({
  required ChatroomSocketTransport socketTransport,
  HttpTransport? httpTransport,
  Duration heartbeatInterval = const Duration(seconds: 10),
  Duration reconnectInterval = const Duration(milliseconds: 20),
  Duration ackTimeout = const Duration(milliseconds: 20),
  ChatroomMessageStorage? messageStorage,
}) async {
  final store = MemoryUserSessionStore();
  await store.saveUid('user-1');
  await store.saveAuthToken('token-1');
  final api = GenesisApi(
    transport: httpTransport ?? _WorldChatroomHttpTransport(),
    useMock: false,
    deviceIdService: const _FakeDeviceIdService(),
    sessionStore: store,
    chatroomHttpBaseUrl: 'https://chatroom.test/',
  );
  final client = ChatroomClient(
    wsBaseUrl: 'ws://localhost:8082/aitown-chat/ws',
    sessionStore: store,
    deviceIdService: const _FakeDeviceIdService(),
    transport: socketTransport,
    heartbeatInterval: heartbeatInterval,
    ackTimeout: ackTimeout,
    autoHeartbeat: false,
  );
  return WorldChatroomService(
    api: api,
    client: client,
    messageStorage: messageStorage ?? MemoryChatroomMessageStorage(),
    heartbeatInterval: heartbeatInterval,
    reconnectInterval: reconnectInterval,
  );
}

ChatroomConnectionIdentity _identity() {
  return const ChatroomConnectionIdentity(
    userId: 'user-1',
    senderId: 'user-1',
    senderName: 'Player One',
  );
}

Map<String, dynamic> _httpMessageJson({
  required int messageId,
  required String locationId,
  required String content,
}) {
  return {
    'msg_id': messageId,
    'location_id': locationId,
    'conversation_round_id': messageId,
    'round_order': 1,
    'sender_type': 'user',
    'sender_id': 'user-$messageId',
    'sender_name': 'User $messageId',
    'user_id': 'user-$messageId',
    'content': content,
    'ts': 1717300000000 + messageId,
  };
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  if (!condition()) {
    fail('Condition was not met within $timeout');
  }
}

class _WorldChatroomHttpTransport implements HttpTransport {
  String worldName = 'World One';
  String userLocationId = 'loc-2';
  int detailRequests = 0;
  int userLocationRequests = 0;
  int messagesRequests = 0;
  final Set<String> failedMessageLocationIds = <String>{};
  final Map<String, int> messagesRequestsByLocation = {};
  final Map<String, List<int?>> messageSinceByLocation = {};
  final Map<String, List<Map<String, dynamic>>> messagesByLocation = {
    'loc-1': [
      _httpMessageJson(messageId: 2, locationId: 'loc-1', content: 'gap'),
    ],
    'loc-2': [
      _httpMessageJson(messageId: 4, locationId: 'loc-2', content: 'loc-2'),
    ],
  };

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final path = request.uri.path;
    if (path.endsWith('/api/v1/world/detail')) {
      detailRequests += 1;
      return _json({'err_no': 0, 'err_msg': 'succ', 'data': _worldDetail()});
    }
    if (path.endsWith('/aitown-chat/api/ulocation')) {
      userLocationRequests += 1;
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'world_id': 'world-1',
          'locations': [
            {
              'location_id': userLocationId,
              'users': [
                {
                  'user_id': 'user-1',
                  'user_name': 'Player One',
                  'avatar': 'player.png',
                },
              ],
            },
          ],
        },
      });
    }
    if (path.endsWith('/aitown-chat/api/messages')) {
      messagesRequests += 1;
      final locationId = request.uri.queryParameters['location_id'] ?? '';
      final since = int.tryParse(request.uri.queryParameters['since'] ?? '');
      messagesRequestsByLocation[locationId] =
          (messagesRequestsByLocation[locationId] ?? 0) + 1;
      messageSinceByLocation.putIfAbsent(locationId, () => <int?>[]).add(since);
      if (failedMessageLocationIds.contains(locationId)) {
        return _json({'err_no': 500, 'err_msg': 'history failed', 'data': {}});
      }
      final allMessages =
          messagesByLocation[locationId] ?? const <Map<String, dynamic>>[];
      final messages = since == null
          ? allMessages
          : allMessages
                .where((message) {
                  final messageId = message['msg_id'];
                  return messageId is int && messageId < since;
                })
                .toList(growable: false);
      return _json({
        'err_no': 0,
        'err_msg': 'succ',
        'data': {
          'messages': messages,
          'has_more': false,
          'newest_message_id': messages.fold<int>(
            0,
            (previous, message) => (message['msg_id'] as int? ?? 0) > previous
                ? message['msg_id'] as int
                : previous,
          ),
        },
      });
    }
    return _json({
      'err_no': 404,
      'err_msg': 'Unhandled test request: $path',
      'data': {},
    });
  }

  Map<String, Object?> _worldDetail() {
    return {
      'info': {
        'world_id': 'world-1',
        'world_name': worldName,
        'origin_id': 'origin-1',
        'origin_version': 1,
        'owner_uid': 'owner-1',
        'owner_name': 'Owner',
        'brief': 'brief',
        'setting': 'setting',
        'metric': {},
        'created_at': 1717300000000,
        'updated_at': 1717300000000,
        'status': 10,
      },
      'stats': {
        'character_cnt': 1,
        'connect_cnt': 1,
        'location_cnt': 2,
        'tick_cnt': 0,
        'player_cnt': 1,
      },
      'relation_status': 'owner',
      'characters': [
        {
          'char_id': 'char-1',
          'type': 'ai',
          'name': 'Alice',
          'avatar': 'alice.png',
          'location_id': 'loc-1',
        },
        {
          'char_id': 'char-user-1',
          'type': 'player',
          'player_uid': 'user-1',
          'name': 'Role One',
          'avatar': 'role.png',
          'location_id': 'loc-2',
        },
      ],
      'locations': [
        {
          'location_id': 'loc-root',
          'location_pid': '',
          'name': 'Town',
          'description': 'Town desc',
        },
        {
          'location_id': 'loc-1',
          'location_pid': 'loc-root',
          'name': 'Square',
          'description': 'Square desc',
        },
        {
          'location_id': 'loc-2',
          'location_pid': 'loc-root',
          'name': 'Cafe',
          'description': 'Cafe desc',
        },
      ],
      'ticks': [],
    };
  }

  TransportResponse _json(Map<String, Object?> body) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _SequencedChatroomTransport implements ChatroomSocketTransport {
  _SequencedChatroomTransport(this.results);

  final List<ChatroomSocket> results;
  int connectCount = 0;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    connectCount += 1;
    if (results.isEmpty) {
      throw StateError('no socket result queued');
    }
    return results.removeAt(0);
  }
}

class _FakeChatroomTransport implements ChatroomSocketTransport {
  _FakeChatroomTransport(this.socket);

  final _FakeChatroomSocket socket;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return socket;
  }
}

class _FakeChatroomSocket implements ChatroomSocket {
  final _messages = StreamController<String>.broadcast();
  final sent = <String>[];
  bool closed = false;

  List<String> get sentTypes {
    return sent
        .map(
          (raw) => (jsonDecode(raw) as Map<String, dynamic>)['type'] as String,
        )
        .toList(growable: false);
  }

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> send(String message) async {
    if (closed) throw StateError('socket closed');
    sent.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    await _messages.close();
  }

  Future<void> serverClose() async {
    await _messages.close();
  }

  void serverFrame(String type, Map<String, Object?> fields) {
    _messages.add(jsonEncode(<String, Object?>{'type': type, ...fields}));
  }

  void serverUserMessage({
    required int messageId,
    required int roundId,
    required String content,
  }) {
    serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': messageId,
      'conversation_round_id': roundId,
      'payload': {
        'round_order': 1,
        'sender_type': 'user',
        'sender_id': 'user-1',
        'sender_name': 'Player One',
        'content': content,
        'created_at': 1717300000000 + messageId,
      },
    });
  }
}
