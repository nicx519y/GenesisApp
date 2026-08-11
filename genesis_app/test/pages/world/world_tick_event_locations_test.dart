import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_tick_event_locations.dart';

void main() {
  test('extracts and deduplicates locations from the current Tick', () {
    final tick = _tickMessage(
      messageId: 10,
      tickNo: 2,
      subTickNo: 3,
      eventLocationIds: const ['loc_a', 'loc_b', 'loc_a', ''],
    );

    expect(
      worldCurrentTickEventLocationIds(
        messagesByLocation: {
          'loc_a': [tick],
          'loc_b': [tick.copyWith(locationId: 'loc_b')],
        },
        tickNo: 2,
        subTickNo: 3,
      ),
      const {'loc_a', 'loc_b'},
    );
  });

  test('supports matching Tick 0-n', () {
    expect(
      worldCurrentTickEventLocationIds(
        messagesByLocation: {
          'loc_a': [
            _tickMessage(
              messageId: 11,
              tickNo: 0,
              subTickNo: 4,
              eventLocationIds: const ['loc_zero'],
            ),
          ],
        },
        tickNo: 0,
        subTickNo: 4,
      ),
      const {'loc_zero'},
    );
  });

  test('distinguishes a missing Tick from a Tick without Events', () {
    final messages = {
      'loc_a': [
        _tickMessage(
          messageId: 12,
          tickNo: 3,
          subTickNo: 0,
          eventLocationIds: const [],
        ),
      ],
    };

    expect(
      worldCurrentTickEventLocationIds(
        messagesByLocation: messages,
        tickNo: 2,
        subTickNo: 0,
      ),
      isNull,
    );
    expect(
      worldCurrentTickEventLocationIds(
        messagesByLocation: messages,
        tickNo: 3,
        subTickNo: 0,
      ),
      isEmpty,
    );
  });
}

WorldChatroomMessage _tickMessage({
  required int messageId,
  required int tickNo,
  required int subTickNo,
  required List<String> eventLocationIds,
}) {
  return WorldChatroomMessage(
    globalMessageId: 90000 + messageId,
    messageId: messageId,
    locationMessageId: messageId,
    conversationRoundId: '$messageId',
    roundOrder: 0,
    tickNo: tickNo,
    subTickNo: subTickNo,
    locationId: 'loc_a',
    senderType: 'tick',
    businessType: 'tick',
    senderId: 'tick',
    senderName: 'Time',
    content: '',
    createdAt: DateTime.utc(2026, 8, 11),
    v2TickPayload: ChatroomV2TickPayload(
      currentTime: 'Day 1, 08:00',
      tickNo: tickNo,
      subTickNo: subTickNo,
      globalText: '',
      storyEvents: [
        for (final locationId in eventLocationIds)
          ChatroomV2StoryEvent(
            locationId: locationId,
            timestamp: 'Day 1, 08:00',
            visibility: 'public',
            visibleTo: null,
            text: 'Event',
            clue: '',
          ),
      ],
      charactersMoved: const [],
      fallbackContent: '',
    ),
  );
}
