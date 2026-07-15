import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';

void main() {
  test('worldLatestPlayerJoinNotice picks newest joined player role', () {
    final notice = worldLatestPlayerJoinNotice(const [
      {
        'char_id': 'char_ai',
        'type': 'ai',
        'name': 'NPC',
        'player_uid': '',
        'player_username': '',
        'player_joined_at': 999999,
      },
      {
        'char_id': 'char_old',
        'type': 'custom',
        'name': 'Old Role',
        'player_uid': 'user_old',
        'player_username': 'Old Player',
        'player_joined_at': 100,
      },
      {
        'char_id': 'char_new',
        'type': 'custom',
        'name': 'New Role',
        'player_uid': 'user_new',
        'player_username': 'New Player',
        'player_joined_at': '200',
      },
    ]);

    expect(notice?.characterId, 'char_new');
    expect(notice?.playerUid, 'user_new');
    expect(notice?.displayPlayerUsername, 'New Player');
    expect(notice?.displayCharacterName, 'New Role');
  });
}
