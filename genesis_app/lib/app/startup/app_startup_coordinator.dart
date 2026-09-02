import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

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
  static Stopwatch? _launchStopwatch;
  static String? _launchStartupId;
  static String? _launchPage;
  static String? _launchPageReason;
  static bool _launchStartupRecorded = false;
  static bool _launchPageRecorded = false;
  static bool _launchRequestStarted = false;
  static bool _launchRequestEnded = false;
  static bool _launchRenderRecorded = false;
  static bool _attRequestClaimed = false;
  // Kept as a shared startup readiness signal for upgrade/polling work. It is
  // open from the beginning and is unrelated to ATT or network permission.
  static final ValueNotifier<bool> _postLaunchWorkAllowed = ValueNotifier<bool>(
    true,
  );

  static ValueListenable<bool> get postLaunchWorkAllowedListenable =>
      _postLaunchWorkAllowed;

  static bool get isPostLaunchWorkAllowed => _postLaunchWorkAllowed.value;

  static bool get isLaunchTrackingActive => _launchStopwatch != null;

  static String resolveLaunchPageReason({
    required bool hasSession,
    required bool sessionReadFailed,
    required bool hasHomeCache,
    required bool hasWorldoCache,
  }) {
    if (sessionReadFailed) return 'session_error';
    if (!hasSession) {
      return hasWorldoCache
          ? 'no_session_worldo_cache_hit'
          : 'no_session_worldo_cache_miss';
    }
    if (hasHomeCache) return 'session_home_cache_hit';
    return hasWorldoCache
        ? 'session_home_miss_worldo_cache_hit'
        : 'session_all_cache_miss';
  }

  static void beginLaunchTracking({String? startupId}) {
    if (_launchStopwatch != null) return;
    _launchStartupId = startupId ?? const Uuid().v4().replaceAll('-', '');
    _launchStopwatch = Stopwatch()..start();
  }

  static void setLaunchPageDecision({
    required String page,
    required String reason,
  }) {
    if (!isLaunchTrackingActive || _launchPageRecorded) return;
    final normalizedPage = page.trim().toLowerCase();
    final normalizedReason = reason.trim().toLowerCase();
    if ((normalizedPage != 'home' && normalizedPage != 'worldo') ||
        normalizedReason.isEmpty) {
      return;
    }
    _launchPage = normalizedPage;
    _launchPageReason = normalizedReason;
  }

  static void recordLaunchPage() {
    final page = _launchPage;
    final reason = _launchPageReason;
    if (!isLaunchTrackingActive ||
        _launchPageRecorded ||
        page == null ||
        reason == null) {
      return;
    }
    _launchPageRecorded = true;
    _collectLaunchEvent(action: 'launch_page', page: page, result: reason);
  }

  static void recordLaunchRequestStart({required String page}) {
    final normalizedPage = page.trim().toLowerCase();
    if (!isLaunchTrackingActive ||
        _launchRequestStarted ||
        _launchRenderRecorded ||
        normalizedPage != _launchPage) {
      return;
    }
    _launchRequestStarted = true;
    _collectLaunchEvent(
      action: 'launch_req_start',
      page: normalizedPage,
      result: 'started',
    );
  }

  static void recordLaunchRequestEnd({
    required String page,
    required String result,
  }) {
    final normalizedPage = page.trim().toLowerCase();
    final normalizedResult = result.trim().toLowerCase();
    if (!isLaunchTrackingActive ||
        !_launchRequestStarted ||
        _launchRequestEnded ||
        normalizedPage != _launchPage ||
        (normalizedResult != 'success' &&
            normalizedResult != 'failure' &&
            normalizedResult != 'cancelled')) {
      return;
    }
    _launchRequestEnded = true;
    _collectLaunchEvent(
      action: 'launch_req_end',
      page: normalizedPage,
      result: normalizedResult,
    );
  }

  static void recordLaunchRender({
    required String page,
    required String result,
  }) {
    final normalizedPage = page.trim().toLowerCase();
    final normalizedResult = result.trim().toLowerCase();
    if (!isLaunchTrackingActive ||
        _launchRenderRecorded ||
        normalizedPage != _launchPage ||
        (normalizedResult != 'cache' &&
            normalizedResult != 'network' &&
            normalizedResult != 'network_empty' &&
            normalizedResult != 'network_error')) {
      return;
    }
    _launchRenderRecorded = true;
    _collectLaunchEvent(
      action: 'launch_render',
      page: normalizedPage,
      result: normalizedResult,
    );
  }

  static void _recordLaunchStartup() {
    if (!isLaunchTrackingActive || _launchStartupRecorded) return;
    _launchStartupRecorded = true;
    _collectLaunchEvent(
      action: 'launch_startup',
      page: 'launch',
      result: 'started',
      elapsedMilliseconds: 0,
    );
  }

  static void _collectLaunchEvent({
    required String action,
    required String page,
    required String result,
    int? elapsedMilliseconds,
  }) {
    final startupId = _launchStartupId;
    final stopwatch = _launchStopwatch;
    if (startupId == null || stopwatch == null) return;
    GenesisTelemetry.collectLog(
      actionType: 'monitor',
      action: action,
      object1: startupId,
      object2: page,
      object3: elapsedMilliseconds ?? stopwatch.elapsedMilliseconds,
      object4: result,
    );
  }

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
    _recordLaunchStartup();
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
    _launchStopwatch?.stop();
    _launchStopwatch = null;
    _launchStartupId = null;
    _launchPage = null;
    _launchPageReason = null;
    _launchStartupRecorded = false;
    _launchPageRecorded = false;
    _launchRequestStarted = false;
    _launchRequestEnded = false;
    _launchRenderRecorded = false;
    _attRequestClaimed = false;
    _postLaunchWorkAllowed.value = true;
  }
}
