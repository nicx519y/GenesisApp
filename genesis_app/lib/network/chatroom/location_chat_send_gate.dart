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
  final _active = <ChatSendOperation>{};
  final _ticks = <String, ChatSendOperation>{};
  bool _resetting = false;
  int _resetRevision = 0;
  int _lastScheduleScanCount = 0;
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
    if (_disposed || _resetting) return;
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
    for (final operation in _active.toList()) {
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
    if (_disposed) throw StateError('Send gate is disposed');
    final key = (worldId, tick ? '' : locationId, operationId);
    if (_resetting) {
      return ChatSendOperation._(this, key, scene, tick, _now()).._release();
    }
    final operation = _operations.putIfAbsent(key, () {
      final next = ChatSendOperation._(this, key, scene, tick, _now());
      _active.add(next);
      return next;
    });
    _schedule();
    return operation;
  }

  ChatSendOperation beginTick(String worldId) {
    final current = _ticks[worldId];
    if (current != null && !current.finished) return current;
    final next = begin(
      worldId: worldId,
      locationId: '',
      operationId: 'tick:${++_tickSequence}',
      scene: 'tick',
      tick: true,
    );
    if (!_resetting) _ticks[worldId] = next;
    return next;
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

  bool blocks(String world, String location) => _active.any(
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
      for (final op in _active.toList()) {
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

  void _releaseOperation(ChatSendOperation operation) {
    if (_disposed || !operation.blocks) return;
    operation._release();
    _schedule();
    if (!_disposed) notifyListeners();
  }

  void _schedule() {
    if (_disposed || _checking || _resetting) return;
    _timer?.cancel();
    _timer = null;
    _lastScheduleScanCount = 0;
    DateTime? next;
    for (final op in _active) {
      _lastScheduleScanCount++;
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
            for (final other in _active)
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
    if (_resetting) return;
    _resetting = true;
    _resetRevision++;
    _timer?.cancel();
    _timer = null;
    _lastScheduleScanCount = 0;
    final previous = _active.toList();
    _active.clear();
    _operations.clear();
    _ticks.clear();
    _worldContexts.clear();
    try {
      for (final op in previous) {
        op._release();
      }
    } finally {
      _resetting = false;
    }
    if (!_disposed) notifyListeners();
  }

  @visibleForTesting
  ({
    int history,
    int active,
    int progressStates,
    int progressKeys,
    int listeners,
    int guards,
    int handoffs,
    int scheduleScans,
    bool timer,
  })
  get debugResources => (
    history: _operations.length,
    active: _active.length,
    progressStates: _operations.values
        .where((op) => op._progress != null)
        .length,
    progressKeys: _operations.values.fold(
      0,
      (n, op) => n + (op._progress?.keys.length ?? 0),
    ),
    listeners: _operations.values.fold(
      0,
      (n, op) => n + (op._cancellation?.listeners.length ?? 0),
    ),
    guards: _operations.values.fold(
      0,
      (n, op) => n + (op._cancellation?.guards.length ?? 0),
    ),
    handoffs: _operations.values.fold(
      0,
      (n, op) => n + (op._cancellation?.preparations.length ?? 0),
    ),
    scheduleScans: _lastScheduleScanCount,
    timer: _timer?.isActive ?? false,
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    reset();
    _binding?.removeObserver(this);
    super.dispose();
  }
}

/// Owns subscriptions, not operations. Clearing a scope never cancels a send.
class ChatSendReleaseScope {
  final _registrations = <_ChatSendReleaseRegistration>{};

  void listen(ChatSendOperation operation, VoidCallback callback) {
    operation._listen(callback, owner: this);
  }

  void clear() {
    for (final registration in _registrations.toList()) {
      registration.cancel();
    }
  }

  @visibleForTesting
  int get debugListenerCount => _registrations.length;
}

class _ChatSendProgress {
  final openStreams = <String>{};
  final streamGenerations = <String, (String, int)>{};
  final latestAttempts = <String, int>{};
  final keys = <Object>{};
}

class _ChatSendCancellation {
  final listeners = <VoidCallback, _ChatSendReleaseRegistration>{};
  final guards = <_ChatSendGuard<dynamic>>{};
  final preparations = <ChatSendOperation>{};
}

class _ChatSendReleaseRegistration {
  _ChatSendReleaseRegistration(this.operation, this.callback, this.owner);
  ChatSendOperation? operation;
  VoidCallback? callback;
  ChatSendReleaseScope? owner;

  void cancel() {
    final op = operation;
    final action = callback;
    operation = null;
    callback = null;
    owner?._registrations.remove(this);
    owner = null;
    if (op?._cancellation?.listeners[action] == this) {
      op!._cancellation!.listeners.remove(action);
      op._dropEmptyCancellation();
    }
  }

  void release() {
    final action = callback;
    cancel();
    try {
      action?.call();
    } catch (_) {
      // Other owners must still release.
    }
  }
}

/// The original future retains only this empty bridge after a local timeout;
/// it cannot keep the caller's completed result or operation alive through it.
class _ChatSendGuard<T> {
  _ChatSendGuard(this.operation);
  ChatSendOperation? operation;
  Completer<T>? _result = Completer<T>();

  Future<T> get future => _result!.future;

  void watch(Future<T> future) {
    unawaited(future.then<void>(_success, onError: _error));
  }

  void detach() {
    final op = operation;
    operation = null;
    op?._cancellation?.guards.remove(this);
    op?._dropEmptyCancellation();
  }

  void release(String id) =>
      _error(ChatSendWaitReleased(id), StackTrace.current);

  void _success(T value) {
    final result = _result;
    _result = null;
    detach();
    result?.complete(value);
  }

  void _error(Object error, StackTrace stack) {
    final result = _result;
    _result = null;
    detach();
    result?.completeError(error, stack);
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
  // Only scalar diagnostics/correlation survive completion.
  final diagnostics = <String, Object?>{};
  _ChatSendProgress? _progress = _ChatSendProgress();
  _ChatSendCancellation? _cancellation;
  bool _terminalStreaming = false;
  bool _handoffPending = false;
  bool _dispatchingRelease = false;
  bool _warned = false;
  bool released = false;
  bool finished = false;

  String get worldId => _key.$1;
  String get locationId => _key.$2;
  String get operationId => _key.$3;
  bool get blocks => !released && !finished;
  bool get streaming => _progress?.openStreams.isNotEmpty ?? _terminalStreaming;

  VoidCallback onRelease(VoidCallback listener) => _listen(listener);

  VoidCallback _listen(VoidCallback listener, {ChatSendReleaseScope? owner}) {
    if (released) {
      listener();
      return () {};
    }
    if (finished) return () {};
    final cancellation = _cancellation ??= _ChatSendCancellation();
    final existing = cancellation.listeners[listener];
    if (existing != null) return existing.cancel;
    final registration = _ChatSendReleaseRegistration(this, listener, owner);
    cancellation.listeners[listener] = registration;
    owner?._registrations.add(registration);
    return registration.cancel;
  }

  void removeReleaseListener(VoidCallback listener) =>
      _cancellation?.listeners[listener]?.cancel();

  void _dropEmptyCancellation() {
    final state = _cancellation;
    if (state != null &&
        state.listeners.isEmpty &&
        state.guards.isEmpty &&
        state.preparations.isEmpty) {
      _cancellation = null;
    }
  }

  void progress(Object key, {String? phase}) {
    if (!blocks || !_progress!.keys.add(key)) return;
    if (phase != null && !streaming) this.phase = phase;
    if (!streaming) lastProgressAt = _gate._now();
    _gate._schedule();
  }

  /// Actual reveal changes refresh presentation waiting without retaining any
  /// message/render object or accumulating a key for every animation frame.
  void presentationProgress() {
    if (!blocks || scene != 'reply_presentation' || streaming) return;
    lastProgressAt = _gate._now();
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
    final progress = _progress!;
    if (generationKey != null && attemptNo != null) {
      if (attemptNo < (progress.latestAttempts[generationKey] ?? 0)) return;
      progress.latestAttempts[generationKey] = attemptNo;
    }
    if (!progress.keys.add(('stream', streamId, frameId))) return;
    if (generationKey != null && attemptNo != null) {
      progress.openStreams.removeWhere((id) {
        final generation = progress.streamGenerations[id];
        return generation != null &&
            generation.$1 == generationKey &&
            generation.$2 < attemptNo;
      });
      progress.streamGenerations[streamId] = (generationKey, attemptNo);
      diagnostics['generation_key'] = generationKey;
      diagnostics['attempt_no'] = attemptNo;
    }
    if (end) {
      progress.openStreams.remove(streamId);
    } else {
      progress.openStreams.add(streamId);
    }
    phase = streaming ? 'streaming' : 'awaiting_terminal';
    if (!end || !streaming) lastProgressAt = _gate._now();
    _gate._schedule();
  }

  void check() {
    if (released || finished) throw ChatSendWaitReleased(operationId);
  }

  Future<T> guard<T>(Future<T> future) {
    final waiter = _ChatSendGuard<T>(this);
    final result = waiter.future;
    if (released) {
      waiter.release(operationId);
    } else if (blocks || _handoffPending) {
      (_cancellation ??= _ChatSendCancellation()).guards.add(waiter);
    } else {
      waiter.detach();
    }
    // Register before listening: SynchronousFuture can deliver inside then().
    waiter.watch(future);
    return result;
  }

  /// Only the request owns a deadline. Cancellation subscriptions survive the
  /// handoff until the request ends, but preparation progress is freed now.
  void handoffTo(ChatSendOperation next) {
    if (!blocks || identical(this, next)) return;
    finished = true;
    _handoffPending = true;
    _retireProgress();
    if (next.released) {
      _endHandoff(release: true);
    } else if (next.finished && !next._handoffPending) {
      _endHandoff(release: false);
    } else {
      (next._cancellation ??= _ChatSendCancellation()).preparations.add(this);
    }
    _gate._schedule();
  }

  void _retireProgress() {
    _terminalStreaming = streaming;
    _progress = null;
    _gate._active.remove(this);
  }

  void finish() {
    finished = true;
    _retireProgress();
    // A page finally may run after handoff while its guarded transaction is
    // still pending. Remove UI cleanup, but preserve request cancellation.
    if (_dispatchingRelease) return;
    if (_handoffPending) {
      for (final listener
          in _cancellation?.listeners.values.toList() ??
              <_ChatSendReleaseRegistration>[]) {
        listener.cancel();
      }
    } else {
      _endCancellation(release: false);
    }
    _gate._schedule();
  }

  void releaseLocalWait() => _gate._releaseOperation(this);

  void _release() {
    if (!blocks) return;
    released = true;
    _retireProgress();
    _endCancellation(release: true);
  }

  void _endHandoff({required bool release}) {
    if (!_handoffPending) return;
    _handoffPending = false;
    if (release) released = true;
    _endCancellation(release: release);
  }

  void _endCancellation({required bool release}) {
    final state = _cancellation;
    if (state == null) return;
    // Keep the detached snapshot local: callbacks may finish/reset operations
    // or unsubscribe another owner without retaining the old closures.
    final guards = state.guards.toList();
    final listeners = state.listeners.values.toList();
    final preparations = state.preparations.toList();
    final revision = _gate._resetRevision;
    state.preparations.clear();
    if (release) _dispatchingRelease = true;
    for (final waiter in guards) {
      if (release) {
        waiter.release(operationId);
      } else {
        waiter.detach();
      }
    }
    for (final preparation in preparations) {
      preparation._endHandoff(release: release);
    }
    for (final listener in listeners) {
      if (release && revision == _gate._resetRevision) {
        listener.release();
      } else {
        listener.cancel();
      }
    }
    _dispatchingRelease = false;
    _dropEmptyCancellation();
  }
}
