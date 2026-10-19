import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';
import 'history_fixtures.dart';

void main() {
  test(
    'same operation coalesces; opaque cursor and world-level order survive',
    () async {
      final calls = <String?>[];
      final pending = Completer<WorldHistoryPage>();
      final c = WorldHistoryController(
        worldId: 'w',
        fetch: ({required worldId, cursor, limit = 20, cancellationToken}) {
          calls.add(cursor);
          return pending.future;
        },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      final first = c.refresh(), second = c.refresh();
      expect(identical(first, second), isTrue);
      pending.complete(
        historyPage([
          '2',
          '999999999999999999999999',
          '1',
        ], cursor: ' a+/= token '),
      );
      await first;
      expect(calls, [null]);
      expect(c.newestFirst.map((m) => m.id), [
        '2',
        '999999999999999999999999',
        '1',
      ]);
    },
  );

  test(
    'failure retains window and exact failed cursor; no automatic retry',
    () async {
      final calls = <String?>[];
      var fail = false;
      final c = WorldHistoryController(
        worldId: 'w',
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              calls.add(cursor);
              if (fail) throw StateError('cursor expired');
              return cursor == null
                  ? historyPage(['a'], cursor: 'opaque+/=')
                  : historyPage(['b']);
            },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      fail = true;
      await c.loadOlder();
      await c.refresh();
      expect(c.newestFirst.single.id, 'a');
      expect(c.pages.single.responseCursor, 'opaque+/=');
      fail = false;
      await c.retry();
      expect(calls.last, isNull);
      fail = true;
      await c.loadOlder();
      fail = false;
      await c.retry();
      expect(calls.sublist(calls.length - 2), ['opaque+/=', 'opaque+/=']);
      expect(c.newestFirst.map((m) => m.id), ['a', 'b']);
    },
  );

  test(
    'pause cancels, resumes only canceled operation and discards late reply',
    () async {
      final pending = <Completer<WorldHistoryPage>>[];
      final tokens = <NetworkCancellationToken>[];
      final c = WorldHistoryController(
        worldId: 'w',
        fetch: ({required worldId, cursor, limit = 20, cancellationToken}) {
          tokens.add(cancellationToken!);
          final p = Completer<WorldHistoryPage>();
          pending.add(p);
          return p.future;
        },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      final request = c.refresh();
      c.setActive(false);
      await request;
      expect(tokens.single.isCancelled, isTrue);
      pending.first.complete(historyPage(['stale']));
      await Future<void>.delayed(Duration.zero);
      expect(c.ready, isFalse);
      c.setActive(true);
      expect(pending.length, 2);
      pending.last.complete(historyPage(['good']));
      await Future<void>.delayed(Duration.zero);
      c.setActive(false);
      c.setActive(true);
      expect(pending.length, 2);
      expect(c.newestFirst.single.id, 'good');
      final late = c.refresh();
      c.clear();
      pending.last.complete(historyPage(['old-account']));
      await late;
      expect(c.ready, isFalse);
      expect(c.pages, isEmpty);
    },
  );

  test(
    'wrong world, nonadvancing and cyclic cursors leave existing data',
    () async {
      var page = historyPage(['a'], cursor: 'next');
      final c = WorldHistoryController(
        worldId: 'w',
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async =>
                page,
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      page = historyPage(['bad'], world: 'another');
      await c.loadOlder();
      expect(c.failed, isTrue);
      expect(c.residentCount, 1);
      page = historyPage(['bad'], cursor: 'next');
      await c.retry();
      expect(c.failed, isTrue);
      expect(c.residentCount, 1);
      page = historyPage(['b'], cursor: 'third');
      await c.retry();
      page = historyPage(['bad'], cursor: 'next');
      await c.loadOlder();
      expect(c.failed, isTrue);
      expect(c.residentCount, 2);
    },
  );

  test(
    'whole-page memory eviction and reload work in both directions',
    () async {
      final calls = <String?>[];
      final c = WorldHistoryController(
        worldId: 'w',
        maxMessages: 6,
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              calls.add(cursor);
              final i = cursor == null ? 0 : int.parse(cursor.substring(5));
              return historyPage([
                '$i-a',
                '$i-b',
              ], cursor: i < 9 ? 'page-${i + 1}' : '');
            },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      for (var i = 1; i <= 9; i++) {
        await c.loadOlder();
        c.updateReading(messageId: '$i-a', pinnedIds: ['$i-a']);
        expect(c.residentCount, lessThanOrEqualTo(6));
      }
      expect(c.pages.length, 10);
      expect(c.hasOlder, isFalse);
      expect(c.hasNewer, isTrue);
      for (var i = c.firstResident - 1; i >= 0; i--) {
        await c.loadNewer();
        c.updateReading(messageId: '$i-a', pinnedIds: ['$i-a']);
        expect(c.residentCount, lessThanOrEqualTo(6));
        expect(calls.last, i == 0 ? null : 'page-$i');
      }
      expect(c.hasNewer, isFalse);
      expect(c.hasOlder, isTrue);
      expect(c.newestFirst.first.id, '0-a');
    },
  );

  test(
    'bytes budget, pinned pages, failed reload and oversized page keep content',
    () async {
      var fail = false;
      final c = WorldHistoryController(
        worldId: 'w',
        maxBytes: 3,
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              if (fail) throw StateError('expired');
              final i = cursor == null ? 0 : int.parse(cursor);
              return historyPage(['$i'], cursor: '${i + 1}');
            },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      expect(c.residentBytes, greaterThan(3));
      expect(c.residentCount, 1);
      for (var i = 1; i < 6; i++) {
        await c.loadOlder();
        c.updateReading(messageId: '$i', pinnedIds: ['$i']);
      }
      expect(c.residentCount, lessThanOrEqualTo(2));
      final ids = c.newestFirst.map((m) => m.id).toList();
      fail = true;
      await c.loadNewer();
      expect(c.newestFirst.map((m) => m.id), ids);
      expect(c.hasNewer, isTrue);
      expect(c.failed, isTrue);
    },
  );
}
