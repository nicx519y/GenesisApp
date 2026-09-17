part of 'chat_ui_library.dart';

/// Waiting reply with AI text/fill colors and four equal rounded corners.
class ChatReplyWaitingBubble extends StatefulWidget {
  const ChatReplyWaitingBubble({
    super.key,
    required this.style,
    this.inActionSlot = false,
    this.visible = true,
  });

  final ChatUiStyleConfig style;
  final bool inActionSlot;
  final bool visible;

  @override
  State<ChatReplyWaitingBubble> createState() => _ChatReplyWaitingBubbleState();
}

class _ChatReplyWaitingBubbleState extends State<ChatReplyWaitingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: kChatReplyWaitingPeriod,
    );
    if (widget.visible) _animation.repeat();
  }

  @override
  void didUpdateWidget(covariant ChatReplyWaitingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _animation
        ..value = 0
        ..repeat();
    } else {
      _animation
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.style.bubbleTextStyle.color ?? Colors.white;
    final dotsWidth =
        kChatReplyWaitingDotSlotSize * 3 + kChatReplyWaitingDotGap * 2;
    return ExcludeSemantics(
      excluding: !widget.visible,
      child: Opacity(
        opacity: widget.visible ? 1 : 0,
        child: Semantics(
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
                child: widget.visible
                    ? AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) => Row(
                          key: const ValueKey<String>(
                            'location-chat-ack-loading-dots',
                          ),
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
                      )
                    : SizedBox(
                        width: dotsWidth,
                        height: kChatReplyWaitingDotSlotSize,
                      ),
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
