import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world_recent_summary.dart';
import 'package:genesis_flutter_android/pages/world/world_bottom_sheet.dart';
import 'package:genesis_flutter_android/pages/world/world_models.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_section.dart';

void main() {
  late WorldRecapCache cache;
  late ScrollController scroll;
  setUp(() {
    cache = WorldRecapCache();
    scroll = ScrollController();
  });
  tearDown(() {
    cache.dispose();
    scroll.dispose();
  });

  Widget view(WorldRecapLoader load, {bool active = true}) => MaterialApp(
    home: Scaffold(
      body: WorldRecapSection(
        cache: cache,
        load: load,
        scrollController: scroll,
        active: active,
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
      expect(
        find.byKey(const ValueKey('world-recap-skeleton')),
        findsOneWidget,
      );
      expect(find.text('No recap yet.'), findsNothing);
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
      expect(find.text('No recap yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('world-recap-skeleton')), findsNothing);
      final pending = Completer<WorldRecentSummaryPage>();
      final refresh = cache.refresh(
        'w1',
        ({required worldId, cursor}) => pending.future,
      );
      await tester.pump();
      expect(find.text('No recap yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('world-recap-skeleton')), findsNothing);
      pending.complete(
        const WorldRecentSummaryPage(items: [], hasMore: false, cursor: ''),
      );
      await refresh;
    },
  );

  testWidgets(
    'preserves full paragraphs, duplicates and cross-page tick headings',
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
      expect(
        tester.getTopLeft(find.text('no chapter')).dy,
        lessThan(tester.getTopLeft(find.text('Tick 7')).dy),
      );
    },
  );

  testWidgets(
    'inactive preview never paginates, active scrolling loads exactly once and failure stops',
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
