part of 'chat_ui_library.dart';

const Color _tickMessageBackgroundColor = Color(0x99151517);
const Color _tickMessageAccentColor = GenesisColors.redPrimary;
const Color _tickMessageHeaderColor = GenesisColors.darkTextPrimary;
const Color _tickMessageBorderColor = Color(0x33FFFFFF);
const Color _tickMessageDividerColor = Color(0x29FFFFFF);
const double _tickMessageBlurSigma = GenesisBlur.strong;

class ChatTickPayloadVm extends ChatTimelinePayloadVm {
  const ChatTickPayloadVm({
    this.globalText = '',
    this.storyEvents,
    this.charactersMoved,
    this.fallbackContent = '',
    this.globalStatuses = const [],
    this.isMalformed = false,
  });

  final String globalText;
  final ChatStoryEventsPayloadVm? storyEvents;
  final ChatCharactersMovedPayloadVm? charactersMoved;
  final String fallbackContent;
  final List<ChatTickStatusVm> globalStatuses;
  final bool isMalformed;

  bool get hasGlobal => globalText.trim().isNotEmpty;

  bool get hasStoryEvents => storyEvents?.paragraphs.isNotEmpty ?? false;

  bool get hasCharactersMoved => charactersMoved?.movements.isNotEmpty ?? false;

  bool get hasStructuredSections =>
      hasGlobal ||
      globalStatuses.isNotEmpty ||
      hasStoryEvents ||
      hasCharactersMoved;

  String get copyText {
    return [
      if (hasGlobal) ...['Global', globalText.trim()],
      ...globalStatuses.map((status) => status.copyText),
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
        other.fallbackContent == fallbackContent &&
        other.isMalformed == isMalformed &&
        listEquals(other.globalStatuses, globalStatuses);
  }

  @override
  int get hashCode => Object.hash(
    globalText,
    storyEvents,
    charactersMoved,
    fallbackContent,
    isMalformed,
    Object.hashAll(globalStatuses),
  );
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
    final isProgress = payload is ChatTickProgressPayloadVm;
    final Widget content;
    final String transitionKey;
    if (payload is ChatTickProgressPayloadVm) {
      transitionKey = 'progress';
      content = _ChatTickProgressContent(payload: payload);
    } else if (payload is ChatTickPayloadVm) {
      transitionKey = 'complete';
      content = _ChatCompositeTickMessageContent(
        message: message,
        payload: payload,
        style: style,
        onLocationTap: onLocationTap,
      );
    } else {
      transitionKey = 'plain';
      content = _ChatCompositeTickMessageContent(
        message: message,
        payload: ChatTickPayloadVm(fallbackContent: message.text),
        style: style,
        onLocationTap: onLocationTap,
      );
    }
    return _ChatTickSurface(
      style: style,
      bubbleKey: const ValueKey('chat-tick-message-bubble'),
      onLongPressStart: isProgress ? null : onLongPressStart,
      child: AnimatedSize(
        duration: ChatStreamingBody.ownsSizeAnimation(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: KeyedSubtree(key: ValueKey(transitionKey), child: content),
        ),
      ),
    );
  }
}

class _ChatTickSurface extends StatelessWidget {
  const _ChatTickSurface({
    required this.style,
    required this.bubbleKey,
    required this.child,
    required this.onLongPressStart,
  });

  final ChatUiStyleConfig style;
  final Key bubbleKey;
  final Widget child;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final usesScenePlate = style.useScenePlateBubbleGeometry;
    final borderRadius = BorderRadius.circular(
      usesScenePlate ? 10 : style.systemMessageBorderRadius,
    );
    final surface = ChatBubbleGeometry(
      child: Container(
        key: const ValueKey<String>('chat-tick-message-surface'),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _tickMessageBackgroundColor,
          borderRadius: borderRadius,
          border: usesScenePlate
              ? Border.all(color: _tickMessageBorderColor)
              : null,
        ),
        child: usesScenePlate
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: ChatStreamingBody(child: child),
              )
            : Stack(
                children: [
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: ColoredBox(
                      key: ValueKey<String>('chat-tick-message-accent'),
                      color: _tickMessageAccentColor,
                    ),
                  ),
                  Padding(
                    padding: style.systemMessagePadding,
                    child: ChatStreamingBody(child: child),
                  ),
                ],
              ),
      ),
    );
    final margin = style.systemMessageMargin;
    final plateMargin = usesScenePlate
        ? margin.copyWith(
            left: math.max(margin.left, style.avatarSideSpacerWidth),
            right: math.max(margin.right, style.avatarSideSpacerWidth),
          )
        : margin;
    return Padding(
      key: bubbleKey,
      padding: plateMargin,
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: usesScenePlate
            ? ChatStableBackdropSurface(
                borderRadius: borderRadius,
                sigma: _tickMessageBlurSigma,
                child: surface,
              )
            : surface,
      ),
    );
  }
}

class _ChatCompositeTickMessageContent extends StatelessWidget {
  const _ChatCompositeTickMessageContent({
    required this.message,
    required this.payload,
    required this.style,
    required this.onLocationTap,
  });

  final ChatMessageVm message;
  final ChatTickPayloadVm payload;
  final ChatUiStyleConfig style;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final movements = _groupTickCharacterMovements(
      payload.charactersMoved?.movements ?? const [],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatTickHeader(
          label: _tickLabel(message),
          headerKey: ValueKey<String>('chat-tick-header-${message.localId}'),
          style: style,
        ),
        ChatTickChapterContent(
          payload: payload,
          currentTime: message.currentTime,
          messageLocalId: '${message.localId}-tick',
        ),
        if (!payload.isMalformed && movements.isNotEmpty)
          _ChatTickMovementSection(
            messageLocalId: '${message.localId}-tick',
            movements: movements,
            style: style,
            onLocationTap: onLocationTap,
          ),
      ],
    );
  }
}

class _ChatTickProgressContent extends StatelessWidget {
  const _ChatTickProgressContent({required this.payload});

  final ChatTickProgressPayloadVm payload;

  @override
  Widget build(BuildContext context) {
    final avatars = payload.avatars
        .map(
          (avatar) =>
              GenesisGenerationWaitAvatar(name: avatar.name, url: avatar.url),
        )
        .toList(growable: false);
    return Column(
      key: const ValueKey<String>('chat-tick-progress-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChatTickProgressTitle(title: payload.title),
        if (avatars.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(child: GenerationAvatarCarousel(avatars: avatars, size: 44)),
        ],
      ],
    );
  }
}

class _ChatTickProgressTitle extends StatefulWidget {
  const _ChatTickProgressTitle({required this.title});

  final String title;

  @override
  State<_ChatTickProgressTitle> createState() => _ChatTickProgressTitleState();
}

class _ChatTickProgressTitleState extends State<_ChatTickProgressTitle> {
  static const Duration _dotsInterval = Duration(milliseconds: 400);

  Timer? _timer;
  var _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_dotsInterval, (_) {
      if (!mounted) return;
      setState(() => _dotCount = _dotCount == 6 ? 1 : _dotCount + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      key: const ValueKey<String>('chat-tick-progress-title'),
      '${widget.title}${List.filled(_dotCount, '.').join()}',
      textAlign: TextAlign.left,
      style: GenesisTypography.bodyStrong.copyWith(
        color: GenesisColors.darkTextPrimary,
      ),
    );
  }
}

class ChatTickHeader extends StatelessWidget {
  const ChatTickHeader({
    super.key,
    required this.label,
    required this.style,
    this.headerKey,
  });

  final String label;
  final Key? headerKey;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: headerKey,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _tickMessageDividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatTickFirstLineIcon(
            textStyle: GenesisTypography.bodyStrong.copyWith(
              leadingDistribution: TextLeadingDistribution.even,
            ),
            child: Container(
              key: const ValueKey<String>('chat-tick-header-dot'),
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: _tickMessageAccentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GenesisTypography.bodyStrong.copyWith(
                color: GenesisColors.darkTextPrimary,
                // Center the letterforms as well as the line box beside the dot.
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatTickGlobalSection extends StatelessWidget {
  const ChatTickGlobalSection({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('chat-tick-global-section'),
      child: _InlineMarkdownText(
        text: text,
        softItalic: true,
        style: GenesisTypography.body.copyWith(
          color: GenesisColors.darkTextSecondary,
        ),
      ),
    );
  }
}

class _ChatTickMovementSection extends StatelessWidget {
  const _ChatTickMovementSection({
    required this.messageLocalId,
    required this.movements,
    required this.style,
    required this.onLocationTap,
  });

  final String messageLocalId;
  final List<ChatCharacterMovementVm> movements;
  final ChatUiStyleConfig style;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('chat-tick-movement-section'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 13),
      padding: const EdgeInsets.only(top: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _tickMessageDividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < movements.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 10),
            _ChatCharacterMovementRow(
              messageLocalId: messageLocalId,
              index: index,
              movement: movements[index],
              style: style,
              onLocationTap: onLocationTap,
              usePastTenseDirection: true,
              scenePlate: true,
            ),
          ],
        ],
      ),
    );
  }
}

String chatTickMessageCopyText(ChatMessageVm message) {
  final header = message.currentTime.trim().isEmpty
      ? _tickLabel(message)
      : '${_tickLabel(message)} · ${message.currentTime.trim()}';
  final payload = message.timelinePayload;
  if (payload is! ChatTickPayloadVm) return _tickAdvanceText(message);
  if (!payload.hasStructuredSections &&
      payload.fallbackContent.trim() == message.currentTime.trim())
    return header;
  final content = payload.copyText.trim();
  return content.isEmpty ? header : '$header\n$content';
}

String _storyEventsCopyText(ChatStoryEventsPayloadVm event) {
  return [
    for (final paragraph in event.paragraphs) ...[
      if (paragraph.locationName.isNotEmpty)
        paragraph.locationName
      else if (event.locationName.isNotEmpty)
        event.locationName
      else
        'Event',
      [
        if (paragraph.timestamp.trim().isNotEmpty) paragraph.timestamp.trim(),
        if (paragraph.visibilityLabel.trim().isNotEmpty)
          paragraph.visibilityLabel.trim(),
      ].join(' · '),
      paragraph.text.trim(),
      ...paragraph.statuses.map((status) => status.copyText),
      if (paragraph.clue.trim().isNotEmpty) paragraph.clue.trim(),
    ],
  ].where((value) => value.trim().isNotEmpty).join('\n');
}

String _charactersMovedCopyText(ChatCharactersMovedPayloadVm event) {
  return [
    'Character destinations',
    for (final movement in _groupTickCharacterMovements(event.movements))
      '${movement.characterName.trim()} '
          '${movement.isDestinationCurrentLocation ? 'came to' : 'went to'} '
          '${movement.toLocationName.trim()}',
  ].join('\n');
}

List<ChatCharacterMovementVm> _groupTickCharacterMovements(
  List<ChatCharacterMovementVm> movements,
) {
  final movementsByDestination = <String, List<ChatCharacterMovementVm>>{};
  for (final movement in movements) {
    final destinationId = movement.toLocationId.trim();
    movementsByDestination
        .putIfAbsent(destinationId, () => <ChatCharacterMovementVm>[])
        .add(movement);
  }
  final groupedMovements = <ChatCharacterMovementVm>[];
  for (final group in movementsByDestination.values) {
    final first = group.first;
    groupedMovements.add(
      ChatCharacterMovementVm(
        characterId: first.characterId,
        characterName: group
            .map((movement) => movement.characterName.trim())
            .where((name) => name.isNotEmpty)
            .join(', '),
        toLocationId: first.toLocationId,
        toLocationName: first.toLocationName,
        isDestinationCurrentLocation: first.isDestinationCurrentLocation,
      ),
    );
  }
  return List<ChatCharacterMovementVm>.unmodifiable(groupedMovements);
}
