import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_recent_chat_location.dart';

void main() {
  test('selects the location whose chat message has the latest timestamp', () {
    final result = latestChatLocationIdFromMessages(
      allLocationsLoaded: true,
      messagesByLocation: {
        'location_a': [
          _message(
            locationId: 'location_a',
            messageId: 10,
            createdAt: DateTime.utc(2026, 7, 17, 9),
          ),
        ],
        'location_b': [
          _message(
            locationId: 'location_b',
            messageId: 20,
            createdAt: DateTime.utc(2026, 7, 17, 10),
          ),
        ],
      },
      allowedLocationIds: const ['location_a', 'location_b'],
    );

    expect(result, 'location_b');
  });

  test('ignores newer tick messages when selecting recent chat location', () {
    final result = latestChatLocationIdFromMessages(
      allLocationsLoaded: true,
      messagesByLocation: {
        'location_a': [
          _message(
            locationId: 'location_a',
            messageId: 10,
            createdAt: DateTime.utc(2026, 7, 17, 9),
          ),
        ],
        'location_b': [
          _message(
            locationId: 'location_b',
            messageId: 20,
            senderType: 'tick',
            createdAt: DateTime.utc(2026, 7, 17, 11),
          ),
        ],
      },
      allowedLocationIds: const ['location_a', 'location_b'],
    );

    expect(result, 'location_a');
  });

  test('only compares messages belonging to current world leaf locations', () {
    final result = latestChatLocationIdFromMessages(
      allLocationsLoaded: true,
      messagesByLocation: {
        'current_world_location': [
          _message(
            locationId: 'current_world_location',
            messageId: 10,
            createdAt: DateTime.utc(2026, 7, 17, 9),
          ),
        ],
        'other_world_location': [
          _message(
            locationId: 'other_world_location',
            messageId: 20,
            createdAt: DateTime.utc(2026, 7, 17, 12),
          ),
        ],
      },
      allowedLocationIds: const ['current_world_location'],
    );

    expect(result, 'current_world_location');
  });

  test('uses global message id to break equal timestamp ties', () {
    final timestamp = DateTime.utc(2026, 7, 17, 9);
    final result = latestChatLocationIdFromMessages(
      allLocationsLoaded: true,
      messagesByLocation: {
        'location_a': [
          _message(
            locationId: 'location_a',
            messageId: 10,
            globalMessageId: 100,
            createdAt: timestamp,
          ),
        ],
        'location_b': [
          _message(
            locationId: 'location_b',
            messageId: 20,
            globalMessageId: 101,
            createdAt: timestamp,
          ),
        ],
      },
      allowedLocationIds: const ['location_a', 'location_b'],
    );

    expect(result, 'location_b');
  });

  test('does not select a temporary location before all queues load', () {
    final result = latestChatLocationIdFromMessages(
      allLocationsLoaded: false,
      messagesByLocation: {
        'location_a': [
          _message(
            locationId: 'location_a',
            messageId: 10,
            createdAt: DateTime.utc(2026, 7, 17, 9),
          ),
        ],
      },
      allowedLocationIds: const ['location_a', 'location_b'],
    );

    expect(result, isEmpty);
  });
}

WorldChatroomMessage _message({
  required String locationId,
  required int messageId,
  required DateTime createdAt,
  int globalMessageId = 0,
  String senderType = 'user',
}) {
  return WorldChatroomMessage(
    globalMessageId: globalMessageId,
    messageId: messageId,
    locationMessageId: messageId,
    conversationRoundId: '$messageId',
    roundOrder: 0,
    locationId: locationId,
    senderType: senderType,
    senderId: 'sender',
    senderName: 'Sender',
    content: 'Message $messageId',
    createdAt: createdAt,
  );
}
