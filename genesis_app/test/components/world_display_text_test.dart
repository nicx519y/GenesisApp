import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_location_list.dart';
import 'package:genesis_flutter_android/components/world_point.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/utils/genesis_display_text.dart';

void main() {
  tearDown(() => onMalformedDisplayText = null);
  testWidgets('World role names repair display text without modifying source', (
    tester,
  ) async {
    final character = {'name': 'Role\uD800😀', 'avatar': '', 'player_uid': ''};
    final reports = <MalformedDisplayText>[];
    onMalformedDisplayText = reports.add;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldCharacterRow(
            character: character,
            currentUid: '',
            subtitle: 'Brief\uDC00',
            subtitleColor: Colors.grey,
            showCharacterDetails: false,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Role�😀'), findsOneWidget);
    expect(find.text('Brief�'), findsOneWidget);
    expect(character['name'], 'Role\uD800😀');
    expect(reports.map((r) => r.source), contains('world.character.name'));
  });

  testWidgets('location names and character spans are valid UTF-16', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorldLocationList(
            enableOuterScrollHandoff: false,
            points: [
              WorldPoint(
                id: 'loc',
                name: 'Place\uD800',
                type: WorldPointType.castle,
                position: Offset.zero,
                users: [UserAvatar('R', name: 'Role\uDC00😀')],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Place�'), findsOneWidget);
    expect(find.text('Role�😀', findRichText: true), findsOneWidget);
  });

  testWidgets('Tick character delta spans repair malformed names and units', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldTickEventItem(
            tick: {
              'tick_result': {
                'paragraphs': [
                  {
                    'location_id': 'loc',
                    'text': 'Story',
                    'character_deltas': [
                      {'name': 'Name\uD800', 'delta': '+3\uDC00'},
                    ],
                  },
                ],
              },
            },
            tickNumber: 1,
            fallbackBody: '',
            dateLabel: '',
            locationsById: const {
              'loc': {'name': 'Place'},
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Name� +3�', findRichText: true), findsOneWidget);
  });
}
