import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  testWidgets(
    'events pager renders sub ticks for one tick number on one page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldEventsSection(
              world: _worldDetail(),
              ticks: const [
                {
                  'tick_id': 'tick_3_1',
                  'tick_no': 3,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Tick 3 body',
                    'paragraphs': <Object?>[],
                  },
                },
                {
                  'tick_id': 'tick_4_2',
                  'tick_no': 4,
                  'sub_tick_no': 2,
                  'tick_result': {
                    'narrator': 'Tick 4 sub tick 2 body',
                    'paragraphs': <Object?>[],
                  },
                },
                {
                  'tick_id': 'tick_4_1',
                  'tick_no': 4,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Tick 4 sub tick 1 body',
                    'paragraphs': <Object?>[],
                  },
                },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey<String>('world-events-tick-pager')),
      );
      expect(pager.childrenDelegate.estimatedChildCount, 2);
      expect(find.text('Tick 4-2'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 2 body'), findsOneWidget);
      expect(find.text('Tick 4-1'), findsNothing);

      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tick 4-1'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 1 body'), findsOneWidget);
    },
  );

  testWidgets('events pager groups tick zero events on one page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldEventsSection(
            world: _worldDetail(),
            ticks: const [
              {
                'tick_id': 'tick_0_2',
                'tick_no': 0,
                'sub_tick_no': 2,
                'tick_result': {
                  'narrator': 'Tick zero sub tick 2 body',
                  'paragraphs': <Object?>[],
                },
              },
              {
                'tick_id': 'tick_0_1',
                'tick_no': 0,
                'sub_tick_no': 1,
                'tick_result': {
                  'narrator': 'Tick zero sub tick 1 body',
                  'paragraphs': <Object?>[],
                },
              },
            ],
            initialLoading: false,
            loadingMore: false,
            hasMore: false,
            error: null,
            latestRevision: 0,
            targetTickNumber: null,
            contentPadding: EdgeInsets.zero,
            onLoadMore: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('world-events-tick-pager')),
    );
    expect(pager.childrenDelegate.estimatedChildCount, 1);
    expect(find.text('Tick 0-2'), findsOneWidget);
    expect(find.text('Tick zero sub tick 2 body'), findsOneWidget);
    expect(find.text('Tick 0-1'), findsNothing);

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('Tick 0-1'), findsOneWidget);
    expect(find.text('Tick zero sub tick 1 body'), findsOneWidget);
  });

  testWidgets(
    'AI notice appears above the earliest event tick including zero',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldEventsSection(
              world: _worldDetail(),
              ticks: const [
                {
                  'tick_id': 'tick_0_1',
                  'tick_no': 0,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Earliest tick body',
                    'paragraphs': <Object?>[],
                  },
                },
                {
                  'tick_id': 'tick_1_1',
                  'tick_no': 1,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Later tick body',
                    'paragraphs': <Object?>[],
                  },
                },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tick 1-1'), findsOneWidget);
      expect(find.text(kAiContentDisclaimerText), findsNothing);

      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tick 0-1'), findsOneWidget);
      expect(find.text(kAiContentDisclaimerText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(kAiContentDisclaimerText)).dy,
        lessThan(tester.getTopLeft(find.text('Tick 0-1')).dy),
      );
    },
  );

  testWidgets(
    'events sheet renders non-empty paragraph clues like story events',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: WorldEventsSection(
              world: _worldDetail(),
              ticks: const [
                {
                  'tick_id': 'tick_4_1',
                  'tick_no': 4,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'A signal reaches the harbor.',
                    'paragraphs': <Object?>[
                      {
                        'location_id': 'loc_harbor',
                        'text': 'The harbor lights answer in sequence.',
                        'clue': 'Follow the light toward the gate.',
                      },
                      {
                        'location_id': 'loc_harbor',
                        'text': 'The other signal fades.',
                        'clue': '',
                      },
                    ],
                  },
                },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.text('A signal reaches the harbor.'))
            .style
            ?.color,
        const Color(0xFF111111),
      );
      expect(
        tester
            .widget<Text>(find.text('The harbor lights answer in sequence.'))
            .style
            ?.color,
        const Color(0xFF111111),
      );
      expect(find.text('Follow the light toward the gate.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SvgPicture &&
              widget.bytesLoader.toString().contains(clueIconAsset),
        ),
        findsOneWidget,
      );
      final clueText = find.text('Follow the light toward the gate.');
      expect(tester.widget<Text>(clueText).style?.fontStyle, FontStyle.normal);
      expect(
        find.ancestor(
          of: clueText,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Transform &&
                _matchesIosInlineEmphasisSkew(widget.transform),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.text('Follow the light toward the gate.'))
            .style
            ?.color,
        const Color(0xFF666666),
      );
    },
  );

  testWidgets('events sheet shows AI and user visible roles after event time', (
    WidgetTester tester,
  ) async {
    const aiRoleName =
        'Oracle With A Very Long Ceremonial Name That Wraps Below';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldEventsSection(
            world: _worldDetail(
              characters: const [
                {
                  'char_id': 'char_oracle',
                  'name': aiRoleName,
                  'player_uid': '',
                },
                {
                  'char_id': 'char_iris',
                  'name': 'Iris',
                  'player_uid': 'user_iris',
                },
              ],
            ),
            ticks: const [
              {
                'tick_id': 'tick_4_1',
                'tick_no': 4,
                'sub_tick_no': 1,
                'tick_result': {
                  'narrator': 'A signal reaches the harbor.',
                  'paragraphs': <Object?>[
                    {
                      'location_id': 'loc_harbor',
                      'timestamp': 'Day 4, 20:25',
                      'visibility': 'char_only',
                      'visible_to': ['char_oracle', 'char_iris'],
                      'text': 'Only the visible roles hear the signal.',
                    },
                  ],
                },
              },
            ],
            initialLoading: false,
            loadingMore: false,
            hasMore: false,
            error: null,
            latestRevision: 0,
            targetTickNumber: null,
            contentPadding: EdgeInsets.zero,
            onLoadMore: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 4, 20:25'), findsOneWidget);
    expect(find.text(aiRoleName), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Day 4, 20:25')).style?.color,
      const Color(0xFF666666),
    );
    expect(
      tester.widget<Text>(find.text(aiRoleName)).style?.color,
      const Color(0xFF666666),
    );
    expect(
      tester.widget<Text>(find.text('Iris')).style?.color,
      const Color(0xFF666666),
    );
    final aiIcon = find.byWidgetPredicate(
      (widget) =>
          widget is SvgPicture &&
          widget.bytesLoader.toString().contains(characterStatIconAsset),
    );
    final userIcon = find.byWidgetPredicate(
      (widget) =>
          widget is SvgPicture &&
          widget.bytesLoader.toString().contains(userStatIconAsset),
    );
    expect(aiIcon, findsOneWidget);
    expect(userIcon, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Day 4, 20:25')).dy,
      closeTo(tester.getTopLeft(find.text(aiRoleName)).dy, 2),
    );
    expect(tester.getSize(find.text(aiRoleName)).width, greaterThan(224));
    expect(tester.getSize(find.text(aiRoleName)).height, greaterThan(20));
    expect(
      tester.getTopLeft(aiIcon).dy,
      closeTo(tester.getTopLeft(find.text(aiRoleName)).dy + 2, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('Iris')).dy,
      greaterThan(tester.getTopLeft(find.text(aiRoleName)).dy),
    );
  });

  testWidgets('latest sub-tick starts a 500 sub-tick page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WorldEventsSection(
              world: _worldDetail(),
              ticks: [
                for (var index = 1; index <= 500; index += 1)
                  {
                    'tick_id': 'tick_4_$index',
                    'tick_no': 4,
                    'sub_tick_no': index,
                    'tick_result': {
                      'narrator': 'Sub tick $index body',
                      'paragraphs': <Object?>[],
                    },
                  },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sub tick 500 body'), findsOneWidget);
    expect(find.text('Sub tick 1 body'), findsNothing);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>(
                'world-event-tick-item-id:tick_4_500:sub:500',
              ),
            ),
          )
          .dy,
      0,
    );
    expect(find.textContaining('Sub tick').evaluate().length, lessThan(500));
  });

  testWidgets('previous tick opens at its latest sub-tick', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WorldEventsSection(
              world: _worldDetail(),
              ticks: [
                for (var index = 1; index <= 500; index += 1)
                  {
                    'tick_id': 'tick_3_$index',
                    'tick_no': 3,
                    'sub_tick_no': index,
                    'tick_result': {
                      'narrator': 'Previous sub tick $index body',
                      'paragraphs': <Object?>[],
                    },
                  },
                {
                  'tick_id': 'tick_4_1',
                  'tick_no': 4,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Latest tick body',
                    'paragraphs': <Object?>[],
                  },
                },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Latest tick body'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 300));
    await tester.pumpAndSettle();

    const latestPreviousSubTickKey = ValueKey<String>(
      'world-event-tick-item-id:tick_3_500:sub:500',
    );
    expect(find.text('Previous sub tick 500 body'), findsOneWidget);
    expect(find.text('Previous sub tick 1 body'), findsNothing);
    expect(tester.getTopLeft(find.byKey(latestPreviousSubTickKey)).dy, 0);
  });
}

bool _matchesIosInlineEmphasisSkew(Matrix4 transform) {
  final expected = Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew);
  for (var index = 0; index < transform.storage.length; index += 1) {
    if ((transform.storage[index] - expected.storage[index]).abs() > 0.0001) {
      return false;
    }
  }
  return true;
}

WorldDetail _worldDetail({
  List<Map<String, dynamic>> characters = const <Map<String, dynamic>>[],
}) {
  return WorldDetail(
    id: 1,
    worldId: 'world_events_test',
    originId: 1,
    ownerUid: 'owner',
    name: 'Events Test',
    tickCount: 4,
    connectCount: 0,
    characterCount: 0,
    playerCount: 0,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'joined',
    metric: const <String, dynamic>{},
    inviteToken: '',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'origin_events_test',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: characters,
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
