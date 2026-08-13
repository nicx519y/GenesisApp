import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

class _FakeTransport implements HttpTransport {
  final requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    final path = request.uri.path;
    if (path == '/aitown-chat/api/ulocation') {
      return _ok({
        'world_id': 'w_1',
        'locations': [
          {
            'location_id': 'loc_1',
            'users': [
              {
                'user_id': 'u_1',
                'user_name': '勇者小明',
                'avatar': 'https://cdn.example.com/u_1.png',
              },
            ],
          },
        ],
      });
    }
    if (path == '/aitown-chat/internal/world/messages') {
      return _ok({
        'locations': [
          {
            'location_id': 'loc_1',
            'messages': [
              {
                'global_message_id': 90001,
                'message_id': 1001,
                'location_msg_id': 101,
                'location_id': 'loc_1',
                'conversation_round_id': 100,
                'sender_type': 'user',
                'sender_id': 'char_1',
                'sender_name': 'A',
                'user_id': 'u_1',
                'content': 'hello',
                'current_time': 'Day 1, 08:00',
                'tick_no': 3,
                'created_at': '2026-07-01 10:00:00',
              },
            ],
          },
        ],
      });
    }
    if (path == '/aitown-chat/api/messages') {
      return _ok({
        'messages': [
          {
            'global_message_id': 90001,
            'message_id': 1001,
            'location_msg_id': 101,
            'location_id': 'loc_1',
            'conversation_round_id': 100,
            'sender_type': 'user',
            'sender_id': 'char_1',
            'sender_name': 'A',
            'user_id': 'u_1',
            'content': 'hello',
            'message_type': ' IMAGE ',
            'current_time': 'Day 1, 08:00',
            'tick_no': 3,
            'created_at': '2026-07-01 10:00:00',
          },
        ],
        'has_more': false,
        'newest_message_id': 1001,
      });
    }
    if (path == '/aitown-chat/api/v2/messages') {
      return _ok({
        'messages': [
          {
            'type': 'user',
            'stream_type': '',
            'ts': 1782890400000,
            'world_id': 'w_1',
            'global_message_id': 90001,
            'message_id': 1001,
            'location_message_id': 101,
            'location_id': 'loc_1',
            'conversation_round_id': 100,
            'sender_type': 'user',
            'sender_id': 'char_1',
            'sender_name': 'A',
            'user_id': 'u_1',
            'client_msg_id': 'client_1',
            'message_type': ' IMAGE ',
            'min_app_version': 34,
            'created_at': '2026-07-01 10:00:00',
            'payload': {'content': 'hello'},
            'err_no': 0,
            'err_msg': '',
          },
        ],
        'has_more': false,
        'newest_message_id': 101,
      });
    }
    if (path == '/aitown-chat/internal/tick/lock') {
      return _camelOk({'locked': true});
    }
    if (path == '/aitown-chat/internal/tick/is_locked') {
      return _ok({'is_locked': true});
    }
    if (path == '/aitown-chat/internal/tick/progress') {
      return _camelOk({
        'progress': 1,
        'pending_messages': 0,
        'active_llm_calls': 0,
      });
    }
    if (path == '/aitown-chat/internal/tick/unlock') {
      return _camelOk({'unlocked': true});
    }
    if (path == '/aitown-chat/internal/narrator/write') {
      return _camelOk({'message_id': 1002});
    }
    return const TransportResponse(
      statusCode: 404,
      headers: {'content-type': 'application/json'},
      body: '{"err_no":404,"err_msg":"not found"}',
    );
  }

  TransportResponse _ok(Object? data) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
    );
  }

  TransportResponse _camelOk(Object? data) {
    return TransportResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'errNo': 0, 'errMsg': 'succ', 'data': data}),
    );
  }
}

void main() {
  test('ChatroomHttpMessage reads legacy location_message_id fallback', () {
    final message = ChatroomHttpMessage.fromJson({
      'message_id': 1001,
      'location_message_id': 101,
      'location_id': 'loc_1',
    });

    expect(message.locationMessageId, 101);
    expect(message.messageType, 'text');
  });

  test('ChatroomHttpMessage normalizes message_type values', () {
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 1,
        'message_type': ' IMAGE ',
      }).messageType,
      'image',
    );
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 2,
        'message_type': '   ',
      }).messageType,
      'text',
    );
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 3,
        'message_type': ' Future_Format ',
      }).messageType,
      'future_format',
    );
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 4,
        'sender_id': 'nar_pic',
      }).messageType,
      'image',
    );
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 5,
        'sender_id': 'nar_pic',
        'message_type': null,
      }).messageType,
      'text',
    );
    expect(
      ChatroomHttpMessage.fromJson({
        'message_id': 6,
        'sender_id': 'nar_pic',
        'message_type': 'text',
      }).messageType,
      'text',
    );
  });

  test('ChatroomMessageListResponse preserves raw response json', () {
    final response = ChatroomMessageListResponse.fromJson({
      'messages': [
        {
          'global_message_id': 90001,
          'message_id': 1001,
          'location_msg_id': 101,
          'location_id': 'loc_1',
          'conversation_round_id': 100,
          'sender_type': 'user',
          'sender_id': 'char_1',
          'sender_name': 'A',
          'user_id': 'u_1',
          'content': 'full body',
          'current_time': 'Day 1, 08:00',
          'custom_server_field': {'nested': true},
        },
      ],
      'has_more': true,
      'newest_message_id': 1001,
      'server_extra': 'keep-me',
    });

    expect(response.rawJson['server_extra'], 'keep-me');
    final rawMessages = response.rawJson['messages'] as List<Object?>;
    final rawMessage = rawMessages.single as Map<Object?, Object?>;
    expect(rawMessage['custom_server_field'], {'nested': true});
    expect(rawMessage.containsKey('locationMsgId'), isFalse);
    expect(rawMessage['location_msg_id'], 101);
    expect(response.messages.single.rawJson['content'], 'full body');
  });

  test('V2 history preserves wire fields and decodes tick payload', () {
    final response = ChatroomMessageListResponse.fromV2Json({
      'messages': [
        {
          'type': 'tick',
          'stream_type': '',
          'ts': 1786340797000,
          'world_id': 'world_001',
          'location_id': 'loc_2_2_2',
          'session_id': 'session_1',
          'global_message_id': 8702,
          'message_id': 101,
          'location_message_id': 29,
          'conversation_round_id': 7359,
          'sender_type': 'tick',
          'sender_id': 'tick',
          'sender_name': 'SubTick',
          'user_id': 'u_1',
          'client_msg_id': 'client_1',
          'message_type': 'text',
          'min_app_version': 34,
          'created_at': '2026-08-10 11:06:37',
          'payload': {
            'current_time': 'Day 1, 13:50',
            'tick_no': 1,
            'sub_tick_no': 2,
            'global': 'The promise-shaped key pulses.',
            'story_events': [
              {
                'location_id': 'loc_2_2_2',
                'timestamp': 'Day 1, 13:30',
                'visibility': 'public',
                'visible_to': null,
                'text': 'Frost creeps from the vault.',
                'clue': '',
              },
            ],
            'characters_moved': [
              {
                'char_id': 'char_2',
                'old_loc_id': 'loc_2_2_2',
                'to_loc_id': 'loc_1_2_1',
              },
            ],
          },
          'err_no': 0,
          'err_msg': '',
        },
      ],
      'has_more': true,
    });

    final message = response.messages.single;
    expect(response.newestMessageId, 29);
    expect(message.businessType, 'tick');
    expect(message.streamType, '');
    expect(message.ts, 1786340797000);
    expect(message.worldId, 'world_001');
    expect(message.locationId, 'loc_2_2_2');
    expect(message.sessionId, 'session_1');
    expect(message.globalMessageId, 8702);
    expect(message.messageId, 101);
    expect(message.locationMessageId, 29);
    expect(message.conversationRoundId, 7359);
    expect(message.clientMsgId, 'client_1');
    expect(message.minAppVersion, 34);
    expect(message.payload['global'], 'The promise-shaped key pulses.');
    expect(message.rawPayload, same(message.payload));
    expect(message.v2TickPayload?.currentTime, 'Day 1, 13:50');
    expect(message.v2TickPayload?.tickNo, 1);
    expect(message.v2TickPayload?.subTickNo, 2);
    expect(message.isLocationSupplementalMessage, isFalse);
    expect(message.v2TickPayload?.storyEvents.single.visibleTo, isNull);
    expect(
      message.v2TickPayload?.charactersMoved.single.toLocationId,
      'loc_1_2_1',
    );
    expect(message.content, 'The promise-shaped key pulses.');
  });

  test('V2 character history reads tick metadata from top-level fields', () {
    final response = ChatroomMessageListResponse.fromV2Json({
      'messages': [
        {
          'type': 'world_new_message',
          'stream_type': '',
          'world_id': 'world_001',
          'location_id': 'loc_1_1_1',
          'message_id': 101,
          'location_message_id': 2,
          'conversation_round_id': 348861,
          'tick_no': 1,
          'sub_tick_no': 4,
          'sender_type': 'character',
          'sender_id': 'char_1',
          'payload': {'content': 'Top-level tick metadata'},
          'err_no': 0,
          'err_msg': '',
        },
      ],
      'has_more': false,
    });

    final message = response.messages.single;
    expect(message.tickNo, 1);
    expect(message.subTickNo, 4);
    expect(message.content, 'Top-level tick metadata');
  });

  test('invalid V2 tick arrays fall back to payload content', () {
    final response = ChatroomMessageListResponse.fromV2Json({
      'messages': [
        {
          'type': 'tick',
          'location_message_id': 7,
          'sender_type': 'tick',
          'payload': {
            'content': 'legacy tick content',
            'story_events': {'invalid': true},
          },
          'err_no': 0,
          'err_msg': '',
        },
      ],
      'has_more': false,
    });

    final message = response.messages.single;
    expect(message.content, 'legacy tick content');
    expect(message.v2TickPayload?.isFallback, isTrue);
    expect(message.locationMessageId, 7);
  });

  test('legacy history remains available through an explicit method', () async {
    final transport = _FakeTransport();
    final api = ChatroomHttpApi(
      ApiClient(baseUrl: 'http://chat.local/', transport: transport),
    );

    final response = await api.getLegacyMessages(
      worldId: 'w_1',
      locationId: 'loc_1',
      since: 102,
      limit: 20,
    );

    expect(response.messages.single.content, 'hello');
    expect(transport.requests.single.uri.path, '/aitown-chat/api/messages');
    expect(
      transport.requests.single.uri.queryParameters,
      containsPair('since', '102'),
    );
  });

  test(
    'flat response keeps cursorless timelines in compatibility classification',
    () {
      final response = ChatroomMessageListResponse.fromJson({
        'messages': [
          {
            'message_id': 230,
            'location_message_id': 0,
            'location_id': '',
            'sender_type': 'user_enter_location',
            'sender_id': 'sub_tick',
            'content': jsonEncode({
              'char_id': 'char_alice',
              'to_location_id': 'loc_cafe',
              'text': 'Alice came to the cafe',
            }),
          },
          {
            'message_id': 231,
            'location_message_id': 0,
            'location_id': '',
            'sender_type': 'story_events',
            'sender_id': 'sub_tick',
            'tick_no': 4,
            'sub_tick_no': 1,
            'current_time': 'Day 2, 00:09:15',
            'content': jsonEncode({
              'location_id': 'loc_cafe',
              'location_name': 'Cafe',
              'paragraphs': [
                {
                  'timestamp': 'Day 2, 10:15',
                  'visibility': 'public',
                  'visible_to': <String>[],
                  'text': 'The lights flickered.',
                  'clue': '',
                },
              ],
            }),
          },
          {
            'message_id': 232,
            'location_message_id': 0,
            'location_id': '',
            'sender_type': 'characters_moved',
            'sender_id': 'sub_tick',
            'content': jsonEncode([
              {
                'char_id': 'char_alice',
                'old_loc_id': 'loc_cafe',
                'to_loc_id': 'loc_station',
              },
            ]),
          },
        ],
        'has_more': true,
        'newest_message_id': 232,
      });

      expect(response.messages, hasLength(3));
      expect(
        response.messages.map((message) => message.locationMessageId),
        everyElement(0),
      );
      expect(
        response.messages.map(
          (message) => message.isLocationSupplementalMessage,
        ),
        everyElement(isTrue),
      );
      expect(
        response.messages[0].timelinePayload,
        isA<ChatroomUserEnterLocationPayload>(),
      );
      expect(
        response.messages[1].decodeTimelinePayload(),
        isA<ChatroomStoryEventsPayload>(),
      );
      expect(response.messages[1].tickNo, 4);
      expect(response.messages[1].subTickNo, 1);
      expect(response.messages[1].currentTime, 'Day 2, 00:09:15');
      expect(
        response.messages[2].timelinePayload,
        isA<ChatroomCharactersMovedPayload>(),
      );
      expect(
        (response.messages[2].timelinePayload as ChatroomCharactersMovedPayload)
            .movements
            .single
            .toLocationId,
        'loc_station',
      );
      expect(response.hasMore, isTrue);
      expect(response.newestMessageId, 232);
    },
  );

  test(
    'HTTP story_events 60 and 61 decode flat content with location cursors',
    () {
      final response = ChatroomMessageListResponse.fromJson({
        'messages': [
          {
            'global_message_id': 6140,
            'message_id': 60,
            'location_message_id': 31,
            'location_id': 'loc_1_1_1',
            'conversation_round_id': 7003,
            'sender_type': 'story_events',
            'sender_id': 'tick',
            'sender_name': 'SubTick',
            'user_id': null,
            'content': jsonEncode({
              'location_id': 'loc_1_1_1',
              'timestamp': 'Day 2, 00:08:30',
              'visibility': 'char_only',
              'visible_to': ['char_1'],
              'text': '中年男人把录音带塞进桌角的旧录音机。',
              'clue': '问他为什么不敢让你听完。',
            }),
            'message_type': 'text',
            'current_time': 'Day 2, 00:09:15',
            'tick_no': 4,
            'sub_tick_no': 1,
            'created_at': '2026-08-06 20:57:54',
          },
          {
            'global_message_id': 6141,
            'message_id': 61,
            'location_message_id': 32,
            'location_id': 'loc_1_1_1',
            'conversation_round_id': 7003,
            'sender_type': 'story_events',
            'sender_id': 'tick',
            'sender_name': 'SubTick',
            'user_id': null,
            'content': jsonEncode({
              'location_id': 'loc_1_1_1',
              'timestamp': 'Day 2, 00:09:00',
              'visibility': 'char_only',
              'visible_to': ['char_1'],
              'text': '录音机开始播放，第三人的声音从磁带深处浮出来。',
              'clue': '去辨认磁带里的耳语者。',
            }),
            'message_type': 'text',
            'current_time': 'Day 2, 00:09:15',
            'tick_no': 4,
            'sub_tick_no': 1,
            'created_at': '2026-08-06 20:57:54',
          },
        ],
        'has_more': true,
        'newest_message_id': 67,
      });

      expect(response.messages.map((message) => message.messageId), [60, 61]);
      expect(response.messages.map((message) => message.locationMessageId), [
        31,
        32,
      ]);
      for (final message in response.messages) {
        expect(message.timelinePayload, isA<ChatroomStoryEventsPayload>());
        final story = message.timelinePayload as ChatroomStoryEventsPayload;
        expect(story.locationId, 'loc_1_1_1');
        expect(story.locationName, isEmpty);
        expect(story.paragraphs, hasLength(1));
        expect(story.paragraphs.single.visibleTo, ['char_1']);
      }
      expect(
        (response.messages.first.timelinePayload as ChatroomStoryEventsPayload)
            .paragraphs
            .single
            .timestamp,
        'Day 2, 00:08:30',
      );
      expect(
        (response.messages.last.timelinePayload as ChatroomStoryEventsPayload)
            .paragraphs
            .single
            .timestamp,
        'Day 2, 00:09:00',
      );
    },
  );

  test('ChatroomHttpApi maps all Apifox chatroom HTTP endpoints', () async {
    final transport = _FakeTransport();
    final api = ChatroomHttpApi(
      ApiClient(baseUrl: 'http://chat.local/', transport: transport),
    );

    final userLocations = await api.getUserLocations(worldId: 'w_1');
    expect(userLocations.worldId, 'w_1');
    final user = userLocations.locations.single.users.single;
    expect(user.userId, 'u_1');
    expect(user.userName, '勇者小明');
    expect(user.avatar, 'https://cdn.example.com/u_1.png');

    final worldMessages = await api.getWorldMessages(worldId: 'w_1');
    expect(worldMessages.locations.single.locationId, 'loc_1');
    final worldMessage = worldMessages.locations.single.messages.single;
    expect(worldMessage.content, 'hello');
    expect(worldMessage.globalMessageId, 90001);
    expect(worldMessage.messageId, 1001);
    expect(worldMessage.locationMessageId, 101);
    expect(worldMessage.currentTime, 'Day 1, 08:00');
    expect(worldMessage.tickNo, 3);

    final history = await api.getMessages(
      worldId: 'w_1',
      locationId: 'loc_1',
      since: 0,
      limit: 20,
    );
    expect(history.newestMessageId, 101);
    final historyMessage = history.messages.single;
    expect(historyMessage.senderType, 'user');
    expect(historyMessage.globalMessageId, 90001);
    expect(historyMessage.messageId, 1001);
    expect(historyMessage.locationMessageId, 101);
    expect(historyMessage.businessType, 'user');
    expect(historyMessage.payload['content'], 'hello');
    expect(historyMessage.clientMsgId, 'client_1');
    expect(historyMessage.minAppVersion, 34);
    expect(historyMessage.messageType, 'image');
    expect(historyMessage.createdAt, DateTime(2026, 7, 1, 10));

    expect(await api.lockWorld(worldId: 'w_1'), true);
    final lockStatus = await api.tickLockStatus(worldId: 'w_1');
    expect(lockStatus.isLocked, true);
    final progress = await api.tickProgress(worldId: 'w_1');
    expect(progress.progress, 1);
    expect(await api.unlockWorld(worldId: 'w_1'), true);
    final narratorMessageId = await api.writeNarrator(
      worldId: 'w_1',
      tickId: 'tick_1',
      locationGroups: const [
        ChatroomNarratorLocationGroup(
          locationId: 'loc_1',
          locationName: 'Hall',
          locationSummary: 'Quiet hall',
          characters: [ChatroomNarratorCharacter(charId: 'char_1', name: 'A')],
          initialDialogue: [
            ChatroomNarratorDialogueLine(
              charId: 'char_1',
              charName: 'A',
              content: 'Narration',
            ),
          ],
        ),
      ],
    );
    expect(narratorMessageId, 1002);

    expect(transport.requests.map((request) => request.uri.path).toList(), [
      '/aitown-chat/api/ulocation',
      '/aitown-chat/internal/world/messages',
      '/aitown-chat/api/v2/messages',
      '/aitown-chat/internal/tick/lock',
      '/aitown-chat/internal/tick/is_locked',
      '/aitown-chat/internal/tick/progress',
      '/aitown-chat/internal/tick/unlock',
      '/aitown-chat/internal/narrator/write',
    ]);
    expect(
      transport.requests[0].uri.queryParameters,
      containsPair('world_id', 'w_1'),
    );
    expect(
      transport.requests[2].uri.queryParameters,
      containsPair('world_id', 'w_1'),
    );
    expect(
      transport.requests[2].uri.queryParameters,
      containsPair('location_id', 'loc_1'),
    );
    expect(
      transport.requests[2].uri.queryParameters,
      containsPair('since', '0'),
    );
    expect(
      utf8.decode(transport.requests[3].bodyBytes!),
      contains('name="world_id"'),
    );
    expect(
      transport.requests[4].uri.queryParameters,
      containsPair('world_id', 'w_1'),
    );
  });
}
