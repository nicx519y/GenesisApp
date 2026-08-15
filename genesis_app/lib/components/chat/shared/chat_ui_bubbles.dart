part of 'chat_ui_library.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onLongPressStart,
    this.onTap,
    this.style,
  });

  final ChatMessageVm message;
  final GestureLongPressStartCallback? onLongPressStart;
  final VoidCallback? onTap;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final background = message.isMe
        ? style.selfBubbleColor
        : style.otherBubbleColor;
    final text = message.error == null
        ? message.text
        : '${message.text}\n${message.error}';
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      child: Container(
        padding: style.bubblePadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(style.systemMessageBorderRadius),
        ),
        child: _InlineMarkdownText(
          text: text.isEmpty ? '...' : text,
          style: style.bubbleTextStyle,
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.label,
    required this.colors,
    this.imageUrl = '',
    this.seed,
    this.borderColor,
    this.style,
  });

  final String label;
  final List<Color> colors;
  final String imageUrl;
  final String? seed;
  final Color? borderColor;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final seed = this.seed?.trim();
    final imageUrl = this.imageUrl.trim();
    return SizedBox(
      width: style.avatarSize,
      height: style.avatarSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(style.avatarBorderRadius),
              ),
            ),
          ),
          Positioned.fill(
            child: GenesisAvatar(
              name: seed == null || seed.isEmpty ? label : seed,
              url: imageUrl,
              size: style.avatarSize,
              borderRadius: style.avatarBorderRadius,
              textStyle: style.avatarTextStyle,
              showFallbackWhileLoading: false,
              showFallbackWhenUnavailable: imageUrl.isEmpty,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: borderColor ?? Colors.white,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(style.avatarBorderRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatNpcAvatar extends StatelessWidget {
  const ChatNpcAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      key: ValueKey('chat-npc-avatar'),
      dimension: _npcChatAvatarSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _npcChatAvatarBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'NPC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatAiBadge extends StatelessWidget {
  const ChatAiBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Icon(
      MyFlutterApp.redstarCharIcon,
      size: style.aiBadgeSize,
      color: style.aiBadgeColor,
    );
  }
}

class ChatSendingBadge extends StatelessWidget {
  const ChatSendingBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final indicatorSize =
        (style.sendingBadgeSize - (style.sendingBadgePadding * 2)) * (2 / 3);
    return SizedBox.square(
      dimension: style.sendingBadgeSize,
      child: Center(
        child: SizedBox.square(
          dimension: indicatorSize,
          child: CircularProgressIndicator(
            strokeWidth: style.sendingBadgeStrokeWidth,
            color: style.sendingBadgeColor,
          ),
        ),
      ),
    );
  }
}

class ChatFailedBadge extends StatelessWidget {
  const ChatFailedBadge({super.key, this.style});

  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Container(
      width: style.failedBadgeSize,
      height: style.failedBadgeSize,
      decoration: BoxDecoration(
        color: style.failedBadgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.priority_high,
          size: style.failedBadgeIconSize,
          color: style.failedBadgeIconColor,
        ),
      ),
    );
  }
}

class ChatDateDivider extends StatelessWidget {
  ChatDateDivider({super.key, DateTime? time, this.style})
    : time = time ?? DateTime.now();

  final DateTime time;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return Padding(
      padding: EdgeInsets.only(bottom: style.dateDividerBottomPadding),
      child: Center(
        child: GenesisTimestampText(
          timestamp: time,
          style: style.dateDividerTextStyle,
        ),
      ),
    );
  }
}

bool shouldShowChatDateDivider(DateTime? previous, DateTime current) {
  if (previous == null) return true;
  return current.difference(previous) > const Duration(minutes: 30);
}
