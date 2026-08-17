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
                  addTopSpacing: index > 0,
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
    required this.addTopSpacing,
  });

  final String messageLocalId;
  final int index;
  final ChatStoryEventParagraphVm paragraph;
  final ChatUiStyleConfig style;
  final bool addTopSpacing;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final metadataStyle = style.systemMessageTextStyle.copyWith(
      color: textColor.withValues(alpha: 0.72),
      fontSize: (style.systemMessageTextStyle.fontSize ?? 12) - 1,
    );
    final isPublic = paragraph.visibilityLabel.trim().toLowerCase() == 'public';
    final hasTimestamp = paragraph.timestamp.trim().isNotEmpty;
    final hasVisibility =
        !isPublic && paragraph.visibilityLabel.trim().isNotEmpty;
    return Container(
      key: ValueKey<String>(
        'chat-story-event-paragraph-$messageLocalId-$index',
      ),
      width: double.infinity,
      margin: EdgeInsets.only(top: addTopSpacing ? 10 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                eventsIconAsset,
                key: ValueKey<String>(
                  'chat-story-event-icon-$messageLocalId-$index',
                ),
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
              ),
              if (hasTimestamp) ...[
                const SizedBox(width: 8),
                Text(
                  genesisDisplaySafeText(paragraph.timestamp),
                  key: ValueKey<String>(
                    'chat-story-event-timestamp-$messageLocalId-$index',
                  ),
                  style: metadataStyle,
                ),
              ],
              if (hasVisibility) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ChatStoryEventVisibility(
                    key: ValueKey<String>(
                      'chat-story-event-visibility-$messageLocalId-$index',
                    ),
                    label: paragraph.visibilityLabel,
                    visibleRoles: paragraph.visibleRoles,
                    style: style,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          _InlineMarkdownText(
            text: paragraph.text,
            textAlign: TextAlign.left,
            style: style.systemMessageTextStyle.copyWith(height: 1.45),
          ),
          if (paragraph.clue.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              key: ValueKey<String>(
                'chat-story-event-clue-$messageLocalId-$index',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SvgPicture.asset(
                    clueIconAsset,
                    width: 14,
                    height: 14,
                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _InlineMarkdownText(
                    text: paragraph.clue,
                    textAlign: TextAlign.left,
                    style: style.systemMessageTextStyle.copyWith(
                      color: textColor.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                    softItalic: true,
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

class _ChatStoryEventVisibility extends StatelessWidget {
  const _ChatStoryEventVisibility({
    super.key,
    required this.label,
    required this.visibleRoles,
    required this.style,
  });

  final String label;
  final List<ChatStoryEventVisibleRoleVm> visibleRoles;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final badgeColor = textColor.withValues(alpha: 0.72);
    final aiNames = visibleRoles
        .where((role) => role.isAi)
        .map((role) => role.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final userNames = visibleRoles
        .where((role) => !role.isAi)
        .map((role) => role.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (aiNames.isEmpty && userNames.isEmpty && label.trim().isNotEmpty) {
      userNames.add(label.trim());
    }
    return Wrap(
      spacing: 8,
      runSpacing: 5,
      children: [
        if (aiNames.isNotEmpty)
          _ChatStoryEventVisibleRoleGroup(
            iconAsset: locationChatCharacterIconAsset,
            names: aiNames,
            textColor: badgeColor,
          ),
        if (userNames.isNotEmpty)
          _ChatStoryEventVisibleRoleGroup(
            iconAsset: userStatIconAsset,
            names: userNames,
            textColor: badgeColor,
          ),
      ],
    );
  }
}

class _ChatStoryEventVisibleRoleGroup extends StatelessWidget {
  const _ChatStoryEventVisibleRoleGroup({
    required this.iconAsset,
    required this.names,
    required this.textColor,
  });

  final String iconAsset;
  final List<String> names;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SvgPicture.asset(
            iconAsset,
            width: 12,
            height: 12,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            colorFilter: iconAsset == userStatIconAsset
                ? ColorFilter.mode(
                    textColor.withValues(alpha: 1),
                    BlendMode.srcIn,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            genesisDisplaySafeText(names.join(', ')),
            softWrap: true,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
