import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../platform/app/app_metadata_service.dart';
import '../bootstrap/app_bootstrap.dart';
import '../bootstrap/service_registry.dart';
import '../telemetry/genesis_telemetry.dart';

class AppStartupCoordinator {
  AppStartupCoordinator._();

  static AppVersionInfo? _appVersion;
  static Future<void>? _telemetryInitialization;
  static bool _warmUpStarted = false;
  static bool _telemetryLifecycleObserverAdded = false;
  static GenesisTelemetryLifecycleObserver? _telemetryLifecycleObserver;
  static bool _startupFirstReportRecorded = false;
  static bool _attRequestClaimed = false;
  // Kept as a shared startup readiness signal for upgrade/polling work. It is
  // open from the beginning and is unrelated to ATT or network permission.
  static final ValueNotifier<bool> _postLaunchWorkAllowed = ValueNotifier<bool>(
    true,
  );

  static ValueListenable<bool> get postLaunchWorkAllowedListenable =>
      _postLaunchWorkAllowed;

  static bool get isPostLaunchWorkAllowed => _postLaunchWorkAllowed.value;

  static void configure({AppVersionInfo? appVersion}) {
    _appVersion = appVersion;
    // ATT is an independent post-launch prompt. It never gates startup work.
    _postLaunchWorkAllowed.value = true;
  }

  static void startFirebasePerformance() {
    unawaited(AppBootstrap.ensureFirebasePerformanceMonitoring());
  }

  static bool claimAttRequest() {
    if (_attRequestClaimed) return false;
    _attRequestClaimed = true;
    return true;
  }

  static void startWarmUp(AppServices services) {
    if (_warmUpStarted) return;
    _warmUpStarted = true;
    unawaited(AppBootstrap.warmUp(services));
  }

  static Future<void> initializeTelemetry({required AppServices services}) {
    return _telemetryInitialization ??= _initializeTelemetry(
      services: services,
    );
  }

  static Future<void> _initializeTelemetry({
    required AppServices services,
  }) async {
    final version = _appVersion ?? await AppMetadataService.appVersion();
    await GenesisTelemetry.initialize(
      config: services.config,
      deviceIdService: services.deviceId,
      appVersion: version,
      // ATT only controls the tracking permission state; first-party telemetry
      // remains enabled even when the user denies or cannot answer the prompt.
      trackingEnabled: true,
    );
    GenesisTelemetry.startCollectUploader();
    if (_telemetryLifecycleObserverAdded) return;
    _telemetryLifecycleObserverAdded = true;
    final observer = GenesisTelemetryLifecycleObserver();
    _telemetryLifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  static void recordStartupFirstReport() {
    if (_startupFirstReportRecorded) return;
    _startupFirstReportRecorded = true;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'startup_first_report',
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    _appVersion = null;
    _telemetryInitialization = null;
    _warmUpStarted = false;
    _telemetryLifecycleObserverAdded = false;
    final observer = _telemetryLifecycleObserver;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _telemetryLifecycleObserver = null;
    }
    _startupFirstReportRecorded = false;
    _attRequestClaimed = false;
    _postLaunchWorkAllowed.value = true;
  }
}
