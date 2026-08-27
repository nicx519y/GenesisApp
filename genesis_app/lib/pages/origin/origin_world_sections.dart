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
        const _SectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFFF2442),
          title: 'Worldo Brief',
        ),
        const SizedBox(height: 8),
        Text(body, style: _bodyTextStyle),
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
    required this.url,
    required this.width,
    required this.height,
  });
  static const double _maxDevicePixelRatio = 2;

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final imageUrl = selectGenesisImageUrl(
      viewerUrl,
      logicalWidth: width,
      logicalHeight: height,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      maxDevicePixelRatio: _maxDevicePixelRatio,
    ).trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );
    final preview = Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        key: const ValueKey<String>('origin-info-cover'),
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
                  maxDevicePixelRatio: _maxDevicePixelRatio,
                  placeholder: (_) => fallback,
                  errorWidget: (_, _) => fallback,
                ),
        ),
      ),
    );
    if (viewerUrl.isEmpty) return preview;
    return GestureDetector(
      key: const ValueKey<String>('origin-info-cover-viewer'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showGenesisImageViewer(
        context,
        imageUrls: [viewerUrl],
        maxDevicePixelRatio: _maxDevicePixelRatio,
        previewImageProviders: [
          genesisImageViewerPreviewProvider(
            context,
            imageUrl: imageUrl,
            logicalWidth: width,
            logicalHeight: height,
            fit: BoxFit.cover,
            maxDevicePixelRatio: _maxDevicePixelRatio,
          ),
        ],
      ),
      child: preview,
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
        const _SectionTitle(
          icon: Icons.auto_awesome,
          iconColor: Color(0xFF6554FF),
          title: 'Launch Preview',
        ),
        const SizedBox(height: 8),
        WorldTickEventItem(
          tick: previewTick,
          tickNumber: 1,
          fallbackBody: globalBody,
          locationsById: _originLocationsById(origin.allLocations),
          dateLabel: currentTime,
          timeAgoLabel: '',
          stackedContent: true,
          contentLabelStyle: _originTickContentLabelStyle,
          contentTextStyle: _originTickContentTextStyle,
          contentTimestampStyle: _originTickContentTimestampStyle,
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
                    _SectionTitle(
                      iconAsset: discussIconAsset,
                      title: 'Discuss (${origin.discussCount})',
                    ),
                    if (showDiscussList) ...[
                      const SizedBox(height: 8),
                      OriginDiscussList(
                        controller: controller,
                        count: origin.discussCount,
                        contentLineHeight: 1.4,
                        showHeader: false,
                        showActions: false,
                        showReplies: false,
                        disableAvatarProfileTap: true,
                        onViewMoreTap: () => _openDiscussPage(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!hasDiscussContent) ...[
              const SizedBox(height: 8),
              DiscussPostInput(
                bizId: origin.oid,
                onSubmitted: () => unawaited(controller.refreshFirstPage()),
              ),
            ],
          ],
        );
      },
    );
  }
}

List<Widget> _originInitialDialogueSlivers(
  OriginDetail origin,
  _OriginInitialDialoguePreview preview,
) {
  final style = kLocationChatStyle.copyWith(
    headerTitleTextStyle: kLocationChatStyle.headerTitleTextStyle.copyWith(
      color: const Color(0xFF111111),
    ),
    headerTitleIconColor: const Color(0xFF111111),
    senderNameTextStyle: kLocationChatStyle.senderNameTextStyle.copyWith(
      color: const Color(0xFF111111),
    ),
  );
  final padding = style.messageListPadding;
  final brief = _originWorldoBrief(origin);
  return <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey<String>('origin-opening-location'),
        padding: EdgeInsets.fromLTRB(
          padding.left,
          brief.isEmpty ? 6 : 0,
          padding.right,
          8,
        ),
        child: Row(
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
                style: style.headerTitleTextStyle.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    ),
    SliverPadding(
      key: const ValueKey<String>('origin-opening-dialogue'),
      padding: EdgeInsets.fromLTRB(
        padding.left,
        0,
        padding.right,
        originDetailSectionGapForTesting,
      ),
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
          return ChatMessageRow(
            key: ValueKey<String>(message.localId),
            message: message,
            showDateDivider: false,
            style: messageStyle,
          );
        },
      ),
    ),
  ];
}

List<Widget> _originWorldoBriefSlivers(OriginDetail origin) {
  final brief = _originWorldoBrief(origin);
  if (brief.isEmpty) return const <Widget>[];
  final padding = kLocationChatStyle.messageListPadding;
  return <Widget>[
    SliverToBoxAdapter(
      child: Padding(
        key: const ValueKey<String>('origin-opening-worldo-brief'),
        padding: EdgeInsets.fromLTRB(
          padding.left,
          6,
          padding.right,
          originDetailSectionGapForTesting,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  MyFlutterApp.eye,
                  key: ValueKey<String>('origin-opening-worldo-brief-icon'),
                  size: 14,
                  color: Color(0xFFFF2442),
                ),
                SizedBox(width: originDetailSectionTitleIconGapForTesting),
                Flexible(
                  child: Text(
                    'Worldo Brief',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              brief,
              key: const ValueKey<String>('origin-opening-worldo-brief-body'),
              style: _bodyTextStyle.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  ];
}

String _originRoleCardAvatarUrl(BuildContext context, String sourceUrl) {
  return selectGenesisImageUrl(
    sourceUrl,
    logicalWidth: _OriginSetupRoleSection._cardWidth,
    logicalHeight: _OriginSetupRoleSection._cardWidth,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  ).trim();
}
