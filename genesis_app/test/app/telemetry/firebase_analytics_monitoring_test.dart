import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';

void main() {
  late _FakeAnalyticsClient client;

  setUp(() {
    FirebaseAnalyticsMonitoring.resetForTesting();
    client = _FakeAnalyticsClient();
    FirebaseAnalyticsMonitoring.setClientForTesting(client);
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
  });
  tearDown(FirebaseAnalyticsMonitoring.resetForTesting);

  test('records the three custom events with their exact parameters', () async {
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

    expect(client.events, <_RecordedEvent>[
      const _RecordedEvent('launch', <String, Object>{
        'origin_id': 'origin-1',
        'role_type': 'preset',
      }),
      const _RecordedEvent('launch_success', <String, Object>{
        'origin_id': 'origin-2',
        'role_type': 'custom',
        'world_id': 'world-2',
      }),
      const _RecordedEvent('message_sent', <String, Object>{
        'world_id': 'world-3',
        'location_id': 'location-3',
      }),
    ]);
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
    FirebaseAnalyticsMonitoring.setReadinessForTesting(
      Future<void>.error(StateError('initialize failed')),
    );

    await FirebaseAnalyticsMonitoring.recordLaunch(
      originId: 'origin-1',
      roleType: 'preset',
    );

    expect(client.attempts, 0);
  });
}

class _FakeAnalyticsClient implements AppAnalyticsClient {
  final List<_RecordedEvent> events = <_RecordedEvent>[];
  Object? error;
  int attempts = 0;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    attempts += 1;
    final failure = error;
    if (failure != null) throw failure;
    events.add(_RecordedEvent(name, parameters ?? const <String, Object>{}));
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
