import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../icons/my_flutter_app_icons.dart';

class ChatMessageVm {
  ChatMessageVm({
    required this.localId,
    this.messageId,
    this.roundId = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isMe,
    required this.status,
    this.senderType = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessageVm.system(String text) {
    return ChatMessageVm(
      localId: 'system-${DateTime.now().microsecondsSinceEpoch}',
      senderId: '',
      senderName: '',
      text: text,
      isMe: false,
      status: 'system',
      senderType: 'system',
    );
  }

  final String localId;
  int? messageId;
  String roundId;
  final String senderId;
  final String senderName;
  String text;
  final bool isMe;
  String status;
  final String senderType;
  String? error;
  final DateTime createdAt;

  bool get isSystem => senderType == 'system';
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.onBack,
    this.showTitleIcon = true,
    this.showSubtitle = true,
    this.showMoreButton = true,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final VoidCallback onBack;
  final bool showTitleIcon;
  final bool showSubtitle;
  final bool showMoreButton;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      height: topInset + 50,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      color: const Color(0xFFF2EFF2).withValues(alpha: 0.96),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 17),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTitleIcon) ...[
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF526A9F),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showSubtitle) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          connected
                              ? Icons.groups_2
                              : connecting
                              ? Icons.sync
                              : Icons.cloud_off,
                          size: 17,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (showMoreButton)
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz, size: 17),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.inputEnabled,
    required this.sendEnabled,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 16 + bottomInset),
      color: const Color(0xFFF1EFF1).withValues(alpha: 0.98),
      child: Row(
        children: [
          _ComposerIconButton(
            icon: MyFlutterApp.voice,
            onPressed: inputEnabled ? () {} : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: TextField(
                controller: controller,
                enabled: inputEnabled,
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onSubmitted: (_) {
                  if (sendEnabled) unawaited(onSend());
                },
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ComposerIconButton(
            icon: MyFlutterApp.sticker,
            onPressed: inputEnabled ? () {} : null,
          ),
          const SizedBox(width: 10),
          _ComposerIconButton(
            icon: sending ? Icons.hourglass_top : MyFlutterApp.add2,
            onPressed: sendEnabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 30),
      ),
    );
  }
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.topTitle,
  });

  final ScrollController controller;
  final List<ChatMessageVm> messages;
  final String topTitle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _ChatTopTitle(name: topTitle);

        final messageIndex = index - 1;
        final current = messages[messageIndex];
        final previous = messageIndex == 0 ? null : messages[messageIndex - 1];
        return ChatMessageRow(
          key: ValueKey(current.localId),
          message: current,
          showDateDivider: shouldShowChatDateDivider(
            previous?.createdAt,
            current.createdAt,
          ),
        );
      },
    );
  }
}

class _ChatTopTitle extends StatelessWidget {
  const _ChatTopTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.trim().isEmpty) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    super.key,
    required this.message,
    required this.showDateDivider,
    this.onAvatarTap,
  });

  final ChatMessageVm message;
  final bool showDateDivider;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return ChatSystemMessage(text: message.text);
    }

    final row = message.isMe ? _buildMe(context) : _buildOther(context);
    if (!showDateDivider) return row;

    return Column(
      children: [
        ChatDateDivider(time: message.createdAt),
        row,
      ],
    );
  }

  Widget _buildMe(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.68;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.status == 'failed') ...[
            const ChatFailedBadge(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: ChatMessageBubble(message: message),
                ),
                if (message.status != 'sent' && message.status != 'failed') ...[
                  const SizedBox(height: 4),
                  Text(
                    message.status,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ChatAvatar(
            label: chatInitials(message.senderName),
            colors: const [Color(0xFFFFE7B0), Color(0xFF9ED7FF)],
          ),
        ],
      ),
    );
  }

  Widget _buildOther(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAvatarTap,
                child: ChatAvatar(
                  label: chatInitials(message.senderName),
                  colors: const [Color(0xFFBFD7F2), Color(0xFF4F6D94)],
                ),
              ),
              if (message.senderType == 'character')
                const Positioned(right: -5, top: -7, child: ChatAiBadge()),
            ],
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: ChatMessageBubble(message: message),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessageVm message;

  @override
  Widget build(BuildContext context) {
    final background = message.isMe ? const Color(0xFF26F24C) : Colors.white;
    final text = message.error == null
        ? message.text
        : '${message.text}\n${message.error}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text.isEmpty ? '...' : text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          height: 16 / 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.label, required this.colors});

  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class ChatAiBadge extends StatelessWidget {
  const ChatAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: 16, height: 16, color: Colors.red),
    );
  }
}

class ChatFailedBadge extends StatelessWidget {
  const ChatFailedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFFE53935),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.priority_high, size: 17, color: Colors.white),
      ),
    );
  }
}

class ChatDateDivider extends StatelessWidget {
  ChatDateDivider({super.key, DateTime? time}) : time = time ?? DateTime.now();

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Text(
          _dateLabel(time),
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

bool shouldShowChatDateDivider(DateTime? previous, DateTime current) {
  if (previous == null) return true;
  return current.difference(previous) > const Duration(minutes: 30);
}

class ChatSystemMessage extends StatelessWidget {
  const ChatSystemMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

String chatInitials(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '?';
  final chars = clean.characters.take(2).toList(growable: false);
  return chars.join().toUpperCase();
}

String firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _dateLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'today $hour:$minute';
  }
  return '${local.month}/${local.day} $hour:$minute';
}
