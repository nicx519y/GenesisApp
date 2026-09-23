import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world_recent_summary.dart';
import 'package:genesis_flutter_android/pages/world/world_recap_cache.dart';

WorldRecentSummaryPage page(String body, {String cursor = ''}) =>
    WorldRecentSummaryPage(
      items: [WorldRecentSummary(body: body, tickNo: 9)],
      hasMore: cursor.isNotEmpty,
      cursor: cursor,
    );

class Loader {
  final requests = <({String worldId, String? cursor})>[];
  final pending = <Completer<WorldRecentSummaryPage>>[];

  Future<WorldRecentSummaryPage> call({
    required String worldId,
    String? cursor,
  }) {
    requests.add((worldId: worldId, cursor: cursor));
    final completer = Completer<WorldRecentSummaryPage>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  late WorldRecapCache cache;
  late Loader loader;
  setUp(() {
    cache = WorldRecapCache();
    loader = Loader();
  });
  tearDown(() => cache.dispose());

  test(
    'refresh deduplicates, preserves cache, replaces old pages on success',
    () async {
      final first = cache.refresh('w1', loader.call);
      await cache.refresh('w1', loader.call);
      expect(loader.requests.length, 1);
      expect(cache.hasLoaded, isFalse);
      loader.pending[0].complete(page('first', cursor: 'opaque +/='));
      await first;
      final more = cache.loadMore(loader.call);
      await cache.loadMore(loader.call);
      expect(loader.requests[1].cursor, 'opaque +/=');
      expect(loader.requests.length, 2);
      loader.pending[1].complete(page('older'));
      await more;
      final refresh = cache.refresh('w1', loader.call);
      expect(cache.items.map((e) => e.body), ['first', 'older']);
      expect(loader.requests.last.cursor, isNull);
      loader.pending[2].complete(page('new', cursor: 'new-cursor'));
      await refresh;
      expect(cache.items.single.body, 'new');
      expect(cache.cursor, 'new-cursor');
    },
  );

  test('refresh failure retains content and loaded empty state', () async {
    for (final items in [
      <WorldRecentSummary>[],
      [const WorldRecentSummary(body: 'old', tickNo: 7)],
    ]) {
      final first = cache.refresh('w1', loader.call);
      loader.pending.last.complete(
        WorldRecentSummaryPage(items: items, hasMore: false, cursor: ''),
      );
      await first;
      final refresh = cache.refresh('w1', loader.call);
      expect(cache.hasLoaded, isTrue);
      expect(cache.items, items);
      loader.pending.last.completeError(StateError('offline'));
      await refresh;
      expect(cache.hasLoaded, isTrue);
      expect(cache.items, items);
      expect(cache.refreshError, isNotNull);
    }
  });

  test('failed first request is not a loaded empty response', () async {
    final first = cache.refresh('w1', loader.call);
    loader.pending.single.completeError(TimeoutException('timeout'));
    await first;
    expect(cache.hasLoaded, isFalse);
    expect(cache.refreshing, isFalse);
    expect(cache.refreshError, isNotNull);
  });

  test(
    'failed pagination stops automatic retries and retries the same cursor',
    () async {
      final first = cache.refresh('w1', loader.call);
      loader.pending[0].complete(page('same', cursor: 'c1'));
      await first;
      final more = cache.loadMore(loader.call);
      loader.pending[1].completeError(StateError('offline'));
      await more;
      await cache.loadMore(loader.call);
      expect(loader.requests.length, 2);
      expect(cache.items.single.body, 'same');
      final retry = cache.loadMore(loader.call, retry: true);
      expect(loader.requests.last.cursor, 'c1');
      loader.pending[2].complete(page('same'));
      await retry;
      expect(cache.items.map((e) => e.body), ['same', 'same']);
      expect(cache.hasMore, isFalse);
      await cache.loadMore(loader.call);
      expect(loader.requests.length, 3);
    },
  );

  test(
    'refresh invalidates in-flight pagination without losing its loading state',
    () async {
      final first = cache.refresh('w1', loader.call);
      loader.pending[0].complete(page('old', cursor: 'c1'));
      await first;
      final more = cache.loadMore(loader.call);
      final refresh = cache.refresh('w1', loader.call);
      loader.pending[1].complete(page('stale'));
      await more;
      expect(cache.refreshing, isTrue);
      expect(cache.items.single.body, 'old');
      loader.pending[2].complete(page('new'));
      await refresh;
      expect(cache.items.single.body, 'new');
    },
  );

  test(
    'clear and world switch reject late responses even for the same world id',
    () async {
      final old = cache.refresh('w1', loader.call);
      cache.clear();
      final current = cache.refresh('w1', loader.call);
      loader.pending[0].complete(page('stale'));
      await old;
      expect(cache.hasLoaded, isFalse);
      loader.pending[1].complete(page('current'));
      await current;
      final next = cache.refresh('w2', loader.call);
      expect(cache.items, isEmpty);
      expect(cache.hasLoaded, isFalse);
      loader.pending[2].complete(page('world 2'));
      await next;
      expect(cache.worldId, 'w2');
      expect(cache.items.single.body, 'world 2');
    },
  );

  test(
    'disposed World cache cannot be restored by a pending request',
    () async {
      final other = WorldRecapCache();
      final request = other.refresh('w1', loader.call);
      other.dispose();
      loader.pending.single.complete(page('late'));
      await request;
      expect(other.items, isEmpty);
      expect(other.hasLoaded, isFalse);
    },
  );

  test(
    'non-advancing cursor becomes a retryable failure without appending',
    () async {
      final first = cache.refresh('w1', loader.call);
      loader.pending[0].complete(page('first', cursor: 'c1'));
      await first;
      final more = cache.loadMore(loader.call);
      loader.pending[1].complete(page('duplicate', cursor: 'c1'));
      await more;
      expect(cache.items.single.body, 'first');
      expect(cache.loadMoreError, isA<FormatException>());
    },
  );
}
