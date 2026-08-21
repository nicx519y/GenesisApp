import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  testWidgets(
    'events list renders ticks and sub ticks in reverse chronological order',
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

      expect(
        find.byKey(const ValueKey<String>('world-events-tick-list')),
        findsOneWidget,
      );
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Tick 4-2'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 2 body'), findsOneWidget);
      expect(find.text('Tick 4-1'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 1 body'), findsOneWidget);
      final renderedTicks = tester
          .widgetList<WorldTickEventItem>(find.byType(WorldTickEventItem))
          .map((item) => (item.tickNumber, item.subTickNumber))
          .toList();
      expect(renderedTicks, [(4, 2), (4, 1), (3, 1)]);
    },
  );

  testWidgets('events list keeps tick zero sub ticks in descending order', (
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

    expect(find.text('Tick 0-2'), findsOneWidget);
    expect(find.text('Tick zero sub tick 2 body'), findsOneWidget);
    expect(find.text('Tick 0-1'), findsOneWidget);
    expect(find.text('Tick zero sub tick 1 body'), findsOneWidget);
    final renderedTicks = tester
        .widgetList<WorldTickEventItem>(find.byType(WorldTickEventItem))
        .map((item) => item.subTickNumber)
        .toList();
    expect(renderedTicks, [2, 1]);
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
      expect(find.text('Tick 0-1'), findsOneWidget);
      expect(find.text(kAiContentDisclaimerText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(kAiContentDisclaimerText)).dy,
        lessThan(tester.getTopLeft(find.text('Tick 0-1')).dy),
      );
      expect(
        tester.getTopLeft(find.text(kAiContentDisclaimerText)).dy,
        greaterThan(tester.getTopLeft(find.text('Tick 1-1')).dy),
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
        GenesisPalette.redesignInk,
      );
      expect(
        tester
            .widget<Text>(find.text('The harbor lights answer in sequence.'))
            .style
            ?.color,
        GenesisPalette.redesignInk,
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
        GenesisPalette.redesignInk60,
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
      GenesisPalette.redesignInk60,
    );
    expect(
      tester.widget<Text>(find.text(aiRoleName)).style?.color,
      GenesisPalette.redesignInk60,
    );
    expect(
      tester.widget<Text>(find.text('Iris')).style?.color,
      GenesisPalette.redesignInk60,
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
      lessThan(tester.getTopLeft(find.text(aiRoleName)).dy),
    );
    expect(tester.getSize(find.text(aiRoleName)).width, greaterThan(224));
    expect(
      tester.getSize(find.text(aiRoleName)).height,
      greaterThanOrEqualTo(11),
    );
    expect(
      tester.getTopLeft(aiIcon).dy,
      closeTo(tester.getTopLeft(find.text(aiRoleName)).dy + 2, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('Iris')).dy,
      greaterThanOrEqualTo(tester.getTopLeft(find.text(aiRoleName)).dy),
    );
  });

  testWidgets('latest sub-tick starts a lazy 500 sub-tick list', (
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
    final firstRenderedTick = tester
        .widgetList<WorldTickEventItem>(find.byType(WorldTickEventItem))
        .first;
    expect(firstRenderedTick.tickNumber, 4);
    expect(firstRenderedTick.subTickNumber, 500);
    expect(find.textContaining('Sub tick').evaluate().length, lessThan(500));
  });

  testWidgets('upward scroll reveals the previous tick in the same list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 140,
            child: WorldEventsSection(
              world: _worldDetail(),
              ticks: const [
                {
                  'tick_id': 'tick_3_1',
                  'tick_no': 3,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Previous tick body',
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

    final list = find.byKey(const ValueKey<String>('world-events-tick-list'));
    expect(find.byType(PageView), findsNothing);
    final initialOffset = tester
        .widget<Scrollable>(
          find.descendant(of: list, matching: find.byType(Scrollable)),
        )
        .controller!
        .offset;
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Previous tick body'), findsOneWidget);
    expect(
      tester
          .widget<Scrollable>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .controller!
          .offset,
      greaterThan(initialOffset),
    );
  });

  testWidgets('upward pull near the history edge requests older ticks', (
    tester,
  ) async {
    var loadMoreCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WorldEventsSection(
              world: _worldDetail(),
              ticks: [
                for (var tickNumber = 1; tickNumber <= 4; tickNumber += 1)
                  {
                    'tick_id': 'tick_${tickNumber}_1',
                    'tick_no': tickNumber,
                    'sub_tick_no': 1,
                    'tick_result': {
                      'narrator': 'Tick $tickNumber body',
                      'paragraphs': <Object?>[],
                    },
                  },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: true,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () => loadMoreCount += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tick 4 body'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tick 3 body'), findsOneWidget);
    expect(loadMoreCount, greaterThanOrEqualTo(1));
  });

  testWidgets('loaded older ticks append without resetting list position', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var ticks = <Map<String, dynamic>>[
      for (var tickNumber = 1; tickNumber <= 4; tickNumber += 1)
        {
          'tick_id': 'tick_${tickNumber}_1',
          'tick_no': tickNumber,
          'sub_tick_no': 1,
          'tick_result': {
            'narrator': 'Tick $tickNumber body',
            'paragraphs': <Object?>[],
          },
        },
    ];
    var hasMore = true;
    var loadMoreCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: StatefulBuilder(
              builder: (context, setState) => WorldEventsSection(
                world: _worldDetail(),
                ticks: ticks,
                initialLoading: false,
                loadingMore: false,
                hasMore: hasMore,
                error: null,
                latestRevision: 0,
                targetTickNumber: null,
                contentPadding: EdgeInsets.zero,
                scrollController: scrollController,
                onLoadMore: () {
                  loadMoreCount += 1;
                  setState(() {
                    ticks = [
                      {
                        'tick_id': 'tick_0_1',
                        'tick_no': 0,
                        'sub_tick_no': 1,
                        'tick_result': {
                          'narrator': 'Loaded older tick body',
                          'paragraphs': <Object?>[],
                        },
                      },
                      ...ticks,
                    ];
                    hasMore = false;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final list = find.byKey(const ValueKey<String>('world-events-tick-list'));
    await tester.drag(list, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(loadMoreCount, 1);
    expect(scrollController.offset, greaterThan(0));
    expect(find.byType(PageView), findsNothing);
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Loaded older tick body'), findsOneWidget);
  });

  testWidgets(
    'scroll-to-top button appears after scrolling and returns latest',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.worldoDark(),
          home: Scaffold(
            body: SizedBox(
              height: 180,
              child: WorldEventsSection(
                world: _worldDetail(),
                ticks: [
                  for (var tickNumber = 1; tickNumber <= 20; tickNumber += 1)
                    {
                      'tick_id': 'tick_${tickNumber}_1',
                      'tick_no': tickNumber,
                      'sub_tick_no': 1,
                      'tick_result': {
                        'narrator': 'Tick $tickNumber body',
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
                scrollController: scrollController,
                onLoadMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final list = find.byKey(const ValueKey<String>('world-events-tick-list'));
      final button = find.byKey(
        const ValueKey<String>('world-events-scroll-to-top'),
      );
      AnimatedOpacity buttonOpacity() => tester.widget<AnimatedOpacity>(
        find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
      );

      expect(button, findsOneWidget);
      expect(buttonOpacity().opacity, 0);
      await tester.drag(list, const Offset(0, -700));
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(320));
      expect(buttonOpacity().opacity, 1);
      expect(tester.getSize(button), const Size.square(36));
      expect(
        tester.widget<Material>(button).color,
        GenesisPalette.redesignWhite10,
      );
      final buttonIcon = tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
      expect(buttonIcon.icon, Icons.keyboard_double_arrow_up_rounded);
      expect(buttonIcon.size, 22);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(scrollController.offset, 0);
      expect(buttonOpacity().opacity, 0);
      expect(find.text('Tick 20 body'), findsOneWidget);
    },
  );
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
