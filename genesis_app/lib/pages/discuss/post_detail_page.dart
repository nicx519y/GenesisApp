import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_timestamp_text.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/page_header.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_timestamp_formatter.dart';

const String _postDetailLikeFilledAsset =
    'assets/custom-icons/png/discuss_like_filled.png';
const String _postDetailLikeOutlineAsset =
    'assets/custom-icons/png/discuss_like_outline.png';
const String _postDetailReplyAsset =
    'assets/custom-icons/png/discuss_reply.png';
const double _postInputReservedHeight = 96;

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.item});

  final OriginDiscussListItem? item;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final OriginDiscussListController _controller;
  bool _initialRepliesRequested = false;

  @override
  void initState() {
    super.initState();
    _controller = OriginDiscussListController();
    final item = widget.item;
    if (item != null) _controller.seedSingleItem(item);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInitialRepliesIfNeeded();
  }

  @override
  void didUpdateWidget(covariant PostDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final item = widget.item;
    if (item?.discussId == oldWidget.item?.discussId) return;
    _initialRepliesRequested = false;
    if (item != null) _controller.seedSingleItem(item);
    _loadInitialRepliesIfNeeded();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  OriginDiscussListItem? get _currentItem {
    final items = _controller.items;
    if (items.isNotEmpty) return items.first;
    return widget.item;
  }

  void _loadInitialRepliesIfNeeded() {
    if (_initialRepliesRequested) return;
    final item = _currentItem;
    if (item == null || item.discussId.trim().isEmpty) return;
    _initialRepliesRequested = true;
    unawaited(_loadMoreReplies(item));
  }

  Future<void> _loadMoreReplies(OriginDiscussListItem item) async {
    try {
      await _controller.loadMoreReplies(
        rootDiscussId: item.discussId,
        loader: ({required rootDiscussId, required pn, required rn}) async {
          final data = await AppServicesScope.read(context).api.v1.discuss
              .replies(rootDiscussId: rootDiscussId, pn: pn, rn: rn);
          return OriginDiscussRepliesPage.fromJson(data);
        },
      );
    } catch (_) {
      if (mounted) showGenesisToast(context, 'Load replies failed');
    }
  }

  Future<void> _openReplyComposer(OriginDiscussListItem item) async {
    await showOriginDiscussReplyComposer(
      context: context,
      controller: _controller,
      item: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Post Detail'),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final item = _currentItem;
          if (item == null) {
            return const Center(child: Text('Post unavailable'));
          }

          final bottomPadding =
              _postInputReservedHeight + MediaQuery.paddingOf(context).bottom;
          return Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                  children: [
                    _PostDetailRoot(
                      controller: _controller,
                      item: item,
                      onReplyTap: () => unawaited(_openReplyComposer(item)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 26),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEDEDED),
                      ),
                    ),
                    _PostDetailReplies(
                      controller: _controller,
                      item: item,
                      onReplyTap: () => unawaited(_openReplyComposer(item)),
                      onLoadMore: () => unawaited(_loadMoreReplies(item)),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PostDetailCommentBar(
                  onTap: () => unawaited(_openReplyComposer(item)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostDetailRoot extends StatelessWidget {
  const _PostDetailRoot({
    required this.controller,
    required this.item,
    required this.onReplyTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostAvatarLink(
          item: item,
          size: 48,
          borderRadius: GenesisAvatarRadii.user,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostHeaderMeta(item: item),
              const SizedBox(height: 26),
              Text(
                item.content,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 22),
                _PostImageGrid(urls: item.imageUrls),
              ],
              const SizedBox(height: 22),
              _PostActionRow(
                controller: controller,
                item: item,
                onReplyTap: onReplyTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostHeaderMeta extends StatelessWidget {
  const _PostHeaderMeta({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (item.createdAt != null)
              GenesisTimestampText(
                timestamp: item.createdAt,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            DiscussStoryBadge(count: item.storyCount),
            if (item.worldId.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pushNamed(
                    RouteNames.world,
                    arguments: {'wid': item.worldId},
                  ),
                  child: Text(
                    'WID: ${item.worldId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _postMetaStyle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PostActionRow extends StatelessWidget {
  const _PostActionRow({
    required this.controller,
    required this.item,
    required this.onReplyTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final likePending = controller.isLikePending(item.discussId);
    final activeColor = item.isLiked
        ? const Color(0xFFF42C47)
        : const Color(0xFF7D8178);
    return Row(
      children: [
        GestureDetector(
          key: ValueKey('post-detail-like-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: likePending ? null : () => _toggleLike(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              item.isLiked
                  ? _postDetailLikeFilledAsset
                  : _postDetailLikeOutlineAsset,
              width: 21,
              height: 21,
              fit: BoxFit.contain,
              opacity: likePending
                  ? const AlwaysStoppedAnimation<double>(0.55)
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${item.likeCount}',
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 34),
        GestureDetector(
          key: ValueKey('post-detail-reply-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: onReplyTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              _postDetailReplyAsset,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text('${item.replyCount}', style: _postMetaStyle),
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

    controller.setLikePending(discussId, true);
    controller.applyLikeState(
      discussId: discussId,
      isLiked: nextLiked,
      likeCount: nextCount,
    );
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

class _PostDetailReplies extends StatelessWidget {
  const _PostDetailReplies({
    required this.controller,
    required this.item,
    required this.onReplyTap,
    required this.onLoadMore,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final VoidCallback onReplyTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final replyCount = math.max(item.replyCount, item.latestReplies.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Replies $replyCount',
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        if (item.latestReplies.isEmpty &&
            controller.isReplyLoading(item.discussId))
          const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          for (final entry in item.latestReplies.indexed) ...[
            _PostReplyRow(reply: entry.$2, onReplyTap: onReplyTap),
            if (entry.$1 != item.latestReplies.length - 1)
              const SizedBox(height: 28),
          ],
        if (controller.hasMoreReplies(item)) ...[
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              key: ValueKey('post-detail-load-more-${item.discussId}'),
              behavior: HitTestBehavior.opaque,
              onTap: controller.isReplyLoading(item.discussId)
                  ? null
                  : onLoadMore,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: controller.isReplyLoading(item.discussId)
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'View all ${controller.replyButtonCount(item)} replies',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PostReplyRow extends StatelessWidget {
  const _PostReplyRow({required this.reply, required this.onReplyTap});

  final Map<String, dynamic> reply;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final data = _ReplyViewData.fromJson(reply);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReplyAvatarLink(data: data),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1D1D1D),
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (data.dateLabel.isNotEmpty)
                    Text(data.dateLabel, style: _postMetaStyle),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  DiscussStoryBadge(count: data.storyCount),
                  if (data.worldId.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'WID: ${data.worldId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _postMetaStyle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Text(
                data.content,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (data.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PostImageGrid(urls: data.imageUrls, minTileSize: 56),
              ],
              const SizedBox(height: 16),
              _ReplyActionRow(
                likeCount: data.likeCount,
                replyCount: data.replyCount,
                isLiked: data.isLiked,
                onReplyTap: onReplyTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplyActionRow extends StatelessWidget {
  const _ReplyActionRow({
    required this.likeCount,
    required this.replyCount,
    required this.isLiked,
    required this.onReplyTap,
  });

  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          isLiked ? _postDetailLikeFilledAsset : _postDetailLikeOutlineAsset,
          width: 21,
          height: 21,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 7),
        Text('$likeCount', style: _postMetaStyle),
        const SizedBox(width: 34),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReplyTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              _postDetailReplyAsset,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text('$replyCount', style: _postMetaStyle),
      ],
    );
  }
}

class _PostDetailCommentBar extends StatelessWidget {
  const _PostDetailCommentBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey<String>('post-detail-comment-input-bar'),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 58,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Add a comment',
                style: TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostAvatarLink extends StatelessWidget {
  const _PostAvatarLink({
    required this.item,
    required this.size,
    required this.borderRadius,
  });

  final OriginDiscussListItem item;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final avatar = GenesisAvatar(
      url: item.avatar.trim(),
      name: item.authorName,
      size: size,
      borderRadius: borderRadius,
    );
    if (item.authorUid.trim().isEmpty) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.authorUid}),
      child: avatar,
    );
  }
}

class _ReplyAvatarLink extends StatelessWidget {
  const _ReplyAvatarLink({required this.data});

  final _ReplyViewData data;

  @override
  Widget build(BuildContext context) {
    final avatar = GenesisAvatar(
      url: data.avatar,
      name: data.authorName,
      size: 52,
      borderRadius: GenesisAvatarRadii.user,
    );
    if (data.authorUid.trim().isEmpty) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.userInfo, arguments: {'uid': data.authorUid}),
      child: avatar,
    );
  }
}

class _PostImageGrid extends StatelessWidget {
  const _PostImageGrid({required this.urls, this.minTileSize = 72});

  final List<String> urls;
  final double minTileSize;

  @override
  Widget build(BuildContext context) {
    final visibleUrls = urls.take(6).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 288.0;
        final tileSize = ((maxWidth - 16) / 3).clamp(minTileSize, 112.0);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in visibleUrls.indexed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showGenesisImageViewer(
                  context,
                  imageUrls: urls,
                  initialIndex: entry.$1,
                ),
                child: GenesisListImage(
                  imageUrl: entry.$2,
                  width: tileSize,
                  height: tileSize,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReplyViewData {
  const _ReplyViewData({
    required this.authorUid,
    required this.authorName,
    required this.avatar,
    required this.content,
    required this.worldId,
    required this.storyCount,
    required this.likeCount,
    required this.replyCount,
    required this.isLiked,
    required this.imageUrls,
    required this.dateLabel,
  });

  factory _ReplyViewData.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map ? asJsonMap(json['author']) : null;
    final uid = asString(author?['uid'], fallback: asString(json['uid']));
    final name = asString(
      author?['name'] ??
          author?['user_name'] ??
          author?['nickname'] ??
          author?['display_name'] ??
          json['author_name'] ??
          json['user_name'],
      fallback: formatUidForDisplay(uid, fallback: 'User'),
    );
    return _ReplyViewData(
      authorUid: uid,
      authorName: formatUidForDisplay(name, fallback: 'User'),
      avatar: asImageUrl(author?['avatar'] ?? author?['avatar_url']),
      content: asString(json['content']),
      worldId: asString(
        json['world_id'],
        fallback: asString(
          json['wid'],
          fallback: asString(json['display_wid_str']),
        ),
      ),
      storyCount: asInt(
        json['story_cnt'],
        fallback: asInt(json['tick_cnt'], fallback: asInt(json['connect_cnt'])),
      ),
      likeCount: asInt(json['like_cnt'], fallback: asInt(json['like_count'])),
      replyCount: asInt(json['reply_cnt']),
      isLiked: asBool(json['is_liked']),
      imageUrls: _imageUrlsFrom(json['images'] ?? json['image_urls']),
      dateLabel: formatGenesisDateTime(_parseDateTime(json['created_at'])),
    );
  }

  final String authorUid;
  final String authorName;
  final String avatar;
  final String content;
  final String worldId;
  final int storyCount;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final List<String> imageUrls;
  final String dateLabel;
}

const _postMetaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 14,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

List<String> _imageUrlsFrom(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
  if (value is! List) return const <String>[];
  return value
      .map((raw) {
        if (raw is Map) {
          final map = asJsonMap(raw);
          return asImageUrl(
            map['url'] ?? map['image_url'] ?? map['image'],
            fallback: raw,
          );
        }
        return asString(raw);
      })
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}
