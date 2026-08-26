part of 'origin_discuss_library.dart';

class OriginDiscussCommentRow extends StatefulWidget {
  const OriginDiscussCommentRow({
    super.key,
    required this.controller,
    required this.item,
    required this.showActions,
    required this.showReplies,
    required this.imageTapOpensViewer,
    this.disableAvatarProfileTap = false,
    this.contentLineHeight = 1.45,
    this.onAuthorTap,
    this.onViewMoreTap,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final bool showActions;
  final bool showReplies;
  final bool imageTapOpensViewer;
  final bool disableAvatarProfileTap;
  final double contentLineHeight;
  final OriginDiscussItemTap? onAuthorTap;
  final Future<void> Function()? onViewMoreTap;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  State<OriginDiscussCommentRow> createState() =>
      _OriginDiscussCommentRowState();
}

class _OriginDiscussCommentRowState extends State<OriginDiscussCommentRow> {
  static const double _progressPrefetchExtent = 600;

  ScrollPosition? _scrollPosition;
  bool _viewportCheckScheduled = false;
  bool _progressRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollPosition();
      _scheduleViewportCheck();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollPosition();
    _scheduleViewportCheck();
  }

  @override
  void didUpdateWidget(covariant OriginDiscussCommentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.discussId != widget.item.discussId ||
        oldWidget.item.authorUid != widget.item.authorUid ||
        oldWidget.item.bizId != widget.item.bizId) {
      _progressRequested = false;
    }
    _attachScrollPosition();
    _scheduleViewportCheck();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    super.dispose();
  }

  void _attachScrollPosition() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_handleScroll);
  }

  void _handleScroll() {
    _scheduleViewportCheck();
  }

  void _scheduleViewportCheck() {
    if (_progressRequested || _viewportCheckScheduled) return;
    _viewportCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewportCheckScheduled = false;
      _maybeLoadProgress();
    });
  }

  void _maybeLoadProgress() {
    if (_progressRequested) return;
    if (!_isInOrNearViewport()) return;
    if (!widget.controller.hasProgressTarget(widget.item)) return;
    _progressRequested = true;
    final api = AppServicesScope.read(context).api.v1.world;
    unawaited(
      widget.controller.loadProgressForItem(
        item: widget.item,
        loader: ({required uid, required originId}) {
          return api.originProgress(uid: uid, originId: originId);
        },
      ),
    );
  }

  bool _isInOrNearViewport() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return true;

    final rowRenderObject = context.findRenderObject();
    final viewportRenderObject = scrollable.context.findRenderObject();
    if (rowRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !rowRenderObject.hasSize ||
        !viewportRenderObject.hasSize) {
      return false;
    }

    final rowTop = rowRenderObject
        .localToGlobal(Offset.zero, ancestor: viewportRenderObject)
        .dy;
    final rowBottom = rowTop + rowRenderObject.size.height;
    return rowBottom >= -_progressPrefetchExtent &&
        rowTop <= viewportRenderObject.size.height + _progressPrefetchExtent;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscussAvatarLink(
          item: widget.item,
          disabled: widget.disableAvatarProfileTap,
          onTap: widget.onAuthorTap,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussPreviewMeta(
                item: widget.item,
                disabled: widget.disableAvatarProfileTap,
                onAuthorTap: widget.onAuthorTap,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onItemReplyTap == null
                    ? null
                    : () => widget.onItemReplyTap!(widget.item),
                child: Text(
                  widget.item.content,
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    height: widget.contentLineHeight,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (widget.item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DiscussImageThumbnails(
                  urls: widget.item.imageUrls,
                  onTap: (index) => _handleImageTap(context, index),
                ),
              ],
              if (widget.showActions) ...[
                const SizedBox(height: 12),
                _DiscussActions(
                  controller: widget.controller,
                  item: widget.item,
                  onReplyTap: widget.onItemReplyTap,
                ),
              ],
              if (widget.showReplies &&
                  (widget.item.latestReplies.isNotEmpty ||
                      widget.controller.hasMoreReplies(widget.item))) ...[
                const SizedBox(height: 12),
                _DiscussReplyPreview(
                  controller: widget.controller,
                  item: widget.item,
                  onReplyTap: widget.onReplyTap,
                  onViewAllTap: widget.onViewAllRepliesTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleImageTap(BuildContext context, int index) {
    if (widget.imageTapOpensViewer) {
      showGenesisImageViewer(
        context,
        imageUrls: widget.item.imageUrls,
        previewImageProviders: [
          for (final url in widget.item.imageUrls)
            genesisImageViewerListPreviewProvider(
              context,
              source: url,
              logicalWidth: _DiscussImageThumbnail.size,
              logicalHeight: _DiscussImageThumbnail.size,
            ),
        ],
        initialIndex: index,
      );
      return;
    }
    final itemHandler = widget.onItemReplyTap;
    if (itemHandler != null) {
      itemHandler(widget.item);
      return;
    }
    final viewMoreHandler = widget.onViewMoreTap;
    if (viewMoreHandler != null) {
      unawaited(viewMoreHandler());
    }
  }
}

class _DiscussImageThumbnails extends StatelessWidget {
  const _DiscussImageThumbnails({required this.urls, required this.onTap});

  final List<String> urls;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in urls.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _DiscussImageThumbnail(
                url: entry.$2,
                onTap: () => onTap(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscussActions extends StatelessWidget {
  const _DiscussActions({
    required this.controller,
    required this.item,
    this.onReplyTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final OriginDiscussItemTap? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final likePending = controller.isLikePending(item.discussId);
    final activeColor = item.isLiked
        ? const Color(0xFFFF2442)
        : const Color(0xFF7D8178);
    return Row(
      children: [
        GestureDetector(
          key: ValueKey('origin-discuss-like-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: likePending ? null : () => _toggleLike(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              item.isLiked ? _discussLikeFilledAsset : _discussLikeOutlineAsset,
              width: 21,
              height: 21,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${item.likeCount}',
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          key: ValueKey('origin-discuss-reply-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final handler = onReplyTap;
            if (handler != null) {
              handler(item);
              return;
            }
            unawaited(
              showOriginDiscussReplyComposer(
                context: context,
                controller: controller,
                item: item,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              _discussReplyAsset,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${item.replyCount}',
          style: _subtleStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final discussId = item.discussId.trim();
    if (discussId.isEmpty || controller.isLikePending(discussId)) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!context.mounted) return;

    final previousLiked = item.isLiked;
    final previousCount = item.likeCount;
    final nextLiked = !previousLiked;
    final nextCount = previousLiked ? previousCount - 1 : previousCount + 1;

    controller.applyLikeState(
      discussId: discussId,
      isLiked: nextLiked,
      likeCount: nextCount,
    );
    controller.setLikePending(discussId, true);
    try {
      final api = AppServicesScope.read(context).api.v1.discuss;
      if (nextLiked) {
        await api.like(discussId: discussId);
      } else {
        await api.unlike(discussId: discussId);
      }
    } catch (_) {
      controller.applyLikeState(
        discussId: discussId,
        isLiked: previousLiked,
        likeCount: previousCount,
      );
      if (context.mounted) showGenesisToast(context, 'Like failed');
    } finally {
      controller.setLikePending(discussId, false);
    }
  }
}

class _DiscussReplyPreview extends StatelessWidget {
  const _DiscussReplyPreview({
    required this.controller,
    required this.item,
    this.onReplyTap,
    this.onViewAllTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    final hasLoadedReplies = controller.hasLoadedReplies(item.discussId);
    final replies = hasLoadedReplies
        ? item.latestReplies
        : item.latestReplies.take(2).toList(growable: false);
    return OriginDiscussRepliesList(
      discussId: item.discussId,
      replies: replies,
      remainingReplyCount: controller.replyButtonCount(item),
      isLoading: controller.isReplyLoading(item.discussId),
      onLoadMore: () {
        final viewAllHandler = onViewAllTap;
        if (viewAllHandler != null) {
          viewAllHandler(item);
          return;
        }
        unawaited(_loadMoreReplies(context));
      },
      onReplyTap: onReplyTap == null
          ? null
          : (reply) => onReplyTap!(item, reply),
    );
  }

  Future<void> _loadMoreReplies(BuildContext context) async {
    try {
      await controller.loadMoreReplies(
        rootDiscussId: item.replyRootDiscussId,
        loader: ({required rootDiscussId, required pn, required rn}) async {
          final data = await AppServicesScope.read(context).api.v1.discuss
              .replies(rootDiscussId: rootDiscussId, pn: pn, rn: rn);
          return OriginDiscussRepliesPage.fromJson(data);
        },
      );
    } catch (_) {
      if (context.mounted) showGenesisToast(context, 'Load replies failed');
    }
  }
}
