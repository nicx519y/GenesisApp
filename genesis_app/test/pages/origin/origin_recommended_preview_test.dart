import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_role_draft.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';

void main() {
  OriginDetail origin({bool recommended = true}) => OriginDetail.fromJson({
    'info': {'origin_id': 'o_1', 'origin_name': 'Origin'},
    'characters': [
      {
        'char_id': 'char_1',
        'is_recommend': recommended ? 1 : 0,
        'name': 'Same name',
        'avatar': '',
      },
      {'char_id': 'char_2', 'name': 'Same name', 'avatar': ''},
    ],
    'locations': [
      {'location_id': 'loc_1', 'location_name': 'Square'},
    ],
    'init_location_group': {
      'location_id': 'loc_1',
      'initial_dialogue': [
        {'char_id': 'nar', 'content': 'Narration'},
        {'char_id': 'char_1', 'char_name': 'Same name', 'content': 'First'},
        {'char_id': 'char_2', 'char_name': 'Same name', 'content': 'Other'},
        {'char_id': 'char_1', 'char_name': 'Same name', 'content': 'Second'},
      ],
    },
  });

  test('all recommended lines use the edited role and self bubbles by ID', () {
    final messages = originInitialDialoguePreviewForTesting(
      origin(),
      recommendedRole: const OriginCustomRoleDraft(
        name: 'Renamed player',
        avatarUrl: 'https://example.com/player.png',
      ),
    );
    final playerLines = messages.where((line) => line.senderId == 'char_1');
    expect(playerLines, hasLength(2));
    for (final line in playerLines) {
      expect(line.isMe, isTrue);
      expect(line.isPlayerControlledRole, isTrue);
      expect(line.senderName, 'Renamed player');
      expect(line.avatarUrl, 'https://example.com/player.png');
    }
    expect(
      messages
          .where((line) => line.senderId != 'char_1')
          .every((line) => !line.isMe),
      isTrue,
    );
  });

  test('no recommendation keeps all opening lines on their original side', () {
    final messages = originInitialDialoguePreviewForTesting(
      origin(recommended: false),
    );
    expect(messages, isNotEmpty);
    expect(messages.every((line) => !line.isMe), isTrue);
  });
}
