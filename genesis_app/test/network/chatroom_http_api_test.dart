import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
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
            'current_time': 'Day 1, 08:00',
            'tick_no': 3,
            'created_at': '2026-07-01 10:00:00',
          },
        ],
        'has_more': false,
        'newest_message_id': 1001,
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
    expect(history.newestMessageId, 1001);
    final historyMessage = history.messages.single;
    expect(historyMessage.senderType, 'user');
    expect(historyMessage.globalMessageId, 90001);
    expect(historyMessage.messageId, 1001);
    expect(historyMessage.locationMessageId, 101);
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
      '/aitown-chat/api/messages',
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
      utf8.decode(transport.requests[3].bodyBytes!),
      contains('name="world_id"'),
    );
    expect(
      transport.requests[4].uri.queryParameters,
      containsPair('world_id', 'w_1'),
    );
  });
}
