import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/world_recap_debug_preview.dart';
import 'package:genesis_flutter_android/network/models/world_recent_summary.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_section.dart';

const _emptyNote = 'Story recap will appear here as the story moves forward.';

void main() {
  late WorldRecapCache cache;
  late ScrollController scroll;
  late ValueNotifier<int> membershipChanges;
  setUp(() {
    cache = WorldRecapCache();
    scroll = ScrollController();
    membershipChanges = ValueNotifier(0);
    worldRecapDebugPreview.value = WorldRecapDebugPreview.off;
  });
  tearDown(() {
    cache.dispose();
    scroll.dispose();
    membershipChanges.dispose();
    worldRecapDebugPreview.value = WorldRecapDebugPreview.off;
  });

  /// [member] answers each membership check; a member by default.
  Widget view(
    WorldRecapLoader load, {
    bool active = true,
    bool? Function()? member,
  }) => MaterialApp(
    home: Scaffold(
      body: WorldRecapSection(
        cache: cache,
        load: load,
        scrollController: scroll,
        active: active,
        checkVip: (callback) =>
            scheduleMicrotask(() => callback((member ?? () => true)())),
        membershipChanges: membershipChanges,
        worldId: 'w1',
      ),
    ),
  );

  testWidgets(
    'cold loading and failure use skeleton; success empty uses empty state',
    (tester) async {
      final response = Completer<WorldRecentSummaryPage>();
      Future<WorldRecentSummaryPage> load({
        required String worldId,
        String? cursor,
      }) => response.future;
      final request = cache.refresh('w1', load);
      await tester.pumpWidget(view(load));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('world-recap-skeleton')),
        findsOneWidget,
      );
      expect(find.text(_emptyNote), findsNothing);
      response.completeError(StateError('private failure text'));
      await request;
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('private failure'), findsNothing);
      expect(
        find.byKey(const ValueKey('world-recap-skeleton')),
        findsOneWidget,
      );
      await cache.refresh(
        'w1',
        ({required worldId, cursor}) async =>
            const WorldRecentSummaryPage(items: [], hasMore: false, cursor: ''),
      );
      await tester.pump();
      expect(find.text(_emptyNote), findsOneWidget);
      expect(find.byKey(const ValueKey('world-recap-skeleton')), findsNothing);
      final pending = Completer<WorldRecentSummaryPage>();
      final refresh = cache.refresh(
        'w1',
        ({required worldId, cursor}) => pending.future,
      );
      await tester.pump();
      expect(find.text(_emptyNote), findsOneWidget);
      expect(find.byKey(const ValueKey('world-recap-skeleton')), findsNothing);
      pending.complete(
        const WorldRecentSummaryPage(items: [], hasMore: false, cursor: ''),
      );
      await refresh;
    },
  );

  testWidgets(
    'reads oldest first and keeps full paragraphs, duplicates and tick labels',
    (tester) async {
      Future<WorldRecentSummaryPage> load({
        required String worldId,
        String? cursor,
      }) async => WorldRecentSummaryPage(
        items: cursor == null
            ? const [
                WorldRecentSummary(body: 'one\ntwo. three.', tickNo: 9),
                WorldRecentSummary(body: 'duplicate', tickNo: 9),
              ]
            : const [
                WorldRecentSummary(body: 'duplicate', tickNo: 9),
                WorldRecentSummary(body: 'no chapter', tickNo: 0),
                WorldRecentSummary(body: 'earlier', tickNo: 7),
              ],
        hasMore: cursor == null,
        cursor: cursor == null ? 'c1' : '',
      );
      await cache.refresh('w1', load);
      await tester.pumpWidget(view(load, active: false));
      await cache.loadMore(load);
      await tester.pumpAndSettle();
      expect(find.text('Tick 9'), findsOneWidget);
      expect(find.text('Tick 7'), findsOneWidget);
      expect(find.text('Tick 0'), findsNothing);
      expect(find.text('one\ntwo. three.'), findsOneWidget);
      expect(find.text('duplicate'), findsNWidgets(2));
      // The server pages newest first; the recap reads oldest first.
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('earlier'), lessThan(top('no chapter')));
      expect(top('no chapter'), lessThan(top('Tick 9')));
      expect(top('Tick 9'), lessThan(top('one\ntwo. three.')));
    },
  );

  testWidgets(
    'inactive never paginates; active fetches earlier pages at once and failure stops',
    (tester) async {
      var calls = 0;
      Future<WorldRecentSummaryPage> load({
        required String worldId,
        String? cursor,
      }) async {
        calls++;
        if (cursor != null) throw StateError('offline');
        return WorldRecentSummaryPage(
          items: List.generate(
            10,
            (i) => WorldRecentSummary(
              body: 'Paragraph $i\nLine two\nLine three\nLine four',
              tickNo: 9,
            ),
          ),
          hasMore: true,
          cursor: 'next',
        );
      }

      await cache.refresh('w1', load);
      await tester.pumpWidget(view(load, active: false));
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(view(load));
      await tester.pumpAndSettle();
      expect(calls, 2);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Retry'), findsOneWidget);
      expect(cache.items.length, 10);
    },
  );

  testWidgets('non-members see what the recap offers and nothing is fetched', (
    tester,
  ) async {
    var calls = 0;
    Future<WorldRecentSummaryPage> load({
      required String worldId,
      String? cursor,
    }) async {
      calls++;
      return const WorldRecentSummaryPage(
        items: [WorldRecentSummary(body: 'secret', tickNo: 1)],
        hasMore: false,
        cursor: '',
      );
    }

    await tester.pumpWidget(view(load, member: () => false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('world-recap-locked')), findsOneWidget);
    expect(find.text('Subscribe to Unlock'), findsOneWidget);
    expect(find.byKey(const ValueKey('world-recap-skeleton')), findsNothing);
    expect(find.text('secret'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('until membership is known only a skeleton shows', (
    tester,
  ) async {
    Future<WorldRecentSummaryPage> load({
      required String worldId,
      String? cursor,
    }) async =>
        const WorldRecentSummaryPage(items: [], hasMore: false, cursor: '');

    await tester.pumpWidget(view(load, member: () => null));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('world-recap-skeleton')), findsOneWidget);
    expect(find.byKey(const ValueKey('world-recap-locked')), findsNothing);
    expect(find.text(_emptyNote), findsNothing);
  });

  testWidgets('subscribing while on the tab loads the recap there and then', (
    tester,
  ) async {
    var member = false;
    var calls = 0;
    String? requestedWorld;
    Future<WorldRecentSummaryPage> load({
      required String worldId,
      String? cursor,
    }) async {
      calls++;
      requestedWorld = worldId;
      return const WorldRecentSummaryPage(
        items: [WorldRecentSummary(body: 'After subscribing', tickNo: 3)],
        hasMore: false,
        cursor: '',
      );
    }

    await tester.pumpWidget(view(load, member: () => member));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('world-recap-locked')), findsOneWidget);
    expect(calls, 0);
    member = true;
    membershipChanges.value++;
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(requestedWorld, 'w1');
    expect(find.text('After subscribing'), findsOneWidget);
    expect(find.byKey(const ValueKey('world-recap-locked')), findsNothing);
  });

  testWidgets(
    'five bottom tabs retain order and scroll horizontally on narrow screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      WorldBottomSheetKind? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: WorldBottomTags(onTap: (value) => selected = value),
            ),
          ),
        ),
      );
      expect(worldBottomTagItems.map((e) => e.label), [
        'Detail',
        'Locations',
        'Events',
        'Recap',
        'Status',
      ]);
      expect(
        worldBottomSheetPageName(WorldBottomSheetKind.recap),
        'world_recap',
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status'));
      expect(selected, WorldBottomSheetKind.status);
      expect(tester.takeException(), isNull);
    },
  );
}
