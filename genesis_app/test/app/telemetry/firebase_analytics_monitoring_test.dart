import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAnalyticsClient client;

  setUp(() {
    FirebaseAnalyticsMonitoring.resetForTesting();
    client = _FakeAnalyticsClient();
    FirebaseAnalyticsMonitoring.setClientForTesting(client);
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      _MemoryOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () async => 'test-device-id',
    );
  });
  tearDown(FirebaseAnalyticsMonitoring.resetForTesting);

  test('records the five once events with their exact parameters', () async {
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
    );

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('launch', <String, Object>{
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
      const _RecordedEvent('message_sent', <String, Object>{
        'world_id': 'world-3',
        'location_id': 'location-3',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('login', <String, Object>{
        'method': 'google',
        'device_id': 'test-device-id',
      }),
      const _RecordedEvent('purchase', <String, Object>{
        'provider': 'google',
        'product_id': 'worldo_gems_500',
        'device_id': 'test-device-id',
      }),
    ]);
  });

  test('once events skip later triggers after the first success', () async {
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
    ]);
  });

  test('concurrent once-event triggers share one recording', () async {
    final releaseLog = Completer<void>();
    client.beforeLog = () => releaseLog.future;

    final first = FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-1',
      locationId: 'location-1',
    );
    final second = FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-2',
      locationId: 'location-2',
    );
    await Future<void>.delayed(Duration.zero);

    expect(client.attempts, 1);
    releaseLog.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(client.events, hasLength(1));
  });

  test('failed logging remains eligible for a later retry', () async {
    client.error = StateError('log failed');
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'google');

    client.error = null;
    await FirebaseAnalyticsMonitoring.recordLogin(method: 'apple');

    expect(client.attempts, 2);
    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('login', <String, Object>{
        'method': 'apple',
        'device_id': 'test-device-id',
      }),
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

    expect(client.attempts, 1);
    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('login', <String, Object>{
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
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt(
        '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
        'purchase',
      ),
      1,
    );
  });

  test('persisted integer one skips the event after a new app run', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      '${SharedPreferencesFirebaseAnalyticsOnceEventStore.storageKeyPrefix}'
              'message_sent':
          1,
    });
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      const SharedPreferencesFirebaseAnalyticsOnceEventStore(),
    );

    await FirebaseAnalyticsMonitoring.recordMessageSent(
      worldId: 'world-1',
      locationId: 'location-1',
    );

    expect(client.events, isEmpty);
  });

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

    expect(client.events, hasLength(1));
  });

  test('Firebase failures stay best-effort', () async {
    client.error = StateError('log failed');

    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );

    expect(client.attempts, 1);
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
  int attempts = 0;
  Future<void> Function()? beforeLog;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    attempts += 1;
    await beforeLog?.call();
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
