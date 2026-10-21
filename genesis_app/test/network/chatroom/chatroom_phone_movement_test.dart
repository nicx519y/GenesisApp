import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';

Map<String, dynamic> frame() => {
  'type': 'phone_characters_moved',
  'stream_type': '',
  'ts': 1792576800000,
  'world_id': 'world_1',
  'trigger_uid': '',
  'payload': {
    'content': [
      {'char_id': 'char_1', 'old_loc_id': 'loc_a', 'to_loc_id': 'loc_b'},
    ],
  },
  'err_no': 0,
  'err_msg': '',
};

void main() {
  test(
    'phone movement accepts the new envelope without event or message IDs',
    () {
      final event = chatroomEventFromV2Message(
        ChatroomV2Message.fromJson(frame()),
      );
      expect(chatroomEventType(event), 'phone_characters_moved');
      final moved = event as ChatroomPhoneCharactersMoved;
      expect(moved.triggerUid, isEmpty);
      expect(moved.movements.single.oldLocationId, 'loc_a');
      expect(moved.movements.single.toLocationId, 'loc_b');
      expect(moved.ts, 1792576800000);
    },
  );
  test('phone movement rejects malformed, failed and streamed events', () {
    for (final update in <Map<String, dynamic>>[
      {'stream_type': 'llm_chunk'},
      {'world_id': ''},
      {'ts': 0},
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
      {
        'payload': {
          'content': [
            {'char_id': 7, 'old_loc_id': 'a', 'to_loc_id': 'b'},
          ],
        },
      },
    ]) {
      expect(
        () => chatroomEventFromV2Message(
          ChatroomV2Message.fromJson({...frame(), ...update}),
        ),
        throwsA(anything),
        reason: '$update',
      );
    }
  });
  test('empty batches are valid and replay keys preserve timestamp', () {
    ChatroomPhoneCharactersMoved parse(Map<String, dynamic> json) =>
        chatroomEventFromV2Message(ChatroomV2Message.fromJson(json))
            as ChatroomPhoneCharactersMoved;
    expect(
      parse({
        ...frame(),
        'payload': {'content': []},
      }).movements,
      isEmpty,
    );
    expect(parse(frame()).deduplicationKey, parse(frame()).deduplicationKey);
    expect(
      parse(frame()).deduplicationKey,
      isNot(parse({...frame(), 'ts': 1792576800001}).deduplicationKey),
    );
  });
}
