import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/characters_list.dart';

void main() {
  testWidgets('character avatar constrains width without fixed height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharactersList(
            characters: [
              {
                'name': 'Iris',
                'subtitle': 'A test character',
                'tags': ['AI'],
                'image': 'assets/images/mock_avatars/avatar_iris.png',
                'powerText': '',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = find.image(
      const AssetImage('assets/images/mock_avatars/avatar_iris.png'),
    );
    expect(image, findsOneWidget);
    expect(tester.getSize(image).width, 86);
    expect(tester.getSize(image).height, isNot(128));
  });
}
