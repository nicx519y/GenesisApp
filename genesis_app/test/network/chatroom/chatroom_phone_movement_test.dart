import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';

Map<String, dynamic> frame() => {
  'type': 'phone_characters_moved',
  'world_id': 'world_1',
  'location_id': 'loc_b',
  'global_message_id': 1001,
  'message_id': 1001,
  'location_message_id': 25,
  'conversation_round_id': 801,
  'conversation_type': 'phone_characters_moved',
  'sender_type': 'phone_characters_moved',
  'payload': {
    'content': [
      {'char_id': 'char_1', 'old_loc_id': 'loc_a', 'to_loc_id': 'loc_b'},
    ],
  },
};

void main() {
  test('canonical phone movement accepts message IDs without a timestamp', () {
    final event = chatroomEventFromV2Message(
      ChatroomV2Message.fromJson(frame()),
    );
    expect(event, isA<ChatroomMessageEvent>());
    final message = event as ChatroomMessageEvent;
    expect(message.locationMessageId, 25);
    expect(message.messageId, 1001);
    expect(message.conversationRoundId, '801');
    expect(chatroomEventType(message), 'phone_characters_moved');
  });

  test(
    'canonical phone movement rejects old envelope and malformed IDs or content',
    () {
      for (final update in <Map<String, dynamic>>[
        {'location_message_id': null},
        {'message_id': 0},
        {'global_message_id': -1},
        {'conversation_round_id': 801.5},
        {'conversation_round_id': 0},
        {'conversation_round_id': -1},
        {'conversation_round_id': '801'},
        {'location_message_id': '25'},
        {'location_id': ''},
        {'world_id': ''},
        {'sender_type': 'character'},
        {'conversation_type': ''},
        {'stream_type': 'llm_chunk'},
        {'err_no': 1},
        {
          'payload': {'content': 'invalid'},
        },
        {
          'payload': {
            'content': [
              {'char_id': 'c', 'to_loc_id': 'b'},
            ],
          },
        },
      ]) {
        expect(
          () => chatroomEventFromV2Message(
            ChatroomV2Message.fromJson({...frame(), ...update}),
          ),
          throwsA(
            anyOf(isA<FormatException>(), isA<ChatroomProtocolException>()),
          ),
          reason: '$update',
        );
      }
      expect(
        () => chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({
            'type': 'phone_characters_moved',
            'world_id': 'world_1',
            'ts': 1792576800000,
            'payload': frame()['payload'],
          }),
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'canonical phone movement HTTP matches WSS and retains typed payload',
    () {
      final socket = WorldChatroomMessage.fromPhoneCharactersMovedMessage(
        chatroomEventFromV2Message(ChatroomV2Message.fromJson(frame()))
            as ChatroomPhoneCharactersMoved,
      );
      final http = WorldChatroomMessage.fromHttpMessage(
        ChatroomHttpMessage.fromV2Json(frame()),
      );
      for (final message in [socket, http]) {
        expect(message.senderType, 'phone_characters_moved');
        expect(message.businessType, 'phone_characters_moved');
        expect(message.locationMessageId, 25);
        expect(message.conversationRoundId, '801');
        expect(message.conversationType, 'phone_characters_moved');
        expect(message.rawPayload, frame()['payload']);
        final payload =
            message.timelinePayload as ChatroomPhoneCharactersMovedPayload;
        expect(payload.movements.single.oldLocationId, 'loc_a');
        expect(payload.movements.single.toLocationId, 'loc_b');
      }
      expect(socket.content, http.content);
      final page = ChatroomMessageListResponse.fromV2Json({
        'messages': [frame()],
        'has_more': false,
      });
      expect(page.newestMessageId, 25);
    },
  );

  for (final explicitNull in [false, true]) {
    test(
      'roundless phone movement survives WSS and HTTP null=$explicitNull',
      () {
        final json = frame()..remove('conversation_round_id');
        if (explicitNull) json['conversation_round_id'] = null;
        final dto = ChatroomV2Message.fromJson(json);
        expect(dto.conversationRoundId, isNull);
        expect(dto.toJson().containsKey('conversation_round_id'), isFalse);
        final event =
            chatroomEventFromV2Message(dto) as ChatroomPhoneCharactersMoved;
        expect(event.conversationRoundId, isEmpty);
        final socket = WorldChatroomMessage.fromPhoneCharactersMovedMessage(
          event,
        );
        final http = WorldChatroomMessage.fromHttpMessage(
          ChatroomHttpMessage.fromV2Json(json),
        );
        for (final message in [socket, http]) {
          expect(message.conversationRoundNumber, 0);
          expect(message.locationMessageId, 25);
          expect(message.rawPayload, json['payload']);
          final payload =
              message.timelinePayload as ChatroomPhoneCharactersMovedPayload;
          expect(payload.movements.single.toLocationId, 'loc_b');
        }
        expect(socket.content, http.content);
        expect(
          ChatroomMessageListResponse.fromV2Json({
            'messages': [json],
            'has_more': false,
          }).newestMessageId,
          25,
        );
      },
    );
  }

  test('llm message updates still require a conversation round', () {
    final json = frame()
      ..['type'] = 'llm_message_updated'
      ..remove('conversation_round_id');
    expect(
      () => ChatroomV2Message.fromJson(json),
      throwsA(isA<ChatroomProtocolException>()),
    );
  });
}
