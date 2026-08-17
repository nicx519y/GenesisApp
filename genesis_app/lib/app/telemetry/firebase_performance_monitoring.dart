import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import '../config/app_flavor_config.dart';

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

  static Future<void>? _initialization;
  static bool _ready = false;
  static AppPerformanceTraceFactory _traceFactory =
      _createFirebasePerformanceTrace;

  static bool get isReady => _ready;

  static Future<void> enable() {
    return _initialization ??= _enable();
  }

  static Future<void> _enable() async {
    if (!kReleaseMode || AppFlavorConfig.currentIsInternal) {
      try {
        await FirebasePerformance.instance.setPerformanceCollectionEnabled(
          false,
        );
        _ready = false;
        debugPrint(
          '[Telemetry][FirebasePerformance] collection disabled '
          'for non-production build',
        );
      } catch (e, st) {
        _ready = false;
        _initialization = null;
        debugPrint('[Telemetry][FirebasePerformance] disable failed: $e');
        debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
      }
      return;
    }

    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      _ready = true;
      debugPrint('[Telemetry][FirebasePerformance] collection enabled');
    } catch (e, st) {
      _ready = false;
      _initialization = null;
      debugPrint('[Telemetry][FirebasePerformance] enable failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
  }

  static Future<AppPerformanceTrace?> startTrace(
    String name, {
    Map<String, String> attributes = const <String, String>{},
  }) async {
    if (!_ready) return null;
    AppPerformanceTrace? trace;
    try {
      trace = _traceFactory(name);
      for (final entry in attributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      await trace.start();
      return trace;
    } catch (e, st) {
      if (trace != null) {
        try {
          await trace.stop();
        } catch (_) {
          // The trace may not have started. Keep telemetry best-effort.
        }
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
    try {
      await trace.stop();
    } catch (e, st) {
      debugPrint('[Telemetry][FirebasePerformance] trace stop failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialization = null;
    _ready = false;
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
