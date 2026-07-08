import 'dart:async';

import 'package:flutter/foundation.dart';
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
  static bool _startupFirstReportRecorded = false;
  static final ValueNotifier<bool> _postLaunchWorkAllowed = ValueNotifier<bool>(
    true,
  );

  static ValueListenable<bool> get postLaunchWorkAllowedListenable =>
      _postLaunchWorkAllowed;

  static bool get isPostLaunchWorkAllowed => _postLaunchWorkAllowed.value;

  static void configure({
    required DateTime startedAt,
    AppVersionInfo? appVersion,
  }) {
    _startedAt = startedAt;
    _appVersion = appVersion;
    _postLaunchWorkAllowed.value = defaultTargetPlatform != TargetPlatform.iOS;
  }

  static void markPostLaunchWorkAllowed() {
    if (_postLaunchWorkAllowed.value) return;
    _postLaunchWorkAllowed.value = true;
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
    _recordStartupFirstReport();
    if (_telemetryLifecycleObserverAdded) return;
    _telemetryLifecycleObserverAdded = true;
    WidgetsBinding.instance.addObserver(
      GenesisTelemetryLifecycleObserver(
        startedAt: _startedAt ?? DateTime.now(),
      ),
    );
  }

  static void _recordStartupFirstReport() {
    if (_startupFirstReportRecorded) return;
    _startupFirstReportRecorded = true;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'startup_first_report',
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _startedAt = null;
    _appVersion = null;
    _telemetryInitialization = null;
    _warmUpStarted = false;
    _telemetryLifecycleObserverAdded = false;
    _startupFirstReportRecorded = false;
    _postLaunchWorkAllowed.value = true;
  }
}
