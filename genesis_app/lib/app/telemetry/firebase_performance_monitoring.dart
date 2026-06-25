import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

class FirebasePerformanceMonitoring {
  const FirebasePerformanceMonitoring._();

  static Future<void> enable() async {
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      debugPrint('[Telemetry][FirebasePerformance] collection enabled');
    } catch (e, st) {
      debugPrint('[Telemetry][FirebasePerformance] enable failed: $e');
      debugPrint('[Telemetry][FirebasePerformance] stacktrace:\n$st');
    }
  }
}
