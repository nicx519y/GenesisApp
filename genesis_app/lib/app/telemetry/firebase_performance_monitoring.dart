import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_upload_policy.dart';

abstract interface class AppPerformanceTrace {
  Future<void> start();

  Future<void> stop();

  void putAttribute(String name, String value);

  void setMetric(String name, int value);
}

typedef AppPerformanceTraceFactory =
    AppPerformanceTrace Function(String traceName);

class FirebasePerformanceMonitoring {
  const FirebasePerformanceMonitoring._();

  static const Duration instrumentationTimeout = Duration(milliseconds: 500);

  static bool _ready = false;
  static bool _circuitBroken = false;
  static AppPerformanceTraceFactory _traceFactory =
      _createFirebasePerformanceTrace;

  static bool get isReady => _ready && !_circuitBroken;

  static bool get isCircuitBroken => _circuitBroken;

  static Future<void> enable() {
    return configure(TelemetryUploadPolicy.state.value.performanceEnabled);
  }

  static Future<void> configure(bool enabled) {
    return _configure(enabled);
  }

  static Future<void> _configure(bool enabled) async {
    final effectiveEnabled = enabled && !_circuitBroken;
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        effectiveEnabled,
      );
      _ready = effectiveEnabled;
      debugPrint(
        '[Telemetry][FirebasePerformance] collection '
        '${effectiveEnabled ? 'enabled' : 'disabled'}',
      );
    } catch (e, st) {
      _ready = false;
      debugPrint('[Telemetry][FirebasePerformance] configure failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
  }

  static Future<AppPerformanceTrace?> startTrace(
    String name, {
    Map<String, String> attributes = const <String, String>{},
  }) async {
    if (!isReady) return null;
    AppPerformanceTrace? trace;
    try {
      trace = _traceFactory(name);
      for (final entry in attributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      final startFuture = trace.start();
      try {
        await startFuture.timeout(instrumentationTimeout);
      } on TimeoutException catch (e, st) {
        disableForCurrentProcess('trace_start_timeout');
        unawaited(_stopTraceAfterStartCompletes(trace, startFuture));
        debugPrint(
          '[Telemetry][FirebasePerformance] trace $name start timed out: $e',
        );
        debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
        return null;
      }
      return trace;
    } catch (e, st) {
      if (trace != null) {
        _stopTraceDetached(trace);
      }
      debugPrint(
        '[Telemetry][FirebasePerformance] trace $name start failed: $e',
      );
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
      return null;
    }
  }

  static Future<void> stopTrace(
    AppPerformanceTrace? trace, {
    Map<String, String> attributes = const <String, String>{},
    Map<String, int> metrics = const <String, int>{},
  }) async {
    if (trace == null) return;
    try {
      for (final entry in attributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      for (final entry in metrics.entries) {
        trace.setMetric(entry.key, entry.value);
      }
    } catch (e, st) {
      debugPrint('[Telemetry][FirebasePerformance] trace metadata failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
    _stopTraceDetached(trace);
  }

  static void disableForCurrentProcess(String reason) {
    if (_circuitBroken) return;
    _circuitBroken = true;
    _ready = false;
    debugPrint(
      '[Telemetry][FirebasePerformance] disabled for current process: $reason',
    );
  }

  static Future<void> _stopTraceAfterStartCompletes(
    AppPerformanceTrace trace,
    Future<void> startFuture,
  ) async {
    try {
      await startFuture;
    } catch (_) {
      return;
    }
    _stopTraceDetached(trace);
  }

  static void _stopTraceDetached(AppPerformanceTrace trace) {
    Future<void> stopFuture;
    try {
      stopFuture = trace.stop();
    } catch (e, st) {
      debugPrint('[Telemetry][FirebasePerformance] trace stop failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
      return;
    }
    unawaited(_observeTraceStop(stopFuture));
  }

  static Future<void> _observeTraceStop(Future<void> stopFuture) async {
    try {
      await stopFuture.timeout(instrumentationTimeout);
    } on TimeoutException catch (e, st) {
      disableForCurrentProcess('trace_stop_timeout');
      debugPrint('[Telemetry][FirebasePerformance] trace stop timed out: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    } catch (e, st) {
      debugPrint('[Telemetry][FirebasePerformance] trace stop failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _ready = false;
    _circuitBroken = false;
    _traceFactory = _createFirebasePerformanceTrace;
  }

  @visibleForTesting
  static void setReadyForTesting(bool value) {
    _ready = value;
  }

  @visibleForTesting
  static void setTraceFactoryForTesting(AppPerformanceTraceFactory value) {
    _traceFactory = value;
  }
}

class _FirebaseAppPerformanceTrace implements AppPerformanceTrace {
  _FirebaseAppPerformanceTrace(this._trace);

  final Trace _trace;

  @override
  Future<void> start() => _trace.start();

  @override
  Future<void> stop() => _trace.stop();

  @override
  void putAttribute(String name, String value) {
    _trace.putAttribute(name, value);
  }

  @override
  void setMetric(String name, int value) {
    _trace.setMetric(name, value);
  }
}

AppPerformanceTrace _createFirebasePerformanceTrace(String traceName) {
  return _FirebaseAppPerformanceTrace(
    FirebasePerformance.instance.newTrace(traceName),
  );
}
