import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';

void main() {
  testWidgets('World Detail and Status use role ownership avatar styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WorldCharacterRow(
                character: {'name': 'AI Guide', 'player_uid': '', 'avatar': ''},
                currentUid: 'user-self',
                subtitle: 'AI status',
                subtitleColor: Color(0xFF666666),
                showCharacterDetails: false,
              ),
              WorldCharacterRow(
                character: {
                  'name': 'My Role',
                  'player_uid': 'user-self',
                  'player_username': 'Owner',
                  'avatar': '',
                },
                currentUid: 'user-self',
                subtitle: 'Player status',
                subtitleColor: Color(0xFF666666),
                showCharacterDetails: false,
              ),
            ],
          ),
        ),
      ),
    );

    final avatars = tester
        .widgetList<GenesisCharacterAvatar>(find.byType(GenesisCharacterAvatar))
        .toList(growable: false);
    expect(avatars, hasLength(2));
    expect(avatars[0].showStar, isFalse);
    expect(avatars[0].border, isNull);
    expect(avatars[1].showStar, isFalse);
    final playerBorder = avatars[1].border! as Border;
    expect(playerBorder.top.color, const Color(0xFFFF2442));
    expect(playerBorder.top.width, 2);
    expect(find.textContaining('(Me)'), findsNothing);
    expect(find.text('My Role'), findsOneWidget);
  });

  test('current user character has no name suffix', () {
    expect(
      worldCharacterNameSuffix(
        currentUid: 'user-self',
        playerUid: 'user-self',
        username: 'Owner',
        playerDeleted: false,
      ),
      isEmpty,
    );
  });
}
