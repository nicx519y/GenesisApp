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
      content = _InlineMarkdownText(
        text: _tickAdvanceText(message),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: style.systemMessageTextStyle.copyWith(
          color: context.genesisChatTheme.tickHeader,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return _ChatTickSurface(
      style: style,
      bubbleKey: const ValueKey('chat-tick-message-bubble'),
      onLongPressStart: isProgress ? null : onLongPressStart,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
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
    final chatTheme = context.genesisChatTheme;
    final usesScenePlate = chatTheme.tickBlurSigma > 0;
    final borderRadius = BorderRadius.circular(
      usesScenePlate ? 10 : style.systemMessageBorderRadius,
    );
    final surface = Container(
      key: const ValueKey<String>('chat-tick-message-surface'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: chatTheme.tickBackground,
        borderRadius: borderRadius,
        border: usesScenePlate ? Border.all(color: chatTheme.tickBorder) : null,
      ),
      child: usesScenePlate
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: child,
            )
          : Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: ColoredBox(
                    key: const ValueKey<String>('chat-tick-message-accent'),
                    color: chatTheme.tickAccent,
                  ),
                ),
                Padding(padding: style.systemMessagePadding, child: child),
              ],
            ),
    );
    // The plate belongs to the bubble column, not the full message column: its
    // edges land on the bubbles' outer limits - where a full-width self bubble
    // starts on the left and a full-width AI bubble ends on the right, i.e. one
    // avatarSideSpacerWidth in from each gutter. The narrator runs the full
    // width instead, which is what separates the two tiers. Styles whose
    // systemMessageMargin already carries that inset keep it as is - the two
    // are the same offset, not stacked.
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
            ? _ChatStableBackdropSurface(
                borderRadius: borderRadius,
                sigma: chatTheme.tickBlurSigma,
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
    final usesScenePlate = context.genesisChatTheme.tickBlurSigma > 0;
    final storyEvents = payload.storyEvents;
    final charactersMoved = payload.charactersMoved;
    final groupedMovements = charactersMoved == null
        ? const <ChatCharacterMovementVm>[]
        : _groupTickCharacterMovements(charactersMoved.movements);
    final showFallback =
        !payload.hasStructuredSections &&
        payload.fallbackContent.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatTickHeader(message: message, style: style),
        if (payload.hasGlobal) ...[
          _ChatTickSectionDivider(style: style),
          _ChatTickGlobalSection(text: payload.globalText, style: style),
        ],
        if (storyEvents != null && storyEvents.paragraphs.isNotEmpty) ...[
          SizedBox(height: usesScenePlate ? 12 : 20),
          for (var index = 0; index < storyEvents.paragraphs.length; index += 1)
            _ChatStoryEventParagraph(
              messageLocalId: '${message.localId}-tick',
              index: index,
              paragraph: storyEvents.paragraphs[index],
              style: style,
              addTopSpacing: index > 0,
              scenePlate: usesScenePlate,
            ),
        ],
        if (groupedMovements.isNotEmpty)
          usesScenePlate
              ? _ChatTickMovementSection(
                  messageLocalId: '${message.localId}-tick',
                  movements: groupedMovements,
                  style: style,
                  onLocationTap: onLocationTap,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    for (
                      var index = 0;
                      index < groupedMovements.length;
                      index += 1
                    ) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _ChatCharacterMovementRow(
                        messageLocalId: '${message.localId}-tick',
                        index: index,
                        movement: groupedMovements[index],
                        style: style,
                        onLocationTap: onLocationTap,
                        usePastTenseDirection: true,
                      ),
                    ],
                  ],
                ),
        if (showFallback) ...[
          const SizedBox(height: 10),
          _InlineMarkdownText(
            text: payload.fallbackContent,
            textAlign: TextAlign.left,
            style: style.systemMessageTextStyle.copyWith(
              color: usesScenePlate
                  ? context.genesisChatTheme.narratorForeground
                  : null,
              fontSize: usesScenePlate ? 13 : null,
              height: kChatBodyLineHeight,
            ),
          ),
        ],
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
          const SizedBox(height: 14),
          Center(child: GenerationAvatarCarousel(avatars: avatars)),
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
      style: TextStyle(
        color: context.genesisChatTheme.tickHeader,
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
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
    // The section title carries the tick number only; the story time shows
    // up on its own row further down.
    final label = _tickLabel(message);
    final chatTheme = context.genesisChatTheme;
    if (chatTheme.tickBlurSigma <= 0) {
      return Text(
        key: ValueKey<String>('chat-tick-header-${message.localId}'),
        label,
        style: style.systemMessageTextStyle.copyWith(
          color: chatTheme.tickHeader,
          fontWeight: FontWeight.w400,
        ),
      );
    }
    return Container(
      key: ValueKey<String>('chat-tick-header-${message.localId}'),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: chatTheme.tickDivider)),
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey<String>('chat-tick-header-dot'),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: chatTheme.tickAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: style.systemMessageTextStyle.copyWith(
                color: chatTheme.tickHeader,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTickGlobalSection extends StatelessWidget {
  const _ChatTickGlobalSection({required this.text, required this.style});

  final String text;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('chat-tick-global-section'),
      child: _InlineMarkdownText(
        text: text,
        textAlign: TextAlign.left,
        style: style.systemMessageTextStyle.copyWith(
          color: context.genesisChatTheme.narratorForeground,
          fontSize: context.genesisChatTheme.tickBlurSigma > 0 ? 13 : null,
          height: context.genesisChatTheme.tickBlurSigma > 0
              ? kChatBodyLineHeight
              : null,
        ),
        softItalicPerToken: true,
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.genesisChatTheme.tickDivider),
        ),
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

class _ChatTickSectionDivider extends StatelessWidget {
  const _ChatTickSectionDivider({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    if (context.genesisChatTheme.tickBlurSigma > 0) {
      return const SizedBox(height: 10);
    }
    final color =
        (style.systemMessageTextStyle.color ??
                context.genesisColors.textInverse)
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
