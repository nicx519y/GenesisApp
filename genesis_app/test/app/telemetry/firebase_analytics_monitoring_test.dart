import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAnalyticsClient client;
  late int messageSentCount;

  setUp(() {
    FirebaseAnalyticsMonitoring.resetForTesting();
    client = _FakeAnalyticsClient();
    messageSentCount = 0;
    FirebaseAnalyticsMonitoring.setClientForTesting(client);
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      _MemoryOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () async => 'test-device-id',
    );
    FirebaseAnalyticsMonitoring.setMessageSentCountIncrementerForTesting(
      () async {
        messageSentCount += 1;
        return messageSentCount;
      },
    );
  });
  tearDown(FirebaseAnalyticsMonitoring.resetForTesting);

  Future<void> purchase({String identity = 'receipt-1'}) =>
      FirebaseAnalyticsMonitoring.recordPurchase(
        provider: 'google',
        productId: 'gems-product',
        kind: FirebaseAnalyticsPurchaseKind.gems,
        purchaseIdentity: identity,
      );

  test(
    'purchase receipts deduplicate concurrent and later completions',
    () async {
      final ready = Completer<void>();
      FirebaseAnalyticsMonitoring.setReadinessForTesting(ready.future);
      final first = purchase();
      final duplicate = purchase();
      await Future<void>.delayed(Duration.zero);
      ready.complete();
      await Future.wait([first, duplicate]);
      await purchase();
      await purchase(identity: 'receipt-2');
      expect(client.events.map((e) => e.name), [
        'purchase',
        'purchase_first',
        'gems_first',
        'purchase',
      ]);
    },
  );

  test(
    'purchase receipt markers survive restart without storing raw identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
        const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
      );
      await purchase(identity: 'private-store-token');
      final preferences = await SharedPreferences.getInstance();
      final keys = preferences.getKeys();
      expect(
        keys.where((key) => key.contains('purchase_transaction_v1.')),
        hasLength(1),
      );
      expect(keys.any((key) => key.contains('private-store-token')), isFalse);
      expect(
        client.events.every(
          (e) => !e.parameters.values.contains('private-store-token'),
        ),
        isTrue,
      );
      FirebaseAnalyticsMonitoring.resetForTesting();
      FirebaseAnalyticsMonitoring.setClientForTesting(client);
      FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
      FirebaseAnalyticsMonitoring.setReadinessForTesting(Future.value());
      FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
        () async => 'device',
      );
      await purchase(identity: 'private-store-token');
      expect(client.events, hasLength(3));
    },
  );

  test('failed purchase call can retry the same receipt', () async {
    client.error = StateError('SDK unavailable');
    await purchase();
    client.error = null;
    await purchase();
    await purchase();
    expect(client.events.map((e) => e.name), [
      'purchase',
      'purchase_first',
      'gems_first',
    ]);
    expect(client.attempts, 6);
  });

  test('partial purchase failure retries only the unsent event', () async {
    client.failedEventNames.add('gems_first');
    await purchase();
    expect(client.events.map((e) => e.name), ['purchase', 'purchase_first']);
    client.failedEventNames.clear();
    await purchase();
    expect(client.events.map((e) => e.name), [
      'purchase',
      'purchase_first',
      'gems_first',
    ]);
    expect(client.attempts, 4);
  });

  test('legacy first markers remain valid for transaction deduplication', () async {
    SharedPreferences.setMockInitialValues({
      '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}purchase_first':
          1,
      '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}gems_first':
          1,
    });
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );
    await purchase();
    await purchase();
    expect(client.events.map((e) => e.name), ['purchase']);
  });

  test(
    'purchase device lookup failure uses unknown without dropping events',
    () async {
      FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
        () async => throw StateError('device unavailable'),
      );
      await purchase();
      expect(client.events, hasLength(3));
      expect(
        client.events.every((e) => e.parameters['device_id'] == 'unknown'),
        isTrue,
      );
    },
  );

  test(
    'missing identity and disabled collection do not consume first markers',
    () async {
      await purchase(identity: ' ');
      FirebaseAnalyticsMonitoring.setEnabledForTesting(false);
      await purchase();
      expect(client.events, isEmpty);
      FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
      await purchase();
      expect(client.events, hasLength(3));
    },
  );

  test('records base and first events with exact parameters', () async {
    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );
    await FirebaseAnalyticsMonitoring.recordLaunchSuccess(
      originId: 'origin-2',
      roleType: 'custom',
      worldId: 'world-2',
    );
    await FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-3',
      locationId: 'location-3',
    );
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'google');
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'google',
      productId: 'worldo_gems_500',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-1',
    );

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('launch', <String, Object>{
        'origin_id': 'origin-1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', <String, Object>{
        'origin_id': 'origin-1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success', <String, Object>{
        'origin_id': 'origin-2',
        'role_type': 'custom',
        'world_id': 'world-2',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_success_first', <String, Object>{
        'origin_id': 'origin-2',
        'role_type': 'custom',
        'world_id': 'world-2',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('message_sent', <String, Object>{
        'world_id': 'world-3',
        'location_id': 'location-3',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('message_sent_first', <String, Object>{
        'world_id': 'world-3',
        'location_id': 'location-3',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('login', <String, Object>{
        'method': 'google',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('login_first', <String, Object>{
        'method': 'google',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('purchase', <String, Object>{
        'provider': 'google',
        'product_id': 'worldo_gems_500',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('purchase_first', <String, Object>{
        'provider': 'google',
        'product_id': 'worldo_gems_500',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('gems_first', <String, Object>{
        'provider': 'google',
        'product_id': 'worldo_gems_500',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('purchase category first events are independent', () async {
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'google',
      productId: 'gems-1',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-2',
    );
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'google',
      productId: 'gems-2',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-3',
    );
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'subscription-1',
      kind: FirebaseAnalyticsPurchaseKind.subscription,
      purchaseIdentity: 'test-purchase-4',
    );
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'subscription-2',
      kind: FirebaseAnalyticsPurchaseKind.subscription,
      purchaseIdentity: 'test-purchase-5',
    );

    expect(client.events.map((event) => event.name), <String>[
      'purchase',
      'purchase_first',
      'gems_first',
      'purchase',
      'purchase',
      'subscription_first',
      'purchase',
    ]);
    expect(
      client.events.singleWhere((event) => event.name == 'gems_first'),
      const _RecordedEvent('gems_first', <String, Object>{
        'provider': 'google',
        'product_id': 'gems-1',
        'device_id': 'test-device-id',
      }),
    );
    expect(
      client.events.singleWhere((event) => event.name == 'subscription_first'),
      const _RecordedEvent('subscription_first', <String, Object>{
        'provider': 'apple',
        'product_id': 'subscription-1',
        'device_id': 'test-device-id',
      }),
    );
  });

  test(
    'first Day0 Gems purchase records all Day0 events with store price',
    () async {
      final anchorStore = _MemoryDay0AnchorStore();
      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(anchorStore);
      final anchor = DateTime.utc(2026, 1, 1, 0);
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(anchor);
      FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
        () => DateTime.utc(2026, 1, 1, 12),
      );

      await FirebaseAnalyticsMonitoring.recordPurchase(
        provider: 'google',
        productId: 'worldo_gems_500',
        kind: FirebaseAnalyticsPurchaseKind.gems,
        purchaseIdentity: 'day0-gems-1',
        priceAmountMicros: 4990000,
        priceCurrencyCode: 'usd',
      );

      expect(client.events.map((event) => event.name).toSet(), {
        'purchase',
        'purchase_first',
        'gems_first',
        'purchase_day0',
        'gems_day0',
        'purchase_first_day0',
        'gems_first_day0',
      });
      expect(client.events, hasLength(7));
      for (final event in client.events) {
        expect(event.parameters, <String, Object>{
          'provider': 'google',
          'product_id': 'worldo_gems_500',
          'device_id': 'test-device-id',
          'value': 4.99,
          'currency': 'USD',
        });
        expect(event.parameters.values, isNot(contains('day0-gems-1')));
      }
    },
  );

  test(
    'later Day0 purchase emits only transaction-scoped Day0 events',
    () async {
      final anchor = DateTime.utc(2026, 1, 1, 0);
      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
        _MemoryDay0AnchorStore(),
      );
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(anchor);
      FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
        () => DateTime.utc(2026, 1, 1, 1),
      );

      await purchase(identity: 'day0-first');
      client.events.clear();
      await purchase(identity: 'day0-second');
      await purchase(identity: 'day0-second');

      expect(client.events.map((event) => event.name).toSet(), {
        'purchase',
        'purchase_day0',
        'gems_day0',
      });
      expect(client.events, hasLength(3));
    },
  );

  test(
    'Day0 category first markers remain independent across purchases',
    () async {
      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
        _MemoryDay0AnchorStore(),
      );
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
        DateTime.utc(2026, 1, 1),
      );
      FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
        () => DateTime.utc(2026, 1, 1, 2),
      );

      await purchase(identity: 'day0-gems');
      await FirebaseAnalyticsMonitoring.recordPurchase(
        provider: 'apple',
        productId: 'subscription-1',
        kind: FirebaseAnalyticsPurchaseKind.subscription,
        purchaseIdentity: 'day0-subscription',
      );

      expect(
        client.events.where((event) => event.name == 'purchase_first_day0'),
        hasLength(1),
      );
      expect(
        client.events.where((event) => event.name == 'gems_first_day0'),
        hasLength(1),
      );
      expect(
        client.events.where((event) => event.name == 'subscription_first_day0'),
        hasLength(1),
      );
      expect(
        client.events.where((event) => event.name == 'purchase_day0'),
        hasLength(2),
      );
    },
  );

  test('Day0 uses the fixed Beijing calendar boundary', () async {
    FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
      _MemoryDay0AnchorStore(),
    );
    await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
      DateTime.utc(2025, 12, 31, 16),
    );
    FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
      () => DateTime.utc(2026, 1, 1, 15, 59, 59, 999),
    );
    await purchase(identity: 'beijing-end');
    expect(client.events.any((event) => event.name == 'purchase_day0'), isTrue);

    client.events.clear();
    FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
      () => DateTime.utc(2026, 1, 1, 16),
    );
    await purchase(identity: 'beijing-next-day');
    expect(client.events.map((event) => event.name), ['purchase']);
  });

  test('a server time before the anchor is never Day0 eligible', () async {
    final anchor = DateTime.utc(2026, 1, 1, 1);
    FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
      _MemoryDay0AnchorStore(),
    );
    await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(anchor);
    FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
      () => anchor.subtract(const Duration(milliseconds: 1)),
    );

    await purchase(identity: 'before-anchor');

    expect(client.events.any((event) => event.name.contains('day0')), isFalse);
  });

  test(
    'Day0 anchor persists once and failed writes retry on the next sync',
    () async {
      final store = _MemoryDay0AnchorStore(failWrites: 1);
      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(store);
      final first = DateTime.utc(2026, 1, 1, 2);
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(first);
      expect(store.value, isNull);

      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(first);
      expect(store.value, first);
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
        DateTime.utc(2026, 1, 2, 2),
      );
      expect(store.value, first);
      expect(store.successfulWrites, 1);

      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(store);
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
        DateTime.utc(2026, 1, 3, 2),
      );
      expect(store.value, first);
      expect(store.successfulWrites, 1);
    },
  );

  test('Day0 transaction markers and anchor survive an app restart', () async {
    SharedPreferences.setMockInitialValues({});
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsDay0AnchorStore(),
    );
    final anchor = DateTime.utc(2026, 1, 1);
    await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(anchor);
    FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
      () => anchor.add(const Duration(hours: 1)),
    );
    await purchase(identity: 'restart-day0');
    expect(client.events, hasLength(7));

    FirebaseAnalyticsMonitoring.resetForTesting();
    FirebaseAnalyticsMonitoring.setClientForTesting(client);
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsDay0AnchorStore(),
    );
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () async => 'test-device-id',
    );
    await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
      anchor.add(const Duration(hours: 2)),
    );
    FirebaseAnalyticsMonitoring.setPurchaseServerNowForTesting(
      () => anchor.add(const Duration(hours: 2)),
    );
    await purchase(identity: 'restart-day0');

    expect(client.events, hasLength(7));
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt(
        SharedPreferencesFirebaseAnalyticsDay0AnchorStore.storageKey,
      ),
      anchor.millisecondsSinceEpoch,
    );
  });

  test(
    'legacy first markers do not block independent Day0 first events',
    () async {
      final onceStore = _MemoryOnceEventStore()
        ..sentEvents.addAll({'purchase_first', 'gems_first'});
      FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(onceStore);
      FirebaseAnalyticsMonitoring.setDay0AnchorStoreForTesting(
        _MemoryDay0AnchorStore(),
      );
      await FirebaseAnalyticsMonitoring.recordServerTimeSynchronized(
        DateTime.utc(2026, 1, 1),
      );

      await purchase(identity: 'upgrade-day0');

      expect(client.events.map((event) => event.name).toSet(), {
        'purchase',
        'purchase_day0',
        'gems_day0',
        'purchase_first_day0',
        'gems_first_day0',
      });
    },
  );

  test('purchase price is all-or-nothing and zero remains valid', () async {
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'trial',
      kind: FirebaseAnalyticsPurchaseKind.subscription,
      purchaseIdentity: 'free-trial',
      priceAmountMicros: 0,
      priceCurrencyCode: 'usd',
    );
    expect(
      client.events.every(
        (event) =>
            event.parameters['value'] == 0 &&
            event.parameters['currency'] == 'USD',
      ),
      isTrue,
    );

    client.events.clear();
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'missing-price',
      kind: FirebaseAnalyticsPurchaseKind.subscription,
      purchaseIdentity: 'missing-price',
      priceAmountMicros: 9990000,
      priceCurrencyCode: 'not-a-currency',
    );
    expect(
      client.events.every(
        (event) =>
            !event.parameters.containsKey('value') &&
            !event.parameters.containsKey('currency'),
      ),
      isTrue,
    );
  });

  test('base event repeats while first event skips later triggers', () async {
    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );
    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-2',
      roleType: 'custom',
    );

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('launch', <String, Object>{
        'origin_id': 'origin-1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch_first', <String, Object>{
        'origin_id': 'origin-1',
        'role_type': 'preset',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('launch', <String, Object>{
        'origin_id': 'origin-2',
        'role_type': 'custom',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test(
    'concurrent triggers keep both base events and share one first',
    () async {
      final first = FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-1',
        locationId: 'location-1',
      );
      final second = FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-2',
        locationId: 'location-2',
      );
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(
        client.events.where((event) => event.name == 'message_sent'),
        hasLength(2),
      );
      expect(
        client.events.where((event) => event.name == 'message_sent_first'),
        hasLength(1),
      );
    },
  );

  test(
    'records message_sent threshold events at ten and twenty only once',
    () async {
      for (var count = 1; count <= 21; count += 1) {
        await FirebaseAnalyticsMonitoring.recordMessageSent(
          worldId: 'world-$count',
          locationId: 'location-$count',
        );
      }

      expect(
        client.events.where(
          (event) =>
              event.name == 'message_sent_10_first' ||
              event.name == 'message_sent_20_first',
        ),
        <_RecordedEvent>[
          const _RecordedEvent('message_sent_10_first', <String, Object>{
            'world_id': 'world-10',
            'location_id': 'location-10',
            'device_id': 'test-device-id',
          }),
          const _RecordedEvent('message_sent_20_first', <String, Object>{
            'world_id': 'world-20',
            'location_id': 'location-20',
            'device_id': 'test-device-id',
          }),
        ],
      );
    },
  );

  test('concurrent sends serialize the persisted threshold count', () async {
    messageSentCount = 8;

    await Future.wait<void>(<Future<void>>[
      FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-9',
        locationId: 'location-9',
      ),
      FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-10',
        locationId: 'location-10',
      ),
    ]);

    expect(messageSentCount, 10);
    expect(
      client.events.where((event) => event.name == 'message_sent_10_first'),
      <_RecordedEvent>[
        const _RecordedEvent('message_sent_10_first', <String, Object>{
          'world_id': 'world-10',
          'location_id': 'location-10',
          'device_id': 'test-device-id',
        }),
      ],
    );
  });

  test('failed logging remains eligible for a later retry', () async {
    client.error = StateError('log failed');
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'google');

    client.error = null;
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'apple');

    expect(client.attempts, 4);
    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('login', <String, Object>{
        'method': 'apple',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('login_first', <String, Object>{
        'method': 'apple',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('failed purchase first events remain eligible for retry', () async {
    client.error = StateError('log failed');
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'google',
      productId: 'gems-1',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-6',
    );

    client.error = null;
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'google',
      productId: 'gems-2',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-7',
    );

    expect(client.attempts, 6);
    expect(client.events.map((event) => event.name), <String>[
      'purchase',
      'purchase_first',
      'gems_first',
    ]);
  });

  test('failed device id lookup remains eligible for a later retry', () async {
    var shouldFail = true;
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(() async {
      if (shouldFail) throw StateError('device id unavailable');
      return 'recovered-device-id';
    });

    await FirebaseAnalyticsMonitoring.recordLogin(method: 'google');
    shouldFail = false;
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'apple');

    expect(client.attempts, 2);
    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('login', <String, Object>{
        'method': 'apple',
        'device_id': 'recovered-device-id',
      }),
      const _RecordedEvent('login_first', <String, Object>{
        'method': 'apple',
        'device_id': 'recovered-device-id',
      }),
    ]);
  });

  test('shared preferences stores integer one only after success', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );

    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'com.worldo.gems.500',
      kind: FirebaseAnalyticsPurchaseKind.gems,
      purchaseIdentity: 'test-purchase-8',
    );
    await FirebaseAnalyticsMonitoring.recordPurchase(
      provider: 'apple',
      productId: 'com.worldo.pro.monthly',
      kind: FirebaseAnalyticsPurchaseKind.subscription,
      purchaseIdentity: 'test-purchase-9',
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt(
        '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
        'purchase_first',
      ),
      1,
    );
    expect(
      preferences.getInt(
        '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
        'gems_first',
      ),
      1,
    );
    expect(
      preferences.getInt(
        '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
        'subscription_first',
      ),
      1,
    );
    expect(
      preferences.getInt(
        '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
        'purchase',
      ),
      isNull,
    );
  });

  test('persisted integer one skips the event after a new app run', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
              'message_sent_first':
          1,
    });
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );

    await FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-1',
      locationId: 'location-1',
    );

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('message_sent', <String, Object>{
        'world_id': 'world-1',
        'location_id': 'location-1',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test(
    'persists message count and threshold once marker across runs',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesFirebaseAnalyticsMessageSentCounter.storageKey: 9,
      });
      FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
        const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
      );
      FirebaseAnalyticsMonitoring.setMessageSentCountIncrementerForTesting(
        const SharedPreferencesFirebaseAnalyticsMessageSentCounter().increment,
      );

      await FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-10',
        locationId: 'location-10',
      );

      var preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt(
          SharedPreferencesFirebaseAnalyticsMessageSentCounter.storageKey,
        ),
        10,
      );
      expect(
        preferences.getInt(
          '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
          'message_sent_10_first',
        ),
        1,
      );

      FirebaseAnalyticsMonitoring.resetForTesting();
      client = _FakeAnalyticsClient();
      FirebaseAnalyticsMonitoring.setClientForTesting(client);
      FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
        const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
      );
      FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
      FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
      FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
        () async => 'test-device-id',
      );

      await FirebaseAnalyticsMonitoring.recordMessageSent(
        worldId: 'world-11',
        locationId: 'location-11',
      );

      preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt(
          SharedPreferencesFirebaseAnalyticsMessageSentCounter.storageKey,
        ),
        11,
      );
      expect(
        client.events.where((event) => event.name == 'message_sent_10_first'),
        isEmpty,
      );
    },
  );

  test('records performance completion with its stable dimensions', () async {
    await FirebaseAnalyticsMonitoring.recordPerformanceOperation(
      surface: 'popular',
      phase: 'render',
      result: 'failure',
      durationMs: 1200,
      attempt: 2,
      dataSource: 'network',
      errorType: 'render_timeout',
    );

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('perf_operation_complete', <String, Object>{
        'surface': 'popular',
        'phase': 'render',
        'result': 'failure',
        'duration_ms': 1200,
        'attempt': 2,
        'data_source': 'network',
        'error_type': 'render_timeout',
      }),
    ]);
  });

  test('performance completion remains a per-operation event', () async {
    for (var attempt = 1; attempt <= 2; attempt += 1) {
      await FirebaseAnalyticsMonitoring.recordPerformanceOperation(
        surface: 'world_page',
        phase: 'request',
        result: 'success',
        durationMs: attempt * 100,
        attempt: attempt,
        dataSource: 'network',
      );
    }

    expect(client.events.map((event) => event.name), <String>[
      'perf_operation_complete',
      'perf_operation_complete',
    ]);
  });

  test(
    'does not wait for Firebase or log when collection is disabled',
    () async {
      final readiness = Completer<void>();
      FirebaseAnalyticsMonitoring.setEnabledForTesting(false);
      FirebaseAnalyticsMonitoring.setReadinessForTesting(readiness.future);

      await FirebaseAnalyticsMonitoring.recordLaunch(
        originId: 'origin-1',
        roleType: 'preset',
      );

      expect(client.events, isEmpty);
    },
  );

  test('defaults to disabled outside a release build', () async {
    final readiness = Completer<void>();
    FirebaseAnalyticsMonitoring.setEnabledForTesting(null);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(readiness.future);

    await FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-1',
      locationId: 'location-1',
    );

    expect(client.events, isEmpty);
  });

  test('waits for shared Firebase readiness before logging', () async {
    final readiness = Completer<void>();
    FirebaseAnalyticsMonitoring.setReadinessForTesting(readiness.future);

    final recording = FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-1',
      locationId: 'location-1',
    );
    await Future<void>.delayed(Duration.zero);
    expect(client.events, isEmpty);

    readiness.complete();
    await recording;

    expect(client.events, hasLength(2));
  });

  test('Firebase failures stay best-effort', () async {
    client.error = StateError('log failed');

    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );

    expect(client.attempts, 2);
  });

  test('Firebase readiness failures stay best-effort', () async {
    final deviceId = Completer<String>();
    final readiness = Completer<void>();
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () => deviceId.future,
    );
    FirebaseAnalyticsMonitoring.setReadinessForTesting(readiness.future);

    final recording = FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );
    deviceId.complete('test-device-id');
    await Future<void>.delayed(Duration.zero);
    readiness.completeError(StateError('initialize failed'));
    await recording;

    expect(client.attempts, 0);
  });
}

class _FakeAnalyticsClient implements AppAnalyticsClient {
  final List<_RecordedEvent> events = <_RecordedEvent>[];
  Object? error;
  final Set<String> failedEventNames = {};
  int attempts = 0;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    attempts += 1;
    if (failedEventNames.contains(name)) throw StateError('SDK unavailable');
    final failure = error;
    if (failure != null) throw failure;
    events.add(_RecordedEvent(name, parameters ?? const <String, Object>{}));
  }
}

class _MemoryOnceEventStore implements FirebaseAnalyticsOnceEventStore {
  final Set<String> sentEvents = <String>{};

  @override
  Future<void> markSent(String eventName) async {
    sentEvents.add(eventName);
  }

  @override
  Future<bool> wasSent(String eventName) async {
    return sentEvents.contains(eventName);
  }
}

class _MemoryDay0AnchorStore implements FirebaseAnalyticsDay0AnchorStore {
  _MemoryDay0AnchorStore({this.failWrites = 0});

  DateTime? value;
  int failWrites;
  int successfulWrites = 0;

  @override
  Future<DateTime?> read() async => value;

  @override
  Future<void> write(DateTime serverUtc) async {
    if (failWrites > 0) {
      failWrites -= 1;
      throw StateError('storage unavailable');
    }
    successfulWrites += 1;
    value = serverUtc.toUtc();
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;

  @override
  bool operator ==(Object other) {
    return other is _RecordedEvent &&
        other.name == name &&
        _mapsEqual(other.parameters, parameters);
  }

  @override
  int get hashCode => Object.hash(
    name,
    Object.hashAllUnordered(
      parameters.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() => '_RecordedEvent($name, $parameters)';
}

bool _mapsEqual(Map<String, Object> first, Map<String, Object> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}
