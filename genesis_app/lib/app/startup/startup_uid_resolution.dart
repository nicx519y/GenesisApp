import 'dart:async';

import 'package:flutter/services.dart';

class StartupUidResolution {
  const StartupUidResolution({required this.uid, required this.status});
  final String? uid;
  final String status;
  bool get readFailed => status == 'timeout' || status == 'read_error';
}

/// One startup read budget. Diagnostics never contain UID or error messages.
Future<StartupUidResolution> resolveStartupUid({
  required Future<String?> Function() readUid,
  required void Function(String? uid) setTelemetryUser,
  required void Function(Map<String, Object> data) recordDiagnostics,
  Duration timeout = const Duration(seconds: 2),
  Map<String, Object>? nativeTiming,
}) async {
  final watch = Stopwatch()..start();
  final data = <String, Object>{'timeout_ms': timeout.inMilliseconds};
  void report() {
    try {
      recordDiagnostics({...data, ...?nativeTiming});
    } catch (_) {
      // Diagnostics must not change the login decision.
    }
  }

  String errorKind(Object error) {
    if (error is PlatformException) {
      final details = error.details;
      final nativeType = details is Map ? details['native_error_type'] : null;
      return nativeType is String
          ? '${error.code}:$nativeType'
          : 'platform_error:${error.code}';
    }
    return error is MissingPluginException
        ? 'missing_plugin'
        : error.runtimeType.toString();
  }

  var timedOut = false;
  final read = Future<String?>.sync(readUid);
  unawaited(
    read.then<void>(
      (uid) {
        if (!timedOut) return;
        data['late_status'] = uid == null ? 'signed_out' : 'signed_in';
        data['late_elapsed_ms'] = watch.elapsedMilliseconds;
        report();
      },
      onError: (Object error, StackTrace stack) {
        if (!timedOut) return;
        data['late_status'] = 'read_error';
        data['late_elapsed_ms'] = watch.elapsedMilliseconds;
        data['late_error_type'] = errorKind(error);
        report();
      },
    ),
  );
  String? uid;
  try {
    uid = await read.timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        throw TimeoutException('Startup UID read budget exceeded');
      },
    );
  } catch (error) {
    final status = timedOut ? 'timeout' : 'read_error';
    data.addAll({
      'status': status,
      'elapsed_ms': watch.elapsedMilliseconds,
      'error_type': errorKind(error),
    });
    report();
    return StartupUidResolution(uid: null, status: status);
  }
  final status = uid == null ? 'signed_out' : 'signed_in';
  data.addAll({'status': status, 'elapsed_ms': watch.elapsedMilliseconds});
  try {
    setTelemetryUser(uid);
  } catch (error) {
    data['telemetry_error_type'] = errorKind(error);
  }
  report();
  return StartupUidResolution(uid: uid, status: status);
}
