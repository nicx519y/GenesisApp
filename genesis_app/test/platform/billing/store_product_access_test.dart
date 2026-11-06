import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/store_product_access.dart';

void main() {
  setUp(() {
    StoreProductAccess.invalidateNativeForTesting = () async {};
  });
  tearDown(() {
    StoreProductAccess.invalidateNativeForTesting = null;
  });
  test(
    'unavailable cached product reloads catalog then retries exactly once',
    () async {
      final calls = <String>[];
      var count = 0;
      final result = await StoreProductAccess.retryUnavailable(
        canContinue: () => true,
        purchase: () async {
          calls.add('purchase');
          if (++count == 1)
            throw PlatformException(code: 'product_details_changed');
          return true;
        },
        refresh: () async {
          calls.add('server-and-platform-refresh');
        },
      );
      expect(result, true);
      expect(calls, ['purchase', 'server-and-platform-refresh', 'purchase']);
    },
  );
  test('cancel or ambiguous payment error never auto-retries', () async {
    for (final code in ['USER_CANCELED', 'network_error', 'purchase_error']) {
      await expectLater(
        StoreProductAccess.retryUnavailable(
          canContinue: () => true,
          purchase: () async => throw PlatformException(code: code),
          refresh: () async =>
              fail('Must not refresh and repeat an ambiguous payment'),
        ),
        throwsA(isA<PlatformException>()),
      );
    }
  });
  test(
    'expired checkout does not launch after refreshed results arrive',
    () async {
      var active = true;
      var launches = 0;
      await expectLater(
        StoreProductAccess.retryUnavailable(
          canContinue: () => active,
          purchase: () async {
            launches++;
            throw PlatformException(code: 'NOT_FOUND');
          },
          refresh: () async {
            active = false;
          },
        ),
        throwsA(anything),
      );
      expect(launches, 1);
    },
  );
  test('refresh context is scoped and stores no product results', () async {
    expect(StoreProductAccess.forceRefresh, false);
    await StoreProductAccess.refresh(() async {
      expect(StoreProductAccess.forceRefresh, true);
      await Future<void>.delayed(Duration.zero);
      expect(StoreProductAccess.forceRefresh, true);
    });
    expect(StoreProductAccess.forceRefresh, false);
  });
  test('session invalidation finishes before the next lookup', () async {
    final gate = Completer<void>();
    var invalidated = false;
    StoreProductAccess.invalidateNativeForTesting = () async {
      await gate.future;
      invalidated = true;
    };
    final revision = StoreProductAccess.revision;
    StoreProductAccess.reset();
    var ready = false;
    final lookup = StoreProductAccess.ready().then((_) {
      ready = true;
    });
    await pumpEventQueue();
    expect(ready, false);
    gate.complete();
    await lookup;
    expect(invalidated, true);
    expect(StoreProductAccess.revision, greaterThan(revision));
  });
  test('cancel and ordinary errors do not discard product cache', () async {
    final revision = StoreProductAccess.revision;
    for (final code in ['USER_CANCELED', 'network_error']) {
      await expectLater(
        StoreProductAccess.launch(
          () async => throw PlatformException(code: code),
        ),
        throwsA(isA<PlatformException>()),
      );
    }
    expect(StoreProductAccess.revision, revision);
  });
  test('invalid purchase credentials invalidate native cache', () async {
    var invalidations = 0;
    StoreProductAccess.invalidateNativeForTesting = () async {
      invalidations++;
    };
    await expectLater(
      StoreProductAccess.launch(
        () async => throw PlatformException(code: 'product_details_changed'),
      ),
      throwsA(isA<PlatformException>()),
    );
    await StoreProductAccess.ready();
    expect(invalidations, 1);
  });
}
