import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/components/genesis_character_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';

void main() {
  testWidgets('events empty state uses fourteen pixel text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldEventsSection(
            world: _worldDetail(),
            ticks: const [],
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

    expect(
      tester.widget<Text>(find.text('No events yet.')).style?.fontSize,
      14,
    );
  });

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
      expect(find.text('Tick 4-1'), findsOneWidget);

      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tick 3-1'), findsOneWidget);
      expect(find.text('Tick 3 body'), findsOneWidget);
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
    expect(find.text('Tick 0-1'), findsOneWidget);

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
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
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
            .textSpan
            ?.style
            ?.color,
        GenesisColors.darkTextSecondary,
      );
      expect(
        tester
            .widget<Text>(find.text('The harbor lights answer in sequence.'))
            .textSpan
            ?.style
            ?.color,
        GenesisColors.darkTextSecondary,
      );
      expect(find.byType(ChatTickHeader), findsOneWidget);
      expect(find.byType(ChatTickChapterContent), findsOneWidget);
      expect(find.text('Global'), findsNothing);
      final tickHeader = tester.widget<Text>(find.text('Tick 4-1'));
      expect(tickHeader.style?.fontSize, GenesisTypography.bodyStrong.fontSize);
      expect(
        tickHeader.style?.fontWeight,
        GenesisTypography.bodyStrong.fontWeight,
      );
      expect(tickHeader.style?.color, GenesisColors.darkTextPrimary);
      final global = tester.widget<Text>(
        find.text('A signal reaches the harbor.'),
      );
      expect(global.textSpan?.style?.fontStyle, FontStyle.italic);
      expect(global.textSpan?.style?.fontSize, GenesisTypography.body.fontSize);
      expect(global.textSpan?.style?.height, GenesisTypography.body.height);
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
      expect(
        tester.widget<Text>(clueText).textSpan?.style?.fontStyle,
        FontStyle.italic,
      );
      expect(
        find.ancestor(of: clueText, matching: find.byType(Transform)),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.text('Follow the light toward the gate.'))
            .textSpan
            ?.style
            ?.color,
        GenesisColors.redSecondary,
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
    expect(find.byType(ChatTickChapterContent), findsOneWidget);
    expect(find.text(aiRoleName), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Day 4, 20:25')).style?.color,
      GenesisColors.darkTextTertiary,
    );
    expect(
      tester.widget<Text>(find.text(aiRoleName)).style?.color,
      GenesisColors.darkTextPrimary,
    );
    expect(
      tester.widget<Text>(find.text('Iris')).style?.color,
      GenesisColors.darkTextPrimary,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is GenesisCharacterAvatar && widget.name == aiRoleName,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is GenesisCharacterAvatar && widget.name == 'Iris',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text(aiRoleName)).dy,
      greaterThan(tester.getTopLeft(find.text('Day 4, 20:25')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet can scroll from Tick 0-94 to older sub-ticks', (
    tester,
  ) async {
    var hasMore = true;
    late StateSetter updateEvents;
    final sheetController = DraggableScrollableController();
    addTearDown(sheetController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableScrollableSheet(
            controller: sheetController,
            initialChildSize: 0.8,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            builder: (context, controller) => StatefulBuilder(
              builder: (context, setState) {
                updateEvents = setState;
                return WorldEventsSection(
                  scrollController: controller,
                  world: _worldDetail(),
                  ticks: [
                    for (var sub = 76; sub <= 94; sub++)
                      {
                        'tick_id': 'tick_0_$sub',
                        'tick_no': 0,
                        'sub_tick_no': sub,
                        'tick_result': {
                          'current_time': 'Day 3',
                          'narrator': 'Chapter $sub',
                          'global_status': <Object?>[],
                          'paragraphs': <Object?>[],
                        },
                      },
                    {
                      'tick_id': 'tick_1',
                      'tick_no': 1,
                      'sub_tick_no': 0,
                      'tick_result': {
                        'current_time': 'Day 4',
                        'narrator': 'Chapter 1',
                        'global_status': <Object?>[],
                        'paragraphs': <Object?>[],
                      },
                    },
                  ],
                  initialLoading: false,
                  loadingMore: false,
                  hasMore: hasMore,
                  error: null,
                  latestRevision: 0,
                  targetTickNumber: null,
                  contentPadding: EdgeInsets.zero,
                  onLoadMore: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 240));
    await tester.pumpAndSettle();
    expect(find.text('Tick 0-94'), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scroll.position.minScrollExtent, lessThan(0));
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 240));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, lessThan(0));
    final historyOffset = scroll.position.pixels;
    // Pagination has finished; connecting the sheet must not reset history.
    updateEvents(() => hasMore = false);
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(historyOffset, 0.01));
    expect(sheetController.isAttached, isFalse);
    expect(tester.getSize(find.byType(CustomScrollView).last).height, 480);
    // Reach the true beginning; the next drag may collapse the sheet.
    for (
      var attempt = 0;
      attempt < 30 && !sheetController.isAttached;
      attempt++
    ) {
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 350),
      );
      await tester.pumpAndSettle();
    }
    expect(sheetController.isAttached, isTrue);
    expect(find.text(kAiContentDisclaimerText), findsOneWidget);
    expect(sheetController.size, closeTo(0.8, 0.001));
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(sheetController.size, lessThan(0.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('latest sub-tick in a long history ends above bottom padding', (
    tester,
  ) async {
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
              contentPadding: const EdgeInsets.only(bottom: 32),
              onLoadMore: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub tick 500 body'), findsOneWidget);
    expect(find.text('Sub tick 1 body'), findsNothing);
    expect(
      tester
          .getBottomRight(
            find.byKey(
              const ValueKey<String>(
                'world-event-tick-item-id:tick_4_500:sub:500',
              ),
            ),
          )
          .dy,
      288,
    );
    expect(find.textContaining('Sub tick').evaluate().length, lessThan(500));
  });

  testWidgets('latest item uses natural bounds for short and tall content', (
    tester,
  ) async {
    Future<void> pumpItems(List<double> heights) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              width: 400,
              child: WorldTickEventCardPage(
                key: UniqueKey(),
                resetRevision: 0,
                hasTopEdgePage: false,
                hasBottomEdgePage: false,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                alignLastItemToTop: true,
                onTurnPage: (_) {},
                itemCount: heights.length,
                itemBuilder: (_, index) => SizedBox(
                  key: ValueKey('natural-item-$index'),
                  height: heights[index],
                  width: double.infinity,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpItems([50, 50]);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('natural-item-0'))).dy,
      10,
    );
    await pumpItems([400, 80]);
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('natural-item-1'))).dy,
      288,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('natural-item-1'))).dy,
      288,
    );
    await pumpItems([400, 600]);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('natural-item-1'))).dy,
      10,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('natural-item-1'))).dy,
      288,
    );
    expect(tester.takeException(), isNull);
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
    expect(tester.getBottomRight(find.byKey(latestPreviousSubTickKey)).dy, 320);
  });

  testWidgets(
    'events with a sheet controller prioritizes the previous tick pull',
    (tester) async {
      final sheetScrollController = ScrollController();
      addTearDown(sheetScrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: WorldEventsSection(
                scrollController: sheetScrollController,
                world: _worldDetail(),
                ticks: const [
                  {
                    'tick_id': 'tick_1',
                    'tick_no': 1,
                    'tick_result': {
                      'narrator': 'Previous tick body',
                      'paragraphs': <Object?>[],
                    },
                  },
                  {
                    'tick_id': 'tick_2',
                    'tick_no': 2,
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
      expect(sheetScrollController.hasClients, isFalse);

      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Previous tick body'), findsOneWidget);
      expect(find.text('Latest tick body'), findsNothing);
      // This short page fits entirely, so the sheet can already own its drag.
      expect(sheetScrollController.hasClients, isTrue);
    },
  );
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
