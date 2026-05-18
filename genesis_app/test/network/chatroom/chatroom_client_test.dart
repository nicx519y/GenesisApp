import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_socket_transport.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('connects with location query and sends join payload', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(transport);

    final connectFuture = client.connect(
      worldInstanceId: 'world-1',
      locationId: 'loc-1',
      senderId: 'player1',
      senderName: 'Ming',
    );
    await _tick();

    expect(
      transport.lastUri.toString(),
      'ws://localhost:8080/ws?world_instance_id=world-1&location_id=loc-1',
    );
    expect(socket.sentTypes, contains('join'));
    expect(socket.sentPayload('join'), {
      'user_id': 'u_1',
      'sender_id': 'player1',
      'sender_name': 'Ming',
    });

    socket.serverEvent('joined', {
      'session_id': 'sess-1',
      'world_instance_id': 'world-1',
      'location_id': 'loc-1',
      'online_users': <Object?>[],
    });

    final session = await connectFuture;
    expect(session.joined!.sessionId, 'sess-1');
    await session.close();
  });

  test('sendMessage returns the matching ack as a Future', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final ackFuture = session.sendMessage('hello', clientMsgId: 'client-1');
    await _tick();

    expect(socket.sentTypes, contains('send_message'));
    expect(socket.sentPayload('send_message'), {
      'text': 'hello',
      'client_msg_id': 'client-1',
    });

    socket.serverEvent('ack', {
      'session_id': 'sess-1',
      'message_id': 1001,
      'conversation_round_id': 'round-1',
      'client_msg_id': 'client-1',
      'queue_position': 0,
    });

    final ack = await ackFuture;
    expect(ack.messageId, 1001);
    expect(ack.conversationRoundId, 'round-1');
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
        isA<ChatroomErrorEvent>().having((e) => e.code, 'code', 'ack_timeout'),
      ),
    );

    await session.close();
  });

  test('creates stream lifecycle objects for ai stream events', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final streamFuture = session.streams.first;
    socket.serverEvent('ai_stream_start', {
      'session_id': 'sess-1',
      'message_id': 1002,
      'conversation_round_id': 'round-1',
      'round_order': 1,
      'sender_type': 'character',
      'sender_id': 'isabella',
      'sender_name': 'Isabella',
    });
    final aiStream = await streamFuture;
    final chunks = <String>[];
    final sub = aiStream.chunks.listen((chunk) => chunks.add(chunk.chunk));

    socket.serverEvent('ai_stream_chunk', {
      'session_id': 'sess-1',
      'message_id': 1002,
      'conversation_round_id': 'round-1',
      'sender_id': 'isabella',
      'chunk': 'hello ',
      'is_delta': true,
    });
    socket.serverEvent('ai_stream_chunk', {
      'session_id': 'sess-1',
      'message_id': 1002,
      'conversation_round_id': 'round-1',
      'sender_id': 'isabella',
      'chunk': 'there',
      'is_delta': true,
    });
    socket.serverEvent('ai_stream_end', {
      'session_id': 'sess-1',
      'message_id': 1002,
      'conversation_round_id': 'round-1',
      'sender_id': 'isabella',
      'created_at': '2026-05-17T10:00:05.000Z',
    });

    final end = await aiStream.done;
    await sub.cancel();
    expect(end.messageId, 1002);
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
      'code': 'invalid_token',
      'message': 'Token invalid',
    });

    final error = await errorFuture;
    expect(error.code, 'invalid_token');
    expect(error.message, 'Token invalid');
    await session.close();
  });

  test('starts heartbeat after joined and stops on close', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(
      _FakeChatroomTransport(socket),
      heartbeatInterval: const Duration(milliseconds: 20),
    );
    final session = await _connectedSession(client, socket);

    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(
      socket.sentTypes.where((type) => type == 'heartbeat').length,
      greaterThanOrEqualTo(1),
    );

    await session.close();
    final sentAfterClose = socket.sentTypes.length;
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(socket.sentTypes.length, sentAfterClose);
    expect(socket.sentTypes, contains('leave'));
    expect(socket.closed, true);
  });
}

Future<ChatroomClient> _client(
  ChatroomSocketTransport transport, {
  Duration heartbeatInterval = const Duration(seconds: 30),
  Duration ackTimeout = const Duration(milliseconds: 100),
}) async {
  final store = MemoryUserSessionStore();
  await store.saveUid('u_1');
  return ChatroomClient(
    wsBaseUrl: 'ws://localhost:8080/ws',
    sessionStore: store,
    transport: transport,
    heartbeatInterval: heartbeatInterval,
    ackTimeout: ackTimeout,
  );
}

Future<ChatroomSession> _connectedSession(
  ChatroomClient client,
  _FakeChatroomSocket socket,
) async {
  final future = client.connect(
    worldInstanceId: 'world-1',
    locationId: 'loc-1',
    senderId: 'player1',
    senderName: 'Ming',
  );
  await _tick();
  socket.serverEvent('joined', {
    'session_id': 'sess-1',
    'world_instance_id': 'world-1',
    'location_id': 'loc-1',
    'online_users': <Object?>[],
  });
  return future;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

class _FakeChatroomTransport implements ChatroomSocketTransport {
  _FakeChatroomTransport(this.socket);

  final _FakeChatroomSocket socket;
  Uri? lastUri;

  @override
  Future<ChatroomSocket> connect(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    lastUri = uri;
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

  Map<String, dynamic> sentPayload(String type) {
    final raw = sent.lastWhere(
      (item) => (jsonDecode(item) as Map<String, dynamic>)['type'] == type,
    );
    return (jsonDecode(raw) as Map<String, dynamic>)['payload']
        as Map<String, dynamic>;
  }

  void serverEvent(String type, Map<String, Object?> payload) {
    _messages.add(
      jsonEncode(<String, Object?>{'type': type, 'payload': payload}),
    );
  }
}
