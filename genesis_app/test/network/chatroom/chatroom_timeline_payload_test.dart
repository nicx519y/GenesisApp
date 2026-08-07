import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_timeline_payload.dart';

void main() {
  test('recognizes timeline payload and supplemental sender types', () {
    expect(isChatroomTimelinePayloadSenderType(' STORY_EVENTS '), isTrue);
    expect(isChatroomTimelinePayloadSenderType('tick'), isFalse);
    expect(isChatroomLocationSupplementalSenderType('tick'), isTrue);
    expect(
      isChatroomLocationSupplementalSenderType('characters_moved'),
      isTrue,
    );
    expect(isChatroomLocationSupplementalSenderType('user'), isFalse);
  });

  test('decodes user_enter_location content from a JSON string', () {
    final payload = decodeChatroomTimelinePayload(
      senderType: chatroomUserEnterLocationSenderType,
      rawPayload: jsonEncode({
        'char_id': 'char_alice',
        'to_location_id': 'loc_cafe',
        'text': 'Alice came to the cafe',
      }),
    );

    expect(payload, isA<ChatroomUserEnterLocationPayload>());
    final enter = payload as ChatroomUserEnterLocationPayload;
    expect(enter.charId, 'char_alice');
    expect(enter.toLocationId, 'loc_cafe');
    expect(enter.text, 'Alice came to the cafe');
  });

  test('decodes story_events paragraph visibility contract', () {
    final payload = decodeChatroomTimelinePayload(
      senderType: chatroomStoryEventsSenderType,
      rawPayload: {
        'location_id': 'loc_station',
        'location_name': 'Old station',
        'paragraphs': [
          {
            'timestamp': 'Day 2, 10:15',
            'visibility': 'char_only',
            'visible_to': ['char_alice'],
            'text': 'Alice found a torn ticket.',
            'clue': 'The date is three years old.',
          },
          {
            'timestamp': 'Day 2, 10:16',
            'visibility': 'public',
            'text': 'A train whistle sounded.',
            'clue': '',
          },
        ],
      },
    );

    expect(payload, isA<ChatroomStoryEventsPayload>());
    final story = payload as ChatroomStoryEventsPayload;
    expect(story.locationId, 'loc_station');
    expect(story.paragraphs, hasLength(2));
    expect(story.paragraphs.first.visibleTo, ['char_alice']);
    expect(story.paragraphs.last.visibleTo, isEmpty);
  });

  test('normalizes a flat story_events content object to one paragraph', () {
    final payload = decodeChatroomTimelinePayload(
      senderType: chatroomStoryEventsSenderType,
      rawPayload: jsonEncode({
        'location_id': 'loc_1_1_1',
        'timestamp': 'Day 2, 00:09:00',
        'visibility': 'char_only',
        'visible_to': ['char_1'],
        'text': '录音机开始播放，第三人的声音从磁带深处浮出来。',
        'clue': '去辨认磁带里的耳语者。',
      }),
    );

    expect(payload, isA<ChatroomStoryEventsPayload>());
    final story = payload as ChatroomStoryEventsPayload;
    expect(story.locationId, 'loc_1_1_1');
    expect(story.locationName, isEmpty);
    expect(story.paragraphs, hasLength(1));
    expect(story.paragraphs.single.timestamp, 'Day 2, 00:09:00');
    expect(story.paragraphs.single.visibility, 'char_only');
    expect(story.paragraphs.single.visibleTo, ['char_1']);
    expect(story.paragraphs.single.text, '录音机开始播放，第三人的声音从磁带深处浮出来。');
    expect(story.paragraphs.single.clue, '去辨认磁带里的耳语者。');
  });

  test('does not treat an explicit null paragraphs field as flat payload', () {
    expect(
      () => decodeChatroomTimelinePayload(
        senderType: chatroomStoryEventsSenderType,
        rawPayload: const {
          'location_id': 'loc_station',
          'paragraphs': null,
          'timestamp': 'Day 2, 10:15',
          'visibility': 'public',
          'text': 'This is not the flat wire shape.',
          'clue': '',
        },
      ),
      throwsFormatException,
    );
  });

  test('decodes and encodes characters_moved wire field names', () {
    final payload = decodeChatroomTimelinePayload(
      senderType: chatroomCharactersMovedSenderType,
      rawPayload: {
        'movements': [
          {'char_id': 'char_alice', 'to_loc_id': 'loc_cafe'},
        ],
      },
    );

    expect(payload, isA<ChatroomCharactersMovedPayload>());
    final moved = payload as ChatroomCharactersMovedPayload;
    expect(moved.movements.single.charId, 'char_alice');
    expect(moved.movements.single.toLocationId, 'loc_cafe');
    expect(jsonDecode(encodeChatroomTimelinePayload(moved)), {
      'movements': [
        {'char_id': 'char_alice', 'to_loc_id': 'loc_cafe'},
      ],
    });
  });

  test('decodes characters_moved top-level movement array from HTTP', () {
    final payload = decodeChatroomTimelinePayload(
      senderType: chatroomCharactersMovedSenderType,
      rawPayload: jsonEncode([
        {
          'char_id': 'char_1',
          'old_loc_id': 'loc_1_1_1',
          'to_loc_id': 'loc_2_1_1',
        },
      ]),
    );

    expect(payload, isA<ChatroomCharactersMovedPayload>());
    final moved = payload as ChatroomCharactersMovedPayload;
    expect(moved.movements.single.charId, 'char_1');
    expect(moved.movements.single.toLocationId, 'loc_2_1_1');
    expect(jsonDecode(encodeChatroomTimelinePayload(moved)), {
      'movements': [
        {'char_id': 'char_1', 'to_loc_id': 'loc_2_1_1'},
      ],
    });
  });

  test(
    'strict decode rejects malformed payload and tolerant decode hides it',
    () {
      const malformed = {
        'location_id': 'loc_station',
        'location_name': 'Old station',
        'paragraphs': [
          {
            'timestamp': 'Day 2, 10:15',
            'visibility': 'char_only',
            'visible_to': <String>[],
            'text': 'Hidden event',
            'clue': '',
          },
        ],
      };

      expect(
        () => decodeChatroomTimelinePayload(
          senderType: chatroomStoryEventsSenderType,
          rawPayload: malformed,
        ),
        throwsFormatException,
      );
      expect(
        tryDecodeChatroomTimelinePayload(
          senderType: chatroomStoryEventsSenderType,
          rawPayload: malformed,
        ),
        isNull,
      );
      expect(
        tryDecodeChatroomTimelinePayload(
          senderType: 'future_timeline_type',
          rawPayload: const <String, Object?>{},
        ),
        isNull,
      );
    },
  );
}
