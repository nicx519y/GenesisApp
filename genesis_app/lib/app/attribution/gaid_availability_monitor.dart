import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../telemetry/genesis_telemetry.dart';

typedef GaidAvailabilityReporter =
    Future<bool> Function(String action, String source);

abstract interface class GaidFailureStateStore {
  Future<bool> hasPendingFailure(String environment);
  Future<void> setPendingFailure(String environment, bool pending);
}

/// Persists only whether a GAID failure was queued, never the GAID itself.
class SharedPreferencesGaidFailureStateStore implements GaidFailureStateStore {
  const SharedPreferencesGaidFailureStateStore();

  String _key(String environment) =>
      'adjust_gaid_failure_${environment.trim().toLowerCase()}_v1';

  @override
  Future<bool> hasPendingFailure(String environment) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(environment)) ?? false;
  }

  @override
  Future<void> setPendingFailure(String environment, bool pending) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_key(environment), pending)) {
      throw StateError('Failed to save GAID failure state');
    }
  }
}

Future<bool> _reportGaidAvailability(String action, String source) =>
    GenesisTelemetry.collectLogAndWait(
      actionType: 'monitor',
      action: action,
      object1: source,
      object2: TargetPlatform.android.name,
    );

/// Emits one failure per unavailable period, followed by one recovery only
/// when that failure was successfully queued for upload.
class GaidAvailabilityMonitor {
  GaidAvailabilityMonitor({
    this.store = const SharedPreferencesGaidFailureStateStore(),
    this.report = _reportGaidAvailability,
  });

  final GaidFailureStateStore store;
  final GaidAvailabilityReporter report;
  final Map<String, bool> _pendingByEnvironment = <String, bool>{};
  Future<void> _work = Future<void>.value();

  /// The reporting queue is separate from registration, so telemetry never
  /// holds up the device request or the page that triggered it.
  void observe({required String environment, required String? source}) {
    _work = _work.then((_) => _record(environment, source)).catchError((
      Object error,
    ) {
      debugPrint('[Adjust][GAID] availability monitor failed: $error');
    });
  }

  @visibleForTesting
  Future<void> get whenIdle => _work;

  Future<void> _record(String environment, String? source) async {
    final normalizedEnvironment = environment.trim().toLowerCase();
    final pending =
        _pendingByEnvironment[normalizedEnvironment] ??
        await store.hasPendingFailure(normalizedEnvironment);
    _pendingByEnvironment[normalizedEnvironment] = pending;

    if (source == null) {
      if (pending ||
          !await report('get_gaid_failed', 'adjust_and_native_unavailable')) {
        return;
      }
      _pendingByEnvironment[normalizedEnvironment] = true;
      await store.setPendingFailure(normalizedEnvironment, true);
      return;
    }

    if (!pending || !await report('get_gaid_success', source)) return;
    _pendingByEnvironment[normalizedEnvironment] = false;
    await store.setPendingFailure(normalizedEnvironment, false);
  }
}
