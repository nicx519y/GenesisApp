import 'dart:async';
import 'dart:math';

import '../../platform/session/user_session_store.dart';
import 'chatroom_models.dart';
import 'chatroom_socket_transport.dart';

class ChatroomClient {
  ChatroomClient({
    required String wsBaseUrl,
    required UserSessionStore sessionStore,
    ChatroomSocketTransport? transport,
    Duration heartbeatInterval = const Duration(seconds: 30),
    Duration ackTimeout = const Duration(seconds: 12),
  }) : _wsBaseUri = Uri.parse(wsBaseUrl),
       _sessionStore = sessionStore,
       _transport = transport ?? const IoChatroomSocketTransport(),
       _heartbeatInterval = heartbeatInterval,
       _ackTimeout = ackTimeout;

  final Uri _wsBaseUri;
  final UserSessionStore _sessionStore;
  final ChatroomSocketTransport _transport;
  final Duration _heartbeatInterval;
  final Duration _ackTimeout;

  Future<ChatroomSession> connect({
    required String worldInstanceId,
    required String locationId,
    String? userId,
    required String senderId,
    required String senderName,
  }) async {
    final resolvedUserId = (userId ?? await _sessionStore.readUid())?.trim();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      throw const ChatroomProtocolException('userId is required');
    }

    final uri = _resolveUri(
      worldInstanceId: worldInstanceId,
      locationId: locationId,
    );
    final socket = await _transport.connect(uri);
    final session = ChatroomSession._(
      socket: socket,
      worldInstanceId: worldInstanceId,
      locationId: locationId,
      heartbeatInterval: _heartbeatInterval,
      ackTimeout: _ackTimeout,
    );
    try {
      await session._join(
        userId: resolvedUserId,
        senderId: senderId,
        senderName: senderName,
      );
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }

  Uri _resolveUri({
    required String worldInstanceId,
    required String locationId,
  }) {
    final base = _wsBaseUri;
    final path = base.path.trim().isEmpty ? '/ws' : base.path;
    return base.replace(
      path: path,
      queryParameters: <String, String>{
        ...base.queryParameters,
        'world_instance_id': worldInstanceId,
        'location_id': locationId,
      },
    );
  }
}

class ChatroomSession {
  ChatroomSession._({
    required ChatroomSocket socket,
    required this.worldInstanceId,
    required this.locationId,
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
  }

  final ChatroomSocket _socket;
  final Duration _heartbeatInterval;
  final Duration _ackTimeout;
  final String worldInstanceId;
  final String locationId;
  final _events = StreamController<ChatroomEvent>.broadcast();
  final _errors = StreamController<ChatroomErrorEvent>.broadcast();
  final _streams = StreamController<ChatroomAiMessageStream>.broadcast();
  final _pendingAcks = <String, _PendingAck>{};
  final _activeStreams = <int, ChatroomAiMessageStream>{};
  late final StreamSubscription<String> _subscription;
  Timer? _heartbeatTimer;
  bool _closed = false;
  bool _disposed = false;
  ChatroomJoined? _joined;

  Stream<ChatroomEvent> get events => _events.stream;

  Stream<ChatroomErrorEvent> get errors => _errors.stream;

  Stream<ChatroomAiMessageStream> get streams => _streams.stream;

  ChatroomJoined? get joined => _joined;

  Future<ChatroomAck> sendMessage(String text, {String? clientMsgId}) async {
    _throwIfClosed();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatroomProtocolException('Message text is required');
    }
    final resolvedClientMsgId = clientMsgId ?? _newClientMessageId();
    final completer = Completer<ChatroomAck>();
    final timer = Timer(_ackTimeout, () {
      final pending = _pendingAcks.remove(resolvedClientMsgId);
      if (pending != null && !pending.completer.isCompleted) {
        final error = ChatroomErrorEvent(
          code: 'ack_timeout',
          message: 'Timed out waiting for message ack',
          cause: resolvedClientMsgId,
        );
        _emitError(error);
        pending.completer.completeError(error);
      }
    });
    _pendingAcks[resolvedClientMsgId] = _PendingAck(completer, timer);

    try {
      await _sendEnvelope('send_message', <String, Object?>{
        'text': trimmed,
        'client_msg_id': resolvedClientMsgId,
      });
    } catch (e) {
      final pending = _pendingAcks.remove(resolvedClientMsgId);
      pending?.cancel();
      rethrow;
    }

    return completer.future;
  }

  ChatroomAiMessageStream? streamForMessage(int messageId) {
    return _activeStreams[messageId];
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sendLeaveIfPossible();
    await _disposeState(
      ChatroomErrorEvent(code: 'closed', message: 'Chatroom session closed'),
    );
    await _socket.close();
  }

  Future<void> _join({
    required String userId,
    required String senderId,
    required String senderName,
  }) async {
    final joinedCompleter = Completer<ChatroomJoined>();
    late final StreamSubscription<ChatroomEvent> joinedSubscription;
    joinedSubscription = events.listen((event) {
      if (event is ChatroomJoined && !joinedCompleter.isCompleted) {
        joinedCompleter.complete(event);
      }
    });

    await _sendEnvelope('join', <String, Object?>{
      'user_id': userId,
      'sender_id': senderId,
      'sender_name': senderName,
    });

    try {
      final joined = await joinedCompleter.future.timeout(_ackTimeout);
      _joined = joined;
      _startHeartbeat();
    } on TimeoutException catch (e) {
      throw ChatroomErrorEvent(
        code: 'join_timeout',
        message: 'Timed out waiting for joined message',
        cause: e,
      );
    } finally {
      await joinedSubscription.cancel();
    }
  }

  Future<void> _sendEnvelope(String type, Map<String, Object?> payload) {
    _throwIfClosed();
    return _socket.send(
      ChatroomEnvelope(type: type, payload: payload).encode(),
    );
  }

  void _handleMessage(String raw) {
    try {
      final envelope = ChatroomEnvelope.decode(raw);
      final event = chatroomEventFromEnvelope(envelope);
      _dispatchEvent(event);
    } catch (e) {
      _emitError(
        ChatroomErrorEvent(
          code: 'protocol_error',
          message: 'Failed to parse chatroom message',
          cause: e,
        ),
      );
    }
  }

  void _dispatchEvent(ChatroomEvent event) {
    if (event is ChatroomAck) {
      final pending = _pendingAcks.remove(event.clientMsgId);
      pending?.complete(event);
    } else if (event is ChatroomAiStreamStart) {
      final stream = ChatroomAiMessageStream._(event);
      _activeStreams[event.messageId] = stream;
      _streams.add(stream);
    } else if (event is ChatroomAiStreamChunk) {
      _activeStreams[event.messageId]?.addChunk(event);
    } else if (event is ChatroomAiStreamEnd) {
      final stream = _activeStreams.remove(event.messageId);
      stream?.complete(event);
    } else if (event is ChatroomErrorEvent) {
      _emitError(event);
      _failMatchingStream(event);
    }

    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _handleSocketError(Object error) {
    _emitError(
      ChatroomErrorEvent(
        code: 'socket_error',
        message: 'Chatroom socket error',
        cause: error,
      ),
    );
  }

  void _handleSocketDone() {
    final reason = ChatroomErrorEvent(
      code: 'socket_closed',
      message: 'Chatroom socket closed',
    );
    _emitError(reason);
    unawaited(_disposeState(reason));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(
        _sendEnvelope('heartbeat', <String, Object?>{
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }).catchError((Object error) {
          _handleSocketError(error);
        }),
      );
    });
  }

  Future<void> _sendLeaveIfPossible() async {
    try {
      await _socket.send(
        const ChatroomEnvelope(
          type: 'leave',
          payload: <String, dynamic>{},
        ).encode(),
      );
    } catch (_) {
      // Closing is best effort.
    }
  }

  Future<void> _disposeState(ChatroomErrorEvent reason) async {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    for (final pending in _pendingAcks.values) {
      pending.completeError(reason);
    }
    _pendingAcks.clear();

    for (final stream in _activeStreams.values) {
      stream.fail(reason);
    }
    _activeStreams.clear();

    await _subscription.cancel();
    await _events.close();
    await _errors.close();
    await _streams.close();
  }

  void _emitError(ChatroomErrorEvent error) {
    if (!_errors.isClosed) {
      _errors.add(error);
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

  void _throwIfClosed() {
    if (_closed) {
      throw const ChatroomProtocolException('Chatroom session is closed');
    }
  }

  String _newClientMessageId() {
    final random = Random().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
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
  _PendingAck(this.completer, this.timer);

  final Completer<ChatroomAck> completer;
  final Timer timer;

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
