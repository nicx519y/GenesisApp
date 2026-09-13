part of 'chat_ui_library.dart';

/// Waiting reply with AI text/fill colors and four equal rounded corners.
class ChatReplyWaitingBubble extends StatefulWidget {
  const ChatReplyWaitingBubble({
    super.key,
    required this.style,
    this.inActionSlot = false,
  });

  final ChatUiStyleConfig style;
  final bool inActionSlot;

  @override
  State<ChatReplyWaitingBubble> createState() => _ChatReplyWaitingBubbleState();
}

class _ChatReplyWaitingBubbleState extends State<ChatReplyWaitingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: kChatReplyWaitingPeriod,
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.style.bubbleTextStyle.color ?? Colors.white;
    return Semantics(
      label: 'AI reply loading',
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.inActionSlot
              ? 0
              : widget.style.avatarSize + widget.style.avatarBubbleGap,
          bottom: widget.inActionSlot ? 0 : widget.style.rowBottomPadding,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ChatBubbleSurface(
            padding: widget.style.bubblePadding,
            color: widget.style.otherBubbleColor,
            borderRadius: BorderRadius.circular(
              widget.style.bubbleBorderRadius,
            ),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Row(
                key: const ValueKey<String>('location-chat-ack-loading-dots'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    if (index > 0)
                      const SizedBox(width: kChatReplyWaitingDotGap),
                    SizedBox.square(
                      dimension: kChatReplyWaitingDotSlotSize,
                      child: Center(
                        child: Transform.scale(
                          scale: _dotScale(index),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(
                              dimension: kChatReplyWaitingDotSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _dotScale(int index) {
    final phase = (_animation.value - index / 3 + 1) % 1;
    final triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return kChatReplyWaitingMinScale +
        kChatReplyWaitingScaleRange * Curves.easeInOut.transform(triangle);
  }
}
