import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_connection_controller.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_type.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_socket_transport.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';
import 'package:genesis_flutter_android/network/gateway_auth.dart';
import 'package:genesis_flutter_android/platform/device/device_id_service.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

void main() {
  test('envelope retains schema version and event id', () {
    final envelope = ChatroomEnvelope.fromJson({
      'type': 'map_updated',
      'schema_version': 1,
      'event_id': 'evt-map-1',
      'ts': 1785890000000,
      'world_id': 'world-1',
      'payload': <String, Object?>{},
    });

    expect(envelope.schemaVersion, 1);
    expect(envelope.eventId, 'evt-map-1');
    expect(envelope.mergedPayload['schema_version'], 1);
    expect(envelope.mergedPayload['event_id'], 'evt-map-1');
    expect(
      jsonDecode(envelope.encode()),
      containsPair('event_id', 'evt-map-1'),
    );
  });

  test('parses the five new world timeline event types', () {
    ChatroomEvent parse(String type, Map<String, Object?> payload) {
      final isQueuedTimeline =
          type == 'story_events' || type == 'characters_moved';
      return chatroomEventFromEnvelope(
        ChatroomEnvelope.fromJson({
          'type': type,
          'schema_version': 1,
          'event_id': 'evt-$type',
          'ts': 1785890000000,
          'world_id': 'world-1',
          'location_id': 'loc-1',
          'global_msg_id': isQueuedTimeline ? 5626 : null,
          'msg_id': isQueuedTimeline ? 232 : null,
          'location_msg_id': isQueuedTimeline ? 32 : null,
          'conversation_round_id': isQueuedTimeline ? 6816 : null,
          'sender_id': isQueuedTimeline ? 'sub_tick' : null,
          'sender_name': isQueuedTimeline ? 'SubTick' : null,
          'tick_no': isQueuedTimeline ? 4 : null,
          'sub_tick_no': isQueuedTimeline ? 1 : null,
          'current_time': isQueuedTimeline ? 'Day 2, 00:09:15' : null,
          'payload': payload,
        }),
      );
    }

    final entered =
        parse('user_enter_location', {
              'char_id': 'char-alice',
              'to_location_id': 'loc-1',
              'text': 'Alice entered',
            })
            as ChatroomWorldNotification;
    expect(entered.schemaVersion, 1);
    expect(entered.eventId, 'evt-user_enter_location');
    expect(entered.timelinePayload, isA<ChatroomUserEnterLocationPayload>());

    final story =
        parse('story_events', {
              'location_id': 'loc-1',
              'location_name': 'Station',
              'paragraphs': [
                {
                  'timestamp': 'Day 1, 08:00',
                  'visibility': 'public',
                  'visible_to': <String>[],
                  'text': 'A train arrived.',
                  'clue': '',
                },
              ],
            })
            as ChatroomStoryEventsMessage;
    expect(story.messageId, 232);
    expect(story.locationId, 'loc-1');
    expect(story.schemaVersion, 1);
    expect(story.eventId, 'evt-story_events');
    expect(story.tickNo, 4);
    expect(story.subTickNo, 1);
    expect(story.currentTime, 'Day 2, 00:09:15');
    expect(story.timelinePayload.paragraphs.single.text, 'A train arrived.');

    final mapUpdated = parse('map_updated', const {});
    final characterUpdated = parse('character_updated', const {});
    final moved =
        parse('characters_moved', {
              'movements': [
                {'char_id': 'char-alice', 'to_loc_id': 'loc-2'},
              ],
            })
            as ChatroomCharactersMovedMessage;
    expect((mapUpdated as ChatroomWorldNotification).eventType, 'map_updated');
    expect(
      (characterUpdated as ChatroomWorldNotification).eventType,
      'character_updated',
    );
    expect(moved.globalMessageId, 5626);
    expect(moved.messageId, 232);
    expect(moved.locationMessageId, 32);
    expect(moved.locationId, 'loc-1');
    expect(moved.conversationRoundId, '6816');
    expect(moved.senderId, 'sub_tick');
    expect(moved.senderName, 'SubTick');
    expect(moved.tickNo, 4);
    expect(moved.subTickNo, 1);
    expect(moved.currentTime, 'Day 2, 00:09:15');
    expect(moved.schemaVersion, 1);
    expect(moved.eventId, 'evt-characters_moved');
    expect(moved.timelinePayload.movements.single.charId, 'char-alice');
    expect(moved.timelinePayload.movements.single.toLocationId, 'loc-2');
  });

  test('story_events requires a positive msg_id', () {
    expect(
      () => chatroomEventFromEnvelope(
        ChatroomEnvelope.fromJson({
          'type': 'story_events',
          'world_id': 'world-1',
          'msg_id': 0,
          'payload': {
            'location_id': 'loc-1',
            'location_name': 'Station',
            'paragraphs': <Object?>[],
          },
        }),
      ),
      throwsA(
        isA<ChatroomProtocolException>().having(
          (error) => error.message,
          'message',
          contains('msg_id'),
        ),
      ),
    );
  });

  test('story_events accepts the flat single-event websocket payload', () {
    final event =
        chatroomEventFromEnvelope(
              ChatroomEnvelope.fromJson({
                'type': 'story_events',
                'world_id': 'world-1',
                'location_id': 'loc_1_1_1',
                'msg_id': 61,
                'location_msg_id': 32,
                'tick_no': 4,
                'sub_tick_no': 1,
                'current_time': 'Day 2, 00:09:15',
                'payload': {
                  'location_id': 'loc_1_1_1',
                  'timestamp': 'Day 2, 00:09:00',
                  'visibility': 'char_only',
                  'visible_to': ['char_1'],
                  'text': '录音机开始播放。',
                  'clue': '去辨认磁带里的耳语者。',
                },
              }),
            )
            as ChatroomStoryEventsMessage;

    expect(event.locationMessageId, 32);
    expect(event.tickNo, 4);
    expect(event.subTickNo, 1);
    expect(event.timelinePayload.locationId, 'loc_1_1_1');
    expect(event.timelinePayload.locationName, isEmpty);
    expect(event.timelinePayload.paragraphs, hasLength(1));
    expect(event.timelinePayload.paragraphs.single.visibleTo, ['char_1']);
    expect(event.timelinePayload.paragraphs.single.text, '录音机开始播放。');
  });

  test(
    'characters_moved supports formal messages and legacy notifications',
    () {
      ChatroomEvent parse({
        required int messageId,
        required String locationId,
      }) {
        return chatroomEventFromEnvelope(
          ChatroomEnvelope.fromJson({
            'type': 'characters_moved',
            'world_id': 'world-1',
            'location_id': locationId,
            'msg_id': messageId,
            'payload': {
              'movements': [
                {'char_id': 'char-alice', 'to_loc_id': 'loc-2'},
              ],
            },
          }),
        );
      }

      final legacy = parse(messageId: 0, locationId: 'loc-1');
      expect(legacy, isA<ChatroomWorldNotification>());
      expect(
        (legacy as ChatroomWorldNotification).timelinePayload,
        isA<ChatroomCharactersMovedPayload>(),
      );

      final broadcast = parse(messageId: 233, locationId: '');
      expect(broadcast, isA<ChatroomCharactersMovedMessage>());
      expect((broadcast as ChatroomCharactersMovedMessage).locationId, isEmpty);
    },
  );

  test(
    'invalid characters_moved payload is reported as protocol_error',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);
      final failureFuture = session.failures.first;

      socket.serverFrame('characters_moved', {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'msg_id': 233,
        'payload': {
          'movements': [
            {'char_id': '', 'to_loc_id': 'loc-2'},
          ],
        },
      });

      final failure = await failureFuture;
      expect(failure.code, 'protocol_error');
      expect(failure.sourceType, 'protocol_error');
      expect(
        failure.cause,
        isA<ChatroomProtocolException>().having(
          (error) => error.message,
          'message',
          contains('Invalid characters_moved payload'),
        ),
      );
      await session.close();
    },
  );

  test('nar_new_message normalizes message_type and defaults to text', () {
    ChatroomNarratorMessage parse(Map<String, dynamic> payload) {
      return chatroomEventFromEnvelope(
            ChatroomEnvelope.fromJson({
              'type': 'nar_new_message',
              'payload': payload,
            }),
          )
          as ChatroomNarratorMessage;
    }

    expect(parse({'message_type': ' IMAGE '}).messageType, 'image');
    expect(parse(const {}).messageType, 'text');
    expect(parse({'sender_id': 'nar_pic'}).messageType, 'image');
    expect(
      parse({'sender_id': 'nar_pic', 'message_type': null}).messageType,
      'text',
    );
    expect(
      parse({'sender_id': 'nar_pic', 'message_type': '   '}).messageType,
      'text',
    );
    expect(parse({'message_type': '   '}).messageType, 'text');
    expect(
      parse({'message_type': ' Future_Format '}).messageType,
      'future_format',
    );
  });

  test('chatroom render policy requires image and nar_pic', () {
    ChatroomMessageRenderKind resolve(Object? type, Object? senderId) {
      return resolveChatroomMessageRenderKind(
        messageType: type,
        senderId: senderId,
      );
    }

    expect(resolve(null, 'nar_pic'), ChatroomMessageRenderKind.text);
    expect(resolve('text', 'nar_pic'), ChatroomMessageRenderKind.text);
    expect(resolve(' IMAGE ', ' NAR_PIC '), ChatroomMessageRenderKind.image);
    expect(resolve('image', 'nar'), ChatroomMessageRenderKind.hidden);
    expect(resolve('image', 'char-1'), ChatroomMessageRenderKind.hidden);
    expect(resolve('video', 'nar_pic'), ChatroomMessageRenderKind.hidden);
    expect(
      resolve('future_format', 'char-1'),
      ChatroomMessageRenderKind.hidden,
    );
  });

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
      'user-agent': 'Android 15',
      'Authorization': 'Bearer token-1',
    });
    expect(socket.sentTypes, isNot(contains('join')));
    expect(session.joined, isNull);
    await session.disconnect();
  });

  test(
    'connect includes signed Gateway headers when handshake signer is set',
    () async {
      final socket = _FakeChatroomSocket();
      final transport = _FakeChatroomTransport(socket);
      final client = await _client(
        transport,
        handshakeHeaderSigner: (uri, headers) async {
          expect(
            uri.toString(),
            'ws://localhost:8082/aitown-chat/ws?world_id=world-1',
          );
          expect(headers['Authorization'], 'Bearer token-1');
          return {
            ...headers,
            'X-App-ID': 'hashed-app-id',
            'X-Platform': 'android',
            'X-Device-ID': 'test-device-id',
            'X-App-Version': '0.1.0',
            'X-Key-ID': 'key-registered',
            'X-Timestamp': '1000',
            'X-Nonce': 'nonce-1',
            'X-Body-SHA256': 'empty-body-hash',
            'X-Signature-Alg': 'ECDSA-P256-SHA256',
            'X-Signature': 'signature-1',
          };
        },
      );

      final session = await client.connect(
        worldId: 'world-1',
        locationId: 'loc-1',
      );

      expect(transport.lastHeaders?['X-App-ID'], 'hashed-app-id');
      expect(transport.lastHeaders?['X-Platform'], 'android');
      expect(transport.lastHeaders?['X-Device-ID'], 'test-device-id');
      expect(transport.lastHeaders?['X-App-Version'], '0.1.0');
      expect(transport.lastHeaders?['X-Key-ID'], 'key-registered');
      expect(transport.lastHeaders?['X-Timestamp'], '1000');
      expect(transport.lastHeaders?['X-Nonce'], 'nonce-1');
      expect(transport.lastHeaders?['X-Body-SHA256'], 'empty-body-hash');
      expect(transport.lastHeaders?['X-Signature-Alg'], 'ECDSA-P256-SHA256');
      expect(transport.lastHeaders?['X-Signature'], 'signature-1');
      await session.disconnect();
    },
  );

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

  test('join sends a new join frame when switching locations', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(transport);
    final session = await client.connect(
      worldId: 'world-1',
      locationId: 'loc-1',
    );

    final firstJoin = session.join();
    await _tick();
    socket.serverJoinAck();
    await firstJoin;

    final secondJoin = session.join(locationId: 'loc-2');
    await _tick();

    final joinFrames = socket.sentFrames('join');
    expect(joinFrames, hasLength(2));
    expect(joinFrames.last['location_id'], 'loc-2');

    socket.serverJoinAck();
    final joined = await secondJoin;
    expect(joined.locationId, 'loc-2');
    expect(session.joined!.locationId, 'loc-2');
    await session.close();
  });

  test('user_enter_location sends one unacked generic envelope', () async {
    final socket = _FakeChatroomSocket();
    final transport = _FakeChatroomTransport(socket);
    final client = await _client(
      transport,
      ackTimeout: const Duration(milliseconds: 5),
      autoHeartbeat: false,
    );
    final session = await client.connect(
      worldId: 'world-1',
      locationId: 'loc-1',
    );

    await session.sendUserEnterLocation(locationId: ' loc-1 ');
    final frame = socket.sentFrame('user_enter_location');
    expect(frame, {
      'type': 'user_enter_location',
      'ts': isA<int>(),
      'world_id': 'world-1',
      'payload': {'loc_id': 'loc-1'},
      'err_no': '',
      'err_msg': '',
      'broadcast': false,
    });
    expect(frame, isNot(contains('client_msg_id')));

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(socket.sentFrames('user_enter_location'), hasLength(1));
    await session.disconnect();
  });

  test('parses canonical user_enter_location server message', () {
    final event = chatroomEventFromEnvelope(
      ChatroomEnvelope.fromJson({
        'type': 'user_enter_location',
        'ts': 1786000000000,
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'global_msg_id': 1006,
        'msg_id': 506,
        'location_msg_id': 203,
        'conversation_round_id': 126,
        'user_id': 'user-1',
        'sender_id': 'char-1',
        'sender_name': 'Alice',
        'location_id': 'loc-1',
        'err_no': '',
        'err_msg': '',
        'broadcast': true,
        'payload': {
          'content': 'Alice entered the cafe.',
          'message_type': 'text',
        },
      }),
    );

    expect(event, isA<ChatroomUserEnterLocationMessage>());
    final entered = event as ChatroomUserEnterLocationMessage;
    expect(entered.messageId, 506);
    expect(entered.locationMessageId, 203);
    expect(entered.locationId, 'loc-1');
    expect(entered.senderId, 'char-1');
    expect(entered.userId, 'user-1');
    expect(entered.content, 'Alice entered the cafe.');
    expect(entered.messageType, 'text');
    expect(entered.broadcast, isTrue);
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
    final defaultUri = Uri.parse(GenesisApi.defaultChatroomWsBaseUrl);

    expect(
      transport.lastUri.toString(),
      '${defaultUri.scheme}://${defaultUri.host}:443'
      '${defaultUri.path}?world_id=world-1',
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
        wsBaseUrl: 'ws://api.worldo.ai/aitown-chat/',
      );

      final session = await client.connect(worldId: 'world-1');

      expect(
        transport.lastUri.toString(),
        'ws://api.worldo.ai:80/aitown-chat/?world_id=world-1',
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
      'global_msg_id': 9001,
      'msg_id': 1001,
      'location_msg_id': 11,
      'conversation_round_id': 201,
      'err_no': '',
      'err_msg': '',
      'payload': {'client_msg_id': 'client-1'},
    });

    final ack = await ackFuture;
    expect(ack.globalMessageId, 9001);
    expect(ack.messageId, 1001);
    expect(ack.locationMessageId, 11);
    expect(ack.conversationRoundId, '201');
    await session.close();
  });

  test(
    'sendMessage leaves UGC backslashes to JSON and normalizes real newlines',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);
      const raw = '  first\r\n${r'literal \n \u300c \\'}  ';
      const expected = '  first\n${r'literal \n \u300c \\'}  ';

      final ackFuture = session.sendMessage(raw, clientMsgId: 'client-ugc');
      await _tick();

      expect(socket.sentFrame('send_message'), {
        'type': 'send_message',
        'client_msg_id': 'client-ugc',
        'content': expected,
      });
      expect(
        socket.sent.lastWhere(
          (raw) =>
              (jsonDecode(raw) as Map<String, dynamic>)['type'] ==
              'send_message',
        ),
        jsonEncode({
          'type': 'send_message',
          'client_msg_id': 'client-ugc',
          'content': expected,
        }),
      );

      socket.serverFrame('ack', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'location_id': 'loc-1',
        'global_msg_id': 9002,
        'msg_id': 1002,
        'location_msg_id': 12,
        'conversation_round_id': 202,
        'err_no': '',
        'err_msg': '',
        'payload': {'client_msg_id': 'client-ugc'},
      });

      await ackFuture;
      await session.close();
    },
  );

  test('sendMessage completes from matching user_message push', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final ackFuture = session.sendMessage('吃饭了吗', clientMsgId: 'client-1');
    await _tick();

    socket.serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'user_id': 'user-1',
      'sender_id': 'user-1',
      'sender_name': 'Player One',
      'global_msg_id': 9126,
      'msg_id': 126,
      'location_msg_id': 26,
      'conversation_round_id': 1317,
      'payload': {'content': '吃饭了吗', 'client_msg_id': 'client-1'},
    });

    final ack = await ackFuture;
    expect(ack.globalMessageId, 9126);
    expect(ack.messageId, 126);
    expect(ack.locationMessageId, 26);
    expect(ack.conversationRoundId, '1317');
    expect(ack.clientMsgId, 'client-1');
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
      'err_no': '',
      'err_msg': '',
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

  test(
    'balance error without client id fails the only pending send immediately',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        ackTimeout: const Duration(milliseconds: 20),
      );
      final session = await _connectedSession(client, socket);

      final future = session.sendMessage(
        'hello',
        clientMsgId: 'client-balance',
      );
      await _tick();

      socket.serverFrame('ack', {
        'payload': {
          'err_no': 3001,
          'err_msg': 'Insufficient balance',
          'err_detail': 'Insufficient balance, please recharge',
        },
      });

      await expectLater(
        future,
        throwsA(
          isA<ChatroomFailureEvent>()
              .having((e) => e.code, 'code', '3001')
              .having(
                (e) => e.detail,
                'detail',
                'Insufficient balance, please recharge',
              )
              .having((e) => e.clientMsgId, 'clientMsgId', 'client-balance'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        socket
            .sentFrames('send_message')
            .where((frame) => frame['client_msg_id'] == 'client-balance'),
        hasLength(1),
      );
      await session.close();
    },
  );

  test(
    'unauthorized ack restores the pending send before failure broadcast',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);
      final completionOrder = <String>[];
      final failureSub = session.failures.listen((_) {
        completionOrder.add('failure_broadcast');
      });

      final sendFuture = session
          .sendMessage('retry after login', clientMsgId: 'client-unauthorized')
          .catchError((Object error) {
            completionOrder.add('send_failure');
            throw error;
          });
      await _tick();

      socket.serverFrame('ack', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'err_no': 10001,
        'err_msg': 'Unauthorized',
        'payload': <String, Object?>{},
      });

      await expectLater(
        sendFuture,
        throwsA(
          isA<ChatroomFailureEvent>()
              .having((e) => e.code, 'code', '10001')
              .having(
                (e) => e.clientMsgId,
                'clientMsgId',
                'client-unauthorized',
              ),
        ),
      );
      await _tick();
      expect(completionOrder, <String>['send_failure', 'failure_broadcast']);

      await failureSub.cancel();
      await session.close();
    },
  );

  test('balance_low is parsed as a supported chatroom event', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final eventFuture = session.events.firstWhere(
      (event) => event is ChatroomBalanceLow,
    );

    socket.serverFrame('balance_low', {
      'payload': {'balance': 10, 'message': '余额即将不足，请及时充值'},
    });

    final event = await eventFuture as ChatroomBalanceLow;
    expect(event.balance, 10);
    expect(event.message, '余额即将不足，请及时充值');
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
    expect(
      socket
          .sentFrames('send_message')
          .where((frame) => frame['client_msg_id'] == 'client-timeout'),
      hasLength(3),
    );

    await session.close();
  });

  test('sendMessage completes when retry receives matching ack', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(
      _FakeChatroomTransport(socket),
      ackTimeout: const Duration(milliseconds: 20),
    );
    final session = await _connectedSession(client, socket);

    final future = session.sendMessage('hello', clientMsgId: 'client-retry');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
      socket
          .sentFrames('send_message')
          .where((frame) => frame['client_msg_id'] == 'client-retry'),
      hasLength(2),
    );
    socket.serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'location_id': 'loc-1',
      'user_id': 'u_1',
      'err_no': '',
      'err_msg': '',
      'payload': {'client_msg_id': 'client-retry'},
    });

    await future;
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
      'global_msg_id': 9789,
      'msg_id': 789,
      'location_msg_id': 89,
      'conversation_round_id': 201,
      'payload': {
        'sender_type': 'character',
        'sender_id': 'char_001',
        'sender_name': '村长',
      },
    });
    final aiStream = await streamFuture;
    final chunks = <String>[];
    final seqs = <int>[];
    final sub = aiStream.chunks.listen((chunk) {
      chunks.add(chunk.chunk);
      seqs.add(chunk.seq);
    });

    socket.serverFrame('llm_chunk', {
      'world_id': 'world-1',
      'location_id': 'loc-1',
      'global_msg_id': 9789,
      'msg_id': 789,
      'location_msg_id': 89,
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
      'global_msg_id': 9789,
      'msg_id': 789,
      'location_msg_id': 89,
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
      'global_msg_id': 9789,
      'msg_id': 789,
      'location_msg_id': 89,
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
    expect(aiStream.start.globalMessageId, 9789);
    expect(aiStream.start.locationMessageId, 89);
    expect(aiStream.start.conversationRoundId, '201');
    expect(chunks, ['hello ', 'there']);
    expect(seqs, [1, 2]);
    expect(aiStream.content, 'hello there');
    await session.close();
  });

  test('socket close does not surface unobserved ai stream error', () async {
    final unhandledErrors = <Object>[];

    await runZonedGuarded<Future<void>>(
      () async {
        final socket = _FakeChatroomSocket();
        final client = await _client(_FakeChatroomTransport(socket));
        final session = await _connectedSession(client, socket);

        final streamFuture = session.streams.first;
        socket.serverFrame('llm_stream_start', {
          'world_id': 'world-1',
          'location_id': 'loc-1',
          'global_msg_id': 9789,
          'msg_id': 789,
          'location_msg_id': 89,
          'conversation_round_id': 201,
          'payload': {
            'sender_type': 'character',
            'sender_id': 'char_001',
            'sender_name': '村长',
          },
        });

        await streamFuture;
        final failureFuture = session.failures.first;

        await socket.serverClose();
        final failure = await failureFuture;
        await Future<void>.delayed(Duration.zero);

        expect(failure.code, 'socket_closed');
      },
      (error, _) {
        unhandledErrors.add(error);
      },
    );

    expect(unhandledErrors, isEmpty);
  });

  test('routes error ack to common failure stream', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final failureFuture = session.failures.first;
    socket.serverFrame('ack', {
      'session_id': 'sess-1',
      'err_no': '2006',
      'err_msg': '当前 Tick 正在推进，请稍后',
      'world_id': 'world-1',
      'payload': <String, Object?>{},
    });

    final failure = await failureFuture;
    expect(failure.code, '2006');
    expect(failure.message, '当前 Tick 正在推进，请稍后');
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
    socket.serverFrame('new_user_join', {
      'world_id': 'world-1',
      'payload': {
        'char_id': 'char-2',
        'type': 'ai',
        'name': '老沈',
        'player_uid': 'user-2',
        'player_username': 'Nikos',
      },
    });
    socket.serverFrame('user_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'msg_id': 1002,
      'conversation_round_id': 201,
      'user_id': 'u_1',
      'sender_id': 'u_1',
      'sender_name': 'Alice',
      'location_id': 'loc-1',
      'payload': {'content': '你好'},
    });
    socket.serverFrame('tick_advance', {
      'world_id': 'world-1',
      'msg_id': 156,
      'conversation_round_id': 1350,
      'current_time': 'Day 45, 19:30',
      'sub_tick_no': 1,
      'payload': {'content': 'Day 45, 19:30', 'tick_no': 7},
    });
    socket.serverFrame('nar_new_message', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'msg_id': 155,
      'conversation_round_id': 1349,
      'sender_id': 'nar',
      'sender_name': '旁白',
      'location_id': 'loc-2',
      'broadcast': true,
      'payload': {'content': '*旁白推进剧情*', 'message_type': ' IMAGE '},
    });
    await _tick();

    expect(
      events.whereType<ChatroomWorldNotification>().map((e) => e.eventType),
      containsAll(['tick_start', 'world_change']),
    );
    final join = events.whereType<ChatroomNewUserJoinEvent>().single;
    expect(join.worldId, 'world-1');
    expect(join.characterId, 'char-2');
    expect(join.characterType, 'ai');
    expect(join.characterName, '老沈');
    expect(join.playerUid, 'user-2');
    expect(join.playerUsername, 'Nikos');
    final userMessage = events.whereType<ChatroomUserMessage>().single;
    expect(userMessage.content, '你好');
    expect(userMessage.messageType, 'text');
    final tick = events.whereType<ChatroomTickAdvanceMessage>().single;
    expect(tick.currentTime, 'Day 45, 19:30');
    expect(tick.tickNo, 7);
    expect(tick.subTickNo, 1);
    expect(tick.content, 'Day 45, 19:30');
    expect(tick.messageType, 'text');
    final narrator = events.whereType<ChatroomNarratorMessage>().single;
    expect(narrator.messageId, 155);
    expect(narrator.conversationRoundId, '1349');
    expect(narrator.locationId, 'loc-2');
    expect(narrator.senderId, 'nar');
    expect(narrator.senderName, '旁白');
    expect(narrator.content, '*旁白推进剧情*');
    expect(narrator.messageType, 'image');
    expect(narrator.broadcast, isTrue);
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

  test('heartbeat sends a protocol heartbeat without client msg id', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);
    final before = socket.sentTypes.where((type) => type == 'heartbeat').length;

    await session.heartbeat();
    await _tick();
    final heartbeat = socket.sentFrame('heartbeat');
    expect(heartbeat, {'type': 'heartbeat'});

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

  test('server error acks are routed to unified failure stream once', () async {
    final socket = _FakeChatroomSocket();
    final client = await _client(_FakeChatroomTransport(socket));
    final session = await _connectedSession(client, socket);

    final failures = <ChatroomFailureEvent>[];
    final sub = session.failures.listen(failures.add);
    socket.serverFrame('ack', {
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'err_no': '2006',
      'err_msg': '当前 Tick 正在推进，请稍后',
      'payload': <String, Object?>{},
    });
    await _tick();

    expect(failures, hasLength(1));
    expect(failures.single.code, '2006');
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
    'oversized frame reports protocol error and keeps the socket alive',
    () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(_FakeChatroomTransport(socket));
      final session = await _connectedSession(client, socket);

      final failureFuture = session.failures.first;
      socket.serverRaw('x' * (chatroomMaxFrameBytes + 1));
      final failure = await failureFuture;
      expect(failure.code, 'protocol_error');

      final eventFuture = session.events
          .where((event) => event is ChatroomWorldNotification)
          .cast<ChatroomWorldNotification>()
          .first;
      socket.serverFrame('map_updated', {
        'world_id': 'world-1',
        'payload': <String, Object?>{},
      });
      expect((await eventFuture).eventType, 'map_updated');
      await session.close();
    },
  );

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
          onFailure: (_) => handled.add('failure'),
          onWorldNotification: (_) => handled.add('world_notification'),
          onCharactersMovedMessage: (_) => handled.add('characters_moved'),
          onUserMessage: (_) => handled.add('user_message'),
          onTickAdvanceMessage: (_) => handled.add('tick_advance'),
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
        'err_no': '',
        'err_msg': '',
        'payload': {'client_msg_id': 'client-handler'},
      });
      socket.serverFrame('ack', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'err_no': '2006',
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
      socket.serverFrame('characters_moved', {
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'global_msg_id': 9002,
        'msg_id': 1002,
        'location_msg_id': 202,
        'conversation_round_id': 201,
        'payload': {
          'movements': [
            {'char_id': 'char_alice', 'to_loc_id': 'loc-2'},
          ],
        },
      });
      socket.serverFrame('user_message', {
        'world_id': 'world-1',
        'session_id': 'sess-1',
        'location_id': 'loc-1',
        'user_id': 'u_1',
        'sender_id': 'u_1',
        'sender_name': 'Alice',
        'msg_id': 1001,
        'conversation_round_id': 201,
        'payload': {'content': '你好'},
      });
      socket.serverFrame('tick_advance', {
        'world_id': 'world-1',
        'msg_id': 1003,
        'conversation_round_id': 202,
        'current_time': 'Day 45, 19:30',
        'payload': {'content': 'Day 45, 19:30', 'tick_no': 7},
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
          'failure',
          'world_notification',
          'characters_moved',
          'user_message',
          'tick_advance',
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

  group('V2 WebSocket contract', () {
    test('selects V2 only above the 0.3.3 version boundary', () {
      expect(
        resolveChatroomProtocolVersion(''),
        ChatroomProtocolVersion.legacy,
      );
      expect(
        resolveChatroomProtocolVersion('not-semver'),
        ChatroomProtocolVersion.legacy,
      );
      expect(
        resolveChatroomProtocolVersion('0.3.3+9'),
        ChatroomProtocolVersion.legacy,
      );
      expect(
        resolveChatroomProtocolVersion('0.3.4-rc'),
        ChatroomProtocolVersion.v2,
      );
      expect(
        resolveChatroomProtocolVersion('0.3.4'),
        ChatroomProtocolVersion.v2,
      );
      expect(
        resolveChatroomProtocolVersion('0.3.4+34'),
        ChatroomProtocolVersion.v2,
      );
      expect(
        resolveChatroomProtocolVersion('1.0.0'),
        ChatroomProtocolVersion.v2,
      );
    });

    test('V2 DTO retains every top-level field and payload', () {
      final json = <String, dynamic>{
        'type': 'character',
        'stream_type': 'llm_chunk',
        'ts': 1786340797400,
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'session_id': 'sess-1',
        'global_message_id': 8703,
        'message_id': 102,
        'location_message_id': 30,
        'conversation_round_id': 7360,
        'sender_type': 'character',
        'sender_id': 'char-2',
        'sender_name': 'Elara',
        'user_id': 'user-1',
        'client_msg_id': 'client-2',
        'message_type': 'text',
        'min_app_version': 34,
        'created_at': '2026-08-10 11:06:37',
        'current_time': 'Day 1, 13:50',
        'payload': <String, dynamic>{
          'seq': 3,
          'content': 'Hello',
          'current_time': 'Day 1, 13:50',
        },
        'err_no': 0,
        'err_msg': '',
      };

      final message = ChatroomV2Message.fromJson(json);

      expect(message.toJson(), json);
      expect(message.isLlmStream, true);
      expect(message.streamType, 'llm_chunk');
      expect(message.conversationRoundId, 7360);
    });

    test('routes the V2 waiting conversation round control event', () {
      final event = chatroomEventFromV2Message(
        ChatroomV2Message.fromJson(<String, dynamic>{
          'type': 'waiting_conversation_round',
          'stream_type': '',
          'ts': 1785890000000,
          'world_id': 'world-1',
          'location_id': 'loc-1',
          'conversation_round_id': 301,
          'payload': <String, dynamic>{},
          'err_no': 0,
          'err_msg': '',
        }),
      );

      expect(event, isA<ChatroomWaitingConversationRound>());
      final waiting = event as ChatroomWaitingConversationRound;
      expect(waiting.worldId, 'world-1');
      expect(waiting.locationId, 'loc-1');
      expect(waiting.conversationRoundId, '301');
      expect(waiting.ok, isTrue);
      expect(chatroomEventType(waiting), 'waiting_conversation_round');
    });

    test('routes the V2 end conversation round control event', () {
      final event = chatroomEventFromV2Message(
        ChatroomV2Message.fromJson(<String, dynamic>{
          'type': 'end_conversation_round',
          'stream_type': '',
          'ts': 1785890001000,
          'world_id': 'world-1',
          'location_id': 'loc-1',
          'conversation_round_id': 301,
          'payload': <String, dynamic>{},
          'err_no': 0,
          'err_msg': '',
        }),
      );

      expect(event, isA<ChatroomEndConversationRound>());
      final end = event as ChatroomEndConversationRound;
      expect(end.worldId, 'world-1');
      expect(end.locationId, 'loc-1');
      expect(end.conversationRoundId, '301');
      expect(end.ok, isTrue);
      expect(chatroomEventType(end), 'end_conversation_round');
    });

    test('rejects malformed or legacy waiting conversation round events', () {
      expect(
        () => chatroomEventFromV2Message(
          const ChatroomV2Message(
            type: 'waiting_conversation_round',
            conversationRoundId: 301,
          ),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
      expect(
        () => chatroomEventFromV2Message(
          const ChatroomV2Message(
            type: 'waiting_conversation_round',
            locationId: 'loc-1',
          ),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
      expect(
        () => chatroomLegacyEventFromEnvelope(
          ChatroomEnvelope.fromJson(<String, dynamic>{
            'type': 'waiting_conversation_round',
            'location_id': 'loc-1',
            'conversation_round_id': 301,
            'payload': <String, dynamic>{},
          }),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
    });

    test('rejects malformed end conversation round events', () {
      expect(
        () => chatroomEventFromV2Message(
          const ChatroomV2Message(
            type: 'end_conversation_round',
            conversationRoundId: 301,
          ),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
      expect(
        () => chatroomEventFromV2Message(
          const ChatroomV2Message(
            type: 'end_conversation_round',
            locationId: 'loc-1',
          ),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
    });

    test('unknown V2 business type is rejected as a single-frame error', () {
      expect(
        () => chatroomEventFromV2Message(
          const ChatroomV2Message(
            type: 'future_business',
            payload: <String, dynamic>{},
          ),
        ),
        throwsA(isA<ChatroomProtocolException>()),
      );
    });

    test('routes stream_type before business type and decodes typed tick', () {
      final chunk = chatroomEventFromV2Message(
        ChatroomV2Message.fromJson(<String, dynamic>{
          'type': 'narrator',
          'stream_type': 'llm_chunk',
          'payload': <String, dynamic>{'seq': 1, 'content': 'A'},
          'err_no': 0,
          'err_msg': '',
        }),
      );
      expect(chunk, isA<ChatroomAiStreamChunk>());
      expect((chunk as ChatroomAiStreamChunk).businessType, 'narrator');

      final tick =
          chatroomEventFromV2Message(
                ChatroomV2Message.fromJson(<String, dynamic>{
                  'type': 'tick',
                  'stream_type': '',
                  'world_id': 'world-1',
                  'location_id': 'loc-1',
                  'global_message_id': 8702,
                  'message_id': 101,
                  'location_message_id': 29,
                  'conversation_round_id': 7359,
                  'sender_type': 'tick',
                  'sender_id': 'tick',
                  'sender_name': 'SubTick',
                  'message_type': 'text',
                  'min_app_version': 0,
                  'payload': <String, dynamic>{
                    'current_time': 'Day 1, 13:50',
                    'tick_no': 0,
                    'sub_tick_no': 2,
                    'global': 'The key pulses.',
                    'story_events': <Object?>[],
                    'characters_moved': <Object?>[],
                  },
                  'err_no': 0,
                  'err_msg': '',
                }),
              )
              as ChatroomTickAdvanceMessage;

      expect(tick.isV2LocationTick, true);
      expect(tick.v2TickPayload!.tickNo, 0);
      expect(tick.v2TickPayload!.globalText, 'The key pulses.');
      expect(tick.businessType, 'tick');
      expect(tick.rawPayload['sub_tick_no'], 2);
    });

    test('sends exact V2 envelopes and treats ACK as receipt only', () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        autoHeartbeat: false,
        handshakeHeaderSigner: _v2HandshakeSigner,
      );
      final session = await client.connect(
        worldId: 'world-1',
        locationId: 'loc-1',
      );
      expect(session.protocolVersion, ChatroomProtocolVersion.v2);

      final joinFuture = session.join();
      await _tick();
      final join = socket.sentFrame('join');
      expect(join, <String, Object?>{
        'type': 'join',
        'stream_type': '',
        'ts': isA<int>(),
        'world_id': 'world-1',
        'client_msg_id': isA<String>(),
        'payload': <String, Object?>{'location_id': 'loc-1'},
        'err_no': 0,
        'err_msg': '',
      });
      socket.serverV2Ack(join['client_msg_id']! as String);
      await joinFuture;

      final sendFuture = session.sendMessage('Hello', clientMsgId: 'client-2');
      await _tick();
      expect(socket.sentFrame('send_message'), <String, Object?>{
        'type': 'send_message',
        'stream_type': '',
        'ts': isA<int>(),
        'world_id': 'world-1',
        'client_msg_id': 'client-2',
        'payload': <String, Object?>{'content': 'Hello'},
        'err_no': 0,
        'err_msg': '',
      });
      socket.serverV2Ack(
        'client-2',
        extra: const <String, Object?>{
          'global_message_id': 9001,
          'message_id': 1001,
          'location_message_id': 11,
          'conversation_round_id': 201,
        },
      );
      final receipt = await sendFuture;
      expect(receipt.clientMsgId, 'client-2');
      expect(receipt.hasCanonicalMessageMetadata, false);
      expect(receipt.messageId, 0);

      await session.sendUserEnterLocation(locationId: 'loc-2');
      expect(socket.sentFrame('user_enter_location'), <String, Object?>{
        'type': 'user_enter_location',
        'stream_type': '',
        'ts': isA<int>(),
        'world_id': 'world-1',
        'client_msg_id': isA<String>(),
        'payload': <String, Object?>{'location_id': 'loc-2'},
        'err_no': 0,
        'err_msg': '',
      });

      await session.heartbeat();
      expect(socket.sentFrame('heartbeat'), <String, Object?>{
        'type': 'heartbeat',
        'stream_type': '',
        'ts': isA<int>(),
        'client_msg_id': isA<String>(),
        'payload': <String, Object?>{},
        'err_no': 0,
        'err_msg': '',
      });

      await session.leave();
      expect(socket.sentFrame('leave'), <String, Object?>{
        'type': 'leave',
        'stream_type': '',
        'ts': isA<int>(),
        'client_msg_id': isA<String>(),
        'payload': <String, Object?>{},
        'err_no': 0,
        'err_msg': '',
      });
      await session.disconnect();
    });

    test('canonical user echo does not complete the V2 ACK future', () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        autoHeartbeat: false,
        handshakeHeaderSigner: _v2HandshakeSigner,
      );
      final session = await client.connect(worldId: 'world-1');
      var completed = false;
      final receiptFuture = session.sendMessage(
        'Hello',
        clientMsgId: 'client-echo',
      );
      unawaited(receiptFuture.then((_) => completed = true));
      await _tick();
      socket.serverFrame('user', <String, Object?>{
        'stream_type': '',
        'ts': 1786340797200,
        'world_id': 'world-1',
        'location_id': 'loc-1',
        'global_message_id': 8703,
        'message_id': 102,
        'location_message_id': 30,
        'conversation_round_id': 7360,
        'sender_type': 'user',
        'sender_id': 'char-1',
        'sender_name': 'Alice',
        'user_id': 'u_1',
        'client_msg_id': 'client-echo',
        'message_type': 'text',
        'payload': <String, Object?>{'content': 'Hello'},
        'err_no': 0,
        'err_msg': '',
      });
      await _tick();
      expect(completed, false);

      socket.serverV2Ack('client-echo');
      await receiptFuture;
      expect(completed, true);
      await session.disconnect();
    });

    test('bad V2 frame is isolated and the next frame is delivered', () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        autoHeartbeat: false,
        handshakeHeaderSigner: _v2HandshakeSigner,
      );
      final session = await client.connect(worldId: 'world-1');
      final failureFuture = session.failures.first;
      final userFuture = session.events
          .where((event) => event is ChatroomUserMessage)
          .cast<ChatroomUserMessage>()
          .first;

      socket.serverRaw(
        jsonEncode(<String, Object?>{
          'type': 'character',
          'stream_type': 'unsupported_stream',
          'payload': <String, Object?>{},
          'err_no': 0,
          'err_msg': '',
        }),
      );
      expect((await failureFuture).code, 'protocol_error');
      socket.serverFrame('user', <String, Object?>{
        'stream_type': '',
        'payload': <String, Object?>{'content': 'still alive'},
        'err_no': 0,
        'err_msg': '',
      });

      expect((await userFuture).content, 'still alive');
      expect(socket.closed, false);
      await session.disconnect();
    });

    test(
      'cursorless stream uses a unique candidate and orders chunks',
      () async {
        final socket = _FakeChatroomSocket();
        final client = await _client(
          _FakeChatroomTransport(socket),
          autoHeartbeat: false,
          handshakeHeaderSigner: _v2HandshakeSigner,
        );
        final session = await client.connect(worldId: 'world-1');
        final streamFuture = session.streams.first;
        socket.serverV2StreamFrame('llm_stream_start');
        final stream = await streamFuture;
        final sequences = <int>[];
        final chunks = <String>[];
        final subscription = stream.chunks.listen((chunk) {
          sequences.add(chunk.seq);
          chunks.add(chunk.chunk);
        });

        socket.serverV2StreamFrame('llm_chunk', seq: 2, content: 'B');
        socket.serverV2StreamFrame('llm_chunk', seq: 1, content: 'A');
        socket.serverV2StreamFrame('llm_chunk', seq: 1, content: 'duplicate');
        socket.serverV2StreamFrame('llm_stream_end', content: 'AB');
        await stream.done;
        await _tick();

        expect(sequences, <int>[1, 2]);
        expect(chunks, <String>['A', 'B']);
        expect(stream.content, 'AB');
        await subscription.cancel();
        await session.disconnect();
      },
    );

    test('stream end may replace the start message id', () async {
      final socket = _FakeChatroomSocket();
      final client = await _client(
        _FakeChatroomTransport(socket),
        autoHeartbeat: false,
        handshakeHeaderSigner: _v2HandshakeSigner,
      );
      final session = await client.connect(worldId: 'world-1');
      final streamFuture = session.streams.first;
      socket.serverV2StreamFrame(
        'llm_stream_start',
        conversationRoundId: 9,
        messageId: 40,
      );
      final stream = await streamFuture;

      socket.serverV2StreamFrame(
        'llm_stream_end',
        conversationRoundId: 9,
        messageId: 41,
        content: 'authoritative final',
      );
      final end = await stream.done;

      expect(end.messageId, 41);
      expect(stream.content, 'authoritative final');
      await session.disconnect();
    });

    test(
      'composite stream identity isolates sender and reports ambiguity',
      () async {
        final socket = _FakeChatroomSocket();
        final client = await _client(
          _FakeChatroomTransport(socket),
          autoHeartbeat: false,
          handshakeHeaderSigner: _v2HandshakeSigner,
        );
        final session = await client.connect(worldId: 'world-1');
        final streamsFuture = session.streams.take(2).toList();
        socket.serverV2StreamFrame(
          'llm_stream_start',
          senderId: 'char-a',
          conversationRoundId: 7,
        );
        socket.serverV2StreamFrame(
          'llm_stream_start',
          senderId: 'char-b',
          conversationRoundId: 7,
        );
        final streams = await streamsFuture;
        final streamA = streams.singleWhere(
          (stream) => stream.start.senderId == 'char-a',
        );
        final streamB = streams.singleWhere(
          (stream) => stream.start.senderId == 'char-b',
        );
        socket.serverV2StreamFrame(
          'llm_chunk',
          senderId: 'char-a',
          conversationRoundId: 7,
          seq: 1,
          content: 'A',
        );
        socket.serverV2StreamFrame(
          'llm_chunk',
          senderId: 'char-b',
          conversationRoundId: 7,
          seq: 1,
          content: 'B',
        );
        await _tick();
        expect(streamA.content, 'A');
        expect(streamB.content, 'B');

        final duplicateFuture = session.streams.first;
        socket.serverV2StreamFrame(
          'llm_stream_start',
          senderId: 'char-a',
          conversationRoundId: 7,
        );
        await duplicateFuture;
        final ambiguityFuture = session.failures.firstWhere(
          (failure) => failure.code == 'stream_ambiguous',
        );
        socket.serverV2StreamFrame(
          'llm_chunk',
          senderId: 'char-a',
          conversationRoundId: 7,
          seq: 2,
          content: 'must-not-cross-wire',
        );
        expect((await ambiguityFuture).code, 'stream_ambiguous');
        expect(streamA.content, 'A');
        await session.disconnect();
      },
    );
  });
}

Future<Map<String, String>> _v2HandshakeSigner(
  Uri _,
  Map<String, String> headers,
) async => <String, String>{...headers, 'X-App-Version': '0.3.4-rc'};

Future<ChatroomClient> _client(
  ChatroomSocketTransport transport, {
  String wsBaseUrl = 'ws://localhost:8082/aitown-chat/ws',
  Duration heartbeatInterval = const Duration(seconds: 2),
  Duration ackTimeout = const Duration(milliseconds: 100),
  bool autoHeartbeat = true,
  GatewayHandshakeHeaderSigner? handshakeHeaderSigner,
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
    autoHeartbeat: autoHeartbeat,
    handshakeHeaderSigner: handshakeHeaderSigner,
    requestHeaderProvider: () async => const {
      'user-agent': 'Android 15',
      'app-id': 'legacy-app-id',
      'app-version': '0.1.0',
      'app-platform': 'android',
      'device-id': 'legacy-device-id',
    },
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

  List<Map<String, dynamic>> sentFrames(String type) {
    return sent
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .where((frame) => frame['type'] == type)
        .toList(growable: false);
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
      'err_no': '',
      'err_msg': '',
      'payload': {'client_msg_id': clientMsgId},
    });
  }

  void serverV2Ack(
    String clientMsgId, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    serverFrame('ack', <String, Object?>{
      'stream_type': '',
      'ts': 1786340797100,
      'world_id': 'world-1',
      'session_id': 'sess-1',
      'client_msg_id': clientMsgId,
      'payload': <String, Object?>{},
      'err_no': 0,
      'err_msg': '',
      ...extra,
    });
  }

  void serverV2StreamFrame(
    String streamType, {
    String senderId = 'char-1',
    int? conversationRoundId,
    int? messageId,
    int? seq,
    String content = '',
  }) {
    serverFrame('character', <String, Object?>{
      'stream_type': streamType,
      'ts': 1786340797400,
      'world_id': 'world-1',
      'location_id': 'loc-1',
      if (conversationRoundId != null)
        'conversation_round_id': conversationRoundId,
      if (messageId != null) 'message_id': messageId,
      'sender_type': 'character',
      'sender_id': senderId,
      'sender_name': senderId,
      'payload': <String, Object?>{
        if (seq != null) 'seq': seq,
        if (content.isNotEmpty) 'content': content,
      },
      'err_no': 0,
      'err_msg': '',
    });
  }

  void serverRaw(String raw) {
    _messages.add(raw);
  }
}
