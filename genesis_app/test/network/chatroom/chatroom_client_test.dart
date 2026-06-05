import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_connection_controller.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_socket_transport.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('connect only opens socket with world query and auth header', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(transport);

    final session = await client.connect(
      worldId: 'world-1',
      locationId: 'loc-1',
    );

    expect(
      transport.lastUri.toString(),
      'ws://localhost:8082/aitown-chat/ws?world_id=world-1',
    );
    expect(transport.lastHeaders, {
      'device-id': 'test-device-id',
      'Authorization': 'Bearer token-1',
    });
    expect(socket.sentTypes, isNot(contains('join')));
    expect(session.joined, isNull);
    await session.disconnect();
  });

  test('join sends join payload and completes with joined event', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(transport);
    final session = await client.connect(
      worldId: 'world-1',
      locationId: 'loc-1',
    );

    final joinFuture = session.join();
    await _tick();

    expect(socket.sentTypes, contains('join'));
    expect(socket.sentPayload('join'), {'location_id': 'loc-1'});

    socket.serverEvent('joined', {
      'session_id': 'sess-1',
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'user_id': 'u_1',
      'code': 0,
      'code_msg': 'ok',
      'online_users': <Object?>[],
    });

    final joined = await joinFuture;
    expect(joined.sessionId, 'sess-1');
    expect(session.joined!.sessionId, 'sess-1');
    await session.close();
  });

  test('connect requires authorization token from the session store', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final store = MemoryUserSessionStore();
    await store.saveUid('u_1');
    final client = ChatroomClient(
      wsBaseUrl: 'ws://localhost:8082/aitown-chat/ws',
      sessionStore: store,
      deviceIdService: const _FakeDeviceIdService(),
      transport: transport,
    );

    await expectLater(
      client.connect(worldId: 'world-1'),
      throwsA(
        isA<ChatroomProtocolException>().having(
          (e) => e.message,
          'message',
          'authToken is required',
        ),
      ),
    );
    expect(transport.lastUri, isNull);
  });

  test('connect keeps configured service prefix path', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(
      transport,
      wsBaseUrl: 'ws://localhost:8080/aitown-chat/',
    );

    final session = await client.connect(worldId: 'world-1');

    expect(
      transport.lastUri.toString(),
      'ws://localhost:8080/aitown-chat/?world_id=world-1',
    );
    await session.disconnect();
  });

  test('default websocket URL uses documented chatroom ws endpoint', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(
      transport,
      wsBaseUrl: GenesisApi.defaultChatroomWsBaseUrl,
    );

    final session = await client.connect(worldId: 'world-1');

    expect(
      transport.lastUri.toString(),
      'ws://dev.hushie.ai:80/aitown-chat/ws?world_id=world-1',
    );
    await session.disconnect();
  });

  test(
    'connect normalizes default websocket port when base URL omits it',
    () async {
      final socket = _FakeChatroomSocket();
      final transport = _FakeChatroomTransport(socket);
      final client = await _client(
        transport,
        wsBaseUrl: 'ws://dev.hushie.ai/aitown-chat/',
      );

      final session = await client.connect(worldId: 'world-1');

      expect(
        transport.lastUri.toString(),
        'ws://dev.hushie.ai:80/aitown-chat/?world_id=world-1',
      );
      expect(transport.lastUri?.port, 80);
      await session.disconnect();
    },
  );

  test('sendMessage returns the matching ack as a Future', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final ackFuture = session.sendMessage('hello', clientMsgId: 'client-1');
    await _tick();

    expect(socket.sentTypes, contains('send_message'));
    expect(socket.sentPayload('send_message'), {
      'text': 'hello',
      'client_uuid': 'client-1',
    });

    socket.serverEvent('ack', {
      'session_id': 'sess-1',
      'message_id': 1001,
      'conversation_round_id': 201,
      'client_uuid': 'client-1',
      'code': 0,
      'code_msg': 'ok',
    });

    final ack = await ackFuture;
    expect(ack.messageId, 1001);
    expect(ack.conversationRoundId, '201');
    await session.close();
  });

  test(
    'sendMessage matches ack by pending order when server omits client_uuid',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);

      final ackFuture = session.sendMessage('hello', clientMsgId: 'client-1');
      await _tick();

      socket.serverEvent('ack', {
        'session_id': 'sess-1',
        'message_id': 1001,
        'conversation_round_id': 201,
        'code': 0,
        'code_msg': 'ok',
      });

      final ack = await ackFuture;
      expect(ack.clientUuid, isEmpty);
      expect(ack.messageId, 1001);
      await session.close();
    },
  );

  test('sendMessage fails when ack times out', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(
      _FakeChatroomTransport(socket),
      ackTimeout: const Duration(milliseconds: 20),
    );
    final session = await _connectedSession(client, socket);

    await expectLater(
      session.sendMessage('hello', clientMsgId: 'client-timeout'),
      throwsA(
        isA<ChatroomFailureEvent>().having(
          (e) => e.code,
          'code',
          'ack_timeout',
        ),
      ),
    );

    await session.close();
  });

  test('creates stream lifecycle objects for ai stream events', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final streamFuture = session.streams.first;
    socket.serverEvent('ai_stream_start', {'conversation_round_id': 201});
    final aiStream = await streamFuture;
    final chunks = <String>[];
    final sub = aiStream.chunks.listen((chunk) => chunks.add(chunk.chunk));

    socket.serverEvent('ai_stream_chunk', {'chunk': 'hello '});
    socket.serverEvent('ai_stream_chunk', {'chunk': 'there'});
    socket.serverEvent('ai_stream_end', {'message_id': 1002});

    final end = await aiStream.done;
    await sub.cancel();
    expect(end.messageId, 1002);
    expect(aiStream.start.conversationRoundId, '201');
    expect(chunks, ['hello ', 'there']);
    expect(aiStream.content, 'hello there');
    await session.close();
  });

  test('routes protocol errors to common error stream', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final errorFuture = session.errors.first;
    socket.serverEvent('error', {
      'session_id': 'sess-1',
      'code': 1005,
      'code_msg': '未加入聊天室',
    });

    final error = await errorFuture;
    expect(error.code, '1005');
    expect(error.message, '未加入聊天室');
    await session.close();
  });

  test('parses documented control, world, and message events', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final events = <ChatroomEvent>[];
    final sub = session.events.listen(events.add);

    socket.serverEvent('input_blocked', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'code': 2006,
      'code_msg': '世界正在推进中',
    });
    socket.serverWorldEvent(
      'world_notification',
      worldPayload: {
        'world_id': 'world-1',
        'event_type': 'weather_change',
        'title': '天气变化',
        'summary': '下雨了',
        'detail_url': '/api/v1/world/world-1/events/weather',
      },
      broadcast: true,
    );
    socket.serverEvent('character_message', {
      'message_id': 1002,
      'conversation_round_id': 201,
      'round_order': 1,
      'sender_type': 'character',
      'sender_id': 'char_alice',
      'sender_name': 'Alice',
      'content': '你好',
    }, broadcast: true);
    await _tick();

    expect(events.whereType<ChatroomInputBlocked>(), isNotEmpty);
    expect(
      events.whereType<ChatroomWorldNotification>().single.eventType,
      'weather_change',
    );
    expect(events.whereType<ChatroomCharacterMessage>().single.content, '你好');
    await sub.cancel();
    await session.close();
  });

  test('starts heartbeat after connect and stops on disconnect', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(
      _FakeChatroomTransport(socket),
      heartbeatInterval: const Duration(milliseconds: 20),
    );
    final session = await client.connect(
      worldId: 'world-1',
      locationId: 'loc-1',
    );

    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(
      socket.sentTypes.where((type) => type == 'heartbeat').length,
      greaterThanOrEqualTo(1),
    );

    await session.close();
    final sentAfterClose = socket.sentTypes.length;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(socket.sentTypes.length, sentAfterClose);
    expect(socket.sentTypes, isNot(contains('leave')));
    expect(socket.closed, true);
  });

  test('heartbeat completes after server heartbeat response', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final before = socket.sentTypes.where((type) => type == 'heartbeat').length;
    final events = <ChatroomEvent>[];
    final sub = session.events.listen(events.add);

    var completed = false;
    final heartbeatFuture = session.heartbeat().then((_) {
      completed = true;
    });
    await _tick();

    expect(
      socket.sentTypes.where((type) => type == 'heartbeat').length,
      before + 1,
    );
    expect(completed, false);

    socket.serverEvent('heartbeat', _basePayload(), mySessionId: 'sess-1');

    await heartbeatFuture;
    await _tick();
    expect(completed, true);
    final heartbeat = events.whereType<ChatroomHeartbeat>().single;
    expect(heartbeat.mySessionId, 'sess-1');
    await sub.cancel();
    await session.close();
  });

  test(
    'leave sends leave and keeps heartbeat without closing socket',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        heartbeatInterval: const Duration(milliseconds: 20),
      );
      final session = await _connectedSession(client, socket);

      await session.leave();
      final sentAfterLeave = socket.sentTypes.length;
      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(socket.sentTypes, contains('leave'));
      expect(socket.sentTypes.length, greaterThan(sentAfterLeave));
      expect(socket.closed, false);
      await session.disconnect();
    },
  );

  test('disconnect closes socket without sending disconnect message', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    await session.disconnect();

    expect(socket.closed, true);
    expect(socket.sentTypes, isNot(contains('disconnect')));
  });

  test('server errors are routed to unified failure stream once', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final failures = <ChatroomFailureEvent>[];
    final sub = session.failures.listen(failures.add);
    socket.serverEvent('error', {
      'session_id': 'sess-1',
      'code': 1005,
      'code_msg': '未加入聊天室',
    });
    await _tick();

    expect(failures, hasLength(1));
    expect(failures.single.code, '1005');
    expect(failures.single.message, '未加入聊天室');
    await sub.cancel();
    await session.close();
  });

  test('parse failures are routed to unified failure stream once', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final failureFuture = session.failures.first;
    socket.serverRaw('not-json');

    final failure = await failureFuture;
    expect(failure.code, 'protocol_error');
    await session.close();
  });

  test(
    'listenMessages dispatches every server event to typed handlers',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);
      final handled = <String>[];
      final sub = session.listenMessages(
        ChatroomMessageHandlers(
          onJoined: (_) => handled.add('joined'),
          onLeaved: (_) => handled.add('leaved'),
          onKicked: (_) => handled.add('kicked'),
          onDisconnected: (_) => handled.add('disconnected'),
          onAck: (_) => handled.add('ack'),
          onError: (_) => handled.add('error'),
          onFailure: (_) => handled.add('failure'),
          onInputBlocked: (_) => handled.add('input_blocked'),
          onInputReady: (_) => handled.add('input_ready'),
          onWorldNotification: (_) => handled.add('world_notification'),
          onQueuePosition: (_) => handled.add('queue_position'),
          onUserMessage: (_) => handled.add('user_message'),
          onCharacterMessage: (_) => handled.add('character_message'),
          onNarratorMessage: (_) => handled.add('narrator_message'),
          onAiStreamStart: (_) => handled.add('ai_stream_start'),
          onAiStreamChunk: (_) => handled.add('ai_stream_chunk'),
          onAiStreamEnd: (_) => handled.add('ai_stream_end'),
        ),
      );

      socket.serverEvent('joined', _joinedPayload());
      socket.serverEvent('leaved', _basePayload());
      socket.serverEvent('kicked', _basePayload());
      socket.serverEvent('disconnected', const <String, Object?>{});
      socket.serverEvent('ack', {
        ..._basePayload(),
        'message_id': 1001,
        'conversation_round_id': 201,
        'queue_position': 0,
      });
      socket.serverEvent('error', {
        'session_id': 'sess-1',
        'code': 1005,
        'code_msg': '未加入聊天室',
      });
      socket.serverEvent('input_blocked', _basePayload());
      socket.serverEvent('input_ready', _basePayload());
      socket.serverWorldEvent(
        'world_notification',
        worldPayload: {
          'world_id': 'world-1',
          'event_type': 'weather_change',
          'title': '天气变化',
          'summary': '下雨了',
          'detail_url': '/api/v1/world/world-1/events/weather',
        },
      );
      socket.serverEvent('queue_position', {
        'session_id': 'sess-1',
        'conversation_round_id': 201,
        'position': 2,
        'estimated_wait_seconds': 8,
      });
      socket.serverEvent('user_message', _messagePayload('user'));
      socket.serverEvent('character_message', _messagePayload('character'));
      socket.serverEvent('narrator_message', _messagePayload('narrator'));
      socket.serverEvent('ai_stream_start', _aiStartPayload());
      socket.serverEvent('ai_stream_chunk', {
        'session_id': 'sess-1',
        'message_id': 1002,
        'conversation_round_id': 201,
        'sender_id': 'char_alice',
        'chunk': 'hello',
      });
      socket.serverEvent('ai_stream_end', {
        'session_id': 'sess-1',
        'message_id': 1002,
        'conversation_round_id': 201,
        'sender_id': 'char_alice',
      });
      await _tick();

      expect(
        handled,
        containsAll(<String>[
          'joined',
          'leaved',
          'kicked',
          'disconnected',
          'ack',
          'error',
          'failure',
          'input_blocked',
          'input_ready',
          'world_notification',
          'queue_position',
          'user_message',
          'character_message',
          'narrator_message',
          'ai_stream_start',
          'ai_stream_chunk',
          'ai_stream_end',
        ]),
      );
      await sub.cancel();
      await session.close();
    },
  );

  test(
    'controller reconnects immediately after unexpected socket close',
    () async {
      final firstSocket = _FakeChatroomSocket();
      final secondSocket = _FakeChatroomSocket();
      final transport = _SequencedChatroomTransport([
        firstSocket,
        secondSocket,
      ]);
      final client = await _client(transport);
      final controller = ChatroomConnectionController(
        client: client,
        reconnectInterval: const Duration(milliseconds: 20),
      );

      await controller.connect(worldId: 'world-1', identity: _identity());
      expect(transport.connectCount, 1);

      await firstSocket.serverClose();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(transport.connectCount, 2);
      expect(controller.status, ChatroomConnectionStatus.connected);
      await controller.disconnect();
      await controller.dispose();
    },
  );

  test('controller retries reconnect failures on interval', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([
      firstSocket,
      StateError('first reconnect failed'),
      secondSocket,
    ]);
    final client = await _client(transport);
    final controller = ChatroomConnectionController(
      client: client,
      reconnectInterval: const Duration(milliseconds: 20),
    );

    await controller.connect(worldId: 'world-1', identity: _identity());
    await firstSocket.serverClose();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(transport.connectCount, 2);
    expect(controller.status, ChatroomConnectionStatus.disconnected);

    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(transport.connectCount, 3);
    expect(controller.status, ChatroomConnectionStatus.connected);
    await controller.disconnect();
    await controller.dispose();
  });

  test('controller does not reconnect after explicit disconnect', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final client = await _client(transport);
    final controller = ChatroomConnectionController(
      client: client,
      reconnectInterval: const Duration(milliseconds: 20),
    );

    await controller.connect(worldId: 'world-1', identity: _identity());
    await controller.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(transport.connectCount, 1);
    expect(firstSocket.closed, true);
    await controller.dispose();
  });

  test('controller auto rejoins after reconnect from joined state', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final client = await _client(transport);
    final controller = ChatroomConnectionController(
      client: client,
      reconnectInterval: const Duration(milliseconds: 20),
    );

    await controller.connect(worldId: 'world-1', identity: _identity());
    final joinFuture = controller.join(locationId: 'loc-1');
    await _tick();
    firstSocket.serverEvent('joined', _joinedPayload());
    await joinFuture;
    expect(controller.status, ChatroomConnectionStatus.joined);

    await firstSocket.serverClose();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(transport.connectCount, 2);
    expect(secondSocket.sentTypes, contains('join'));
    expect(secondSocket.sentPayload('join')['location_id'], 'loc-1');
    secondSocket.serverEvent('joined', _joinedPayload());
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(controller.status, ChatroomConnectionStatus.joined);
    await controller.disconnect();
    await controller.dispose();
  });

  test('controller restores connected state across app background', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final client = await _client(transport);
    final controller = ChatroomConnectionController(
      client: client,
      reconnectInterval: const Duration(milliseconds: 20),
    );

    await controller.connect(worldId: 'world-1', identity: _identity());
    await controller.handleAppBackground();
    expect(firstSocket.closed, true);
    expect(controller.status, ChatroomConnectionStatus.disconnected);

    await controller.handleAppForeground();
    expect(transport.connectCount, 2);
    expect(controller.status, ChatroomConnectionStatus.connected);
    await controller.disconnect();
    await controller.dispose();
  });

  test('controller restores joined state across app background', () async {
    final firstSocket = _FakeChatroomSocket();
    final secondSocket = _FakeChatroomSocket();
    final transport = _SequencedChatroomTransport([firstSocket, secondSocket]);
    final client = await _client(transport);
    final controller = ChatroomConnectionController(
      client: client,
      reconnectInterval: const Duration(milliseconds: 20),
    );

    await controller.connect(worldId: 'world-1', identity: _identity());
    final joinFuture = controller.join(locationId: 'loc-1');
    await _tick();
    firstSocket.serverEvent('joined', _joinedPayload());
    await joinFuture;

    await controller.handleAppBackground();
    expect(firstSocket.sentTypes, contains('leave'));
    expect(firstSocket.closed, true);

    final foregroundFuture = controller.handleAppForeground();
    await _tick();
    expect(secondSocket.sentTypes, contains('join'));
    secondSocket.serverEvent('joined', _joinedPayload());
    await foregroundFuture;

    expect(controller.status, ChatroomConnectionStatus.joined);
    await controller.disconnect();
    await controller.dispose();
  });
}

Future<ChatroomClient> _client(
  ChatroomSocketTransport transport, {
  String wsBaseUrl = 'ws://localhost:8082/aitown-chat/ws',
  Duration heartbeatInterval = const Duration(seconds: 2),
  Duration ackTimeout = const Duration(milliseconds: 100),
}) async {
  final store = MemoryUserSessionStore();
  await store.saveUid('u_1');
  await store.saveAuthToken('token-1');
  return ChatroomClient(
    wsBaseUrl: wsBaseUrl,
    sessionStore: store,
    deviceIdService: const _FakeDeviceIdService(),
    transport: transport,
    heartbeatInterval: heartbeatInterval,
    ackTimeout: ackTimeout,
  );
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

Future<ChatroomSession> _connectedSession(
  ChatroomClient client,
  _FakeChatroomSocket socket,
) async {
  final session = await client.connect(worldId: 'world-1', locationId: 'loc-1');
  final future = session.join();
  await _tick();
  socket.serverEvent('joined', {
    'session_id': 'sess-1',
    'world_id': 'world-1',
    'location_id': 'loc-1',
    'user_id': 'u_1',
    'code': 0,
    'code_msg': 'ok',
    'online_users': <Object?>[],
  });
  await future;
  return session;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

Map<String, Object?> _basePayload() {
  return {
    'session_id': 'sess-1',
    'world_id': 'world-1',
    'location_id': 'loc-1',
    'user_id': 'u_1',
    'code': 0,
    'code_msg': 'ok',
  };
}

Map<String, Object?> _joinedPayload() {
  return {..._basePayload(), 'online_users': <Object?>[]};
}

Map<String, Object?> _messagePayload(String senderType) {
  return {
    ..._basePayload(),
    'message_id': senderType == 'user' ? 1001 : 1002,
    'conversation_round_id': 201,
    'round_order': senderType == 'user' ? 0 : 1,
    'sender_type': senderType,
    'sender_id': senderType == 'narrator' ? 'narrator' : 'char_alice',
    'sender_name': senderType == 'narrator' ? 'Narrator' : 'Alice',
    'content': '你好',
  };
}

Map<String, Object?> _aiStartPayload() {
  return {
    'session_id': 'sess-1',
    'message_id': 1002,
    'conversation_round_id': 201,
    'round_order': 1,
    'sender_type': 'character',
    'sender_id': 'char_alice',
    'sender_name': 'Alice',
  };
}

ChatroomConnectionIdentity _identity() {
  return const ChatroomConnectionIdentity(
    userId: 'u_1',
    senderId: 'u_1',
    senderName: 'u_1',
  );
}

class _SequencedChatroomTransport implements ChatroomSocketTransport {
  _SequencedChatroomTransport(this.results);

  final List<Object> results;
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
    final next = results.removeAt(0);
    if (next is ChatroomSocket) return next;
    throw next;
  }
}

class _FakeChatroomTransport implements ChatroomSocketTransport {
  _FakeChatroomTransport(this.socket);

  final _FakeChatroomSocket socket;
  Uri? lastUri;
  Map<String, String>? lastHeaders;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    lastUri = uri;
    lastHeaders = headers;
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

  Map<String, dynamic> sentPayload(String type) {
    final raw = sent.lastWhere(
      (item) => (jsonDecode(item) as Map<String, dynamic>)['type'] == type,
    );
    return (jsonDecode(raw) as Map<String, dynamic>)['payload']
        as Map<String, dynamic>;
  }

  void serverEvent(
    String type,
    Map<String, Object?> payload, {
    bool? broadcast,
    String? mySessionId,
  }) {
    _messages.add(
      jsonEncode(<String, Object?>{
        'type': type,
        'payload': payload,
        if (broadcast != null) 'broadcast': broadcast,
        if (mySessionId != null) 'my_session_id': mySessionId,
      }),
    );
  }

  void serverWorldEvent(
    String type, {
    required Map<String, Object?> worldPayload,
    bool? broadcast,
  }) {
    _messages.add(
      jsonEncode(<String, Object?>{
        'type': type,
        'world_payload': worldPayload,
        if (broadcast != null) 'broadcast': broadcast,
      }),
    );
  }

  void serverRaw(String raw) {
    _messages.add(raw);
  }
}
