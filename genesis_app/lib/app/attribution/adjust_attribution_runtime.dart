import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_session_failure.dart';
import 'package:adjust_sdk/adjust_session_success.dart';
import 'package:flutter/foundation.dart';

typedef AdjustSdkInitializer = void Function(AdjustConfig config);
typedef AdjustIdfvGetter = Future<String?> Function();
typedef AdjustSessionListener = void Function(String? adid);
typedef AdjustSessionFailureListener =
    void Function(AdjustSessionFailure failure);

class AdjustAttributionRuntime {
  const AdjustAttributionRuntime._();

  static const String appToken = 'k5fhwrccqmtc';
  static const String metaAppId = '1085582550499704';

  static bool _initialized = false;
  static bool _initializing = false;
  static bool _initializationAttempted = false;
  static bool _hasSuccessfulSession = false;
  static final Set<AdjustSessionListener> _sessionListeners =
      <AdjustSessionListener>{};
  static final Set<AdjustSessionFailureListener> _sessionFailureListeners =
      <AdjustSessionFailureListener>{};
  static String? _latestSessionAdid;
  static AdjustSessionFailure? _latestSessionFailure;

  static bool get isInitialized => _initialized;
  static bool get hasAttemptedInitialization => _initializationAttempted;
  static bool get hasSuccessfulSession => _hasSuccessfulSession;

  /// Observes successful Adjust sessions and their ADID when available.
  ///
  /// The latest result is replayed so services created after the first session
  /// can register the device or perform one cached-ADID fallback read.
  static VoidCallback addSessionListener(AdjustSessionListener listener) {
    _sessionListeners.add(listener);
    if (_hasSuccessfulSession) listener(_latestSessionAdid);
    return () => _sessionListeners.remove(listener);
  }

  static VoidCallback addSessionFailureListener(
    AdjustSessionFailureListener listener,
  ) {
    _sessionFailureListeners.add(listener);
    final failure = _latestSessionFailure;
    if (failure != null) listener(failure);
    return () => _sessionFailureListeners.remove(listener);
  }

  /// Initializes Adjust once without blocking or failing the app startup path.
  static void initialize({
    bool releaseMode = kReleaseMode,
    bool debugMode = kDebugMode,
    TargetPlatform? platform,
    AdjustSdkInitializer initializeSdk = Adjust.initSdk,
    AdjustIdfvGetter getIdfv = Adjust.getIdfv,
  }) {
    if (_initializationAttempted || _initializing) return;
    _initializing = true;
    _initializationAttempted = true;

    try {
      final resolvedPlatform = platform ?? defaultTargetPlatform;
      initializeSdk(
        createConfig(releaseMode: releaseMode, platform: resolvedPlatform),
      );
      _initialized = true;

      if (debugMode && resolvedPlatform == TargetPlatform.iOS) {
        unawaited(_logDebugIdfv(getIdfv));
      }
    } catch (error, stackTrace) {
      debugPrint('[Adjust] SDK initialization failed: $error');
      debugPrint('[Adjust] stacktrace:\n$stackTrace');
    } finally {
      _initializing = false;
    }
  }

  @visibleForTesting
  static AdjustConfig createConfig({
    required bool releaseMode,
    TargetPlatform? platform,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final config =
        AdjustConfig(
            appToken,
            releaseMode
                ? AdjustEnvironment.production
                : AdjustEnvironment.sandbox,
          )
          ..logLevel = releaseMode
              ? AdjustLogLevel.suppress
              : AdjustLogLevel.verbose;

    if (resolvedPlatform == TargetPlatform.android) {
      config.fbAppId = metaAppId;
    }

    // Session callbacks are part of device-registration reliability. Keep
    // them enabled in production as well as sandbox builds. The log level
    // remains environment-specific.
    config
      ..sessionSuccessCallback = _handleSessionSuccess
      ..sessionFailureCallback = _handleSessionFailure;

    // Do not configure Adjust's ATT waiting interval here. While the native
    // ATT alert is visible iOS marks the app inactive, and Adjust pauses that
    // countdown. If the user leaves the alert open, the first session would
    // otherwise remain queued indefinitely instead of being sent with IDFV
    // and a notDetermined ATT status.

    if (!releaseMode) {
      config.attributionCallback = _logAttribution;
    }

    return config;
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _initializing = false;
    _initializationAttempted = false;
    _hasSuccessfulSession = false;
    _latestSessionAdid = null;
    _latestSessionFailure = null;
    _sessionListeners.clear();
    _sessionFailureListeners.clear();
  }

  static void _logAttribution(AdjustAttribution attribution) {
    debugPrint(
      '[Adjust] attribution changed: '
      'tracker=${attribution.trackerName ?? attribution.trackerToken}, '
      'network=${attribution.network}, campaign=${attribution.campaign}, '
      'adgroup=${attribution.adgroup}, creative=${attribution.creative}',
    );
  }

  static void _handleSessionSuccess(AdjustSessionSuccess session) {
    debugPrint(
      '[Adjust] session succeeded: message=${session.message}, '
      'timestamp=${session.timestamp}, adid=${session.adid}',
    );
    final adid = session.adid?.trim() ?? '';
    _hasSuccessfulSession = true;
    _latestSessionFailure = null;
    if (adid.isNotEmpty) _latestSessionAdid = adid;
    for (final listener in List<AdjustSessionListener>.of(_sessionListeners)) {
      try {
        listener(adid.isEmpty ? null : adid);
      } catch (error, stackTrace) {
        debugPrint('[Adjust] session ADID listener failed: $error');
        debugPrint('[Adjust] listener stacktrace:\n$stackTrace');
      }
    }
  }

  static void _handleSessionFailure(AdjustSessionFailure session) {
    debugPrint(
      '[Adjust] session failed: message=${session.message}, '
      'timestamp=${session.timestamp}, willRetry=${session.willRetry}',
    );
    _latestSessionFailure = session;
    for (final listener in List<AdjustSessionFailureListener>.of(
      _sessionFailureListeners,
    )) {
      try {
        listener(session);
      } catch (error, stackTrace) {
        debugPrint('[Adjust] session failure listener failed: $error');
        debugPrint('[Adjust] listener stacktrace:\n$stackTrace');
      }
    }
  }

  static Future<void> _logDebugIdfv(AdjustIdfvGetter getIdfv) async {
    try {
      final idfv = await getIdfv();
      if (idfv == null || idfv.isEmpty) {
        debugPrint('[Adjust] Worldo IDFV unavailable');
        return;
      }
      debugPrint('[Adjust] Worldo IDFV=$idfv');
    } catch (error, stackTrace) {
      debugPrint('[Adjust] failed to read Worldo IDFV: $error');
      debugPrint('[Adjust] IDFV stacktrace:\n$stackTrace');
    }
  }
}
