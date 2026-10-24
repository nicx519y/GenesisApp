import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/store_query_cache.dart';

void main() {
  setUp(StoreQueryCache.reset);

  test('refresh bypasses a cached SKU without clearing other SKUs', () async {
    final owner = Object();
    var calls = 0;
    Future<int> query(String sku) => StoreQueryCache.load(
      owner,
      sku,
      () async => ++calls,
      usable: (_) => true,
    );
    expect(await query('gems'), 1);
    expect(await query('subscription'), 2);
    expect(await StoreQueryCache.refresh(() => query('gems')), 3);
    expect(await query('gems'), 3);
    expect(await query('subscription'), 2);
    expect(calls, 3);
  });

  test('an older native lookup cannot overwrite a refreshed SKU', () async {
    final owner = Object();
    final oldResponse = Completer<int>();
    final old = StoreQueryCache.load(
      owner,
      'sku',
      () => oldResponse.future,
      usable: (_) => true,
    );
    expect(
      await StoreQueryCache.refresh(
        () => StoreQueryCache.load(
          owner,
          'sku',
          () async => 2,
          usable: (_) => true,
        ),
      ),
      2,
    );
    oldResponse.complete(1);
    await old;
    expect(
      await StoreQueryCache.load(
        owner,
        'sku',
        () async => 3,
        usable: (_) => true,
      ),
      2,
    );
  });

  test(
    'reuses successful native objects and coalesces in-flight queries',
    () async {
      final owner = Object();
      final response = Completer<Object>();
      var calls = 0;
      Future<Object> query() => StoreQueryCache.load(owner, 'sku/offer', () {
        calls++;
        return response.future;
      }, usable: (_) => true);
      final first = query();
      final second = query();
      final native = Object();
      response.complete(native);
      expect(await first, same(native));
      expect(await second, same(native));
      expect(await query(), same(native));
      expect(calls, 1);
    },
  );

  test('failed and incomplete queries are retryable', () async {
    final owner = Object();
    var calls = 0;
    Future<int> query() => StoreQueryCache.load(owner, 'sku', () async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return calls == 2 ? 0 : 1;
    }, usable: (value) => value > 0);
    await expectLater(query(), throwsStateError);
    expect(await query(), 0);
    expect(await query(), 1);
    expect(await query(), 1);
    expect(calls, 3);
  });

  test(
    'different store instances and offers cannot share credentials',
    () async {
      final owner = Object();
      var calls = 0;
      Future<int> query(Object store, String key) => StoreQueryCache.load(
        store,
        key,
        () async => ++calls,
        usable: (_) => true,
      );
      expect(await query(owner, 'sku/base'), 1);
      expect(await query(owner, 'sku/discount'), 2);
      expect(await query(Object(), 'sku/base'), 3);
    },
  );

  test('session reset discards cached and late native results', () async {
    final owner = Object();
    final response = Completer<int>();
    final old = StoreQueryCache.load(
      owner,
      'sku',
      () => response.future,
      usable: (_) => true,
    );
    StoreQueryCache.reset();
    response.complete(1);
    expect(await old, 1);
    expect(
      await StoreQueryCache.load(
        owner,
        'sku',
        () async => 2,
        usable: (_) => true,
      ),
      2,
    );
  });

  test('launch rejection invalidates stale store credentials', () async {
    final revision = StoreQueryCache.revision;
    expect(await StoreQueryCache.launch(() async => false), isFalse);
    expect(StoreQueryCache.revision, greaterThan(revision));
    await expectLater(
      StoreQueryCache.launch(() async => throw StateError('stale')),
      throwsStateError,
    );
  });
}
