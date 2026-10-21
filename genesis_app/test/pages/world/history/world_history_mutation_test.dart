import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world_history.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_controller.dart';
import 'package:genesis_flutter_android/pages/world/history/world_history_section_participation.dart';
import 'history_fixtures.dart';

WorldHistoryPage page(List<WorldHistoryMessage> rows, String cursor) =>
    WorldHistoryPage(
      worldId: 'w',
      messages: rows,
      cursor: cursor,
      hasMore: cursor.isNotEmpty,
    );

void main() {
  for (final terminal in [false, true]) {
    test('changed page chain recovers locally; terminal=$terminal', () async {
      final calls = <String?>[];
      var mutated = false;
      Completer<WorldHistoryPage>? pending;
      final c = WorldHistoryController(
        worldId: 'w',
        maxMessages: 3,
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              calls.add(cursor);
              if (mutated && cursor == '1') return pending!.future;
              return historyPage(
                ['${cursor ?? '0'}-a'],
                cursor: cursor == 'new'
                    ? ''
                    : '${int.parse(cursor ?? '0') + 1}',
              );
            },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      for (var i = 1; i <= 8; i++) {
        await c.loadOlder();
        c.updateReading(messageId: '$i-a');
      }
      expect(c.firstResident, greaterThan(0));
      expect(c.returnToNewest(), isTrue);
      final before = calls.length;
      mutated = true;
      pending = Completer();
      final loading = c.loadOlder();
      pending.complete(
        historyPage(
          terminal ? [] : ['replacement'],
          cursor: terminal ? '' : 'new',
        ),
      );
      await loading;
      expect(c.failed, isFalse);
      expect(c.pages.length, 2);
      expect(
        c.newestFirst.map((r) => r.id),
        terminal ? ['0-a'] : ['0-a', 'replacement'],
      );
      expect(c.pageFor('8-a'), isNull);
      expect(c.hasOlder, !terminal);
      expect(calls.length, before + 1);
      if (!terminal) {
        await c.loadOlder();
        expect(calls.last, 'new');
      }
    });
  }

  test('changed newer page discards queued older navigation', () async {
    Completer<WorldHistoryPage>? pending;
    final calls = <String?>[];
    final c = WorldHistoryController(
      worldId: 'w',
      maxMessages: 3,
      fetch: ({required worldId, cursor, limit = 20, cancellationToken}) async {
        calls.add(cursor);
        if (pending != null) return pending.future;
        final i = int.parse(cursor ?? '0');
        return historyPage(['$i'], cursor: '${i + 1}');
      },
    );
    addTearDown(c.dispose);
    c.setActive(true);
    await c.refresh();
    for (var i = 1; i <= 8; i++) {
      await c.loadOlder();
      c.updateReading(messageId: '$i');
    }
    final reloaded = c.firstResident - 1;
    final before = calls.length;
    pending = Completer();
    final newer = c.loadNewer();
    final older = c.loadOlder();
    pending.complete(historyPage(['changed'], cursor: 'new-chain'));
    await newer;
    await older;
    expect(calls.length, before + 1);
    expect(c.pages.length, reloaded + 1);
    expect(c.newestFirst.single.id, 'changed');
    expect(c.failed, isFalse);
  });

  test(
    'same cursor accepts changed edges, edits and deleted user; retry retains data',
    () async {
      var changed = false, fail = false;
      final c = WorldHistoryController(
        worldId: 'w',
        maxMessages: 3,
        fetch:
            ({required worldId, cursor, limit = 20, cancellationToken}) async {
              if (cursor == '1') {
                if (fail) throw StateError('offline');
                return page([
                  historyMessage(changed ? 'new-edge' : 'edge'),
                  historyMessage(
                    'tick',
                    type: 'tick',
                    content: changed ? 'edited' : 'original',
                  ),
                  if (!changed) historyMessage('user', type: 'user'),
                  historyMessage('tail', locations: ['B']),
                ], '2');
              }
              final i = int.parse(cursor ?? '0');
              return page([
                historyMessage('$i', locations: ['B']),
              ], '${i + 1}');
            },
      );
      addTearDown(c.dispose);
      c.setActive(true);
      await c.refresh();
      for (var i = 1; i <= 8; i++) {
        await c.loadOlder();
        c.updateReading(messageId: i == 1 ? 'tail' : '$i');
      }
      expect(c.sectionParticipation.includesTick('tick', 'A'), isTrue);
      c.returnToNewest();
      changed = fail = true;
      await c.loadOlder();
      expect(c.failed, isTrue);
      expect(c.newestFirst.single.id, '0');
      fail = false;
      await c.retry();
      expect(c.failed, isFalse);
      expect(c.pages.length, 9); // Unchanged cursor retains the known suffix.
      expect(c.newestFirst.any((m) => m.id == 'new-edge'), isTrue);
      expect(c.newestFirst.firstWhere((m) => m.id == 'tick').content, 'edited');
      expect(c.sectionParticipation.includesTick('tick', 'A'), isFalse);
      final builds = c.residentIndexBuilds;
      c.updateReading(messageId: 'tick', pinnedIds: ['tick', 'tail']);
      final updates = c.readingUpdates;
      for (var i = 0; i < 1000; i++) {
        c.updateReading(messageId: 'tick', pinnedIds: ['tick', 'tail']);
        expect(c.pageFor('tick'), 1);
        expect(c.residentBytes, greaterThan(0));
      }
      expect(c.residentIndexBuilds, builds);
      expect(c.readingUpdates, updates);
    },
  );

  test(
    'participation replaces contributions, splits, joins and transfers duplicate ownership',
    () {
      final index = HistorySectionParticipation(appVersion: 1);
      index.appendOlder([historyMessage('tick', type: 'tick')]);
      index.appendOlder([historyMessage('middle')]);
      index.appendOlder([historyMessage('user', type: 'user')]);
      expect(index.includesTick('tick', 'A'), isTrue);
      index.replacePage(1, [
        historyMessage('middle', locations: ['B']),
      ]);
      expect(index.includesTick('tick', 'A'), isFalse);
      index.replacePage(1, []);
      expect(index.includesTick('tick', 'A'), isTrue);
      index.replacePage(2, [historyMessage('user', type: 'user', version: 2)]);
      expect(index.includesTick('tick', 'A'), isFalse);
      index.replacePage(2, [historyMessage('user', type: 'user')]);
      index.replacePage(1, [
        historyMessage('user', locations: ['B']),
      ]);
      expect(index.includesTick('tick', 'A'), isFalse);
      index.replacePage(1, []); // Older duplicate becomes authoritative again.
      expect(index.includesTick('tick', 'A'), isTrue);
      index.truncate(2);
      expect(index.includesTick('tick', 'A'), isFalse);
      index.appendOlder([
        historyMessage('user', type: 'user', locations: ['B', 'A']),
      ]);
      expect(index.includesTick('tick', 'A'), isTrue);
      index.clear();
      expect(index.includesTick('tick', 'A'), isFalse);
    },
  );

  test(
    'mixed replacements match a full timeline oracle including duplicates',
    () {
      final random = Random(42);
      final index = HistorySectionParticipation(appVersion: 1);
      final pages = <List<WorldHistoryMessage>>[];
      for (var step = 0; step < 200; step++) {
        if (pages.length > 1 && random.nextInt(5) == 0) {
          final length = random.nextInt(pages.length);
          pages.removeRange(length, pages.length);
          index.truncate(length);
        } else {
          final at = random.nextInt(pages.length + 1);
          final rows = List.generate(
            random.nextInt(6),
            (i) => historyMessage(
              'id-${random.nextInt(30)}',
              type: ['user', 'tick', 'character'][random.nextInt(3)],
              version: random.nextInt(3),
              locations: <List<String>>[
                [],
                ['A'],
                ['B'],
                ['A', 'B'],
              ][random.nextInt(4)],
            ),
          );
          if (at == pages.length) {
            pages.add(rows);
          } else {
            pages[at] = rows;
          }
          index.replacePage(at, rows);
        }
        final seen = <String>{};
        final expected = <(String, String)>{};
        final steps = <({WorldHistoryMessage row, Set<String> locations})>[];
        for (final row in pages.expand((page) => page)) {
          if (!seen.add(row.id) || row.minAppVersion > 1) continue;
          final locations = row.locationRefs.isEmpty
              ? ['']
              : row.locationRefs.toSet().toList().reversed;
          if (row.type == 'tick') {
            steps.add((row: row, locations: locations.toSet()));
          } else {
            for (final location in locations) {
              steps.add((row: row, locations: {location}));
            }
          }
        }
        // Independent brute-force oracle: scan one location at a time. Shared
        // Tick refs are one membership step, ordinary refs are separate steps.
        for (final location in ['A', 'B']) {
          var hasUser = false;
          final ticks = <(String, String)>[];
          void finish() {
            if (hasUser) expected.addAll(ticks);
            ticks.clear();
            hasUser = false;
          }

          for (final step in steps) {
            if (!step.locations.contains(location)) {
              finish();
            } else {
              if (step.row.type == 'user') hasUser = true;
              if (step.row.type == 'tick') ticks.add((step.row.id, location));
            }
          }
          finish();
        }
        for (var id = 0; id < 30; id++) {
          for (final place in ['', 'A', 'B']) {
            expect(
              index.includesTick('id-$id', place),
              expected.contains(('id-$id', place)),
              reason: 'mutation $step, id-$id, location $place',
            );
          }
        }
      }
    },
  );

  test(
    'shared Tick participation crosses pages and tracks edits and truncation',
    () {
      final index = HistorySectionParticipation(appVersion: 1);
      final newer = historyMessage(
        'newer-tick',
        type: 'tick',
        locations: ['A', 'B', 'C'],
      );
      final older = historyMessage(
        'older-tick',
        type: 'tick',
        locations: ['A', 'B', 'C'],
      );
      index.appendOlder([newer]);
      index.appendOlder([older]);
      index.appendOlder([
        historyMessage('user', type: 'user', locations: ['B']),
      ]);
      for (final tick in [newer, older]) {
        expect(index.includesTick(tick.id, 'B'), isTrue);
        expect(index.includesTick(tick.id, 'A'), isFalse);
        expect(index.includesTick(tick.id, 'C'), isFalse);
      }
      index.replacePage(1, [
        historyMessage('older-tick', type: 'tick', locations: ['A', 'C']),
      ]);
      expect(index.includesTick('newer-tick', 'B'), isFalse);
      index.replacePage(1, [older]);
      expect(index.includesTick('newer-tick', 'B'), isTrue);
      index.replacePage(2, [
        historyMessage('user', locations: ['B']),
      ]);
      expect(index.includesTick('newer-tick', 'B'), isFalse);
      index.replacePage(2, [
        historyMessage('user', type: 'user', locations: ['B']),
      ]);
      expect(index.includesTick('newer-tick', 'B'), isTrue);
      index.truncate(2);
      expect(index.includesTick('newer-tick', 'B'), isFalse);
    },
  );

  test('page summary work does not grow with visited history', () {
    final index = HistorySectionParticipation(appVersion: 1);
    index.appendOlder([historyMessage('tick', type: 'tick')]);
    for (var i = 1; i < 2000; i++) {
      index.appendOlder([historyMessage('$i')]);
    }
    final examined = index.examinedMessages, nodes = index.summaryNodeVisits;
    index.replacePage(1000, [historyMessage('1000', type: 'user')]);
    expect(index.examinedMessages - examined, 1);
    expect(index.summaryNodeVisits - nodes, lessThanOrEqualTo(32));
    expect(index.includesTick('tick', 'A'), isTrue);
    index.replacePage(1000, [historyMessage('1000')]);
    expect(index.includesTick('tick', 'A'), isFalse);
  });
}
