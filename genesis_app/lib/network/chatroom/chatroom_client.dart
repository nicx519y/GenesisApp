import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../platform/device/device_id_service.dart';
import '../../platform/session/user_session_store.dart';
import 'chatroom_models.dart';
import 'chatroom_socket_transport.dart';

class ChatroomClient {
  ChatroomClient({
    required String wsBaseUrl,
    required UserSessionStore sessionStore,
    DeviceIdService? deviceIdService,
    ChatroomSocketTransport? transport,
    Duration heartbeatInterval = const Duration(seconds: 2),
    Duration ackTimeout = const Duration(seconds: 12),
  }) : _wsBaseUri = Uri.parse(wsBaseUrl),
       _sessionStore = sessionStore,
       _deviceIdService = deviceIdService,
       _transport = transport ?? IoChatroomSocketTransport(),
       _heartbeatInterval = heartbeatInterval,
       _ackTimeout = ackTimeout;

  final Uri _wsBaseUri;
  final UserSessionStore _sessionStore;
  final DeviceIdService? _deviceIdService;
  final ChatroomSocketTransport _transport;
  final Duration _heartbeatInterval;
  final Duration _ackTimeout;

  Future<ChatroomSession> connect({
    String? worldId,
    String? worldInstanceId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
  }) async {
    final resolvedWorldId = (worldId ?? worldInstanceId)?.trim();
    if (resolvedWorldId == null || resolvedWorldId.isEmpty) {
      throw const ChatroomProtocolException('worldId is required');
    }
    final resolvedUserId = (userId ?? await _sessionStore.readUid())?.trim();

    final authToken = (await _sessionStore.readAuthToken())?.trim();
    if (authToken == null || authToken.isEmpty) {
      throw const ChatroomProtocolException('authToken is required');
    }
    final deviceId = (await _deviceIdService?.getDeviceId())?.trim();
    final resolvedSenderId = senderId?.trim().isNotEmpty == true
        ? senderId!.trim()
        : resolvedUserId ?? '';
    final resolvedSenderName = senderName?.trim().isNotEmpty == true
        ? senderName!.trim()
        : resolvedSenderId;
    final uri = _resolveUri(worldInstanceId: resolvedWorldId);
    final headers = <String, String>{
      if (deviceId != null && deviceId.isNotEmpty) 'device-id': deviceId,
      'Authorization': authToken.toLowerCase().startsWith('bearer ')
          ? authToken
          : 'Bearer $authToken',
    };
    final socket = await _transport.connect(
      uri,
      headers: headers.isEmpty ? null : headers,
    );
    final session = ChatroomSession._(
      socket: socket,
      worldInstanceId: resolvedWorldId,
      locationId: locationId?.trim() ?? '',
      userId: resolvedUserId ?? '',
      senderId: resolvedSenderId,
      senderName: resolvedSenderName,
      heartbeatInterval: _heartbeatInterval,
      ackTimeout: _ackTimeout,
    );
    return session;
  }

  Future<ChatroomSession> connectAndJoin({
    String? worldId,
    String? worldInstanceId,
    String? locationId,
    String? userId,
    String? senderId,
    String? senderName,
  }) async {
    final session = await connect(
      worldId: worldId,
      worldInstanceId: worldInstanceId,
      locationId: locationId,
      userId: userId,
      senderId: senderId,
      senderName: senderName,
    );
    try {
      await session.join();
    } catch (_) {
      await session.disconnect();
      rethrow;
    }
    return session;
  }

  Uri _resolveUri({required String worldInstanceId}) {
    final base = _withDefaultWebSocketPort(_wsBaseUri);
    final basePath = base.path.trim();
    final path = basePath.isEmpty ? '/' : basePath;
    return base.replace(
      path: path,
      queryParameters: <String, String>{
        ...base.queryParameters,
        'world_id': worldInstanceId,
      },
    );
  }

  Uri _withDefaultWebSocketPort(Uri uri) {
    if (uri.hasPort) return uri;
    return switch (uri.scheme.toLowerCase()) {
      'ws' => uri.replace(port: 80),
      'wss' => uri.replace(port: 443),
      _ => uri,
    };
  }
}

class ChatroomSession {
  ChatroomSession._({
    required ChatroomSocket socket,
    required this.worldInstanceId,
    required this.locationId,
    required this.userId,
    required this.senderId,
    required this.senderName,
    required Duration heartbeatInterval,
    required Duration ackTimeout,
  }) : _socket = socket,
       _heartbeatInterval = heartbeatInterval,
       _ackTimeout = ackTimeout {
    _subscription = _socket.messages.listen(
      _handleMessage,
      onError: _handleSocketError,
      onDone: () => _handleSocketDone(),
      cancelOnError: false,
    );
    _startHeartbeat();
  }

  final ChatroomSocket _socket;
  final Duration _heartbeatInterval;
  final Duration _ackTimeout;
  final String worldInstanceId;
  final String locationId;
  final String userId;
  final String senderId;
  final String senderName;
  final _events = StreamController<ChatroomEvent>.broadcast();
  final _errors = StreamController<ChatroomErrorEvent>.broadcast();
  final _failures = StreamController<ChatroomFailureEvent>.broadcast();
  final _streams = StreamController<ChatroomAiMessageStream>.broadcast();
  final _pendingAcks = <String, _PendingAck>{};
  final _pendingHeartbeats = <_PendingHeartbeat>[];
  final _activeStreams = <int, ChatroomAiMessageStream>{};
  final _pendingJoinAcks = <String, _PendingAck>{};
  _PendingJoin? _pendingJoin;
  late final StreamSubscription<String> _subscription;
  Timer? _heartbeatTimer;
  bool _closed = false;
  bool _disposed = false;
  ChatroomJoined? _joined;

  Stream<ChatroomEvent> get events => _events.stream;

  Stream<ChatroomErrorEvent> get errors => _errors.stream;

  Stream<ChatroomFailureEvent> get failures => _failures.stream;

  Stream<ChatroomAiMessageStream> get streams => _streams.stream;

  ChatroomJoined? get joined => _joined;

  StreamSubscription<ChatroomEvent> listenMessages(
    ChatroomMessageHandlers handlers, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return events.listen(
      handlers.handle,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<ChatroomJoined> join({String? locationId}) async {
    _throwIfClosed();
    if (_joined != null) return _joined!;
    if (_pendingJoin != null) return _pendingJoin!.completer.future;

    final completer = Completer<ChatroomJoined>();
    final timer = Timer(_ackTimeout, () {
      final pending = _pendingJoin;
      if (pending == null || pending.completer.isCompleted) return;
      _pendingJoin = null;
      final failure = ChatroomFailureEvent(
        code: 'join_timeout',
        message: 'Timed out waiting for joined message',
        sourceType: 'joined',
        requestType: 'join',
      );
      _emitFailure(failure);
      pending.completeError(failure);
    });
    _pendingJoin = _PendingJoin(completer, timer);

    try {
      final requestedLocationId = locationId?.trim();
      final resolvedLocationId =
          requestedLocationId != null && requestedLocationId.isNotEmpty
          ? requestedLocationId
          : this.locationId.trim();
      if (resolvedLocationId.isEmpty) {
        throw const ChatroomProtocolException('locationId is required');
      }
      final clientMsgId = _newClientMessageId();
      _pendingJoinAcks[clientMsgId] = _PendingAck(
        Completer<ChatroomAck>(),
        Timer(_ackTimeout, () {
          _pendingJoinAcks.remove(clientMsgId);
        }),
        requestType: 'join',
      );
      await _sendClientMessage('join', <String, Object?>{
        'client_msg_id': clientMsgId,
        'world_id': worldInstanceId,
        'location_id': resolvedLocationId,
      });
    } catch (e) {
      final pending = _pendingJoin;
      _pendingJoin = null;
      pending?.cancel();
      final failure = ChatroomFailureEvent(
        code: 'join_send_failed',
        message: 'Failed to send join message',
        sourceType: 'join',
        requestType: 'join',
        cause: e,
      );
      _emitFailure(failure);
      pending?.completeError(failure);
    }

    return completer.future;
  }

  Future<void> heartbeat() async {
    _throwIfClosed();
    final completer = Completer<void>();
    final pending = _PendingHeartbeat(completer);
    pending.timer = Timer(_ackTimeout, () {
      if (!_pendingHeartbeats.remove(pending)) return;
      final failure = ChatroomFailureEvent(
        code: 'heartbeat_timeout',
        message: 'Timed out waiting for heartbeat response',
        sourceType: 'heartbeat',
        requestType: 'heartbeat',
      );
      _emitFailure(failure);
      pending.completeError(failure);
    });
    _pendingHeartbeats.add(pending);

    try {
      await _sendClientMessage('heartbeat', const <String, Object?>{});
    } catch (e) {
      _pendingHeartbeats.remove(pending);
      pending.cancel();
      final failure = ChatroomFailureEvent(
        code: 'heartbeat_failed',
        message: 'Failed to send heartbeat message',
        sourceType: 'heartbeat',
        requestType: 'heartbeat',
        cause: e,
      );
      _emitFailure(failure);
      pending.completeError(failure);
    }

    return completer.future;
  }

  Future<ChatroomAck> sendMessage(
    String text, {
    String? clientUuid,
    String? clientMsgId,
  }) async {
    _throwIfClosed();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatroomProtocolException('Message text is required');
    }
    final resolvedClientUuid =
        clientUuid ?? clientMsgId ?? _newClientMessageId();
    final completer = Completer<ChatroomAck>();
    final timer = Timer(_ackTimeout, () {
      final pending = _pendingAcks.remove(resolvedClientUuid);
      if (pending != null && !pending.completer.isCompleted) {
        final failure = ChatroomFailureEvent(
          code: 'ack_timeout',
          message: 'Timed out waiting for message ack',
          sourceType: 'ack',
          requestType: 'send_message',
          cause: resolvedClientUuid,
        );
        _emitFailure(failure);
        pending.completeError(failure);
      }
    });
    _pendingAcks[resolvedClientUuid] = _PendingAck(
      completer,
      timer,
      requestType: 'send_message',
    );

    try {
      await _sendClientMessage('send_message', <String, Object?>{
        'client_msg_id': resolvedClientUuid,
        'content': trimmed,
      });
    } catch (e) {
      final pending = _pendingAcks.remove(resolvedClientUuid);
      pending?.cancel();
      final failure = ChatroomFailureEvent(
        code: 'send_message_failed',
        message: 'Failed to send chatroom message',
        sourceType: 'send_message',
        requestType: 'send_message',
        cause: e,
      );
      _emitFailure(failure);
      pending?.completeError(failure);
    }

    return completer.future;
  }

  ChatroomAiMessageStream? streamForMessage(int messageId) {
    return _activeStreams[messageId];
  }

  Future<void> close() async {
    if (_closed) return;
    if (_joined != null || _pendingJoin != null) {
      try {
        await leave();
      } catch (_) {
        // close() preserves the old best-effort shutdown behavior.
      }
    }
    await disconnect();
  }

  Future<void> leave() async {
    _throwIfClosed();
    try {
      await _sendClientMessage('leave', <String, Object?>{
        'client_msg_id': _newClientMessageId(),
      });
      _joined = null;
    } catch (e) {
      final failure = ChatroomFailureEvent(
        code: 'leave_failed',
        message: 'Failed to send leave message',
        sourceType: 'leave',
        requestType: 'leave',
        cause: e,
      );
      _emitFailure(failure);
      throw failure;
    }
  }

  Future<void> disconnect() async {
    if (_closed) return;
    final reason = ChatroomFailureEvent(
      code: 'closed',
      message: 'Chatroom session closed',
      sourceType: 'disconnect',
      requestType: 'disconnect',
    );
    await _disposeState(reason);
    await _socket.close(1000, 'client_disconnect');
  }

  Future<void> _sendClientMessage(String type, Map<String, Object?> fields) {
    _throwIfClosed();
    final json = <String, Object?>{'type': type};
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      json[entry.key] = value;
    }
    return _socket.send(jsonEncode(json));
  }

  void _handleMessage(String raw) {
    try {
      final envelope = ChatroomEnvelope.decode(raw);
      final event = chatroomEventFromEnvelope(envelope);
      _dispatchEvent(event);
    } catch (e) {
      _emitFailure(
        ChatroomFailureEvent(
          code: 'protocol_error',
          message: 'Failed to parse chatroom message',
          sourceType: 'protocol_error',
          cause: e,
        ),
      );
    }
  }

  void _dispatchEvent(ChatroomEvent event) {
    if (event is ChatroomJoined) {
      final pending = _pendingJoin;
      _pendingJoin = null;
      pending?.cancel();
      _clearPendingJoinAcks();
      if (event.ok) {
        _joined = event;
        pending?.complete(event);
      } else {
        final failure = ChatroomFailureEvent.fromPayloadEvent(
          event,
          requestType: 'join',
        );
        _emitFailure(failure);
        pending?.completeError(failure);
      }
    } else if (event is ChatroomAck) {
      final joinPending = _pendingJoin == null
          ? null
          : event.clientUuid.isEmpty
          ? _removeOldestPendingJoinAck()
          : _pendingJoinAcks.remove(event.clientUuid);
      joinPending?.cancel();
      final pendingJoin = joinPending == null ? null : _pendingJoin;
      if (pendingJoin != null) {
        _pendingJoin = null;
        pendingJoin.cancel();
        final joined = ChatroomJoined(
          sessionId: event.sessionId,
          worldId: event.worldId.isEmpty ? worldInstanceId : event.worldId,
          locationId: event.locationId.isEmpty ? locationId : event.locationId,
          userId: event.userId.isEmpty ? userId : event.userId,
          code: event.code,
          codeMsg: event.codeMsg,
          ts: event.ts,
          onlineUsers: const <ChatroomOnlineUser>[],
        );
        if (joined.ok) {
          _joined = joined;
          pendingJoin.complete(joined);
        } else {
          final failure = ChatroomFailureEvent.fromPayloadEvent(
            joined,
            requestType: 'join',
          );
          _emitFailure(failure);
          pendingJoin.completeError(failure);
        }
      }
      final pending = event.clientUuid.isEmpty
          ? _removeOldestPendingAck()
          : _pendingAcks.remove(event.clientUuid);
      if (event.ok) {
        pending?.complete(event);
      } else {
        final failure = ChatroomFailureEvent.fromPayloadEvent(
          event,
          requestType: pending?.requestType ?? 'send_message',
        );
        _emitFailure(failure);
        pending?.completeError(failure);
      }
    } else if (event is ChatroomHeartbeat) {
      final pending = _removeOldestPendingHeartbeat();
      if (event.ok) {
        pending?.complete();
      } else {
        final failure = ChatroomFailureEvent.fromPayloadEvent(
          event,
          requestType: 'heartbeat',
        );
        _emitFailure(failure);
        pending?.completeError(failure);
      }
    } else if (event is ChatroomAiStreamStart) {
      final stream = ChatroomAiMessageStream._(event);
      _activeStreams[event.messageId] = stream;
      _streams.add(stream);
    } else if (event is ChatroomAiStreamChunk) {
      _streamForAiEvent(
        messageId: event.messageId,
        conversationRoundId: event.conversationRoundId,
        senderId: event.senderId,
      )?.addChunk(event);
    } else if (event is ChatroomAiStreamEnd) {
      final stream = _removeStreamForAiEvent(
        messageId: event.messageId,
        conversationRoundId: event.conversationRoundId,
        senderId: event.senderId,
      );
      stream?.complete(event);
    } else if (event is ChatroomErrorEvent) {
      _emitError(event);
      _emitFailure(ChatroomFailureEvent.fromError(event));
      _failMatchingStream(event);
    } else if (event is ChatroomPayloadEvent && !event.ok) {
      _emitFailure(ChatroomFailureEvent.fromPayloadEvent(event));
    }

    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _handleSocketError(Object error) {
    final event = ChatroomErrorEvent(
      code: 'socket_error',
      message: 'Chatroom socket error',
      cause: error,
    );
    _emitError(event);
    _emitFailure(ChatroomFailureEvent.fromError(event, requestType: 'socket'));
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleSocketDone() {
    final reason = ChatroomFailureEvent(
      code: 'socket_closed',
      message: 'Chatroom socket closed',
      sourceType: 'socket_closed',
    );
    _emitFailure(reason);
    unawaited(_disposeState(reason));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(heartbeat().catchError((Object error) {}));
    });
  }

  Future<void> _disposeState(ChatroomFailureEvent reason) async {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    _stopHeartbeat();

    _pendingJoin?.completeError(reason);
    _pendingJoin = null;
    _clearPendingJoinAcks();

    for (final pending in _pendingAcks.values) {
      pending.completeError(reason);
    }
    _pendingAcks.clear();

    for (final pending in _pendingHeartbeats) {
      pending.completeError(reason);
    }
    _pendingHeartbeats.clear();

    for (final stream in _activeStreams.values) {
      stream.fail(reason);
    }
    _activeStreams.clear();

    await _subscription.cancel();
    await _events.close();
    await _errors.close();
    await _failures.close();
    await _streams.close();
  }

  void _emitError(ChatroomErrorEvent error) {
    if (!_errors.isClosed) {
      _errors.add(error);
    }
  }

  void _emitFailure(ChatroomFailureEvent failure) {
    if (!_failures.isClosed) {
      _failures.add(failure);
    }
    if (!_events.isClosed) {
      _events.add(failure);
    }
  }

  void _failMatchingStream(ChatroomErrorEvent error) {
    if (error.conversationRoundId.isEmpty && error.senderId.isEmpty) return;
    final matches = _activeStreams.entries
        .where((entry) {
          final start = entry.value.start;
          final roundMatches =
              error.conversationRoundId.isEmpty ||
              error.conversationRoundId == start.conversationRoundId;
          final senderMatches =
              error.senderId.isEmpty || error.senderId == start.senderId;
          return roundMatches && senderMatches;
        })
        .toList(growable: false);

    for (final match in matches) {
      _activeStreams.remove(match.key);
      match.value.fail(error);
    }
  }

  ChatroomAiMessageStream? _streamForAiEvent({
    required int messageId,
    required String conversationRoundId,
    required String senderId,
  }) {
    if (messageId != 0) {
      final exact = _activeStreams[messageId];
      if (exact != null) return exact;
    }
    final matches = _matchingStreams(
      conversationRoundId: conversationRoundId,
      senderId: senderId,
    );
    if (matches.length == 1) return matches.single.value;
    if (_activeStreams.length == 1) return _activeStreams.values.single;
    return null;
  }

  ChatroomAiMessageStream? _removeStreamForAiEvent({
    required int messageId,
    required String conversationRoundId,
    required String senderId,
  }) {
    if (messageId != 0) {
      final exact = _activeStreams.remove(messageId);
      if (exact != null) return exact;
    }
    final matches = _matchingStreams(
      conversationRoundId: conversationRoundId,
      senderId: senderId,
    );
    if (matches.length == 1) {
      return _activeStreams.remove(matches.single.key);
    }
    if (_activeStreams.length == 1) {
      final key = _activeStreams.keys.single;
      return _activeStreams.remove(key);
    }
    return null;
  }

  List<MapEntry<int, ChatroomAiMessageStream>> _matchingStreams({
    required String conversationRoundId,
    required String senderId,
  }) {
    return _activeStreams.entries
        .where((entry) {
          final start = entry.value.start;
          final roundMatches =
              conversationRoundId.isEmpty ||
              conversationRoundId == start.conversationRoundId;
          final senderMatches = senderId.isEmpty || senderId == start.senderId;
          return roundMatches && senderMatches;
        })
        .toList(growable: false);
  }

  void _throwIfClosed() {
    if (_closed) {
      throw const ChatroomProtocolException('Chatroom session is closed');
    }
  }

  String _newClientMessageId() {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  _PendingAck? _removeOldestPendingAck() {
    if (_pendingAcks.isEmpty) return null;
    final key = _pendingAcks.keys.first;
    return _pendingAcks.remove(key);
  }

  _PendingAck? _removeOldestPendingJoinAck() {
    if (_pendingJoinAcks.isEmpty) return null;
    final key = _pendingJoinAcks.keys.first;
    return _pendingJoinAcks.remove(key);
  }

  void _clearPendingJoinAcks() {
    for (final pending in _pendingJoinAcks.values) {
      pending.cancel();
    }
    _pendingJoinAcks.clear();
  }

  _PendingHeartbeat? _removeOldestPendingHeartbeat() {
    if (_pendingHeartbeats.isEmpty) return null;
    return _pendingHeartbeats.removeAt(0);
  }
}

class ChatroomAiMessageStream {
  ChatroomAiMessageStream._(this.start);

  final ChatroomAiStreamStart start;
  final _chunks = StreamController<ChatroomAiStreamChunk>.broadcast();
  final _done = Completer<ChatroomAiStreamEnd>();
  final _buffer = StringBuffer();

  Stream<ChatroomAiStreamChunk> get chunks => _chunks.stream;

  Future<ChatroomAiStreamEnd> get done => _done.future;

  String get content => _buffer.toString();

  bool get isCompleted => _done.isCompleted;

  void addChunk(ChatroomAiStreamChunk chunk) {
    if (_done.isCompleted) return;
    _buffer.write(chunk.chunk);
    _chunks.add(chunk);
  }

  void complete(ChatroomAiStreamEnd end) {
    if (_done.isCompleted) return;
    _done.complete(end);
    unawaited(_chunks.close());
  }

  void fail(Object error) {
    if (!_done.isCompleted) {
      _done.completeError(error);
    }
    if (!_chunks.isClosed) {
      _chunks.addError(error);
      unawaited(_chunks.close());
    }
  }
}

class _PendingAck {
  _PendingAck(this.completer, this.timer, {required this.requestType});

  final Completer<ChatroomAck> completer;
  final Timer timer;
  final String requestType;

  void complete(ChatroomAck ack) {
    cancel();
    if (!completer.isCompleted) {
      completer.complete(ack);
    }
  }

  void completeError(Object error) {
    cancel();
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void cancel() {
    timer.cancel();
  }
}

class _PendingJoin {
  _PendingJoin(this.completer, this.timer);

  final Completer<ChatroomJoined> completer;
  final Timer timer;

  void complete(ChatroomJoined joined) {
    cancel();
    if (!completer.isCompleted) {
      completer.complete(joined);
    }
  }

  void completeError(Object error) {
    cancel();
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void cancel() {
    timer.cancel();
  }
}

class _PendingHeartbeat {
  _PendingHeartbeat(this.completer);

  final Completer<void> completer;
  Timer? timer;

  void complete() {
    cancel();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void completeError(Object error) {
    cancel();
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void cancel() {
    timer?.cancel();
  }
}
