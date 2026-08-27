import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_location_avatars.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  testWidgets(
    'World AI avatar is plain and player role uses the chat red frame',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: TilemapLocationAvatars(
              avatars: [
                UserAvatar('AI', id: 'ai', name: 'AI Role'),
                UserAvatar(
                  'PR',
                  id: 'player',
                  name: 'Player Role',
                  isPlayerControlledRole: true,
                ),
              ],
            ),
          ),
        ),
      );

      GenesisCharacterAvatar avatarFor(String id) {
        return tester.widget<GenesisCharacterAvatar>(
          find.descendant(
            of: find.byKey(ValueKey<String>('tilemap-location-avatar-$id')),
            matching: find.byType(GenesisCharacterAvatar),
          ),
        );
      }

      final aiAvatar = avatarFor('ai');
      final playerAvatar = avatarFor('player');
      expect(aiAvatar.showStar, isFalse);
      expect(aiAvatar.border, isNull);
      expect(playerAvatar.showStar, isFalse);
      final playerBorder = playerAvatar.border! as Border;
      expect(playerBorder.top.color, const Color(0xFFFF2442));
      expect(playerBorder.top.width, 2);
    },
  );
}
