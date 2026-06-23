import 'dart:async';

import 'chatroom_client.dart';
import 'chatroom_models.dart';

enum ChatroomConnectionStatus {
  disconnected,
  connecting,
  connected,
  joining,
  joined,
}

class ChatroomConnectionIdentity {
  const ChatroomConnectionIdentity({
    required this.userId,
    required this.senderId,
    required this.senderName,
  });

  final String userId;
  final String senderId;
  final String senderName;
}

class ChatroomConnectionSnapshot {
  const ChatroomConnectionSnapshot({
    required this.status,
    this.session,
    this.joined,
    this.failure,
  });

  final ChatroomConnectionStatus status;
  final ChatroomSession? session;
  final ChatroomJoined? joined;
  final ChatroomFailureEvent? failure;

  bool get isSocketConnected {
    return status == ChatroomConnectionStatus.connected ||
        status == ChatroomConnectionStatus.joining ||
        status == ChatroomConnectionStatus.joined;
  }

  bool get isJoined => status == ChatroomConnectionStatus.joined;
}

class ChatroomConnectionController {
  ChatroomConnectionController({
    required ChatroomClient client,
    Duration reconnectInterval = const Duration(seconds: 5),
  }) : _client = client,
       _reconnectInterval = reconnectInterval;

  final ChatroomClient _client;
  final Duration _reconnectInterval;
  final _states = StreamController<ChatroomConnectionSnapshot>.broadcast();
  final _failures = StreamController<ChatroomFailureEvent>.broadcast();

  ChatroomConnectionStatus _status = ChatroomConnectionStatus.disconnected;
  ChatroomSession? _session;
  ChatroomJoined? _joined;
  ChatroomFailureEvent? _lastFailure;
  ChatroomConnectionIdentity? _identity;
  String? _worldId;
  String? _joinLocationId;
  bool _desiredConnected = false;
  bool _desiredJoined = false;
  bool _manualSessionClose = false;
  bool _suspended = false;
  bool _disposed = false;
  bool _restoreConnected = false;
  bool _restoreJoined = false;
  Timer? _reconnectTimer;
  Completer<void>? _connectCompleter;
  Completer<ChatroomJoined>? _joinCompleter;
  StreamSubscription<ChatroomEvent>? _eventSubscription;
  StreamSubscription<ChatroomFailureEvent>? _failureSubscription;

  Stream<ChatroomConnectionSnapshot> get states => _states.stream;

  Stream<ChatroomFailureEvent> get failures => _failures.stream;

  ChatroomConnectionStatus get status => _status;

  ChatroomSession? get session => _session;

  ChatroomJoined? get joined => _joined;

  bool get isConnected {
    return _status == ChatroomConnectionStatus.connected ||
        _status == ChatroomConnectionStatus.joining ||
        _status == ChatroomConnectionStatus.joined;
  }

  bool get isJoined => _status == ChatroomConnectionStatus.joined;

  ChatroomConnectionSnapshot get snapshot {
    return ChatroomConnectionSnapshot(
      status: _status,
      session: _session,
      joined: _joined,
      failure: _lastFailure,
    );
  }

  Future<void> connect({
    required String worldId,
    required ChatroomConnectionIdentity identity,
  }) {
    _throwIfDisposed();
    _worldId = worldId.trim();
    _identity = identity;
    _desiredConnected = true;
    _manualSessionClose = false;
    _suspended = false;
    if (_status == ChatroomConnectionStatus.connected ||
        _status == ChatroomConnectionStatus.joining ||
        _status == ChatroomConnectionStatus.joined) {
      return Future<void>.value();
    }
    return _ensureConnected();
  }

  Future<ChatroomJoined> join({String? locationId}) {
    _throwIfDisposed();
    final resolvedLocationId = locationId?.trim();
    if (resolvedLocationId != null && resolvedLocationId.isNotEmpty) {
      _joinLocationId = resolvedLocationId;
    }
    _desiredConnected = true;
    _desiredJoined = true;
    _manualSessionClose = false;
    _suspended = false;
    if (_status == ChatroomConnectionStatus.joined && _joined != null) {
      return Future<ChatroomJoined>.value(_joined);
    }
    return _ensureJoined();
  }

  Future<void> leave() async {
    _throwIfDisposed();
    _desiredJoined = false;
    _restoreJoined = false;
    _joinCompleter = null;
    final session = _session;
    _joined = null;
    if (_status == ChatroomConnectionStatus.joining ||
        _status == ChatroomConnectionStatus.joined) {
      _setStatus(
        session == null
            ? ChatroomConnectionStatus.disconnected
            : ChatroomConnectionStatus.connected,
      );
    }
    if (session == null) return;
    try {
      await session.leave();
    } catch (e) {
      _emitFailure(
        e is ChatroomFailureEvent
            ? e
            : ChatroomFailureEvent(
                code: 'leave_failed',
                message: 'Something went wrong',
                sourceType: 'leave',
                requestType: 'leave',
                cause: e,
              ),
      );
      rethrow;
    }
  }

  Future<void> disconnect() {
    _throwIfDisposed();
    _desiredConnected = false;
    _desiredJoined = false;
    _restoreConnected = false;
    _restoreJoined = false;
    _suspended = false;
    return _disconnectSession(updateDesired: false);
  }

  Future<void> handleAppBackground() async {
    _throwIfDisposed();
    final shouldRestoreJoined =
        _desiredJoined ||
        _status == ChatroomConnectionStatus.joining ||
        _status == ChatroomConnectionStatus.joined;
    final shouldRestoreConnected =
        shouldRestoreJoined ||
        _desiredConnected ||
        _status == ChatroomConnectionStatus.connecting ||
        _status == ChatroomConnectionStatus.connected;
    _restoreJoined = shouldRestoreJoined;
    _restoreConnected = shouldRestoreConnected;
    _suspended = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (shouldRestoreJoined) {
      try {
        await leave();
      } catch (_) {
        // Backgrounding should still close the socket if leave fails.
      }
      _restoreJoined = true;
      _restoreConnected = shouldRestoreConnected;
    }
    await _disconnectSession(updateDesired: false);
  }

  Future<void> handleAppForeground() async {
    _throwIfDisposed();
    if (!_restoreConnected && !_restoreJoined) return;
    _suspended = false;
    _desiredConnected = _restoreConnected || _restoreJoined;
    _desiredJoined = _restoreJoined;
    _manualSessionClose = false;
    if (_desiredConnected) {
      await _ensureConnected();
    }
    if (_desiredJoined) {
      await _ensureJoined();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _desiredConnected = false;
    _desiredJoined = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _detachSessionSubscriptions();
    await _states.close();
    await _failures.close();
  }

  Future<void> _ensureConnected() {
    final session = _session;
    if (session != null &&
        (_status == ChatroomConnectionStatus.connected ||
            _status == ChatroomConnectionStatus.joining ||
            _status == ChatroomConnectionStatus.joined)) {
      return Future<void>.value();
    }
    final current = _connectCompleter;
    if (current != null) return current.future;
    final completer = Completer<void>();
    _connectCompleter = completer;
    unawaited(_connectAttempt(completer));
    return completer.future;
  }

  Future<ChatroomJoined> _ensureJoined() {
    final joined = _joined;
    if (_status == ChatroomConnectionStatus.joined && joined != null) {
      return Future<ChatroomJoined>.value(joined);
    }
    final current = _joinCompleter;
    if (current != null) return current.future;
    final completer = Completer<ChatroomJoined>();
    _joinCompleter = completer;
    unawaited(_joinAttempt(completer));
    return completer.future;
  }

  Future<void> _connectAttempt(Completer<void> completer) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setStatus(ChatroomConnectionStatus.connecting);
    try {
      final identity = _identity;
      final worldId = _worldId;
      if (identity == null || worldId == null || worldId.isEmpty) {
        throw const ChatroomProtocolException('connect request is incomplete');
      }
      final session = await _client.connect(
        worldId: worldId,
        userId: identity.userId,
        senderId: identity.senderId,
        senderName: identity.senderName,
      );
      if (_disposed || _suspended || !_desiredConnected) {
        await session.disconnect();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      await _replaceSession(session);
      _setStatus(ChatroomConnectionStatus.connected);
      if (!completer.isCompleted) completer.complete();
      if (_desiredJoined) {
        unawaited(_joinDesiredLocation());
      }
    } catch (e) {
      final failure = e is ChatroomFailureEvent
          ? e
          : ChatroomFailureEvent(
              code: 'connect_failed',
              message: 'Failed to connect to chatroom',
              sourceType: 'connect',
              requestType: 'connect',
              cause: e,
            );
      _emitFailure(failure);
      _setStatus(ChatroomConnectionStatus.disconnected);
      if (!completer.isCompleted) completer.completeError(failure);
      _scheduleReconnect(immediate: false);
    } finally {
      if (identical(_connectCompleter, completer)) {
        _connectCompleter = null;
      }
    }
  }

  Future<void> _joinAttempt(Completer<ChatroomJoined> completer) async {
    try {
      await _ensureConnected();
      final session = _session;
      if (session == null) {
        throw const ChatroomProtocolException('chatroom is not connected');
      }
      if (!_desiredJoined || _suspended || _disposed) {
        throw const ChatroomProtocolException('join request was cancelled');
      }
      _setStatus(ChatroomConnectionStatus.joining);
      final joined = await session.join(locationId: _joinLocationId);
      if (!_desiredJoined || _suspended || _disposed) {
        throw const ChatroomProtocolException('join request was cancelled');
      }
      _joined = joined;
      _setStatus(ChatroomConnectionStatus.joined);
      if (!completer.isCompleted) completer.complete(joined);
    } catch (e) {
      final failure = e is ChatroomFailureEvent
          ? e
          : ChatroomFailureEvent(
              code: 'join_failed',
              message: 'Failed to join chatroom',
              sourceType: 'join',
              requestType: 'join',
              cause: e,
            );
      _emitFailure(failure);
      if (_session != null && !_suspended) {
        _setStatus(ChatroomConnectionStatus.connected);
      } else {
        _setStatus(ChatroomConnectionStatus.disconnected);
      }
      if (!completer.isCompleted) completer.completeError(failure);
    } finally {
      if (identical(_joinCompleter, completer)) {
        _joinCompleter = null;
      }
    }
  }

  Future<void> _replaceSession(ChatroomSession session) async {
    await _detachSessionSubscriptions();
    _session = session;
    _joined = null;
    _manualSessionClose = false;
    _eventSubscription = session.listenMessages(
      ChatroomMessageHandlers(
        onJoined: (event) {
          if (!event.ok) return;
          _joined = event;
          if (_desiredJoined) {
            _setStatus(ChatroomConnectionStatus.joined);
          }
        },
        onDisconnected: (_) => _handleSessionDone(),
      ),
      onDone: _handleSessionDone,
    );
    _failureSubscription = session.failures.listen(_emitFailure);
    _emit();
  }

  Future<void> _detachSessionSubscriptions() async {
    await _eventSubscription?.cancel();
    await _failureSubscription?.cancel();
    _eventSubscription = null;
    _failureSubscription = null;
  }

  Future<void> _disconnectSession({required bool updateDesired}) async {
    if (updateDesired) {
      _desiredConnected = false;
      _desiredJoined = false;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final session = _session;
    _session = null;
    _joined = null;
    _manualSessionClose = true;
    _setStatus(ChatroomConnectionStatus.disconnected);
    final disconnectFuture = session?.disconnect();
    await _detachSessionSubscriptions();
    await disconnectFuture;
    _manualSessionClose = false;
  }

  void _handleSessionDone() {
    if (_disposed || _manualSessionClose) return;
    _session = null;
    _joined = null;
    unawaited(_detachSessionSubscriptions());
    _setStatus(ChatroomConnectionStatus.disconnected);
    _scheduleReconnect(immediate: true);
  }

  void _scheduleReconnect({required bool immediate}) {
    if (_disposed || _suspended || !_desiredConnected) return;
    _reconnectTimer?.cancel();
    if (immediate) {
      unawaited(_ensureConnected().catchError((Object _) {}));
      return;
    }
    _reconnectTimer = Timer(_reconnectInterval, () {
      _reconnectTimer = null;
      if (_disposed || _suspended || !_desiredConnected) return;
      unawaited(_ensureConnected().catchError((Object _) {}));
    });
  }

  Future<void> _joinDesiredLocation() async {
    try {
      await _ensureJoined();
    } catch (_) {}
  }

  void _setStatus(ChatroomConnectionStatus status) {
    if (_status == status) {
      _emit();
      return;
    }
    _status = status;
    _emit();
  }

  void _emitFailure(ChatroomFailureEvent failure) {
    _lastFailure = failure;
    if (!_failures.isClosed) {
      _failures.add(failure);
    }
    _emit();
  }

  void _emit() {
    if (_states.isClosed) return;
    _states.add(snapshot);
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw const ChatroomProtocolException(
        'Chatroom connection controller is disposed',
      );
    }
  }
}
