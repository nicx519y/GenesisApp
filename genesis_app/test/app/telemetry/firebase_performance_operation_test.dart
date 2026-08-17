import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_performance_monitoring.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_performance_operation.dart';

void main() {
  late _FakeAnalyticsClient analytics;
  late List<_FakePerformanceTrace> traces;

  setUp(() {
    FirebasePerformanceMonitoring.resetForTesting();
    FirebaseAnalyticsMonitoring.resetForTesting();
    analytics = _FakeAnalyticsClient();
    traces = <_FakePerformanceTrace>[];
    FirebaseAnalyticsMonitoring.setClientForTesting(analytics);
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((name) {
      final trace = _FakePerformanceTrace(name);
      traces.add(trace);
      return trace;
    });
  });

  tearDown(() {
    FirebasePerformanceMonitoring.resetForTesting();
    FirebaseAnalyticsMonitoring.resetForTesting();
  });

  test('success stops one trace and emits one GA4 completion', () async {
    final operation = await FirebasePerformanceOperation.start(
      surface: FirebasePerformanceSurface.myWorlds,
      phase: FirebasePerformancePhase.request,
      attempt: 2,
    );

    await operation.succeed();
    await operation.fail(errorType: 'late_failure');

    expect(traces, hasLength(1));
    expect(traces.single.name, 'my_worlds_first_request');
    expect(traces.single.stopCalls, 1);
    expect(traces.single.attributes, <String, String>{
      'phase': 'request',
      'data_source': 'network',
      'attempt': '2',
      'result': 'success',
    });
    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, 'perf_operation_complete');
    expect(
      analytics.events.single.parameters,
      containsPair('result', 'success'),
    );
    expect(analytics.events.single.parameters, containsPair('attempt', 2));
  });

  test('render timeout records failure exactly once', () async {
    final operation = await FirebasePerformanceOperation.start(
      surface: FirebasePerformanceSurface.originWorldPage,
      phase: FirebasePerformancePhase.render,
      dataSource: FirebasePerformanceDataSource.prefetched,
      timeout: const Duration(milliseconds: 5),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await operation.succeed();

    expect(operation.isCompleted, isTrue);
    expect(traces.single.stopCalls, 1);
    expect(traces.single.attributes['result'], 'failure');
    expect(traces.single.attributes['error_type'], 'render_timeout');
    expect(analytics.events, hasLength(1));
    expect(
      analytics.events.single.parameters,
      containsPair('result', 'failure'),
    );
    expect(
      analytics.events.single.parameters,
      containsPair('data_source', 'prefetched'),
    );
  });

  test('failure and cancellation remain distinct GA4 outcomes', () async {
    final failed = await FirebasePerformanceOperation.start(
      surface: FirebasePerformanceSurface.popular,
      phase: FirebasePerformancePhase.request,
      attempt: 1,
    );
    final cancelled = await FirebasePerformanceOperation.start(
      surface: FirebasePerformanceSurface.popular,
      phase: FirebasePerformancePhase.request,
      attempt: 2,
    );

    await failed.fail(errorType: 'parse');
    await cancelled.cancel();

    expect(traces, hasLength(2));
    expect(traces[0].attributes, containsPair('result', 'failure'));
    expect(traces[0].attributes, containsPair('error_type', 'parse'));
    expect(traces[1].attributes, containsPair('result', 'cancelled'));
    expect(traces[1].attributes, isNot(contains('error_type')));
    expect(
      analytics.events.map((event) => event.parameters['result']),
      <Object?>['failure', 'cancelled'],
    );
    expect(
      analytics.events
          .where((event) => event.parameters['result'] != 'cancelled')
          .length,
      1,
      reason: 'cancelled events are excluded from the success-rate denominator',
    );
  });

  test('all ten trace names remain stable', () {
    expect(
      <String>{
        for (final surface in FirebasePerformanceSurface.values)
          for (final phase in FirebasePerformancePhase.values)
            firebasePerformanceTraceNameForTesting(surface, phase),
      },
      <String>{
        'my_worlds_first_request',
        'my_worlds_first_render',
        'popular_first_request',
        'popular_first_render',
        'worldo_first_request',
        'worldo_first_render',
        'world_page_request',
        'world_page_render',
        'origin_world_page_request',
        'origin_world_page_render',
      },
    );
  });
}

class _FakePerformanceTrace implements AppPerformanceTrace {
  _FakePerformanceTrace(this.name);

  final String name;
  final Map<String, String> attributes = <String, String>{};
  var stopCalls = 0;

  @override
  void putAttribute(String name, String value) {
    attributes[name] = value;
  }

  @override
  void setMetric(String name, int value) {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _FakeAnalyticsClient implements AppAnalyticsClient {
  final List<_RecordedEvent> events = <_RecordedEvent>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_RecordedEvent(name, parameters ?? const <String, Object>{}));
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}
