import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/world/world_map_bubble_candidates.dart';

void main() {
  test(
    'selects AI character messages from latest current-tick conversation',
    () {
      final candidates = worldMapBubbleCandidatesFor(
        currentTickNo: 7,
        characterPositions: const [
          {
            'location_id': 'loc_a',
            'character': {
              'char_id': 'char_a',
              'name': 'Ava',
              'type': 1,
              'player_uid': '',
            },
          },
          {
            'location_id': 'loc_b',
            'character': {
              'char_id': 'char_b',
              'name': 'Ben',
              'type': 'ai',
              'player_uid': '',
            },
          },
        ],
        messagesByLocation: {
          'loc_a': [
            _message(
              id: 1,
              tickNo: 7,
              round: '10',
              order: 1,
              locationId: 'loc_a',
              senderId: 'char_a',
              content: 'old round',
            ),
            _message(
              id: 2,
              tickNo: 7,
              round: '11',
              order: 1,
              locationId: 'loc_a',
              senderId: 'char_a',
              content: 'latest one',
              createdAt: DateTime(2026, 6, 27, 10),
            ),
            _message(
              id: 3,
              tickNo: 7,
              round: '11',
              order: 2,
              locationId: 'loc_a',
              senderId: 'char_b',
              content: 'same conversation',
              createdAt: DateTime(2026, 6, 27, 10, 1),
            ),
            _message(
              id: 4,
              tickNo: 6,
              round: '12',
              order: 1,
              locationId: 'loc_a',
              senderId: 'char_a',
              content: 'wrong tick',
            ),
          ],
          'loc_b': [
            _message(
              id: 5,
              tickNo: 7,
              round: '20',
              order: 1,
              locationId: 'loc_b',
              senderId: 'char_b',
              content: 'from loc b',
              createdAt: DateTime(2026, 6, 27, 9),
            ),
          ],
        },
      );

      expect(candidates.map((candidate) => candidate.content), [
        'from loc b',
        'latest one',
        'same conversation',
      ]);
      expect(candidates.map((candidate) => candidate.characterId), [
        'char_b',
        'char_a',
        'char_b',
      ]);
      expect(candidates.map((candidate) => candidate.characterLocationId), [
        'loc_b',
        'loc_a',
        'loc_b',
      ]);
    },
  );

  test('ignores streaming, narrator, users, and player-controlled roles', () {
    final candidates = worldMapBubbleCandidatesFor(
      currentTickNo: 3,
      characterPositions: const [
        {
          'location_id': 'loc_a',
          'character': {
            'char_id': 'ai_char',
            'name': 'AI',
            'type': 'ai',
            'player_uid': '',
          },
        },
        {
          'location_id': 'loc_a',
          'character': {
            'char_id': 'player_char',
            'name': 'Player',
            'type': 'ai',
            'player_uid': 'u_1',
          },
        },
      ],
      messagesByLocation: {
        'loc_a': [
          _message(
            id: 1,
            tickNo: 3,
            round: '1',
            order: 1,
            locationId: 'loc_a',
            senderId: 'nar',
            senderType: 'narrator',
            content: 'narrator',
          ),
          _message(
            id: 2,
            tickNo: 3,
            round: '1',
            order: 2,
            locationId: 'loc_a',
            senderId: 'u_1',
            senderType: 'user',
            content: 'user',
          ),
          _message(
            id: 3,
            tickNo: 3,
            round: '1',
            order: 3,
            locationId: 'loc_a',
            senderId: 'player_char',
            content: 'player controlled',
          ),
          _message(
            id: 4,
            tickNo: 3,
            round: '1',
            order: 4,
            locationId: 'loc_a',
            senderId: 'ai_char',
            content: 'streaming',
            streaming: true,
          ),
          _message(
            id: 5,
            tickNo: 3,
            round: '1',
            order: 5,
            locationId: 'loc_a',
            senderId: 'ai_char',
            content: 'visible',
          ),
        ],
      },
    );

    expect(candidates.map((candidate) => candidate.content), ['visible']);
  });
}

WorldChatroomMessage _message({
  required int id,
  required int tickNo,
  required String round,
  required int order,
  required String locationId,
  required String senderId,
  required String content,
  String senderType = 'character',
  DateTime? createdAt,
  bool streaming = false,
}) {
  return WorldChatroomMessage(
    messageId: id,
    conversationRoundId: round,
    roundOrder: order,
    tickNo: tickNo,
    locationId: locationId,
    senderType: senderType,
    senderId: senderId,
    senderName: senderId,
    content: content,
    createdAt: createdAt ?? DateTime(2026, 6, 27, 8, id),
    streaming: streaming,
  );
}
