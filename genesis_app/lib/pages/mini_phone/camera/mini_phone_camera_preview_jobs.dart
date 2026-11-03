import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/mini_phone_requests.dart';
import 'mini_phone_camera_models.dart';

enum CameraPreviewTaskState { generating, succeeded, failed }

/// Explicitly local sample, never a server album asset or History message.
class CameraPreviewTask {
  CameraPreviewTask._(this.id, this.request, this.sampleAsset);
  final int id;
  final MiniPhoneCameraRequest request;
  final String sampleAsset;
  CameraPreviewTaskState get state => _state;
  CameraPreviewTaskState _state = CameraPreviewTaskState.generating;
  int get attempt => _attempt;
  int _attempt = 0;
  double get progress => _progress;
  double _progress = 0;
  bool get viewed => _viewed;
  bool _viewed = false;
}

/// World-session-owned simulator. Closing a view does not cancel these jobs.
/// No HTTP/album/History/billing dependencies. Session disposal/account changes
/// invalidate all timers; real generation will need a backend task adapter.
class MiniPhoneCameraPreviewJobs extends ChangeNotifier {
  MiniPhoneCameraPreviewJobs({
    required this.requests,
    required MiniPhoneCameraScope scope,
  }) : _scope = scope,
       _generation = requests.generation;

  final MiniPhoneRequests requests;
  MiniPhoneCameraScope _scope;
  int _generation;
  int _sequence = 0;
  bool _disposed = false;
  final _tasks = <CameraPreviewTask>[];
  final _timers = <int, Timer>{};
  final _failedOnLastExit = <int>{};

  // Called before the album subscribes; no notifications during widget build.
  void beginAlbumVisit() {
    if (!_current) return;
    _tasks.removeWhere(
      (task) =>
          _failedOnLastExit.contains(task.id) &&
          task.state == CameraPreviewTaskState.failed,
    );
    _failedOnLastExit.clear();
  }

  void endAlbumVisit() {
    if (!_current) return;
    _failedOnLastExit.addAll(
      tasks
          .where((t) => t.state == CameraPreviewTaskState.failed)
          .map((t) => t.id),
    );
  }

  Timer? _debounce;
  bool get _current =>
      !_disposed &&
      requests.isCurrent(_generation) &&
      requests.uid == _scope.accountId;
  List<CameraPreviewTask> get tasks =>
      _current ? List.unmodifiable(_tasks) : const [];
  int get pendingCount =>
      tasks.where((t) => t.state == CameraPreviewTaskState.generating).length;
  int get unreadCount => tasks
      .where((t) => t.state == CameraPreviewTaskState.succeeded && !t.viewed)
      .length;
  CameraPreviewTask? get latestResult => tasks
      .where((t) => t.state == CameraPreviewTaskState.succeeded)
      .firstOrNull;

  void bindScope(MiniPhoneCameraScope value) {
    if (_disposed || (value == _scope && requests.generation == _generation)) {
      return;
    }
    _clear();
    _scope = value;
    _generation = requests.generation;
    notifyListeners();
  }

  bool submit(MiniPhoneCameraRequest request, {required String sampleAsset}) {
    if (!_current ||
        _debounce != null ||
        request.scope != _scope ||
        request.participants.isEmpty ||
        request.participants.length > 5) {
      return false;
    }
    final task = CameraPreviewTask._(++_sequence, request, sampleAsset);
    _tasks.insert(0, task);
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _debounce = null,
    );
    _start(task);
    return true;
  }

  void retry(int id) {
    if (!_current) return;
    final task = _tasks.where((t) => t.id == id).firstOrNull;
    if (task == null || task.state != CameraPreviewTaskState.failed) return;
    _start(task);
  }

  void _start(CameraPreviewTask task) {
    task._state = CameraPreviewTaskState.generating;
    task._progress = 0;
    task._attempt++;
    // Independent 15/19/23s jobs make concurrency easy to preview. Every third
    // initial job fails deliberately; retry preserves its snapshot and succeeds.
    final ticks = (15 + ((task.id - 1) % 3) * 4) * 2;
    final generation = _generation;
    _timers[task.id] = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!_current || generation != _generation) {
        timer.cancel();
        _timers.remove(task.id);
        return;
      }
      task._progress = (timer.tick / ticks).clamp(0, 1);
      if (task.progress >= 1) {
        timer.cancel();
        _timers.remove(task.id);
        task._state = task.id % 3 == 0 && task.attempt == 1
            ? CameraPreviewTaskState.failed
            : CameraPreviewTaskState.succeeded;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void markViewed(int id) {
    if (!_current) return;
    final task = _tasks.where((t) => t.id == id).firstOrNull;
    if (task == null ||
        task.viewed ||
        task.state != CameraPreviewTaskState.succeeded) {
      return;
    }
    task._viewed = true;
    notifyListeners();
  }

  void _clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _debounce?.cancel();
    _debounce = null;
    _tasks.clear();
    _failedOnLastExit.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
