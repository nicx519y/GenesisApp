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
  static Timer? _telemetryMetadataRetryTimer;
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

  static Future<void> initializeTelemetry({
    required AppServices services,
    Future<AppVersionInfo> Function()? appVersionReader,
    Duration appVersionTimeout = const Duration(seconds: 1),
    Duration deviceIdTimeout = const Duration(seconds: 2),
    List<Duration> metadataRetryDelays = const <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
  }) {
    return _telemetryInitialization ??= _initializeTelemetry(
      services: services,
      appVersionReader: appVersionReader,
      appVersionTimeout: appVersionTimeout,
      deviceIdTimeout: deviceIdTimeout,
      metadataRetryDelays: metadataRetryDelays,
    );
  }

  static Future<void> _initializeTelemetry({
    required AppServices services,
    required Future<AppVersionInfo> Function()? appVersionReader,
    required Duration appVersionTimeout,
    required Duration deviceIdTimeout,
    required List<Duration> metadataRetryDelays,
  }) async {
    try {
      await GenesisTelemetry.initialize(
        config: services.config,
        deviceIdService: services.deviceId,
        appVersion: _appVersion,
        appVersionReader: appVersionReader ?? AppMetadataService.appVersion,
        appVersionTimeout: appVersionTimeout,
        deviceIdTimeout: deviceIdTimeout,
        // ATT only controls the tracking permission state; first-party telemetry
        // remains enabled even when the user denies or cannot answer the prompt.
        trackingEnabled: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[Telemetry] initialization failed: $error\n$stackTrace');
    } finally {
      GenesisTelemetry.startCollectUploader();
    }
    _scheduleTelemetryMetadataRetry(
      services: services,
      appVersionReader: appVersionReader,
      appVersionTimeout: appVersionTimeout,
      deviceIdTimeout: deviceIdTimeout,
      retryDelays: metadataRetryDelays,
    );
    if (_telemetryLifecycleObserverAdded) return;
    _telemetryLifecycleObserverAdded = true;
    final observer = GenesisTelemetryLifecycleObserver();
    _telemetryLifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  static void _scheduleTelemetryMetadataRetry({
    required AppServices services,
    required Future<AppVersionInfo> Function()? appVersionReader,
    required Duration appVersionTimeout,
    required Duration deviceIdTimeout,
    required List<Duration> retryDelays,
    int retryIndex = 0,
  }) {
    if (GenesisTelemetry.hasCompleteContextMetadata ||
        retryIndex >= retryDelays.length) {
      return;
    }
    _telemetryMetadataRetryTimer?.cancel();
    _telemetryMetadataRetryTimer = Timer(retryDelays[retryIndex], () async {
      try {
        await GenesisTelemetry.refreshContextMetadata(
          deviceIdService: services.deviceId,
          appVersionReader: appVersionReader ?? AppMetadataService.appVersion,
          appVersionTimeout: appVersionTimeout,
          deviceIdTimeout: deviceIdTimeout,
        );
      } catch (error, stackTrace) {
        debugPrint('[Telemetry] metadata refresh failed: $error\n$stackTrace');
      } finally {
        _scheduleTelemetryMetadataRetry(
          services: services,
          appVersionReader: appVersionReader,
          appVersionTimeout: appVersionTimeout,
          deviceIdTimeout: deviceIdTimeout,
          retryDelays: retryDelays,
          retryIndex: retryIndex + 1,
        );
      }
    });
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
    _telemetryMetadataRetryTimer?.cancel();
    _telemetryMetadataRetryTimer = null;
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
