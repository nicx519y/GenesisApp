import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';

void main() {
  test('initialsForAvatarName follows Chinese and foreign name rules', () {
    expect(initialsForAvatarName('张三'), '张');
    expect(initialsForAvatarName('李七七'), '七七');
    expect(initialsForAvatarName('Tom Lee'), 'TL');
    expect(initialsForAvatarName('Tom'), 'T');
    expect(initialsForAvatarName(''), '?');
  });

  test('avatarColorForName is stable per name', () {
    expect(avatarColorForName('Tom Lee'), avatarColorForName('Tom Lee'));
    expect(avatarColorForName('李七七'), avatarColorForName('李七七'));
  });

  testWidgets('GenesisAvatar renders generated fallback for empty URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenesisAvatar(url: '', name: 'Tom Lee', size: 40),
        ),
      ),
    );

    expect(find.text('TL'), findsOneWidget);
  });
}
