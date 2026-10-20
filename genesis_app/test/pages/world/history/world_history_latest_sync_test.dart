import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';

import 'history_fixtures.dart';

void main() {
  testWidgets('continuous events flush within two seconds', (tester) async {
    var calls = 0;
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        return historyPage(['${++calls}']);
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.requestEntryRefresh();
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      c.markLatestDirty();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(calls, 2);
  });

  testWidgets('initial request survives closing; background cancels sync', (
    tester,
  ) async {
    var pending = Completer<WorldHistoryPage>();
    var calls = 0;
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) {
        calls++;
        return pending.future;
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.requestEntryRefresh();
    c.setActive(false);
    pending.complete(historyPage(['initial']));
    await tester.pump();
    expect(c.ready, isTrue);
    pending = Completer<WorldHistoryPage>();
    c.markLatestDirty();
    await tester.pump(const Duration(milliseconds: 500));
    c.setSyncEnabled(false);
    pending.complete(historyPage(['late']));
    await tester.pump();
    expect(c.hasPendingLatest, isFalse);
    expect(c.latestDirty, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 2);
    pending = Completer<WorldHistoryPage>()..complete(historyPage(['resumed']));
    c.setSyncEnabled(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 3);
    expect(c.hasPendingLatest, isTrue);
  });

  testWidgets('adoption invalidates pending and queued old pages', (
    tester,
  ) async {
    final old = Completer<WorldHistoryPage>();
    var head = historyPage(['old'], cursor: 'old-cursor');
    final calls = <String?>[];
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) {
        calls.add(cursor);
        return cursor == null ? Future.value(head) : old.future;
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.requestEntryRefresh();
    await tester.pump();
    final loading = c.loadOlder();
    head = historyPage(
      List.generate(20, (i) => 'new-$i'),
      cursor: 'new-cursor',
    );
    c.markLatestDirty();
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.loading, isTrue);
    expect(c.returnToNewest(), isTrue);
    old.complete(historyPage(['stale']));
    await loading;
    await tester.pump();
    expect(c.pages.length, 1);
    expect(c.pages.single.responseCursor, 'new-cursor');
    expect(c.newestFirst.map((m) => m.id), isNot(contains('stale')));
    expect(c.residentCount, 20);
  });

  testWidgets(
    'failure retains both caches and only retries on another trigger',
    (tester) async {
      var calls = 0;
      var fail = false;
      final c = WorldHistoryController(
        worldId: 'w',
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              calls++;
              if (fail) throw StateError('offline');
              return historyPage(['$calls']);
            },
      );
      addTearDown(c.dispose);
      c.setSyncEnabled(true);
      c.requestEntryRefresh();
      await tester.pump();
      c.markLatestDirty();
      fail = true;
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.syncError, isA<StateError>());
      expect(c.error, isNull);
      expect(c.newestFirst.single.id, '1');
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 2);
      fail = false;
      await c.syncLatest();
      expect(c.syncError, isNull);
      expect(c.hasPendingLatest, isTrue);
    },
  );

  testWidgets(
    'same IDs compare all content and empty head replaces old chain',
    (tester) async {
      var row = historyMessage('same');
      var empty = false;
      final c = WorldHistoryController(
        worldId: 'w',
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              return WorldHistoryPage(
                worldId: 'w',
                messages: empty ? [] : [row],
                hasMore: false,
                cursor: '',
              );
            },
      );
      addTearDown(c.dispose);
      c.setSyncEnabled(true);
      c.requestEntryRefresh();
      await tester.pump();
      for (final next in [
        historyMessage('same', content: 'edited'),
        historyMessage('same', content: 'edited', tick: 7),
        historyMessage('same', content: 'edited', tick: 7, subTick: 2),
        historyMessage('same', locations: ['B'], version: 999),
      ]) {
        row = next;
        await c.syncLatest();
        expect(c.hasPendingLatest, isTrue);
        c.returnToNewest();
        expect(c.newestFirst.single, same(next));
      }
      empty = true;
      await c.syncLatest();
      c.returnToNewest();
      expect(c.newestFirst, isEmpty);
      expect(c.hasOlder, isFalse);
    },
  );

  testWidgets('hidden History syncs without replacing the reading chain', (
    tester,
  ) async {
    var page = historyPage(['old'], cursor: 'old-cursor');
    final cursors = <String?>[];
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        cursors.add(cursor);
        return page;
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.markLatestDirty();
    await tester.pump(const Duration(seconds: 3));
    expect(cursors, isEmpty); // Never opened.
    c.requestEntryRefresh();
    await tester.pump();
    final snapshot = c.snapshot;
    c.setActive(false);
    page = historyPage(['new'], cursor: 'new-cursor');
    c.markLatestDirty();
    await tester.pump(const Duration(milliseconds: 499));
    expect(cursors, [null]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(cursors, [null, null]);
    expect(c.newestFirst.single.id, 'old');
    expect(c.hasPendingLatest, isTrue);
    expect(c.snapshot, snapshot);
    c.setActive(true);
    expect(c.returnToNewest(), isTrue);
    expect(c.newestFirst.single.id, 'new');
    expect(c.pages.single.responseCursor, 'new-cursor');
    expect(c.snapshot, snapshot); // Does not clear folds.
    page = historyPage(['older']);
    await c.loadOlder();
    expect(cursors.last, 'new-cursor');
  });

  testWidgets('unchanged response gets only one delayed calibration', (
    tester,
  ) async {
    var calls = 0;
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        calls++;
        return historyPage(['same']);
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.requestEntryRefresh();
    await tester.pump();
    c.markLatestDirty();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 3);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 3);
    expect(c.latestDirty, isTrue);
    expect(c.hasPendingLatest, isFalse);
  });

  testWidgets('new notifications during sync survive the completed request', (
    tester,
  ) async {
    final pending = Completer<WorldHistoryPage>();
    var calls = 0;
    final c = WorldHistoryController(
      worldId: 'w',
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        calls++;
        if (calls == 1) return historyPage(['first']);
        if (calls == 2) return pending.future;
        return historyPage(['third']);
      },
    );
    addTearDown(c.dispose);
    c.setSyncEnabled(true);
    c.requestEntryRefresh();
    await tester.pump();
    c.markLatestDirty();
    await tester.pump(const Duration(milliseconds: 500));
    c.markLatestDirty();
    pending.complete(historyPage(['second']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 3);
    expect(c.latestDirty, isFalse);
    c.returnToNewest();
    expect(c.newestFirst.single.id, 'third');
  });
}
