import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:adjust_sdk/adjust_session_failure.dart';
import 'package:adjust_sdk/adjust_session_success.dart';
import 'package:flutter/foundation.dart';

typedef AdjustSdkInitializer = void Function(AdjustConfig config);
typedef AdjustIdfvGetter = Future<String?> Function();

class AdjustAttributionRuntime {
  const AdjustAttributionRuntime._();

  static const String appToken = 'k5fhwrccqmtc';
  static const String metaAppId = '1085582550499704';

  static bool _initialized = false;

  /// Initializes Adjust once without blocking or failing the app startup path.
  static void initialize({
    bool releaseMode = kReleaseMode,
    bool debugMode = kDebugMode,
    TargetPlatform? platform,
    AdjustSdkInitializer initializeSdk = Adjust.initSdk,
    AdjustIdfvGetter getIdfv = Adjust.getIdfv,
  }) {
    if (_initialized) return;
    _initialized = true;

    try {
      final resolvedPlatform = platform ?? defaultTargetPlatform;
      initializeSdk(
        createConfig(releaseMode: releaseMode, platform: resolvedPlatform),
      );

      if (debugMode && resolvedPlatform == TargetPlatform.iOS) {
        unawaited(_logDebugIdfv(getIdfv));
      }
    } catch (error, stackTrace) {
      debugPrint('[Adjust] SDK initialization failed: $error');
      debugPrint('[Adjust] stacktrace:\n$stackTrace');
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

    // Do not configure Adjust's ATT waiting interval here. While the native
    // ATT alert is visible iOS marks the app inactive, and Adjust pauses that
    // countdown. If the user leaves the alert open, the first session would
    // otherwise remain queued indefinitely instead of being sent with IDFV
    // and a notDetermined ATT status.

    if (!releaseMode) {
      config
        ..attributionCallback = _logAttribution
        ..sessionSuccessCallback = _logSessionSuccess
        ..sessionFailureCallback = _logSessionFailure;
    }

    return config;
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }

  static void _logAttribution(AdjustAttribution attribution) {
    debugPrint(
      '[Adjust] attribution changed: '
      'tracker=${attribution.trackerName ?? attribution.trackerToken}, '
      'network=${attribution.network}, campaign=${attribution.campaign}, '
      'adgroup=${attribution.adgroup}, creative=${attribution.creative}',
    );
  }

  static void _logSessionSuccess(AdjustSessionSuccess session) {
    debugPrint(
      '[Adjust] session succeeded: message=${session.message}, '
      'timestamp=${session.timestamp}, adid=${session.adid}',
    );
  }

  static void _logSessionFailure(AdjustSessionFailure session) {
    debugPrint(
      '[Adjust] session failed: message=${session.message}, '
      'timestamp=${session.timestamp}, willRetry=${session.willRetry}',
    );
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
