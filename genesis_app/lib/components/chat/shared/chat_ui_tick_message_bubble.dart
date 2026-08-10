part of 'chat_ui_library.dart';

class ChatTickPayloadVm extends ChatTimelinePayloadVm {
  const ChatTickPayloadVm({
    this.globalText = '',
    this.storyEvents,
    this.charactersMoved,
    this.fallbackContent = '',
  });

  final String globalText;
  final ChatStoryEventsPayloadVm? storyEvents;
  final ChatCharactersMovedPayloadVm? charactersMoved;
  final String fallbackContent;

  bool get hasGlobal => globalText.trim().isNotEmpty;

  bool get hasStoryEvents => storyEvents?.paragraphs.isNotEmpty ?? false;

  bool get hasCharactersMoved => charactersMoved?.movements.isNotEmpty ?? false;

  bool get hasStructuredSections =>
      hasGlobal || hasStoryEvents || hasCharactersMoved;

  String get copyText {
    return [
      if (hasGlobal) ...['Global', globalText.trim()],
      if (hasStoryEvents) _storyEventsCopyText(storyEvents!),
      if (hasCharactersMoved) _charactersMovedCopyText(charactersMoved!),
      if (!hasStructuredSections && fallbackContent.trim().isNotEmpty)
        fallbackContent.trim(),
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }

  @override
  bool operator ==(Object other) {
    return other is ChatTickPayloadVm &&
        other.globalText == globalText &&
        other.storyEvents == storyEvents &&
        other.charactersMoved == charactersMoved &&
        other.fallbackContent == fallbackContent;
  }

  @override
  int get hashCode =>
      Object.hash(globalText, storyEvents, charactersMoved, fallbackContent);
}

class ChatTickMessageBubble extends StatelessWidget {
  const ChatTickMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
    this.onLocationTap,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final payload = message.timelinePayload;
    if (payload is ChatTickPayloadVm) {
      return _ChatCompositeTickMessageBubble(
        message: message,
        payload: payload,
        style: style,
        onLongPressStart: onLongPressStart,
        onLocationTap: onLocationTap,
      );
    }
    return ChatSystemMessage(
      text: _tickAdvanceText(message),
      fullWidth: true,
      singleLine: true,
      textAlign: TextAlign.left,
      bubbleKey: const ValueKey('chat-tick-message-bubble'),
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}

class _ChatCompositeTickMessageBubble extends StatelessWidget {
  const _ChatCompositeTickMessageBubble({
    required this.message,
    required this.payload,
    required this.style,
    required this.onLongPressStart,
    required this.onLocationTap,
  });

  final ChatMessageVm message;
  final ChatTickPayloadVm payload;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final storyEvents = payload.storyEvents;
    final charactersMoved = payload.charactersMoved;
    final showFallback =
        !payload.hasStructuredSections &&
        payload.fallbackContent.trim().isNotEmpty;
    return Padding(
      padding: style.systemMessageMargin,
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: Container(
          key: const ValueKey<String>('chat-tick-message-bubble'),
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
              _ChatTickHeader(message: message, style: style),
              if (payload.hasGlobal) ...[
                _ChatTickSectionDivider(style: style),
                _ChatTickGlobalSection(text: payload.globalText, style: style),
              ],
              if (storyEvents != null && storyEvents.paragraphs.isNotEmpty) ...[
                _ChatTickSectionDivider(style: style),
                for (
                  var index = 0;
                  index < storyEvents.paragraphs.length;
                  index += 1
                )
                  _ChatStoryEventParagraph(
                    messageLocalId: '${message.localId}-tick',
                    index: index,
                    paragraph: storyEvents.paragraphs[index],
                    style: style,
                    showTopDivider: index > 0,
                  ),
              ],
              if (charactersMoved != null &&
                  charactersMoved.movements.isNotEmpty) ...[
                _ChatTickSectionDivider(style: style),
                _ChatCharactersMovedTitle(style: style),
                const SizedBox(height: 7),
                for (
                  var index = 0;
                  index < charactersMoved.movements.length;
                  index += 1
                )
                  _ChatCharacterMovementRow(
                    messageLocalId: '${message.localId}-tick',
                    index: index,
                    movement: charactersMoved.movements[index],
                    style: style,
                    onLocationTap: onLocationTap,
                  ),
              ],
              if (showFallback) ...[
                _ChatTickSectionDivider(style: style),
                _InlineMarkdownText(
                  text: payload.fallbackContent,
                  textAlign: TextAlign.left,
                  style: style.systemMessageTextStyle.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTickHeader extends StatelessWidget {
  const _ChatTickHeader({required this.message, required this.style});

  final ChatMessageVm message;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final currentTime = message.currentTime.trim();
    return Row(
      key: ValueKey<String>('chat-tick-header-${message.localId}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.schedule_rounded, size: 15, color: textColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            currentTime.isEmpty
                ? _tickLabel(message)
                : '${_tickLabel(message)} · ${genesisDisplaySafeText(currentTime)}',
            style: style.systemMessageTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatTickGlobalSection extends StatelessWidget {
  const _ChatTickGlobalSection({required this.text, required this.style});

  final String text;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    return Column(
      key: const ValueKey<String>('chat-tick-global-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_rounded, size: 15, color: textColor),
            const SizedBox(width: 5),
            Text(
              'Global',
              style: style.systemMessageTextStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _InlineMarkdownText(
          text: text,
          textAlign: TextAlign.left,
          style: style.systemMessageTextStyle.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

class _ChatTickSectionDivider extends StatelessWidget {
  const _ChatTickSectionDivider({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final color = (style.systemMessageTextStyle.color ?? Colors.white)
        .withValues(alpha: 0.16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: color),
    );
  }
}

String chatTickMessageCopyText(ChatMessageVm message) {
  final header = message.currentTime.trim().isEmpty
      ? _tickLabel(message)
      : '${_tickLabel(message)} · ${message.currentTime.trim()}';
  final payload = message.timelinePayload;
  if (payload is! ChatTickPayloadVm) return _tickAdvanceText(message);
  final content = payload.copyText.trim();
  return content.isEmpty ? header : '$header\n$content';
}

String _storyEventsCopyText(ChatStoryEventsPayloadVm event) {
  return [
    for (final paragraph in event.paragraphs) ...[
      'Event',
      [
        if (paragraph.timestamp.trim().isNotEmpty) paragraph.timestamp.trim(),
        if (paragraph.visibilityLabel.trim().isNotEmpty)
          paragraph.visibilityLabel.trim(),
      ].join(' · '),
      paragraph.text.trim(),
      if (paragraph.clue.trim().isNotEmpty) paragraph.clue.trim(),
    ],
  ].where((value) => value.trim().isNotEmpty).join('\n');
}

String _charactersMovedCopyText(ChatCharactersMovedPayloadVm event) {
  return [
    'Character destinations',
    for (final movement in event.movements)
      '${movement.characterName.trim()} has gone to '
          '${movement.toLocationName.trim()}',
  ].join('\n');
}
