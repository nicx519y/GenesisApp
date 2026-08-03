import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';

void main() {
  testWidgets('world character sheet rows are built lazily', (tester) async {
    final characters = List<Map<String, dynamic>>.generate(
      80,
      (index) => <String, dynamic>{
        'character_id': 'character-$index',
        'name': 'Character $index',
        'type': 1,
        'brief': 'Brief $index',
      },
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: WorldCharacterListView(
              storageKey: 'world-character-lazy-test',
              characters: characters,
              currentUid: '',
              emptyText: 'Empty',
              subtitleBuilder: (character) => '${character['brief']}',
              subtitleColor: const Color(0xFF666666),
              showCharacterDetails: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Character 0'), findsOneWidget);
    expect(find.text('Character 79'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Character 79'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Character 79'), findsOneWidget);
  });
}
