part of 'chat_ui_library.dart';

@immutable
class ChatTickStatusVm {
  const ChatTickStatusVm({
    required this.owner,
    required this.icon,
    required this.form,
    required this.content,
    this.name = '',
    this.avatarUrl = '',
  });
  final String owner;
  final String icon;
  final String form;
  final String content;
  final String name;
  final String avatarUrl;
  bool get isWorld => owner == 'world';
  String get copyText =>
      '${isWorld || name.isEmpty ? '' : '$name · '}$icon $form\n$content';
  @override
  bool operator ==(Object other) =>
      other is ChatTickStatusVm &&
      owner == other.owner &&
      icon == other.icon &&
      form == other.form &&
      content == other.content &&
      name == other.name &&
      avatarUrl == other.avatarUrl;
  @override
  int get hashCode => Object.hash(owner, icon, form, content, name, avatarUrl);
}

/// Keeps a leading icon centered on one text line even when its label wraps.
class _ChatTickFirstLineIcon extends StatelessWidget {
  const _ChatTickFirstLineIcon({
    required this.child,
    this.textStyle = GenesisTypography.body,
  });

  final Widget child;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: defaults.style.merge(textStyle)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: defaults.textHeightBehavior,
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    return SizedBox(
      height: lineHeight,
      child: Align(widthFactor: 1, alignment: Alignment.center, child: child),
    );
  }
}

/// Chapter body shared by the chat surface and the World Events pager.
class ChatTickChapterContent extends StatelessWidget {
  const ChatTickChapterContent({
    super.key,
    required this.payload,
    required this.currentTime,
    this.messageLocalId = 'world-event',
    this.locationFooterBuilder,
    this.locationDividers = true,
  });
  final ChatTickPayloadVm payload;
  final String currentTime;
  final String messageLocalId;
  final Widget Function(ChatStoryEventParagraphVm)? locationFooterBuilder;

  /// Rules each location off from the one before. The chat bubble keeps them:
  /// it is already one tight container. A full page drops them and lets the
  /// same space alone part the locations, leaving the tick's own rule as the
  /// one line on it.
  final bool locationDividers;

  @override
  Widget build(BuildContext context) {
    if (payload.isMalformed) return const _TickChapterSkeleton();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentTime.trim().isNotEmpty) ...[
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ChatTickFirstLineIcon(
                textStyle: GenesisTypography.body,
                child: Icon(
                  Icons.schedule,
                  size: 14,
                  color: GenesisColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  currentTime,
                  key: const ValueKey('tick-chapter-time'),
                  style: GenesisTypography.body.copyWith(
                    color: GenesisColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (payload.hasGlobal) ...[
          const SizedBox(height: 10),
          KeyedSubtree(
            key: const ValueKey('chat-tick-global-section'),
            child: _InlineMarkdownText(
              text: payload.globalText,
              softItalic: true,
              style: GenesisTypography.body.copyWith(
                color: GenesisColors.darkTextSecondary,
              ),
            ),
          ),
        ],
        if (payload.globalStatuses.isNotEmpty) ...[
          const SizedBox(height: 10),
          _TickStatusGroup(statuses: payload.globalStatuses),
        ],
        for (final paragraph
            in payload.storyEvents?.paragraphs ??
                const <ChatStoryEventParagraphVm>[])
          _TickChapterLocation(
            paragraph: paragraph,
            messageLocalId: messageLocalId,
            locationName: paragraph.locationName.isNotEmpty
                ? paragraph.locationName
                : payload.storyEvents!.locationName,
            footer: locationFooterBuilder?.call(paragraph),
            divider: locationDividers,
          ),
        if (!payload.hasStructuredSections &&
            payload.fallbackContent.trim().isNotEmpty &&
            payload.fallbackContent != currentTime) ...[
          const SizedBox(height: 10),
          _InlineMarkdownText(
            text: payload.fallbackContent,
            style: GenesisTypography.body.copyWith(
              color: GenesisColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _TickChapterLocation extends StatelessWidget {
  const _TickChapterLocation({
    required this.paragraph,
    required this.messageLocalId,
    required this.locationName,
    this.footer,
    this.divider = true,
  });
  final ChatStoryEventParagraphVm paragraph;
  final String messageLocalId;
  final Widget? footer;
  final String locationName;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final body = GenesisTypography.body.copyWith(
      color: GenesisColors.darkTextSecondary,
    );
    return Container(
      key: ValueKey(
        'chat-story-event-paragraph-$messageLocalId-${paragraph.sourceIndex}',
      ),
      // The gap is the same with or without the rule, so dropping it changes
      // nothing else about the layout.
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 11),
      decoration: divider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: _tickMessageDividerColor)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ChatTickFirstLineIcon(
                textStyle: GenesisTypography.bodyStrong,
                child: Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: GenesisColors.darkTextSecondary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  locationName,
                  style: GenesisTypography.bodyStrong.copyWith(
                    color: GenesisColors.darkTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paragraph.timestamp.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    paragraph.timestamp,
                    style: GenesisTypography.supporting.copyWith(
                      color: GenesisColors.darkTextTertiary,
                    ),
                  ),
                ],
                if (paragraph.visibleRoles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    key: ValueKey(
                      'chat-story-event-visibility-$messageLocalId-${paragraph.sourceIndex}',
                    ),
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final role in paragraph.visibleRoles)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GenesisCharacterAvatar(
                              url: role.avatarUrl,
                              name: role.name,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                role.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GenesisTypography.bodyStrong.copyWith(
                                  color: GenesisColors.darkTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ] else if (paragraph.visibilityLabel.isNotEmpty &&
                    paragraph.visibilityLabel != 'public') ...[
                  const SizedBox(height: 8),
                  Text(
                    paragraph.visibilityLabel,
                    key: ValueKey(
                      'chat-story-event-visibility-$messageLocalId-${paragraph.sourceIndex}',
                    ),
                    style: body,
                  ),
                ],
                if (paragraph.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InlineMarkdownText(text: paragraph.text, style: body),
                ],
                if (paragraph.statuses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _TickStatusGroup(statuses: paragraph.statuses),
                ],
                if (footer != null) footer!,
              ],
            ),
          ),
          if (paragraph.clue.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChatTickFirstLineIcon(
                  child: SvgPicture.asset(
                    clueIconAsset,
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      GenesisColors.redSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _InlineMarkdownText(
                    text: paragraph.clue,
                    softItalic: true,
                    style: GenesisTypography.body.copyWith(
                      color: GenesisColors.redSecondary,
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

class _TickStatusGroup extends StatelessWidget {
  const _TickStatusGroup({required this.statuses});
  final List<ChatTickStatusVm> statuses;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, status) in statuses.indexed) ...[
        if (index > 0) const SizedBox(height: 6),
        Container(
          key: ValueKey('tick-status-${status.owner}-$index'),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            // An information card, not an input: the faint fill read lighter
            // than a chat bubble, above the message it only annotates.
            color: GenesisColors.darkCardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!status.isWorld) ...[
                    GenesisCharacterAvatar(
                      url: status.avatarUrl,
                      name: status.name,
                      size: 18,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GenesisTypography.bodyStrong.copyWith(
                          color: GenesisColors.darkTextPrimary,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                    Text(
                      ' · ',
                      style: GenesisTypography.body.copyWith(
                        color: GenesisColors.darkTextTertiary,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ],
                  ExcludeSemantics(
                    child: SizedBox(
                      width:
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(GenesisTypography.body.fontSize!) *
                          1.6,
                      child: Text(
                        status.icon,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: GenesisTypography.body.copyWith(
                          color: GenesisColors.darkTextPrimary,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      status.form,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GenesisTypography.bodyStrong.copyWith(
                        color: GenesisColors.darkTextPrimary,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _InlineMarkdownText(
                text: status.content,
                style: GenesisTypography.body.copyWith(
                  color: GenesisColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _TickChapterSkeleton extends StatelessWidget {
  const _TickChapterSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('tick-chapter-skeleton'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [0.4, 1.0, 0.8])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: GenesisColors.darkFaintFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
