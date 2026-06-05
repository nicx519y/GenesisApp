import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../network/chatroom/chatroom_client.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../utils/display_name_formatter.dart';

class LocationChatPage extends StatefulWidget {
  const LocationChatPage({
    super.key,
    required this.worldId,
    required this.locationId,
    this.worldName,
    this.locationName,
    this.connection,
  });

  final String worldId;
  final String locationId;
  final String? worldName;
  final String? locationName;
  final ChatroomConnectionController? connection;

  @override
  State<LocationChatPage> createState() => _LocationChatPageState();
}

class _LocationChatPageState extends State<LocationChatPage>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _messages = <ChatMessageVm>[];
  final _streamSubscriptions = <StreamSubscription<Object?>>[];
  final _activeStreams = <int, ChatMessageVm>{};

  ChatroomSession? _session;
  ChatroomSession? _attachedSession;
  ChatroomConnectionController? _connection;
  StreamSubscription<ChatroomConnectionSnapshot>? _connectionSubscription;
  StreamSubscription<ChatroomEvent>? _eventsSubscription;
  StreamSubscription<ChatroomFailureEvent>? _failuresSubscription;
  StreamSubscription<ChatroomAiMessageStream>? _streamsSubscription;
  String _mySenderId = '';
  String _mySenderName = '';
  ChatroomConnectionStatus _connectionStatus =
      ChatroomConnectionStatus.disconnected;
  List<ChatroomOnlineUser> _onlineUsers = const <ChatroomOnlineUser>[];
  bool _ownsConnection = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final connection = _connection;
    if (_ownsConnection && connection != null) {
      unawaited(connection.disconnect().catchError((Object _) {}));
    }
    unawaited(_closeConnection());
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _revealLatestMessageAfterLayout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ownsConnection) return;
    final connection = _connection;
    if (connection == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(connection.handleAppForeground().catchError((Object _) {}));
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(connection.handleAppBackground().catchError((Object _) {}));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _startConnection() {
    final provided = widget.connection;
    if (provided != null) {
      _connection = provided;
      _ownsConnection = false;
      _attachConnection(provided);
      unawaited(_joinLocation(provided));
      return;
    }

    final services = AppServicesScope.read(context);
    final connection = ChatroomConnectionController(client: services.chatroom);
    _connection = connection;
    _ownsConnection = true;
    _attachConnection(connection);
    unawaited(_connectFallbackAndJoin(connection, services));
  }

  Future<void> _connectFallbackAndJoin(
    ChatroomConnectionController connection,
    AppServices services,
  ) async {
    try {
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      final profile = services.identityAuth.currentProfile();
      final senderId = firstNonEmpty([profile?.uid, uid, 'local-user']);
      final senderName = firstNonEmpty([
        profile?.displayName,
        profile?.email,
        formatUidForDisplay(uid),
        'Me',
      ]);
      _mySenderId = senderId;
      _mySenderName = senderName;
      await connection.connect(
        worldId: widget.worldId,
        identity: ChatroomConnectionIdentity(
          userId: senderId,
          senderId: senderId,
          senderName: senderName,
        ),
      );
      await _joinLocation(connection);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageVm.system('WebSocket connection failed: $e'));
      });
      _scrollToBottom();
    }
  }

  Future<void> _joinLocation(ChatroomConnectionController connection) async {
    try {
      if (_mySenderId.isEmpty || _mySenderName.isEmpty) {
        final session = connection.session;
        _mySenderId = firstNonEmpty([session?.senderId, 'local-user']);
        _mySenderName = firstNonEmpty([
          formatUidForDisplay(session?.senderName ?? ''),
          'Me',
        ]);
      }
      await connection.join(locationId: widget.locationId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageVm.system('Join failed: $e'));
      });
      _scrollToBottom();
    }
  }

  void _attachConnection(ChatroomConnectionController connection) {
    _failuresSubscription = bindChatroomFailureToast(
      context,
      connection.failures,
      onFailure: _handleFailure,
    );
    _connectionSubscription = connection.states.listen(_handleConnectionState);
    _handleConnectionState(connection.snapshot);
  }

  void _handleConnectionState(ChatroomConnectionSnapshot snapshot) {
    final session = snapshot.session;
    if (session != null && !identical(session, _attachedSession)) {
      _attachSession(session);
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _connectionStatus = snapshot.status;
      _onlineUsers = snapshot.joined?.onlineUsers ?? _onlineUsers;
      _mySenderId = firstNonEmpty([session?.senderId, _mySenderId]);
      _mySenderName = firstNonEmpty([
        formatUidForDisplay(session?.senderName ?? ''),
        _mySenderName,
      ]);
    });
  }

  void _attachSession(ChatroomSession session) {
    unawaited(_eventsSubscription?.cancel());
    unawaited(_streamsSubscription?.cancel());
    _attachedSession = session;
    _eventsSubscription = session.listenMessages(
      ChatroomMessageHandlers(
        onJoined: (e) {
          if (!mounted) return;
          setState(() {
            _onlineUsers = e.onlineUsers;
          });
        },
        onUserMessage: (e) {
          if (!mounted) return;
          _handleUserMessage(e);
        },
        onQueuePosition: (e) {
          if (!mounted) return;
          setState(() {
            _messages.add(
              ChatMessageVm.system('Queue position: ${e.position}'),
            );
          });
          _scrollToBottom();
        },
      ),
      onDone: _markDisconnected,
    );
    _streamsSubscription = session.streams.listen(_handleAiStream);
  }

  void _handleUserMessage(ChatroomUserMessage event) {
    final isMe = event.senderId == _mySenderId || event.userId == _mySenderId;
    final existingIndex = event.messageId == 0
        ? -1
        : _messages.indexWhere((m) => m.messageId == event.messageId);
    if (existingIndex >= 0) return;

    setState(() {
      _messages.add(
        ChatMessageVm(
          localId: 'user-${event.messageId}',
          messageId: event.messageId,
          roundId: event.conversationRoundId,
          senderId: event.senderId,
          senderName: event.senderName,
          text: event.content,
          isMe: isMe,
          status: 'sent',
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleAiStream(ChatroomAiMessageStream stream) {
    final message = ChatMessageVm(
      localId: 'ai-${stream.start.messageId}',
      messageId: stream.start.messageId,
      roundId: stream.start.conversationRoundId,
      senderId: stream.start.senderId,
      senderName: stream.start.senderName,
      text: '',
      isMe: false,
      status: 'streaming',
    );

    if (!mounted) return;
    setState(() {
      _activeStreams[stream.start.messageId] = message;
      _messages.add(message);
    });
    _scrollToBottom();

    final chunkSubscription = stream.chunks.listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          final target = _activeStreams[chunk.messageId];
          if (target != null) {
            target.text += chunk.chunk;
          }
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          message.status = 'failed';
          message.error = error.toString();
        });
      },
    );

    final doneSubscription = stream.done.asStream().listen(
      (end) {
        if (!mounted) return;
        setState(() {
          final target = _activeStreams.remove(end.messageId);
          if (target != null) {
            target.status = 'sent';
          }
        });
        _scrollToBottom();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _activeStreams.remove(stream.start.messageId);
          message.status = 'failed';
          message.error = error.toString();
        });
      },
    );

    _streamSubscriptions.add(chunkSubscription);
    _streamSubscriptions.add(doneSubscription);
  }

  void _handleFailure(ChatroomFailureEvent failure) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessageVm.system('${failure.code}: ${failure.message}'),
      );
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null ||
        _connectionStatus != ChatroomConnectionStatus.joined ||
        _sending) {
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final localMessage = ChatMessageVm(
      localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: _mySenderId,
      senderName: _mySenderName,
      text: text,
      isMe: true,
      status: 'sending',
    );

    setState(() {
      _sending = true;
      _messages.add(localMessage);
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final ack = await session.sendMessage(text);
      if (!mounted) return;
      setState(() {
        localMessage.messageId = ack.messageId;
        localMessage.roundId = ack.conversationRoundId;
        localMessage.status = ack.queuePosition == 0
            ? 'sent'
            : 'queued ${ack.queuePosition}';
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        localMessage.status = 'failed';
        localMessage.error = e.toString();
        _sending = false;
      });
    }
  }

  Future<void> _closeConnection() async {
    final connection = _connection;
    final ownsConnection = _ownsConnection;
    _connection = null;
    _session = null;
    _attachedSession = null;
    _sending = false;

    await _connectionSubscription?.cancel();
    await _eventsSubscription?.cancel();
    await _failuresSubscription?.cancel();
    await _streamsSubscription?.cancel();
    _connectionSubscription = null;
    _eventsSubscription = null;
    _failuresSubscription = null;
    _streamsSubscription = null;

    for (final subscription in _streamSubscriptions) {
      await subscription.cancel();
    }
    _streamSubscriptions.clear();
    _activeStreams.clear();

    if (connection != null) {
      try {
        await connection.leave();
      } catch (_) {
        // Route disposal must not wait on or surface leave failures.
      }
      if (ownsConnection) {
        try {
          await connection.disconnect();
        } catch (_) {}
        await connection.dispose();
      }
    }
  }

  void _markDisconnected() {
    if (!mounted) return;
    setState(() {
      _session = null;
      _connectionStatus = ChatroomConnectionStatus.disconnected;
    });
  }

  void _scrollToBottom({bool jump = false, int settleFrames = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        if (settleFrames > 0) {
          _scrollToBottom(jump: true, settleFrames: settleFrames - 1);
        }
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _revealLatestMessageAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToBottom(jump: true, settleFrames: 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleCount = _onlineUsers.isEmpty ? 1 : _onlineUsers.length;
    final title = firstNonEmpty([widget.locationName, widget.locationId]);
    final worldName = firstNonEmpty([widget.worldName, widget.worldId]);
    final subtitle = _chatroomStatusLabel(_connectionStatus);
    final joined = _connectionStatus == ChatroomConnectionStatus.joined;
    final connecting =
        _connectionStatus == ChatroomConnectionStatus.connecting ||
        _connectionStatus == ChatroomConnectionStatus.connected ||
        _connectionStatus == ChatroomConnectionStatus.joining;

    return Scaffold(
      backgroundColor: ChatUiStyleConfig.standard.conversationBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          ChatHeader(
            title: '$title ($titleCount)',
            subtitle: subtitle,
            connected: joined,
            connecting: connecting,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ChatMessageList(
              controller: _scrollController,
              messages: _messages,
              topTitle: worldName,
            ),
          ),
          ChatComposer(
            controller: _textController,
            inputEnabled: !_sending,
            sendEnabled: joined && _session != null && !_sending,
            sending: _sending,
            onSend: _send,
            sendLabel: 'Send',
            onHeightChanged: (_) => _revealLatestMessageAfterLayout(),
          ),
        ],
      ),
    );
  }

  String _chatroomStatusLabel(ChatroomConnectionStatus status) {
    return switch (status) {
      ChatroomConnectionStatus.disconnected => 'Disconnect',
      ChatroomConnectionStatus.connecting => 'Connecting',
      ChatroomConnectionStatus.connected => 'Connecting',
      ChatroomConnectionStatus.joining => 'Joining',
      ChatroomConnectionStatus.joined => 'Joined',
    };
  }
}
