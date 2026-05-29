import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';

void main() {
  testWidgets('WorldTickEventItem renders tick_result narrator paragraphs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldTickEventItem(
            tick: {
              'tick_index': 7,
              'created_at': '2026-05-02T00:00:00Z',
              'tick_result': {
                'narrator': 'A signal reaches the harbor.',
                'paragraphs': [
                  {
                    'location_id': 'loc_harbor',
                    'text': 'The harbor lights answer in sequence.',
                    'character_details': [
                      {'name': 'Iris Vale', 'delta': '+3 focus'},
                    ],
                  },
                ],
              },
            },
            tickNumber: 7,
            fallbackBody: 'Legacy fallback text',
            locationsById: const {
              'loc_harbor': {
                'location_id': 'loc_harbor',
                'location_name': 'Harbor Gate',
              },
            },
            dateLabel: 'Day 7',
            timeAgoLabel: '',
          ),
        ),
      ),
    );

    expect(find.text('A signal reaches the harbor.'), findsOneWidget);
    expect(find.text('Harbor Gate'), findsOneWidget);
    expect(find.text('The harbor lights answer in sequence.'), findsOneWidget);
    expect(find.text('Iris Vale +3 focus'), findsOneWidget);
    expect(find.text('Legacy fallback text'), findsNothing);
  });
}
