import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'firebase_analytics_monitoring.dart';
import 'firebase_crash_reporting.dart';
import 'firebase_performance_monitoring.dart';
import 'firebase_runtime.dart';
import 'genesis_telemetry.dart';
import 'telemetry_upload_policy.dart';

class TelemetryRuntimeController {
  const TelemetryRuntimeController._();

  static Future<void> _queue = Future<void>.value();
  static bool _initialized = false;

  static Future<void> initialize(
    AppConfig config, {
    VoidCallback? onCollectReady,
  }) {
    return _enqueue(() async {
      final state = await TelemetryUploadPolicy.initialize(config);
      _initialized = true;
      await _apply(config, state, onCollectReady: onCollectReady);
    });
  }

  static Future<void> updateConfig(AppConfig config) {
    return _enqueue(() async {
      final state = TelemetryUploadPolicy.updateConfig(config);
      if (!_initialized) return;
      await _apply(config, state);
    });
  }

  static Future<void> setDebugOverrideEnabled({
    required AppConfig config,
    required TelemetryChannel channel,
    required bool enabled,
  }) {
    return _enqueue(() async {
      TelemetryUploadPolicy.updateConfig(config);
      final state = await TelemetryUploadPolicy.setDebugOverrideEnabled(
        channel,
        enabled: enabled,
      );
      if (!_initialized) return;
      await _apply(config, state);
    });
  }

  static Future<void> refresh(AppConfig config) => updateConfig(config);

  static Future<void> _apply(
    AppConfig config,
    TelemetryUploadState state, {
    VoidCallback? onCollectReady,
  }) async {
    GenesisTelemetry.reconfigureCollect(config);
    // Cold-start records only depend on the durable Collect queue. Queue them
    // before Firebase initialization so a slow or failed Firebase bootstrap
    // cannot remove the startup from the monitoring denominator.
    onCollectReady?.call();
    try {
      await FirebaseRuntime.ensureInitialized();
      await Future.wait<void>(<Future<void>>[
        FirebaseAnalyticsMonitoring.configureCollection(
          enabled: state.analyticsEnabled,
          appEnvironment: state.appEnvironment,
        ),
        FirebasePerformanceMonitoring.configure(state.performanceEnabled),
        FirebaseCrashReporting.configure(state.crashlyticsEnabled),
      ]);
    } catch (error, stackTrace) {
      debugPrint('[Telemetry] runtime configuration failed: $error');
      debugPrint('[Telemetry] stacktrace:\n$stackTrace');
    }
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.catchError((_) {});
    return result;
  }

  @visibleForTesting
  static void resetForTesting() {
    _queue = Future<void>.value();
    _initialized = false;
  }
}
