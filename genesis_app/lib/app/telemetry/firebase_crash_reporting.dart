import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show NetworkImageLoadException;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../components/origin/origin_item_cover_throttled_image_provider.dart';
import 'telemetry_upload_policy.dart';

@visibleForTesting
bool shouldRecordFirebaseFlutterError(FlutterErrorDetails details) =>
    details.exception is! OriginItemCoverLoadCancelledException;

@visibleForTesting
bool isFirebaseFlutterErrorFatal(FlutterErrorDetails details) {
  final error = details.exception;
  if (details.library == 'image resource service' &&
      (error is http.ClientException || error is NetworkImageLoadException)) {
    return false;
  }
  if (details.library == 'services library' &&
      details.context?.toDescription().startsWith(
            'while de-activating platform stream on channel ',
          ) ==
          true &&
      error is PlatformException &&
      error.code == 'error' &&
      error.message == 'No active stream to cancel') {
    return false;
  }
  return true;
}

@visibleForTesting
Future<void> recordFirebaseCrashlyticsBestEffort(
  Future<void> Function() record, {
  required String operation,
}) async {
  try {
    await record();
  } catch (error, stackTrace) {
    debugPrint('[Telemetry][FirebaseCrashlytics] $operation failed: $error');
    debugPrint('[Telemetry][FirebaseCrashlytics] stacktrace:\n$stackTrace');
  }
}

class FirebaseCrashReporting {
  const FirebaseCrashReporting._();

  static bool _enabled = false;
  static bool _handlersInstalled = false;

  static Future<void> enable() {
    return configure(TelemetryUploadPolicy.state.value.crashlyticsEnabled);
  }

  static Future<void> configure(bool enabled) async {
    final crashlytics = FirebaseCrashlytics.instance;
    if (!enabled) {
      _enabled = false;
      try {
        await crashlytics.setCrashlyticsCollectionEnabled(false);
        await crashlytics.deleteUnsentReports();
        debugPrint(
          '[Telemetry][FirebaseCrashlytics] collection disabled '
          'and unsent reports deleted',
        );
      } catch (e, st) {
        debugPrint('[Telemetry][FirebaseCrashlytics] disable failed: $e');
        debugPrint('[Telemetry][FirebaseCrashlytics] stacktrace:\n$st');
      }
      return;
    }
    if (_enabled) return;
    try {
      await crashlytics.setCrashlyticsCollectionEnabled(true);
      if (!_handlersInstalled) {
        _installFlutterErrorHandler();
        _installPlatformErrorHandler();
        _handlersInstalled = true;
      }
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
      // A card leaving the viewport or losing its queue slot is expected.
      // An image stream without a listener may still surface that cancellation
      // through FlutterError, but it is not an app crash.
      if (!_enabled || !shouldRecordFirebaseFlutterError(details)) return;
      unawaited(
        recordFirebaseCrashlyticsBestEffort(
          () => FirebaseCrashlytics.instance.recordError(
            details.exception,
            details.stack,
            fatal: isFirebaseFlutterErrorFatal(details),
            reason: details.context?.toDescription(),
            information: <Object>[
              if (details.library != null) 'library: ${details.library}',
              ...?details.informationCollector?.call(),
            ],
          ),
          operation: 'record Flutter error',
        ),
      );
    };
  }

  static void _installPlatformErrorHandler() {
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_enabled) return previous?.call(error, stack) ?? true;
      unawaited(
        recordFirebaseCrashlyticsBestEffort(
          () => FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: true,
          ),
          operation: 'record platform fatal error',
        ),
      );
      return previous?.call(error, stack) ?? true;
    };
  }

  static void recordNonFatal(Object error, StackTrace stackTrace) {
    if (!_enabled) return;
    unawaited(
      recordFirebaseCrashlyticsBestEffort(
        () => FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          fatal: false,
        ),
        operation: 'record non-fatal error',
      ),
    );
  }
}
