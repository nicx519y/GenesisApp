import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_performance_monitoring.dart';

void main() {
  setUp(FirebasePerformanceMonitoring.resetForTesting);
  tearDown(FirebasePerformanceMonitoring.resetForTesting);

  test('does not create a custom trace before performance is ready', () async {
    var factoryCalls = 0;
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((_) {
      factoryCalls += 1;
      return _FakePerformanceTrace();
    });

    final trace = await FirebasePerformanceMonitoring.startTrace(
      'tilemap_load',
    );

    expect(trace, isNull);
    expect(factoryCalls, 0);
  });

  test('starts and stops a custom trace with attributes and metrics', () async {
    final fakeTrace = _FakePerformanceTrace();
    final traceNames = <String>[];
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((name) {
      traceNames.add(name);
      return fakeTrace;
    });

    final trace = await FirebasePerformanceMonitoring.startTrace(
      'tilemap_load',
      attributes: const <String, String>{'source': 'world'},
    );
    await FirebasePerformanceMonitoring.stopTrace(
      trace,
      attributes: const <String, String>{'result': 'success'},
      metrics: const <String, int>{
        'tile_count': 12,
        'map_width': 4,
        'map_height': 3,
      },
    );

    expect(traceNames, const <String>['tilemap_load']);
    expect(fakeTrace.started, isTrue);
    expect(fakeTrace.stopped, isTrue);
    expect(fakeTrace.attributes, const <String, String>{
      'source': 'world',
      'result': 'success',
    });
    expect(fakeTrace.metrics, const <String, int>{
      'tile_count': 12,
      'map_width': 4,
      'map_height': 3,
    });
  });

  test('trace failures stay best-effort', () async {
    final fakeTrace = _FakePerformanceTrace(failStart: true);
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((_) => fakeTrace);

    final trace = await FirebasePerformanceMonitoring.startTrace(
      'tilemap_load',
    );

    expect(trace, isNull);
    expect(fakeTrace.stopCalls, 1);
  });

  test(
    'trace start timeout returns disabled and opens circuit breaker',
    () async {
      final startCompleter = Completer<void>();
      final fakeTrace = _FakePerformanceTrace(startCompleter: startCompleter);
      var factoryCalls = 0;
      FirebasePerformanceMonitoring.setReadyForTesting(true);
      FirebasePerformanceMonitoring.setTraceFactoryForTesting((_) {
        factoryCalls += 1;
        return fakeTrace;
      });

      final trace = await FirebasePerformanceMonitoring.startTrace(
        'stuck_trace',
      );

      expect(trace, isNull);
      expect(FirebasePerformanceMonitoring.isCircuitBroken, isTrue);
      expect(fakeTrace.stopCalls, 0);
      expect(
        await FirebasePerformanceMonitoring.startTrace('skipped_trace'),
        isNull,
      );
      expect(factoryCalls, 1);

      startCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      expect(fakeTrace.stopCalls, 1);
    },
  );

  test('trace stop never blocks its caller', () async {
    final stopCompleter = Completer<void>();
    final fakeTrace = _FakePerformanceTrace(stopCompleter: stopCompleter);
    FirebasePerformanceMonitoring.setReadyForTesting(true);
    FirebasePerformanceMonitoring.setTraceFactoryForTesting((_) => fakeTrace);
    final trace = await FirebasePerformanceMonitoring.startTrace('trace');

    await FirebasePerformanceMonitoring.stopTrace(
      trace,
    ).timeout(const Duration(milliseconds: 50));

    expect(fakeTrace.stopCalls, 1);
    stopCompleter.complete();
  });
}

class _FakePerformanceTrace implements AppPerformanceTrace {
  _FakePerformanceTrace({
    this.failStart = false,
    this.startCompleter,
    this.stopCompleter,
  });

  final bool failStart;
  final Completer<void>? startCompleter;
  final Completer<void>? stopCompleter;
  final Map<String, String> attributes = <String, String>{};
  final Map<String, int> metrics = <String, int>{};
  bool started = false;
  bool stopped = false;
  int stopCalls = 0;

  @override
  void putAttribute(String name, String value) {
    attributes[name] = value;
  }

  @override
  void setMetric(String name, int value) {
    metrics[name] = value;
  }

  @override
  Future<void> start() async {
    if (failStart) throw StateError('start failed');
    started = true;
    await startCompleter?.future;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    stopped = true;
    await stopCompleter?.future;
  }
}
