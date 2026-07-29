import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseCrashReporting {
  const FirebaseCrashReporting._();

  static bool _enabled = false;

  static Future<void> enable() async {
    if (_enabled) return;
    final crashlytics = FirebaseCrashlytics.instance;
    if (!kReleaseMode) {
      try {
        await crashlytics.setCrashlyticsCollectionEnabled(false);
        await crashlytics.deleteUnsentReports();
        debugPrint(
          '[Telemetry][FirebaseCrashlytics] collection disabled '
          'and unsent reports deleted for non-release build',
        );
      } catch (e, st) {
        debugPrint('[Telemetry][FirebaseCrashlytics] disable failed: $e');
        debugPrint('[Telemetry][FirebaseCrashlytics] stacktrace:\n$st');
      }
      return;
    }
    try {
      await crashlytics.setCrashlyticsCollectionEnabled(true);
      _installFlutterErrorHandler();
      _installPlatformErrorHandler();
      _enabled = true;
      debugPrint('[Telemetry][FirebaseCrashlytics] collection enabled');
    } catch (e, st) {
      debugPrint('[Telemetry][FirebaseCrashlytics] enable failed: $e');
      debugPrint('[Telemetry][FirebaseCrashlytics] stacktrace:\n$st');
    }
  }

  static void _installFlutterErrorHandler() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
    };
  }

  static void _installPlatformErrorHandler() {
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
      return previous?.call(error, stack) ?? true;
    };
  }

  static void recordNonFatal(Object error, StackTrace stackTrace) {
    if (!_enabled) return;
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: false),
    );
  }
}
