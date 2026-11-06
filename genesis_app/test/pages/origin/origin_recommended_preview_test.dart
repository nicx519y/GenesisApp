import 'package:flutter_test/flutter_test.dart';
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
        'avatar': 'https://example.com/character.png',
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

  test('a recommended character keeps its own identity in the preview', () {
    final messages = originInitialDialoguePreviewForTesting(origin());
    final recommendedLines = messages.where(
      (line) => line.senderId == 'char_1',
    );
    expect(recommendedLines, hasLength(2));
    for (final line in recommendedLines) {
      expect(line.isMe, isFalse);
      expect(line.isPlayerControlledRole, isFalse);
      expect(line.senderName, 'Same name');
      expect(line.avatarUrl, 'https://example.com/character.png');
    }
  });

  test('no recommendation keeps all opening lines on their original side', () {
    final messages = originInitialDialoguePreviewForTesting(
      origin(recommended: false),
    );
    expect(messages, isNotEmpty);
    expect(messages.every((line) => !line.isMe), isTrue);
  });
}
