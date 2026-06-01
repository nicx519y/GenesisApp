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
    if (path == '/aitown-chat/internal/world/messages') {
      return _ok({
        'locations': [
          {
            'location_id': 'loc_1',
            'messages': [
              {
                'message_id': 1001,
                'location_id': 'loc_1',
                'conversation_round_id': 100,
                'round_order': 1,
                'sender_type': 'user',
                'sender_id': 'char_1',
                'sender_name': 'A',
                'user_id': 'u_1',
                'content': 'hello',
                'created_at': '2026-05-29 10:00:00',
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
            'message_id': 1001,
            'conversation_round_id': 100,
            'round_order': 1,
            'sender_type': 'user',
            'sender_id': 'char_1',
            'sender_name': 'A',
            'user_id': 'u_1',
            'content': 'hello',
            'created_at': '2026-05-29 10:00:00',
          },
        ],
        'has_more': false,
        'newest_message_id': 1001,
      });
    }
    if (path == '/aitown-chat/internal/tick/lock') {
      return _camelOk({'locked': true});
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
  test('ChatroomHttpApi maps all Apifox chatroom HTTP endpoints', () async {
    final transport = _FakeTransport();
    final api = ChatroomHttpApi(
      ApiClient(baseUrl: 'http://chat.local/', transport: transport),
    );

    final worldMessages = await api.getWorldMessages(worldId: 'w_1');
    expect(worldMessages.locations.single.locationId, 'loc_1');
    expect(worldMessages.locations.single.messages.single.content, 'hello');

    final history = await api.getMessages(
      worldInstanceId: 'w_1',
      locationId: 'loc_1',
      since: 0,
      limit: 20,
    );
    expect(history.newestMessageId, 1001);
    expect(history.messages.single.senderType, 'user');

    expect(await api.lockWorld(worldId: 'w_1'), true);
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
      '/aitown-chat/internal/world/messages',
      '/aitown-chat/api/messages',
      '/aitown-chat/internal/tick/lock',
      '/aitown-chat/internal/tick/progress',
      '/aitown-chat/internal/tick/unlock',
      '/aitown-chat/internal/narrator/write',
    ]);
    expect(
      transport.requests[0].uri.queryParameters,
      containsPair('world_id', 'w_1'),
    );
    expect(
      utf8.decode(transport.requests[2].bodyBytes!),
      contains('name="world_id"'),
    );
  });
}
