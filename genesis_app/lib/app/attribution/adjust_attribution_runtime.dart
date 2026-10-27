import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_session_failure.dart';
import 'package:adjust_sdk/adjust_session_success.dart';
import 'package:adjust_sdk/adjust_third_party_sharing.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../privacy/privacy_consent_controller.dart';

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
  static bool _firstSessionDelayReleased = false;
  static AdjustEnvironment? _selectedEnvironment;
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
  static bool get isAwaitingFirstSessionPrivacy =>
      _initialized && !_firstSessionDelayReleased && privacyConsent.active;
  static AdjustEnvironment get environment =>
      _selectedEnvironment ??
      (kReleaseMode ? AdjustEnvironment.production : AdjustEnvironment.sandbox);

  /// Resolve the SDK environment from the actual API endpoint used at launch.
  static AdjustEnvironment resolveEnvironment({
    required AppConfig config,
    bool releaseMode = kReleaseMode,
  }) {
    final apiUri = Uri.tryParse(config.apiBaseUrl.trim());
    return releaseMode &&
            config.useMock != true &&
            apiUri?.scheme.toLowerCase() == 'https' &&
            apiUri?.host.toLowerCase() == 'api.worldo.ai' &&
            apiUri?.hasPort == false
        ? AdjustEnvironment.production
        : AdjustEnvironment.sandbox;
  }

  /// Freeze the environment before Adjust starts. Endpoint changes require a
  /// new process because the SDK is initialized only once per process.
  static void configureEnvironment(
    AppConfig config, {
    bool releaseMode = kReleaseMode,
  }) {
    if (_initializationAttempted) return;
    _selectedEnvironment = resolveEnvironment(
      config: config,
      releaseMode: releaseMode,
    );
  }

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
    if (privacyConsent.active && !privacyConsent.startupResolved) return;
    if (_initializationAttempted || _initializing) return;
    _selectedEnvironment ??= releaseMode
        ? AdjustEnvironment.production
        : AdjustEnvironment.sandbox;
    _initializing = true;
    _initializationAttempted = true;

    try {
      final resolvedPlatform = platform ?? defaultTargetPlatform;
      applyPrivacyConsent();
      initializeSdk(
        createConfig(
          releaseMode: releaseMode,
          environment: environment,
          platform: resolvedPlatform,
        ),
      );
      _initialized = true;
      _finishFirstSessionDelayIfReady();

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

  /// Queue Google DMA values before initSdk; later choices update the SDK.
  static void applyPrivacyConsent() {
    final choices = privacyConsent.choices;
    if (choices == null ||
        (!choices.adUserData && !choices.adPersonalization)) {
      _finishFirstSessionDelayIfReady();
      return;
    }
    final sharing = AdjustThirdPartySharing(null);
    final eea = privacyConsent.region.eea;
    if (eea != null) sharing.addGranularOption('google_dma', 'eea', eea);
    if (choices.adUserData) {
      sharing.addGranularOption('google_dma', 'ad_user_data', '1');
    }
    if (choices.adPersonalization) {
      sharing.addGranularOption('google_dma', 'ad_personalization', '1');
    }
    Adjust.trackThirdPartySharing(sharing);
    _finishFirstSessionDelayIfReady();
  }

  // Same-channel calls preserve order: consent is queued before ending delay.
  // No timer: an open consent dialog must never be treated as a decision.
  static void _finishFirstSessionDelayIfReady() {
    if (!_initialized || _firstSessionDelayReleased || !privacyConsent.active) {
      return;
    }
    if (!privacyConsent.loaded ||
        (privacyConsent.choices == null && !privacyConsent.startupResolved)) {
      return;
    }
    Adjust.endFirstSessionDelay();
    _firstSessionDelayReleased = true;
    debugPrint('[Adjust] first-session delay release requested');
  }

  @visibleForTesting
  static AdjustConfig createConfig({
    required bool releaseMode,
    AdjustEnvironment? environment,
    TargetPlatform? platform,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final selectedEnvironment =
        environment ??
        (releaseMode
            ? AdjustEnvironment.production
            : AdjustEnvironment.sandbox);
    final config = AdjustConfig(appToken, selectedEnvironment)
      ..isFirstSessionDelayEnabled = privacyConsent.active
      ..logLevel = selectedEnvironment == AdjustEnvironment.production
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
    _firstSessionDelayReleased = false;
    _selectedEnvironment = null;
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
