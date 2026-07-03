import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../platform/app/app_metadata_service.dart';
import '../../platform/privacy/app_tracking_transparency_service.dart';
import '../bootstrap/app_bootstrap.dart';
import '../bootstrap/service_registry.dart';
import '../telemetry/genesis_telemetry.dart';

class AppStartupCoordinator {
  AppStartupCoordinator._();

  static DateTime? _startedAt;
  static AppVersionInfo? _appVersion;
  static Future<void>? _telemetryInitialization;
  static bool _warmUpStarted = false;
  static bool _telemetryLifecycleObserverAdded = false;

  static void configure({
    required DateTime startedAt,
    required AppVersionInfo appVersion,
  }) {
    _startedAt = startedAt;
    _appVersion = appVersion;
  }

  static void startFirebasePerformance() {
    unawaited(AppBootstrap.ensureFirebasePerformanceMonitoring());
  }

  static void startWarmUp(AppServices services) {
    if (_warmUpStarted) return;
    _warmUpStarted = true;
    unawaited(AppBootstrap.warmUp(services));
  }

  static Future<void> initializeTelemetry({
    required AppServices services,
    required AppTrackingAuthorizationStatus trackingAuthorizationStatus,
  }) {
    return _telemetryInitialization ??= _initializeTelemetry(
      services: services,
      trackingAuthorizationStatus: trackingAuthorizationStatus,
    );
  }

  static Future<void> _initializeTelemetry({
    required AppServices services,
    required AppTrackingAuthorizationStatus trackingAuthorizationStatus,
  }) async {
    final version = _appVersion ?? await AppMetadataService.appVersion();
    await GenesisTelemetry.initialize(
      config: services.config,
      deviceIdService: services.deviceId,
      appVersion: version,
      trackingEnabled: trackingAuthorizationStatus.allowsTracking,
    );
    if (_telemetryLifecycleObserverAdded) return;
    _telemetryLifecycleObserverAdded = true;
    WidgetsBinding.instance.addObserver(
      GenesisTelemetryLifecycleObserver(
        startedAt: _startedAt ?? DateTime.now(),
      ),
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _startedAt = null;
    _appVersion = null;
    _telemetryInitialization = null;
    _warmUpStarted = false;
    _telemetryLifecycleObserverAdded = false;
  }
}
