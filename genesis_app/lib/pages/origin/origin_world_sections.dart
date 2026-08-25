part of 'origin_world_page.dart';

class _WorldViewSection extends StatelessWidget {
  const _WorldViewSection({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final body = _originWorldoBrief(origin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _OriginInfoSectionHeading(title: 'World brief'),
        const SizedBox(height: worldDetailSectionTitleContentGap),
        Text(
          body,
          style: _bodyTextStyle(context).copyWith(
            height: worldDetailLineHeight,
            color: context.genesisColors.textBody,
          ),
        ),
      ],
    );
  }
}

String _originWorldoBrief(OriginDetail origin) {
  final worldView = origin.worldView.trim();
  return worldView.isEmpty ? origin.description.trim() : worldView;
}

class _OriginPreviewImage extends StatelessWidget {
  const _OriginPreviewImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final imageUrl = viewerUrl;
    final fallback = Container(
      color: context.genesisColors.imagePlaceholder,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: context.genesisColors.imagePlaceholderIcon,
      ),
    );
    Widget buildPreview(double width, double height) {
      final preview = Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: imageUrl.isEmpty
                ? fallback
                : imageUrl.startsWith('assets/')
                ? Image.asset(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  )
                : GenesisStaticNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_) => fallback,
                    errorWidget: (_, _) => fallback,
                  ),
          ),
        ),
      );
      if (viewerUrl.isEmpty) return preview;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showGenesisImageViewer(
          context,
          imageUrls: [viewerUrl],
          previewImageProviders: [
            genesisImageViewerPreviewProvider(
              context,
              imageUrl: imageUrl,
              logicalWidth: width,
              logicalHeight: height,
              fit: BoxFit.cover,
            ),
          ],
        ),
        child: preview,
      );
    }

    final explicitWidth = width;
    final explicitHeight = height;
    if (explicitWidth != null && explicitHeight != null) {
      return buildPreview(explicitWidth, explicitHeight);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final width = maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final height = width / _aspectRatio;
        return buildPreview(width, height);
      },
    );
  }
}

class _OriginInfoSectionHeading extends StatelessWidget {
  const _OriginInfoSectionHeading({
    required this.title,
    this.count,
    this.trailing,
  });

  final String title;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return Row(
      children: [
        // 与已加载世界详情页的分区标题同款:9x9 红方块沿 Y 轴斜切。
        Transform(
          transform: Matrix4.skewY(worldDetailSectionGlyphSkew),
          alignment: Alignment.center,
          child: Container(width: 9, height: 9, color: colors.danger),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: GenesisTypography.sectionTitle.copyWith(
            height: worldDetailLineHeight,
            color: colors.textPrimary,
          ),
        ),
        if (count case final count?) ...[
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _LaunchPreviewSection extends StatelessWidget {
  const _LaunchPreviewSection({
    required this.origin,
    required this.previewTick,
  });

  final OriginDetail origin;
  final Map<String, dynamic> previewTick;

  @override
  Widget build(BuildContext context) {
    final tickResult = previewTick['tick_result'] is Map
        ? (previewTick['tick_result'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final currentTime = _mapString(tickResult, const ['current_time']);
    final globalBody = _mapString(tickResult, const ['narrator']);
    final metricUnit = _mapString(origin.metric, const ['unit']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题与页面其余分区(world 详情页同款红方块标题)保持一致。
        const _OriginInfoSectionHeading(title: 'Launch Preview'),
        const SizedBox(height: worldDetailSectionTitleContentGap),
        WorldTickEventItem(
          tick: previewTick,
          tickNumber: 1,
          fallbackBody: globalBody,
          locationsById: _originLocationsById(origin.allLocations),
          dateLabel: currentTime,
          timeAgoLabel: '',
          stackedContent: true,
          contentLabelStyle: _originTickContentLabelStyle(context),
          contentTextStyle: _originTickContentTextStyle(context),
          contentTimestampStyle: _originTickContentTimestampStyle(context),
          metricUnit: metricUnit,
        ),
      ],
    );
  }
}

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({required this.origin, required this.controller});

  final OriginDetail origin;
  final OriginDiscussListController controller;

  bool get _hasDiscussContent =>
      origin.discussCount > 0 ||
      controller.totalAll > 0 ||
      controller.items.isNotEmpty;

  Future<void> _handleDiscussAreaTap(BuildContext context) {
    if (_hasDiscussContent) return _openDiscussPage(context);
    return _openPostComposer(context);
  }

  Future<void> _openDiscussPage(BuildContext context) {
    return Navigator.of(context).pushNamed(
      RouteNames.discuss,
      arguments: {'oid': origin.oid, 'originId': origin.id},
    );
  }

  Future<void> _handleSeeAllTap(BuildContext context) async {
    if (!await ensureGenesisLogin(context) || !context.mounted) return;
    await _openDiscussPage(context);
  }

  Future<void> _openPostComposer(BuildContext context) async {
    final submitted = await showDiscussPostComposer(
      context: context,
      title: 'New post',
      placeholder: 'Write a post',
      submitter: (content, images) async {
        await AppServicesScope.read(context).api.v1.discuss.post(
          bizId: origin.oid.trim(),
          bizType: 1,
          content: content,
          images: images,
        );
      },
    );
    if (!context.mounted || !submitted) return;
    unawaited(controller.refreshFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasDiscussContent = _hasDiscussContent;
        final showDiscussList =
            hasDiscussContent ||
            controller.isInitialLoading ||
            controller.error != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const ValueKey('origin-discuss-summary-area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_handleDiscussAreaTap(context)),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OriginInfoSectionHeading(
                      title: 'Comments',
                      count: '(${origin.discussCount})',
                      trailing: GestureDetector(
                        key: const ValueKey<String>('origin-discuss-see-all'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => unawaited(_handleSeeAllTap(context)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: TextStyle(
                                  color: context.genesisColors.foregroundStrong
                                      .withValues(alpha: 0.72),
                                  fontSize: 9.5,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 9,
                                color: context.genesisColors.foregroundStrong
                                    .withValues(alpha: 0.72),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showDiscussList) ...[
                      const SizedBox(height: worldDetailSectionTitleContentGap),
                      _OriginInfoCommentsPreview(controller: controller),
                    ],
                  ],
                ),
              ),
            ),
            if (!hasDiscussContent) ...[
              const SizedBox(height: 8),
              DiscussPostInput(
                bizId: origin.oid,
                compact: true,
                showCurrentUserAvatar: true,
                onSubmitted: () => unawaited(controller.refreshFirstPage()),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OriginInfoCommentsPreview extends StatelessWidget {
  const _OriginInfoCommentsPreview({required this.controller});

  final OriginDiscussListController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isInitialLoading && controller.items.isEmpty) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (controller.error != null && controller.items.isEmpty) {
      return TextButton(
        onPressed: controller.retryInitial,
        child: const Text('Retry'),
      );
    }
    final comments = controller.items.take(3).toList(growable: false);
    final colors = context.genesisColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, comment) in comments.indexed) ...[
          if (index > 0) const SizedBox(height: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: comment.authorName,
                      style: TextStyle(
                        color: colors.accentText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: '  ${comment.content}'),
                  ],
                ),
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 13,
                  height: worldDetailLineHeight,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${comment.likeCount} likes',
                style: TextStyle(
                  color: colors.textMetadata,
                  fontSize: 9.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

List<Widget> _originInitialDialogueSlivers(
  BuildContext context,
  OriginDetail origin,
  _OriginInitialDialoguePreview preview,
) {
  final locationStyle = context.genesisChatTheme.locationChat;
  // Message geometry (row spacing, avatar, bubble, narrator plate) comes
  // straight from the location-chat style so the preview reads like the chat
  // room; only the sheet inset and theme-aware ink colors are local.
  final style = locationStyle.copyWith(
    // 横向边距统一 20:设计稿 9i 原文是 22,但 9n/9f 与整个详情浮窗体系
    // 都是 20,Opening/Info 左右滑动时内容边缘不应跳动。
    messageListPadding: const EdgeInsets.fromLTRB(
      originDetailSheetHorizontalPaddingForTesting,
      11,
      originDetailSheetHorizontalPaddingForTesting,
      10,
    ),
    headerTitleTextStyle: locationStyle.headerTitleTextStyle.copyWith(
      color: context.genesisColors.foregroundStrong,
      fontSize: 13,
      height: 1,
      fontWeight: FontWeight.w600,
    ),
    headerTitleIconColor: context.genesisColors.textSecondary,
    senderNameTextStyle: locationStyle.senderNameTextStyle.copyWith(
      color: context.genesisColors.foregroundStrong,
    ),
  );
  // The sheet has no scene artwork behind the bubbles, so the chat room's
  // glass backdrop would blur a flat color; drop it and keep the plate fills.
  final baseTheme = Theme.of(context);
  final noGlassExtensions = List<ThemeExtension<dynamic>>.of(
    baseTheme.extensions.values.where((value) => value is! GenesisChatTheme),
  )..add(context.genesisChatTheme.copyWith(aiRoleBubbleBlurSigma: 0));
  final noGlassTheme = baseTheme.copyWith(extensions: noGlassExtensions);
  final padding = style.messageListPadding;
  final brief = _originWorldoBrief(origin);
  final currentTime = preview.currentTime;
  return <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          brief.isEmpty ? 6 : 11,
          padding.right,
          7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentTime.isNotEmpty) ...[
              Row(
                key: const ValueKey<String>('origin-opening-time'),
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: style.headerTitleIconColor,
                  ),
                  SizedBox(width: style.headerTitleIconGap),
                  Expanded(
                    child: Text(
                      currentTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: style.headerTitleTextStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
            ],
            Row(
              key: const ValueKey<String>('origin-opening-location'),
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: style.headerTitleIconColor,
                ),
                SizedBox(width: style.headerTitleIconGap),
                Expanded(
                  child: Text(
                    preview.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: style.headerTitleTextStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    SliverPadding(
      key: const ValueKey<String>('origin-opening-dialogue'),
      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 10),
      sliver: SliverList.builder(
        itemCount: preview.messages.length,
        itemBuilder: (context, index) {
          final message = preview.messages[index];
          final isLast = index == preview.messages.length - 1;
          final messageStyle = isLast
              ? style.copyWith(
                  rowBottomPadding: 0,
                  systemMessageMargin: style.systemMessageMargin.copyWith(
                    bottom: 0,
                  ),
                )
              : style;
          return Theme(
            data: noGlassTheme,
            child: ChatMessageRow(
              key: ValueKey<String>(message.localId),
              message: message,
              showDateDivider: false,
              style: messageStyle,
            ),
          );
        },
      ),
    ),
  ];
}

List<Widget> _originWorldoBriefSlivers(
  BuildContext context,
  OriginDetail origin,
) {
  final brief = _originWorldoBrief(origin);
  if (brief.isEmpty) return const <Widget>[];
  return <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey<String>('origin-opening-worldo-brief'),
        padding: const EdgeInsets.fromLTRB(
          originDetailSheetHorizontalPaddingForTesting,
          6,
          originDetailSheetHorizontalPaddingForTesting,
          0,
        ),
        child: Container(
          padding: const EdgeInsets.only(bottom: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.genesisColors.dividerAction),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform(
                    key: const ValueKey<String>(
                      'origin-opening-worldo-brief-icon',
                    ),
                    transform: Matrix4.skewY(-0.24),
                    alignment: Alignment.center,
                    child: Container(
                      width: 9,
                      height: 9,
                      color: context.genesisColors.danger,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'World brief',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GenesisTypography.sectionTitle.copyWith(
                        color: context.genesisColors.textHeading,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                brief,
                key: const ValueKey<String>('origin-opening-worldo-brief-body'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: context.genesisColors.textBody,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ];
}

String _originRoleCardAvatarUrl(BuildContext context, String sourceUrl) {
  return selectGenesisImageUrl(
    sourceUrl,
    logicalWidth: _OriginSetupRoleSection._cardWidth,
    logicalHeight: _OriginSetupRoleSection._cardHeight,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  ).trim();
}
