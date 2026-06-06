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

  test('join sends join frame and completes with matching ack', () async {
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
    expect(socket.sentFrame('join'), {
      'type': 'join',
      'client_msg_id': isA<String>(),
      'world_id': 'world-1',
      'location_id': 'loc-1',
    });

    socket.serverJoinAck();

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
      'wss://dev.hushie.ai:443/aitown-chat/ws?world_id=world-1',
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
    expect(socket.sentFrame('send_message'), {
      'type': 'send_message',
      'client_msg_id': 'client-1',
      'content': 'hello',
    });

    socket.serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': 1001,
      'conversation_round_id': 201,
      'payload': {'client_msg_id': 'client-1'},
    });

    final ack = await ackFuture;
    expect(ack.messageId, 1001);
    expect(ack.conversationRoundId, '201');
    await session.close();
  });

  test('sendMessage requires ack payload client_msg_id', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(
      _FakeChatroomTransport(socket),
      ackTimeout: const Duration(milliseconds: 20),
    );
    final session = await _connectedSession(client, socket);

    final future = session.sendMessage('hello', clientMsgId: 'client-1');
    await _tick();

    socket.serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'msg_id': 1001,
      'conversation_round_id': 201,
      'payload': <String, Object?>{},
    });

    await expectLater(
      future,
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
    socket.serverFrame('llm_stream_start', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'msg_id': 789,
      'conversation_round_id': 201,
      'payload': {
        'sender_type': 'character',
        'sender_id': 'char_001',
        'sender_name': '村长',
      },
    });
    final aiStream = await streamFuture;
    final chunks = <String>[];
    final sub = aiStream.chunks.listen((chunk) => chunks.add(chunk.chunk));

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'msg_id': 789,
      'conversation_round_id': 201,
      'payload': {
        'sender_type': 'character',
        'sender_id': 'char_001',
        'sender_name': '村长',
        'seq': 1,
        'content': 'hello ',
      },
    });
    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'msg_id': 789,
      'conversation_round_id': 201,
      'payload': {
        'sender_type': 'character',
        'sender_id': 'char_001',
        'sender_name': '村长',
        'seq': 2,
        'content': 'there',
      },
    });
    socket.serverFrame('llm_stream_end', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'msg_id': 789,
      'conversation_round_id': 201,
      'payload': {
        'sender_type': 'character',
        'sender_id': 'char_001',
        'sender_name': '村长',
        'content': 'hello there',
      },
    });

    final end = await aiStream.done;
    await sub.cancel();
    expect(end.messageId, 789);
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
    socket.serverFrame('error', {
      'session_id': 'sess-1',
      'err_code': 'tick_locked',
      'err_msg': '当前 Tick 正在推进，请稍后',
      'payload': <String, Object?>{},
    });

    final error = await errorFuture;
    expect(error.code, 'tick_locked');
    expect(error.message, '当前 Tick 正在推进，请稍后');
    await session.close();
  });

  test('parses documented control, world, and message events', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final events = <ChatroomEvent>[];
    final sub = session.events.listen(events.add);

    socket.serverFrame('tick_start', {
      'world_id': 'world-1',
      'payload': {
        'title': 'Tick 开始',
        'summary': 'Tick 5 开始推进',
        'detail_url': '',
      },
    });
    socket.serverFrame('world_change', {
      'world_id': 'world-1',
      'payload': {
        'title': '天气变化',
        'summary': '下雨了',
        'detail_url': '/api/v1/world/world-1/events/weather',
      },
    });
    socket.serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'msg_id': 1002,
      'conversation_round_id': 201,
      'user_id': 'u_1',
      'sender_name': 'Alice',
      'location_id': 'loc-1',
      'payload': {'content': '你好'},
    });
    await _tick();

    expect(
      events.whereType<ChatroomWorldNotification>().map((e) => e.eventType),
      containsAll(['tick_start', 'world_change']),
    );
    expect(events.whereType<ChatroomUserMessage>().single.content, '你好');
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

  test('heartbeat sends the documented one-way frame', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final before = socket.sentTypes.where((type) => type == 'heartbeat').length;

    await session.heartbeat();

    expect(
      socket.sentTypes.where((type) => type == 'heartbeat').length,
      before + 1,
    );
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
    socket.serverFrame('error', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'err_code': 'tick_locked',
      'err_msg': '当前 Tick 正在推进，请稍后',
      'payload': <String, Object?>{},
    });
    await _tick();

    expect(failures, hasLength(1));
    expect(failures.single.code, 'tick_locked');
    expect(failures.single.message, '当前 Tick 正在推进，请稍后');
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
          onAck: (_) => handled.add('ack'),
          onError: (_) => handled.add('error'),
          onFailure: (_) => handled.add('failure'),
          onWorldNotification: (_) => handled.add('world_notification'),
          onUserMessage: (_) => handled.add('user_message'),
          onAiStreamStart: (_) => handled.add('llm_stream_start'),
          onAiStreamChunk: (_) => handled.add('llm_chunk'),
          onAiStreamEnd: (_) => handled.add('llm_stream_end'),
        ),
      );

      socket.serverFrame('ack', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'location_id': 'loc-1',
        'msg_id': 1001,
        'conversation_round_id': 201,
        'payload': {'client_msg_id': 'client-handler'},
      });
      socket.serverFrame('error', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'err_code': 'tick_locked',
        'err_msg': '当前 Tick 正在推进，请稍后',
        'payload': <String, Object?>{},
      });
      socket.serverFrame('tick_start', {
        'world_id': 'world-1',
        'payload': {
          'title': 'Tick 开始',
          'summary': 'Tick 5 开始推进',
          'detail_url': '',
        },
      });
      socket.serverFrame('world_change', {
        'world_id': 'world-1',
        'payload': {
          'title': '天气变化',
          'summary': '下雨了',
          'detail_url': '/api/v1/world/world-1/events/weather',
        },
      });
      socket.serverFrame('user_message', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'location_id': 'loc-1',
        'user_id': 'u_1',
        'sender_name': 'Alice',
        'msg_id': 1001,
        'conversation_round_id': 201,
        'payload': {'content': '你好'},
      });
      socket.serverFrame('llm_stream_start', {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'msg_id': 1002,
        'conversation_round_id': 201,
        'payload': {
          'sender_type': 'character',
          'sender_id': 'char_alice',
          'sender_name': 'Alice',
        },
      });
      socket.serverFrame('llm_chunk', {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'msg_id': 1002,
        'conversation_round_id': 201,
        'payload': {
          'sender_type': 'character',
          'sender_id': 'char_alice',
          'sender_name': 'Alice',
          'seq': 1,
          'content': 'hello',
        },
      });
      socket.serverFrame('llm_stream_end', {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'msg_id': 1002,
        'conversation_round_id': 201,
        'payload': {
          'sender_type': 'character',
          'sender_id': 'char_alice',
          'sender_name': 'Alice',
          'content': 'hello',
        },
      });
      await _tick();

      expect(
        handled,
        containsAll(<String>[
          'ack',
          'error',
          'failure',
          'world_notification',
          'user_message',
          'llm_stream_start',
          'llm_chunk',
          'llm_stream_end',
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
    firstSocket.serverJoinAck();
    await joinFuture;
    expect(controller.status, ChatroomConnectionStatus.joined);

    await firstSocket.serverClose();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(transport.connectCount, 2);
    expect(secondSocket.sentTypes, contains('join'));
    expect(secondSocket.sentFrame('join')['location_id'], 'loc-1');
    secondSocket.serverJoinAck();
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
    firstSocket.serverJoinAck();
    await joinFuture;

    await controller.handleAppBackground();
    expect(firstSocket.sentTypes, contains('leave'));
    expect(firstSocket.closed, true);

    final foregroundFuture = controller.handleAppForeground();
    await _tick();
    expect(secondSocket.sentTypes, contains('join'));
    secondSocket.serverJoinAck();
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
  socket.serverJoinAck();
  await future;
  return session;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

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

  Map<String, dynamic> sentFrame(String type) {
    final raw = sent.lastWhere(
      (item) => (jsonDecode(item) as Map<String, dynamic>)['type'] == type,
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void serverFrame(String type, Map<String, Object?> fields) {
    _messages.add(jsonEncode(<String, Object?>{'type': type, ...fields}));
  }

  void serverJoinAck() {
    final clientMsgId = sentFrame('join')['client_msg_id'] as String;
    serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': sentFrame('join')['location_id'],
      'user_id': 'u_1',
      'payload': {'client_msg_id': clientMsgId},
    });
  }

  void serverRaw(String raw) {
    _messages.add(raw);
  }
}
