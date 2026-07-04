import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

class FirebasePerformanceMonitoring {
  const FirebasePerformanceMonitoring._();

  static Future<void>? _initialization;
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> enable() {
    return _initialization ??= _enable();
  }

  static Future<void> _enable() async {
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

  @visibleForTesting
  static void resetForTesting() {
    _initialization = null;
    _ready = false;
  }

  @visibleForTesting
  static void setReadyForTesting(bool value) {
    _ready = value;
  }
}
