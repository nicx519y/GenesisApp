import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../auth/login_guard.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_image_viewer_overlay.dart';
import '../common/genesis_timestamp_text.dart';
import 'origin_discuss_list.dart';
import 'origin_discuss_replies_list.dart';
import 'story_badge.dart';

class DiscussPageCommentList extends StatelessWidget {
  const DiscussPageCommentList({
    super.key,
    required this.controller,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final comments = controller.items;
        if (controller.isInitialLoading && comments.isEmpty) {
          return const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (controller.error != null && comments.isEmpty) {
          return TextButton(
            onPressed: controller.retryInitial,
            child: const Text('Retry'),
          );
        }
        if (comments.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            for (final entry in comments.indexed) ...[
              _DiscussPageCommentRow(
                controller: controller,
                item: entry.$2,
                onItemReplyTap: onItemReplyTap,
                onReplyTap: onReplyTap,
                onViewAllRepliesTap: onViewAllRepliesTap,
              ),
              if (entry.$1 != comments.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _DiscussPageCommentRow extends StatefulWidget {
  const _DiscussPageCommentRow({
    required this.controller,
    required this.item,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  State<_DiscussPageCommentRow> createState() => _DiscussPageCommentRowState();
}

class _DiscussPageCommentRowState extends State<_DiscussPageCommentRow> {
  static const double _avatarSize = 40;
  static const double _avatarTextGap = 14;
  static const double _metaBodyGap = 8;
  static const double _bodyImageGap = 8;
  static const double _storyBadgeOffsetY = -2;
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
  void didUpdateWidget(covariant _DiscussPageCommentRow oldWidget) {
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
        _ProfileAvatarLink(item: widget.item),
        const SizedBox(width: _avatarTextGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussPageMeta(item: widget.item),
              const SizedBox(height: _metaBodyGap),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onItemReplyTap == null
                    ? null
                    : () => widget.onItemReplyTap!(widget.item),
                child: Text(
                  widget.item.content,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (widget.item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: _bodyImageGap),
                _DiscussPageImageThumbnails(
                  urls: widget.item.imageUrls,
                  onTap: (index) => showGenesisImageViewer(
                    context,
                    imageUrls: widget.item.imageUrls,
                    initialIndex: index,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _DiscussPageActions(
                controller: widget.controller,
                item: widget.item,
                onReplyTap: widget.onItemReplyTap,
              ),
              if (widget.item.latestReplies.isNotEmpty ||
                  widget.controller.hasMoreReplies(widget.item)) ...[
                const SizedBox(height: 12),
                _DiscussPageReplyPreview(
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
}

class _DiscussPageMeta extends StatelessWidget {
  const _DiscussPageMeta({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final tappableMeta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            item.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              height: 1.18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Transform.translate(
          offset: const Offset(
            0,
            _DiscussPageCommentRowState._storyBadgeOffsetY,
          ),
          child: DiscussStoryBadge(count: item.storyCount),
        ),
      ],
    );
    final canOpenProfile =
        item.authorUid.trim().isNotEmpty && !item.authorDeleted;

    return SizedBox(
      key: ValueKey('discuss-page-meta-${item.discussId}'),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: canOpenProfile
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openProfile(context, item),
                    child: tappableMeta,
                  )
                : tappableMeta,
          ),
          if (item.createdAt != null) ...[
            const SizedBox(width: 8),
            GenesisTimestampText(timestamp: item.createdAt, style: _timeStyle),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatarLink extends StatelessWidget {
  const _ProfileAvatarLink({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final avatar = GenesisAvatar(
      url: item.avatar.trim(),
      name: item.authorName,
      size: _DiscussPageCommentRowState._avatarSize,
      borderRadius: GenesisAvatarRadii.user,
    );
    if (item.authorUid.trim().isEmpty || item.authorDeleted) return avatar;
    return GestureDetector(
      key: ValueKey('discuss-page-avatar-${item.authorUid}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProfile(context, item),
      child: avatar,
    );
  }
}

class _DiscussPageImageThumbnails extends StatelessWidget {
  const _DiscussPageImageThumbnails({required this.urls, required this.onTap});

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
              child: GestureDetector(
                key: ValueKey('discuss-page-image-${entry.$2}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(entry.$1),
                child: GenesisListImage(
                  imageUrl: entry.$2.trim(),
                  width: 48,
                  height: 48,
                  borderRadius: GenesisImageRadii.content,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscussPageActions extends StatelessWidget {
  const _DiscussPageActions({
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
        ? const Color(0xFFF42C47)
        : const Color(0xFF7D8178);
    return Row(
      children: [
        GestureDetector(
          key: ValueKey('discuss-page-like-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: likePending ? null : () => _toggleLike(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              _discussLikeFilledOrOutline(item.isLiked),
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
          key: ValueKey('discuss-page-reply-${item.discussId}'),
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
          style: _timeStyle.copyWith(fontWeight: FontWeight.w600),
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

class _DiscussPageReplyPreview extends StatelessWidget {
  const _DiscussPageReplyPreview({
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

void _openProfile(BuildContext context, OriginDiscussListItem item) {
  Navigator.of(
    context,
  ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.authorUid});
}

String _discussLikeFilledOrOutline(bool isLiked) {
  return isLiked
      ? 'assets/custom-icons/png/discuss_like_filled.png'
      : 'assets/custom-icons/png/discuss_like_outline.png';
}

const String _discussReplyAsset = 'assets/custom-icons/png/discuss_reply.png';

const _timeStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);
