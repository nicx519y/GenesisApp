part of 'chat_ui_library.dart';

class ChatStoryEventsMessageBubble extends StatelessWidget {
  const ChatStoryEventsMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final payload = message.timelinePayload;
    if (payload is! ChatStoryEventsPayloadVm || payload.paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: style.systemMessageMargin,
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: Container(
          key: ValueKey<String>('chat-story-events-message-${message.localId}'),
          width: double.infinity,
          padding: style.systemMessagePadding,
          decoration: BoxDecoration(
            color: style.systemMessageBackgroundColor,
            borderRadius: BorderRadius.circular(
              style.systemMessageBorderRadius,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < payload.paragraphs.length; index += 1)
                _ChatStoryEventParagraph(
                  messageLocalId: message.localId,
                  index: index,
                  paragraph: payload.paragraphs[index],
                  style: style,
                  showTopDivider: index > 0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatStoryEventParagraph extends StatelessWidget {
  const _ChatStoryEventParagraph({
    required this.messageLocalId,
    required this.index,
    required this.paragraph,
    required this.style,
    required this.showTopDivider,
  });

  final String messageLocalId;
  final int index;
  final ChatStoryEventParagraphVm paragraph;
  final ChatUiStyleConfig style;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final metadataStyle = style.systemMessageTextStyle.copyWith(
      color: textColor.withValues(alpha: 0.72),
      fontSize: (style.systemMessageTextStyle.fontSize ?? 12) - 1,
    );
    return Container(
      key: ValueKey<String>(
        'chat-story-event-paragraph-$messageLocalId-$index',
      ),
      width: double.infinity,
      padding: EdgeInsets.only(top: showTopDivider ? 10 : 0),
      margin: EdgeInsets.only(top: showTopDivider ? 10 : 0),
      decoration: showTopDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: (style.systemMessageTextStyle.color ?? Colors.white)
                      .withValues(alpha: 0.16),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 5,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_rounded, size: 14, color: textColor),
                  const SizedBox(width: 4),
                  Text(
                    'Event',
                    style: style.systemMessageTextStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (paragraph.timestamp.trim().isNotEmpty)
                Text(
                  genesisDisplaySafeText(paragraph.timestamp),
                  key: ValueKey<String>(
                    'chat-story-event-timestamp-$messageLocalId-$index',
                  ),
                  style: metadataStyle,
                ),
              if (paragraph.visibilityLabel.trim().isNotEmpty)
                _ChatStoryEventVisibilityBadge(
                  key: ValueKey<String>(
                    'chat-story-event-visibility-$messageLocalId-$index',
                  ),
                  label: paragraph.visibilityLabel,
                  style: style,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _InlineMarkdownText(
            text: paragraph.text,
            textAlign: TextAlign.left,
            style: style.systemMessageTextStyle.copyWith(height: 1.45),
          ),
          if (paragraph.clue.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              key: ValueKey<String>(
                'chat-story-event-clue-$messageLocalId-$index',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _InlineMarkdownText(
                    text: paragraph.clue,
                    textAlign: TextAlign.left,
                    style: style.systemMessageTextStyle.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatStoryEventVisibilityBadge extends StatelessWidget {
  const _ChatStoryEventVisibilityBadge({
    super.key,
    required this.label,
    required this.style,
  });

  final String label;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final badgeColor = textColor.withValues(alpha: 0.72);
    final isPublic = label.trim().toLowerCase() == 'public';
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: textColor.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              genesisDisplaySafeText(label),
              softWrap: true,
              style: style.systemMessageTextStyle.copyWith(
                color: badgeColor,
                fontSize: (style.systemMessageTextStyle.fontSize ?? 12) - 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
