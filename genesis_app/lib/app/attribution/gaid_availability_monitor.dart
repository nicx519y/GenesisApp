import 'package:flutter/foundation.dart';
import '../telemetry/genesis_telemetry.dart';

typedef GaidAvailabilityReporter =
    Future<bool> Function(
      String action,
      String adjustId,
      String nativeId,
      String appInstanceId,
    );

final launchGaidAvailabilityMonitor = GaidAvailabilityMonitor();

enum _LaunchGaidState { fresh, waitingForRecovery, finished }

/// One failure/recovery pair per process; never persisted across launches.
class GaidAvailabilityMonitor {
  GaidAvailabilityMonitor({this.report = _report});
  final GaidAvailabilityReporter report;
  _LaunchGaidState _state = _LaunchGaidState.fresh;
  bool _failureObserved = false;
  Future<void> _work = Future<void>.value();
  int _generation = 0;

  bool get shouldCaptureNative =>
      _state != _LaunchGaidState.finished && _failureObserved;

  void observe({
    required bool available,
    required String adjustId,
    required String nativeId,
    required String appInstanceId,
  }) {
    if (!available && _state != _LaunchGaidState.finished) {
      _failureObserved = true;
    }
    final generation = _generation;
    _work = _work
        .then((_) async {
          if (generation != _generation ||
              _state == _LaunchGaidState.finished) {
            return;
          }
          if (!available && _state == _LaunchGaidState.fresh) {
            try {
              if (await report(
                    'get_gaid_failed',
                    adjustId,
                    nativeId,
                    appInstanceId,
                  ) &&
                  generation == _generation) {
                _state = _LaunchGaidState.waitingForRecovery;
              }
            } finally {
              if (generation == _generation) {
                _failureObserved =
                    _state == _LaunchGaidState.waitingForRecovery;
              }
            }
          } else if (available &&
              _state == _LaunchGaidState.waitingForRecovery) {
            if (await report(
                  'get_gaid_success',
                  adjustId,
                  nativeId,
                  appInstanceId,
                ) &&
                generation == _generation) {
              _state = _LaunchGaidState.finished;
              _failureObserved = false;
            }
          }
        })
        .catchError((Object error) {
          debugPrint('[Adjust][GAID] launch monitor enqueue failed: $error');
        });
  }

  @visibleForTesting
  Future<void> get whenIdle => _work;

  @visibleForTesting
  void resetForTesting() {
    _generation++;
    _state = _LaunchGaidState.fresh;
    _failureObserved = false;
    _work = Future<void>.value();
  }

  static Future<bool> _report(
    String action,
    String adjustId,
    String nativeId,
    String appInstanceId,
  ) => GenesisTelemetry.collectLogAndWait(
    actionType: 'monitor',
    action: action,
    object1: adjustId,
    object2: nativeId,
    object3: appInstanceId,
  );
}
