import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/page_header.dart';
import '../../network/chatroom/chatroom_client.dart';
import '../../network/chatroom/chatroom_models.dart';

class ChatroomTestPage extends StatefulWidget {
  const ChatroomTestPage({super.key});

  @override
  State<ChatroomTestPage> createState() => _ChatroomTestPageState();
}

class _ChatroomTestPageState extends State<ChatroomTestPage> {
  final _worldController = TextEditingController(text: 'world_test');
  final _locationController = TextEditingController(text: 'location_test');
  final _userController = TextEditingController(text: 'u_mock');
  final _senderController = TextEditingController(text: 'user_mock');
  final _senderNameController = TextEditingController(text: 'Genesis Tester');
  final _messageController = TextEditingController(text: 'hello');

  final _streamSubscriptions = <StreamSubscription<Object?>>[];
  final _aiOutputs = <int, _AiStreamViewModel>{};
  final _events = <String>[];
  final _errors = <String>[];

  ChatroomSession? _session;
  StreamSubscription<ChatroomEvent>? _eventsSubscription;
  StreamSubscription<ChatroomErrorEvent>? _errorsSubscription;
  StreamSubscription<ChatroomAiMessageStream>? _streamsSubscription;
  ChatroomAck? _lastAck;
  String? _activeConversationRoundId;
  String _status = 'Disconnected';
  bool _connecting = false;
  bool _sending = false;

  bool get _connected => _session != null;

  @override
  void dispose() {
    unawaited(_closeSession());
    _worldController.dispose();
    _locationController.dispose();
    _userController.dispose();
    _senderController.dispose();
    _senderNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    setState(() {
      _connecting = true;
      _status = 'Connecting';
      _lastAck = null;
      _activeConversationRoundId = null;
      _aiOutputs.clear();
      _events.clear();
      _errors.clear();
    });

    try {
      final chatroom = AppServicesScope.read(context).chatroom;
      final session = await chatroom.connect(
        worldInstanceId: _trimmed(_worldController),
        locationId: _trimmed(_locationController),
        userId: _trimmed(_userController),
        senderId: _trimmed(_senderController),
        senderName: _trimmed(_senderNameController),
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _attachSession(session);
      setState(() {
        _session = session;
        _status = 'Connected';
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = 'Connection failed';
        _pushLimited(_errors, e.toString());
      });
    }
  }

  void _attachSession(ChatroomSession session) {
    _eventsSubscription = session.events.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _pushLimited(_events, _describeEvent(event));
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _session = null;
          _status = 'Disconnected';
        });
      },
    );
    _errorsSubscription = session.errors.listen((error) {
      if (!mounted) return;
      setState(() {
        _pushLimited(_errors, _describeError(error));
      });
    });
    _streamsSubscription = session.streams.listen(_handleAiStream);
  }

  void _handleAiStream(ChatroomAiMessageStream stream) {
    if (stream.start.conversationRoundId != _activeConversationRoundId) {
      return;
    }
    final model = _AiStreamViewModel.fromStart(stream.start);
    if (!mounted) return;
    setState(() {
      _aiOutputs[stream.start.messageId] = model;
      _pushLimited(_events, 'AI stream start: ${model.title}');
    });

    final chunkSubscription = stream.chunks.listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          model.content.write(chunk.chunk);
          _pushLimited(_events, 'AI chunk: message ${chunk.messageId}');
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          model.error = error.toString();
          _pushLimited(_errors, error.toString());
        });
      },
    );
    final doneSubscription = stream.done.asStream().listen(
      (end) {
        if (!mounted) return;
        setState(() {
          model.completed = true;
          _pushLimited(_events, 'AI stream end: message ${end.messageId}');
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          model.error = error.toString();
          _pushLimited(_errors, error.toString());
        });
      },
    );
    _streamSubscriptions.add(chunkSubscription);
    _streamSubscriptions.add(doneSubscription);
  }

  Future<void> _sendMessage() async {
    final session = _session;
    if (session == null || _sending) return;
    setState(() {
      _sending = true;
      _lastAck = null;
      _activeConversationRoundId = null;
      _aiOutputs.clear();
    });

    try {
      final ack = await session.sendMessage(_messageController.text);
      if (!mounted) return;
      setState(() {
        _lastAck = ack;
        _activeConversationRoundId = ack.conversationRoundId;
        _sending = false;
        _pushLimited(_events, 'Ack received: round ${ack.conversationRoundId}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _pushLimited(_errors, e.toString());
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
    if (session != null) {
      await session.close();
    }
    if (mounted) {
      setState(() {
        _status = 'Disconnected';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'WebSocket test'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _StatusPanel(
              status: _status,
              heartbeatText:
                  'Heartbeat is sent by ChatroomSession after joined.',
              recentEvent: _events.isEmpty ? 'No events yet.' : _events.last,
              recentError: _errors.isEmpty ? 'No errors.' : _errors.last,
            ),
            const SizedBox(height: 18),
            _SectionTitle('Connection'),
            _TestTextField(
              controller: _worldController,
              label: 'World instance id',
              enabled: !_connected && !_connecting,
            ),
            _TestTextField(
              controller: _locationController,
              label: 'Location id',
              enabled: !_connected && !_connecting,
            ),
            _TestTextField(
              controller: _userController,
              label: 'User id',
              enabled: !_connected && !_connecting,
            ),
            _TestTextField(
              controller: _senderController,
              label: 'Sender id',
              enabled: !_connected && !_connecting,
            ),
            _TestTextField(
              controller: _senderNameController,
              label: 'Sender name',
              enabled: !_connected && !_connecting,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _connected || _connecting ? null : _connect,
                    child: Text(_connecting ? 'Connecting...' : 'Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _connected ? _closeSession : null,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle('Message'),
            _TestTextField(
              controller: _messageController,
              label: 'Message text',
              enabled: _connected && !_sending,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _connected && !_sending ? _sendMessage : null,
              child: Text(_sending ? 'Sending...' : 'Send message'),
            ),
            const SizedBox(height: 22),
            _SectionTitle('Ack'),
            _InfoBox(
              text: _lastAck == null
                  ? 'No ack yet.'
                  : 'message_id=${_lastAck!.messageId}\n'
                        'conversation_round_id=${_lastAck!.conversationRoundId}\n'
                        'client_msg_id=${_lastAck!.clientMsgId}\n'
                        'queue_position=${_lastAck!.queuePosition}',
            ),
            const SizedBox(height: 22),
            _SectionTitle('AI stream'),
            if (_aiOutputs.isEmpty)
              const _InfoBox(text: 'No AI stream for the current round yet.')
            else
              ..._aiOutputs.values.map(
                (output) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InfoBox(
                    text:
                        '${output.title}\n'
                        'state=${output.completed ? 'ended' : 'streaming'}\n'
                        '${output.error == null ? output.content.toString() : 'error=${output.error}'}',
                  ),
                ),
              ),
            const SizedBox(height: 22),
            _SectionTitle('Events'),
            _InfoBox(
              text: _events.isEmpty ? 'No events yet.' : _events.join('\n'),
            ),
            const SizedBox(height: 22),
            _SectionTitle('Errors'),
            _InfoBox(text: _errors.isEmpty ? 'No errors.' : _errors.join('\n')),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.heartbeatText,
    required this.recentEvent,
    required this.recentError,
  });

  final String status;
  final String heartbeatText;
  final String recentEvent;
  final String recentError;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(heartbeatText),
            const SizedBox(height: 8),
            Text('Recent event: $recentEvent'),
            const SizedBox(height: 8),
            Text('Recent error: $recentError'),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TestTextField extends StatelessWidget {
  const _TestTextField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 13, height: 1.35),
        ),
      ),
    );
  }
}

class _AiStreamViewModel {
  _AiStreamViewModel({required this.title, required this.content})
    : completed = false,
      error = null;

  factory _AiStreamViewModel.fromStart(ChatroomAiStreamStart start) {
    return _AiStreamViewModel(
      title:
          'message_id=${start.messageId}, sender=${start.senderName}, '
          'round=${start.conversationRoundId}',
      content: StringBuffer(),
    );
  }

  final String title;
  final StringBuffer content;
  bool completed;
  String? error;
}

String _trimmed(TextEditingController controller) => controller.text.trim();

void _pushLimited(List<String> target, String value) {
  target.insert(0, value);
  if (target.length > 20) {
    target.removeRange(20, target.length);
  }
}

String _describeEvent(ChatroomEvent event) {
  return switch (event) {
    ChatroomJoined e => 'joined: session=${e.sessionId}',
    ChatroomAck e =>
      'ack: message=${e.messageId}, round=${e.conversationRoundId}',
    ChatroomUserMessage e =>
      'user_message: message=${e.messageId}, round=${e.conversationRoundId}',
    ChatroomAiStreamStart e =>
      'ai_stream_start: message=${e.messageId}, round=${e.conversationRoundId}',
    ChatroomAiStreamChunk e =>
      'ai_stream_chunk: message=${e.messageId}, chars=${e.chunk.length}',
    ChatroomAiStreamEnd e =>
      'ai_stream_end: message=${e.messageId}, round=${e.conversationRoundId}',
    ChatroomQueuePosition e =>
      'queue_position: round=${e.conversationRoundId}, position=${e.position}',
    ChatroomErrorEvent e => _describeError(e),
  };
}

String _describeError(ChatroomErrorEvent error) {
  return '${error.code}: ${error.message}';
}
