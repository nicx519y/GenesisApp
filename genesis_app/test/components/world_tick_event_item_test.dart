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
              'tick_no': 7,
              'created_at': '2026-05-02T00:00:00Z',
              'tick_result': {
                'narrator': 'A signal reaches the harbor.',
                'paragraphs': [
                  {
                    'location_id': 'loc_harbor',
                    'timestamp': 'Day 7, 09:30',
                    'text': 'The harbor lights answer in sequence.',
                    'character_deltas': [
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
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.text('Day 7, 09:30'), findsOneWidget);
    expect(find.text('The harbor lights answer in sequence.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Day 7, 09:30')).dy,
      lessThan(
        tester
            .getTopLeft(find.text('The harbor lights answer in sequence.'))
            .dy,
      ),
    );
    expect(find.text('Iris Vale +3 focus'), findsOneWidget);
    expect(find.text('Legacy fallback text'), findsNothing);
  });

  testWidgets('WorldTickEventItem can stack labels above content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldTickEventItem(
            tick: {
              'tick_result': {
                'narrator': 'A signal reaches the harbor.',
                'paragraphs': [
                  {
                    'location_id': 'loc_harbor',
                    'text': 'The harbor lights answer in sequence.',
                  },
                ],
              },
            },
            tickNumber: 1,
            fallbackBody: '',
            locationsById: const {
              'loc_harbor': {'location_name': 'Harbor Gate'},
            },
            stackedContent: true,
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('A signal reaches the harbor.')).dy,
      greaterThan(tester.getBottomLeft(find.text('Global')).dy),
    );
    expect(
      tester.getTopLeft(find.text('The harbor lights answer in sequence.')).dy,
      greaterThan(tester.getBottomLeft(find.text('Harbor Gate')).dy),
    );
  });

  testWidgets('WorldTickEventItem styles pure numeric character deltas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldTickEventItem(
            tick: {
              'tick_result': {
                'narrator': 'A signal reaches the harbor.',
                'paragraphs': [
                  {
                    'location_id': 'loc_harbor',
                    'text': 'The harbor lights answer in sequence.',
                    'character_deltas': [
                      {'name': 'Iris Vale', 'delta': 18},
                      {'name': 'Marshal Crow', 'delta': -4},
                    ],
                  },
                ],
              },
            },
            tickNumber: 1,
            fallbackBody: '',
            metricUnit: 'pressure',
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(WorldTickEventItem),
            matching: find.byType(RichText),
          )
          .last,
    );
    final textSpan = richText.text as TextSpan;
    final deltaSpans = _flattenTextSpans(textSpan);

    expect(richText.text.toPlainText(), contains('Iris Vale +18pressure'));
    expect(richText.text.toPlainText(), contains('Marshal Crow -4pressure'));
    expect(
      deltaSpans
          .singleWhere((span) => span.text == ' +18pressure')
          .style
          ?.color,
      const Color(0xFF338960),
    );
    expect(
      deltaSpans
          .singleWhere((span) => span.text == ' +18pressure')
          .style
          ?.fontWeight,
      FontWeight.w600,
    );
    expect(
      deltaSpans.singleWhere((span) => span.text == ' -4pressure').style?.color,
      const Color(0xFFFF2442),
    );
    expect(
      deltaSpans
          .singleWhere((span) => span.text == ' -4pressure')
          .style
          ?.fontWeight,
      FontWeight.w600,
    );
  });
}

List<TextSpan> _flattenTextSpans(InlineSpan span) {
  final spans = <TextSpan>[];
  if (span is! TextSpan) return spans;
  spans.add(span);
  final children = span.children;
  if (children == null) return spans;
  for (final child in children) {
    spans.addAll(_flattenTextSpans(child));
  }
  return spans;
}
