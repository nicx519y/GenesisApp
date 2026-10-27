import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../app/telemetry/genesis_telemetry.dart';

/// Local cancellation only. It says nothing about server acceptance or billing.
class ChatSendWaitReleased implements Exception {
  const ChatSendWaitReleased(this.operationId);
  final String operationId;
}

typedef ChatSendTimeoutReporter = void Function(Map<String, Object?> event);

/// The sole business deadline scheduler for LocationChat. Owned by an account
/// session, not by a widget, so rebuilding a page cannot extend a deadline.
class LocationChatSendGate extends ChangeNotifier with WidgetsBindingObserver {
  LocationChatSendGate({
    this.warningAfter = const Duration(seconds: 30),
    this.waitAfter = const Duration(seconds: 45),
    this.streamAfter = const Duration(seconds: 5),
    this.tickAfter = const Duration(seconds: 60),
    DateTime Function()? now,
    ChatSendTimeoutReporter? report,
  }) : _now = now ?? DateTime.now,
       _report = report ?? _collect {
    try {
      _binding = WidgetsBinding.instance;
      _foreground = _binding!.lifecycleState != AppLifecycleState.paused;
      _binding!.addObserver(this);
    } catch (_) {
      // Also usable by headless protocol clients.
    }
  }

  final Duration warningAfter, waitAfter, streamAfter, tickAfter;
  final DateTime Function() _now;
  final ChatSendTimeoutReporter _report;
  final _operations = <(String, String, String), ChatSendOperation>{};
  final _ticks = <String, ChatSendOperation>{};
  int _tickSequence = 0;
  final _worldContexts = <String, Map<String, Object?>>{};
  int _resumeCount = 0;

  int _connectionProgressSequence = 0;
  void updateConnection(
    String world, {
    required bool connected,
    required bool joining,
    String joinedLocation = '',
  }) {
    final before = _worldContexts[world];
    final connectedNow = connected && before?['connected'] != true;
    final joinedNow =
        joinedLocation.isNotEmpty &&
        before?['joined_location_id'] != joinedLocation;
    _worldContexts[world] = {
      'connected': connected,
      'joining': joining,
      'joined_location_id': joinedLocation,
    };
    if (!connectedNow && !joinedNow) return;
    final progress = ('connection', ++_connectionProgressSequence);
    for (final operation in _operations.values) {
      if (operation.worldId != world ||
          (operation.phase != 'connecting' &&
              !(operation.scene == 'initial_send' &&
                  operation.phase == 'preparing'))) {
        continue;
      }
      if (connectedNow ||
          (joinedNow && operation.locationId == joinedLocation)) {
        operation.progress(progress);
      }
    }
  }

  Timer? _timer;
  WidgetsBinding? _binding;
  bool _foreground = true;
  bool _disposed = false;
  bool _checking = false;

  ChatSendOperation begin({
    required String worldId,
    required String locationId,
    required String operationId,
    required String scene,
    bool tick = false,
  }) {
    final key = (worldId, tick ? '' : locationId, operationId);
    final operation = _operations.putIfAbsent(
      key,
      () => ChatSendOperation._(this, key, scene, tick, _now()),
    );
    _schedule();
    return operation;
  }

  ChatSendOperation beginTick(String worldId) {
    final current = _ticks[worldId];
    if (current != null && !current.finished) return current;
    return _ticks[worldId] = begin(
      worldId: worldId,
      locationId: '',
      operationId: 'tick:${++_tickSequence}',
      scene: 'tick',
      tick: true,
    );
  }

  void finishTick(String worldId) => _ticks[worldId]?.finish();

  ChatSendOperation? find(String world, String location, String id) =>
      _operations[(world, location, id)];

  ChatSendOperation? forRound(String world, String location, String round) {
    ChatSendOperation? match;
    for (final operation in _operations.values) {
      if (operation.worldId == world &&
          operation.locationId == location &&
          '${operation.diagnostics['round_id']}' == round &&
          const {
            'send',
            'retry_send',
            'initial_send',
            'inspiration_send',
            'go_on',
            'conversation_wait',
          }.contains(operation.scene)) {
        match = operation;
      }
    }
    return match;
  }

  bool blocks(String world, String location) => _operations.values.any(
    (op) =>
        op.worldId == world &&
        (op.locationId == location || op.tick) &&
        op.blocks,
  );

  /// Rechecks absolute deadlines after resume; neither backgrounding nor an
  /// unrelated event resets the last-progress timestamp.
  void reconcile() {
    if (_disposed || _checking) return;
    _checking = true;
    var changed = false;
    final now = _now();
    try {
      for (final op in _operations.values.toList()) {
        if (!op.blocks) continue;
        final elapsed = now.difference(op.startedAt);
        final idle = now.difference(op.lastProgressAt);
        if (op.tick) {
          if (elapsed >= tickAfter) {
            _emit(op, 'tick_timeout', now);
            op._release();
            changed = true;
          }
        } else if (op.streaming) {
          if (idle >= streamAfter) {
            _emit(op, 'stream_stalled', now);
            op._release();
            changed = true;
          }
        } else {
          if (!op._warned && idle >= warningAfter) {
            op._warned = true;
            _emit(op, 'wait_stalled', now);
          }
          if (idle >= waitAfter) {
            op._release();
            changed = true;
          }
        }
      }
    } finally {
      _checking = false;
      _schedule();
    }
    if (changed && !_disposed) notifyListeners();
  }

  void _schedule() {
    if (_disposed || _checking) return;
    _timer?.cancel();
    DateTime? next;
    for (final op in _operations.values) {
      if (!op.blocks) continue;
      final deadline = op.tick
          ? op.startedAt.add(tickAfter)
          : op.lastProgressAt.add(
              op.streaming
                  ? streamAfter
                  : op._warned
                  ? waitAfter
                  : (warningAfter < waitAfter ? warningAfter : waitAfter),
            );
      if (next == null || deadline.isBefore(next)) next = deadline;
    }
    if (next == null) return;
    final remaining = next.difference(_now());
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, reconcile);
  }

  void _emit(ChatSendOperation op, String reason, DateTime now) {
    final elapsed = now
        .difference(op.startedAt)
        .inMilliseconds
        .clamp(0, 1 << 53);
    final idle = now
        .difference(op.lastProgressAt)
        .inMilliseconds
        .clamp(0, 1 << 53);
    try {
      _report({
        'action_type': 'chat_timeout',
        'action': 'location_chat_send_lock_timeout',
        'object1': op.worldId,
        'object2': op.locationId,
        'object3': op.scene,
        'object4': '$elapsed',
        'ext_data': jsonEncode({
          'operation_id': op.operationId,
          'phase': op.phase,
          'reason': reason,
          'locked_duration_ms': elapsed,
          'idle_duration_ms': idle,
          'report_after_ms':
              (op.tick
                      ? tickAfter
                      : op.streaming
                      ? streamAfter
                      : warningAfter)
                  .inMilliseconds,
          'release_after_ms':
              (op.tick
                      ? tickAfter
                      : op.streaming
                      ? streamAfter
                      : waitAfter)
                  .inMilliseconds,
          'timeout_basis': op.tick ? 'elapsed' : 'idle',
          'foreground': _foreground,
          'resume_count': _resumeCount,
          ...?_worldContexts[op.worldId],
          'blockers': [
            for (final other in _operations.values)
              if (other.blocks &&
                  other.worldId == op.worldId &&
                  (other.locationId == op.locationId || other.tick || op.tick))
                {
                  'operation_id': other.operationId,
                  'scene': other.scene,
                  'phase': other.phase,
                },
          ],
          ...op.diagnostics,
        }),
      });
    } catch (_) {
      // Monitoring never owns the release path.
    }
  }

  static void _collect(Map<String, Object?> event) =>
      GenesisTelemetry.collectLog(
        actionType: 'chat_timeout',
        action: 'location_chat_send_lock_timeout',
        object1: event['object1'],
        object2: event['object2'],
        object3: event['object3'],
        object4: event['object4'],
        extData: event['ext_data']! as String,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumeCount++;
      reconcile();
    }
  }

  void reset() {
    _timer?.cancel();
    for (final op in _operations.values.toList()) {
      op._release();
    }
    _operations.clear();
    _ticks.clear();
    _worldContexts.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    reset();
    _binding?.removeObserver(this);
    super.dispose();
  }
}

class ChatSendOperation {
  ChatSendOperation._(
    this._gate,
    this._key,
    this.scene,
    this.tick,
    this.startedAt,
  ) : lastProgressAt = startedAt;
  final LocationChatSendGate _gate;
  final (String, String, String) _key;
  final String scene;
  final bool tick;
  final DateTime startedAt;
  DateTime lastProgressAt;
  String phase = 'waiting';
  final diagnostics = <String, Object?>{};
  final _openStreams = <String>{};
  final _streamGenerations = <String, (String, int)>{};
  final _latestAttempts = <String, int>{};
  final _progressKeys = <Object>{};
  final _releaseListeners = <VoidCallback>{};
  final _releasedFuture = Completer<void>();
  bool _warned = false;
  bool released = false;
  bool finished = false;

  String get worldId => _key.$1;
  String get locationId => _key.$2;
  String get operationId => _key.$3;
  bool get blocks => !released && !finished;
  bool get streaming => _openStreams.isNotEmpty;

  void onRelease(VoidCallback listener) {
    if (released) {
      listener();
    } else if (!finished) {
      _releaseListeners.add(listener);
    }
  }

  void removeReleaseListener(VoidCallback listener) =>
      _releaseListeners.remove(listener);

  void progress(Object key, {String? phase}) {
    if (!blocks || !_progressKeys.add(key)) return;
    if (phase != null && !streaming) this.phase = phase;
    // Non-stream progress must never postpone a missing stream frame.
    if (!streaming) lastProgressAt = _gate._now();
    _gate._schedule();
  }

  void stream(
    String streamId,
    Object frameId, {
    bool end = false,
    String? generationKey,
    int? attemptNo,
  }) {
    if (!blocks) return;
    if (generationKey != null && attemptNo != null) {
      if (attemptNo < (_latestAttempts[generationKey] ?? 0)) return;
      _latestAttempts[generationKey] = attemptNo;
    }
    if (!_progressKeys.add(('stream', streamId, frameId))) return;
    if (generationKey != null && attemptNo != null) {
      _openStreams.removeWhere((id) {
        final generation = _streamGenerations[id];
        return generation != null &&
            generation.$1 == generationKey &&
            generation.$2 < attemptNo;
      });
      _streamGenerations[streamId] = (generationKey, attemptNo);
      diagnostics['generation_key'] = generationKey;
      diagnostics['attempt_no'] = attemptNo;
    }
    if (end) {
      _openStreams.remove(streamId);
    } else {
      _openStreams.add(streamId);
    }
    phase = streaming ? 'streaming' : 'awaiting_terminal';
    if (!end || !streaming) lastProgressAt = _gate._now();
    _gate._schedule();
  }

  void check() {
    if (released || finished) throw ChatSendWaitReleased(operationId);
  }

  Future<T> guard<T>(Future<T> future) => Future.any([
    future,
    _releasedFuture.future.then<T>(
      (_) => throw ChatSendWaitReleased(operationId),
    ),
  ]);

  /// Preparation hands its local cleanup to the actual request. It no longer
  /// owns a deadline, so active streaming cannot be cut short by a parent wait.
  void handoffTo(ChatSendOperation next) {
    if (!blocks || identical(this, next)) return;
    finished = true;
    next.onRelease(() {
      if (released) return;
      released = true;
      if (!_releasedFuture.isCompleted) _releasedFuture.complete();
      for (final callback in _releaseListeners.toList()) {
        try {
          callback();
        } catch (_) {}
      }
      _releaseListeners.clear();
    });
    _gate._schedule();
  }

  void finish() {
    _releaseListeners.clear();
    if (finished) return;
    finished = true;
    _gate._schedule();
  }

  void _release() {
    if (!blocks) return;
    released = true;
    _releasedFuture.complete();
    for (final callback in _releaseListeners.toList()) {
      try {
        callback();
      } catch (_) {
        /* Other owners must still release. */
      }
    }
    _releaseListeners.clear();
  }
}
