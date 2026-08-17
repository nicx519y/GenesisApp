import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_analytics_monitoring.dart';
import 'firebase_performance_monitoring.dart';

enum FirebasePerformanceSurface {
  myWorlds('my_worlds'),
  popular('popular'),
  worldo('worldo'),
  worldPage('world_page'),
  originWorldPage('origin_world_page');

  const FirebasePerformanceSurface(this.value);

  final String value;
}

enum FirebasePerformancePhase {
  request('request'),
  render('render');

  const FirebasePerformancePhase(this.value);

  final String value;
}

enum FirebasePerformanceResult {
  success('success'),
  failure('failure'),
  cancelled('cancelled');

  const FirebasePerformanceResult(this.value);

  final String value;
}

enum FirebasePerformanceDataSource {
  network('network'),
  prefetched('prefetched');

  const FirebasePerformanceDataSource(this.value);

  final String value;
}

class FirebasePerformanceOperation {
  FirebasePerformanceOperation._disabled({
    required this.surface,
    required this.phase,
    required this.attempt,
    required this.dataSource,
  }) : _trace = null,
       _completed = true;

  FirebasePerformanceOperation._({
    required this.surface,
    required this.phase,
    required this.attempt,
    required this.dataSource,
    required AppPerformanceTrace? trace,
    required Duration? timeout,
  }) : _trace = trace {
    _stopwatch.start();
    if (timeout != null) {
      _timeoutTimer = Timer(
        timeout,
        () => unawaited(fail(errorType: 'render_timeout')),
      );
    }
  }

  static const Duration renderTimeout = Duration(seconds: 10);

  final FirebasePerformanceSurface surface;
  final FirebasePerformancePhase phase;
  final int attempt;
  final FirebasePerformanceDataSource dataSource;
  final AppPerformanceTrace? _trace;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timeoutTimer;
  Future<void>? _completion;
  bool _completed = false;

  bool get isCompleted => _completed;

  static Future<FirebasePerformanceOperation> start({
    required FirebasePerformanceSurface surface,
    required FirebasePerformancePhase phase,
    int attempt = 1,
    FirebasePerformanceDataSource dataSource =
        FirebasePerformanceDataSource.network,
    Duration? timeout,
  }) async {
    final normalizedAttempt = attempt < 1 ? 1 : attempt;
    if (!FirebasePerformanceMonitoring.isReady) {
      return FirebasePerformanceOperation._disabled(
        surface: surface,
        phase: phase,
        attempt: normalizedAttempt,
        dataSource: dataSource,
      );
    }
    final trace = await FirebasePerformanceMonitoring.startTrace(
      _traceName(surface, phase),
      attributes: <String, String>{
        'phase': phase.value,
        'data_source': dataSource.value,
        'attempt': '$normalizedAttempt',
      },
    );
    return FirebasePerformanceOperation._(
      surface: surface,
      phase: phase,
      attempt: normalizedAttempt,
      dataSource: dataSource,
      trace: trace,
      timeout: timeout,
    );
  }

  Future<void> succeed() => _finish(FirebasePerformanceResult.success);

  Future<void> fail({required String errorType}) => _finish(
    FirebasePerformanceResult.failure,
    errorType: errorType.trim().isEmpty ? 'unknown' : errorType.trim(),
  );

  Future<void> cancel() => _finish(FirebasePerformanceResult.cancelled);

  Future<void> _finish(FirebasePerformanceResult result, {String? errorType}) {
    final existing = _completion;
    if (existing != null) return existing;
    if (_completed) return Future<void>.value();
    _completed = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    final attributes = <String, String>{'result': result.value};
    if (errorType != null && errorType.isNotEmpty) {
      attributes['error_type'] = errorType;
    }
    final completion = Future.wait<void>(<Future<void>>[
      FirebasePerformanceMonitoring.stopTrace(_trace, attributes: attributes),
      FirebaseAnalyticsMonitoring.recordPerformanceOperation(
        surface: surface.value,
        phase: phase.value,
        result: result.value,
        durationMs: durationMs,
        attempt: attempt,
        dataSource: dataSource.value,
        errorType: errorType,
      ),
    ]);
    _completion = completion;
    return completion;
  }

  static String _traceName(
    FirebasePerformanceSurface surface,
    FirebasePerformancePhase phase,
  ) {
    switch ((surface, phase)) {
      case (
        FirebasePerformanceSurface.myWorlds,
        FirebasePerformancePhase.request,
      ):
        return 'my_worlds_first_request';
      case (
        FirebasePerformanceSurface.myWorlds,
        FirebasePerformancePhase.render,
      ):
        return 'my_worlds_first_render';
      case (
        FirebasePerformanceSurface.popular,
        FirebasePerformancePhase.request,
      ):
        return 'popular_first_request';
      case (
        FirebasePerformanceSurface.popular,
        FirebasePerformancePhase.render,
      ):
        return 'popular_first_render';
      case (
        FirebasePerformanceSurface.worldo,
        FirebasePerformancePhase.request,
      ):
        return 'worldo_first_request';
      case (FirebasePerformanceSurface.worldo, FirebasePerformancePhase.render):
        return 'worldo_first_render';
      case (
        FirebasePerformanceSurface.worldPage,
        FirebasePerformancePhase.request,
      ):
        return 'world_page_request';
      case (
        FirebasePerformanceSurface.worldPage,
        FirebasePerformancePhase.render,
      ):
        return 'world_page_render';
      case (
        FirebasePerformanceSurface.originWorldPage,
        FirebasePerformancePhase.request,
      ):
        return 'origin_world_page_request';
      case (
        FirebasePerformanceSurface.originWorldPage,
        FirebasePerformancePhase.render,
      ):
        return 'origin_world_page_render';
    }
  }
}

String firebasePerformanceErrorType(Object error) {
  if (error is TimeoutException) return 'timeout';
  final type = error.runtimeType.toString().toLowerCase();
  final text = error.toString().toLowerCase();
  if (type.contains('cancel') || text.contains('cancel')) return 'cancelled';
  if (type.contains('timeout') || text.contains('timeout')) return 'timeout';
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('host lookup') ||
      text.contains('network')) {
    return 'transport';
  }
  if (type.contains('format') ||
      type.contains('typeerror') ||
      text.contains('parse')) {
    return 'parse';
  }
  return 'unknown';
}

@visibleForTesting
String firebasePerformanceTraceNameForTesting(
  FirebasePerformanceSurface surface,
  FirebasePerformancePhase phase,
) {
  return FirebasePerformanceOperation._traceName(surface, phase);
}
