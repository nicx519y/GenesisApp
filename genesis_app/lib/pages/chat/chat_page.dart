import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/models/world_message.dart';
import '../../app/bootstrap/app_services_scope.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.wid,
    required this.pointId,
    required this.sceneId,
    this.locationName = '',
  });

  final String wid;
  final String pointId;
  final String sceneId;
  final String locationName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  Timer? _pollTimer;
  late _ChatTarget _target;
  bool _loading = true;
  bool _sending = false;
  String? _fetchInFlightKey;
  Object? _loadError;
  String _uid = '';
  int _targetGeneration = 0;
  List<WorldMessage> _messages = const <WorldMessage>[];

  @override
  void initState() {
    super.initState();
    _target = _ChatTarget.fromWidget(widget);
    unawaited(_init());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_fetchMessages());
    });
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activateTarget(_ChatTarget.fromWidget(widget));
  }

  Future<void> _init() async {
    final uid = await AppServicesScope.read(context).sessionStore.readUid();
    if (!mounted) return;
    setState(() {
      _uid = uid ?? '';
    });
    await _fetchMessages(isInitial: true);
  }

  Future<void> _fetchMessages({bool isInitial = false}) async {
    final target = _target;
    if (!target.canLoad) {
      if (isInitial && mounted) {
        setState(() {
          _loading = false;
          _loadError = null;
        });
      }
      return;
    }

    final fetchKey = target.identityKey;
    if (_fetchInFlightKey == fetchKey) return;
    final generation = _targetGeneration;
    _fetchInFlightKey = fetchKey;
    try {
      final page = await AppServicesScope.read(context).api.getLocationMessages(
        wid: target.wid,
        pointId: target.pointId,
        locationId: target.sceneId,
        limit: 50,
        offset: 0,
      );

      if (!mounted ||
          generation != _targetGeneration ||
          !_target.hasSameContentIdentity(target)) {
        return;
      }
      final shouldStickToBottom =
          _scrollController.hasClients &&
          _scrollController.position.extentAfter < 80;

      setState(() {
        _messages = page.data.reversed.toList(growable: false);
        _loadError = null;
        if (isInitial) _loading = false;
      });

      if (shouldStickToBottom) _scrollToBottom();
    } catch (e) {
      if (!mounted ||
          generation != _targetGeneration ||
          !_target.hasSameContentIdentity(target)) {
        return;
      }
      if (isInitial) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    } finally {
      if (_fetchInFlightKey == fetchKey) {
        _fetchInFlightKey = null;
      }
    }
  }

  void _activateTarget(_ChatTarget next) {
    if (_target.hasSameContentIdentity(next)) {
      if (_target != next) {
        setState(() => _target = next);
      }
      return;
    }

    _targetGeneration += 1;
    _textController.clear();
    setState(() {
      _target = next;
      _messages = const <WorldMessage>[];
      _loadError = null;
      _loading = next.canLoad;
      _sending = false;
    });
    unawaited(_fetchMessages(isInitial: true));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final target = _target;
    if (!target.canLoad) return;
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sending = true);
    try {
      await AppServicesScope.read(context).api.sendMessage(
        wid: target.wid,
        pointId: target.pointId,
        locationId: target.sceneId,
        content: content,
      );
      if (!mounted) return;
      _textController.clear();
      await _fetchMessages();
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Send failed')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _target.locationName.isEmpty
        ? (_target.sceneId.isEmpty ? _target.pointId : _target.sceneId)
        : _target.locationName;
    final subtitle = 'WID: ${_target.wid}';
    final messages = _messages;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ChatBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _ChatTopBar(title: title, subtitle: subtitle),
                Expanded(child: _buildBody(messages)),
                SafeArea(
                  top: false,
                  child: _ChatComposer(
                    controller: _textController,
                    sending: _sending,
                    onSend: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<WorldMessage> messages) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Load failed', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => _fetchMessages(isInitial: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return _ChatMessages(
      controller: _scrollController,
      messages: messages,
      myUid: _uid,
    );
  }
}

@immutable
class _ChatTarget {
  const _ChatTarget({
    required this.wid,
    required this.pointId,
    required this.sceneId,
    required this.locationName,
  });

  factory _ChatTarget.fromWidget(ChatPage widget) {
    return _ChatTarget(
      wid: widget.wid,
      pointId: widget.pointId,
      sceneId: widget.sceneId,
      locationName: widget.locationName,
    );
  }

  final String wid;
  final String pointId;
  final String sceneId;
  final String locationName;

  bool get canLoad => wid.trim().isNotEmpty && pointId.trim().isNotEmpty;

  String get identityKey {
    return '${wid.trim()}\u001F${pointId.trim()}\u001F${sceneId.trim()}';
  }

  bool hasSameContentIdentity(_ChatTarget other) {
    return identityKey == other.identityKey;
  }

  @override
  bool operator ==(Object other) {
    return other is _ChatTarget &&
        wid == other.wid &&
        pointId == other.pointId &&
        sceneId == other.sceneId &&
        locationName == other.locationName;
  }

  @override
  int get hashCode => Object.hash(wid, pointId, sceneId, locationName);
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.group_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ChatMessages extends StatelessWidget {
  const _ChatMessages({
    required this.controller,
    required this.messages,
    required this.myUid,
  });

  final ScrollController controller;
  final List<WorldMessage> messages;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10, top: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        final isMe = myUid.isNotEmpty && m.uid == myUid;
        final author = m.uid;
        final initials = author.isEmpty
            ? '?'
            : author.substring(0, author.length >= 2 ? 2 : 1);
        final text = m.content;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12),
          child: _MessageRow(
            isMe: isMe,
            author: author,
            initials: initials,
            text: text,
          ),
        );
      },
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.isMe,
    required this.author,
    required this.initials,
    required this.text,
  });

  final bool isMe;
  final String author;
  final String initials;
  final String text;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    final bubble = _MessageBubble(text: text, isMe: isMe);
    if (isMe) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        verticalDirection: VerticalDirection.up,
        children: [
          const SizedBox(width: 44),
          const Spacer(),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: bubble,
          ),
          const SizedBox(width: 10),
          _AvatarCircle(initials: initials),
        ],
      );
    } else if (author.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        verticalDirection: VerticalDirection.up,
        children: [
          const SizedBox(width: 44),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: bubble,
          ),
          const Spacer(),
          // _AvatarCircle(initials: initials),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      verticalDirection: VerticalDirection.up,
      children: [
        _AvatarCircle(initials: initials),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: bubble,
              ),
            ],
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? const Color(0xFF22C55E) : Colors.white;
    final fg = isMe ? Colors.black : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: isMe ? 0.95 : 0.96),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: isMe ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: fg.withValues(alpha: isMe ? 0.95 : 0.9),
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.rectangle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2, left: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '',
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            const SizedBox(width: 2),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, -0.4),
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
