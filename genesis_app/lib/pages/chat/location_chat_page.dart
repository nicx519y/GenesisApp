import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/chat/location_chat/location_chat_composer.dart';
import '../../components/chat/location_chat/location_chat_header.dart';
import '../../components/chat/location_chat/location_chat_message_list.dart';
import '../../components/chat/location_chat/location_chat_message_vm.dart';
import '../../network/chatroom/chatroom_client.dart';
import '../../network/chatroom/chatroom_models.dart';

class LocationChatPage extends StatefulWidget {
  const LocationChatPage({
    super.key,
    required this.worldId,
    required this.locationId,
    this.worldName,
    this.locationName,
  });

  final String worldId;
  final String locationId;
  final String? worldName;
  final String? locationName;

  @override
  State<LocationChatPage> createState() => _LocationChatPageState();
}

class _LocationChatPageState extends State<LocationChatPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _messages = <LocationChatMessageVm>[];
  final _streamSubscriptions = <StreamSubscription<Object?>>[];
  final _activeStreams = <int, LocationChatMessageVm>{};

  ChatroomSession? _session;
  StreamSubscription<ChatroomEvent>? _eventsSubscription;
  StreamSubscription<ChatroomErrorEvent>? _errorsSubscription;
  StreamSubscription<ChatroomAiMessageStream>? _streamsSubscription;
  String _mySenderId = '';
  String _mySenderName = '';
  String _status = 'Connecting...';
  List<ChatroomOnlineUser> _onlineUsers = const <ChatroomOnlineUser>[];
  bool _connecting = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    unawaited(_closeSession());
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = 'Connecting...';
    });

    try {
      final services = AppServicesScope.read(context);
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      final profile = services.identityAuth.currentProfile();
      final senderId = firstNonEmpty([profile?.uid, uid, 'local-user']);
      final senderName = firstNonEmpty([
        profile?.displayName,
        profile?.email,
        uid,
        'Me',
      ]);

      final session = await services.chatroom.connect(
        worldInstanceId: widget.worldId,
        locationId: widget.locationId,
        userId: senderId,
        senderId: senderId,
        senderName: senderName,
      );

      if (!mounted) {
        await session.close();
        return;
      }

      _attachSession(session);
      setState(() {
        _session = session;
        _mySenderId = senderId;
        _mySenderName = senderName;
        _onlineUsers = session.joined?.onlineUsers ?? const [];
        _status = 'Connected';
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Connection failed';
        _connecting = false;
        _messages.add(
          LocationChatMessageVm.system('WebSocket connection failed: $e'),
        );
      });
      _scrollToBottom();
    }
  }

  void _attachSession(ChatroomSession session) {
    _eventsSubscription = session.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case ChatroomJoined e:
          setState(() {
            _onlineUsers = e.onlineUsers;
            _status = 'Connected';
          });
        case ChatroomUserMessage e:
          _handleUserMessage(e);
        case ChatroomQueuePosition e:
          setState(() {
            _messages.add(
              LocationChatMessageVm.system('Queue position: ${e.position}'),
            );
          });
          _scrollToBottom();
        case ChatroomErrorEvent e:
          _handleError(e);
        default:
          break;
      }
    }, onDone: _markDisconnected);

    _errorsSubscription = session.errors.listen(_handleError);
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
        LocationChatMessageVm(
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
    final message = LocationChatMessageVm(
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

  void _handleError(ChatroomErrorEvent error) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        LocationChatMessageVm.system('${error.code}: ${error.message}'),
      );
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null || _sending) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final localMessage = LocationChatMessageVm(
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

  Future<void> _closeSession() async {
    final session = _session;
    _session = null;
    _connecting = false;
    _sending = false;

    await _eventsSubscription?.cancel();
    await _errorsSubscription?.cancel();
    await _streamsSubscription?.cancel();
    _eventsSubscription = null;
    _errorsSubscription = null;
    _streamsSubscription = null;

    for (final subscription in _streamSubscriptions) {
      await subscription.cancel();
    }
    _streamSubscriptions.clear();
    _activeStreams.clear();

    if (session != null) {
      await session.close();
    }
  }

  void _markDisconnected() {
    if (!mounted) return;
    setState(() {
      _session = null;
      _status = 'Disconnected';
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleCount = _onlineUsers.isEmpty ? 1 : _onlineUsers.length;
    final title = firstNonEmpty([widget.locationName, widget.locationId]);
    final worldName = firstNonEmpty([widget.worldName, widget.worldId]);
    final subtitle = _onlineUsers.isEmpty
        ? _status
        : _onlineUsers
              .map((user) => user.senderName)
              .where((name) => name.trim().isNotEmpty)
              .take(3)
              .join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFFE7E1E5),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          LocationChatHeader(
            title: '$title ($titleCount)',
            subtitle: subtitle.isEmpty ? _status : subtitle,
            connected: _session != null,
            connecting: _connecting,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: LocationChatMessageList(
              controller: _scrollController,
              messages: _messages,
              worldName: worldName,
            ),
          ),
          LocationChatComposer(
            controller: _textController,
            inputEnabled: !_sending,
            sendEnabled: _session != null && !_sending,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
