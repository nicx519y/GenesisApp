import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/discuss/discuss_page_comment_list.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/page_header.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';

const String _postDetailLikeFilledAsset =
    'assets/custom-icons/png/discuss_like_filled.png';
const String _postDetailLikeOutlineAsset =
    'assets/custom-icons/png/discuss_like_outline.png';
const String _postDetailReplyAsset =
    'assets/custom-icons/png/discuss_reply.png';
const double _postInputReservedHeight = 96;
const TextStyle _postDetailMetaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);
const TextStyle _postDetailNameStyle = TextStyle(
  color: Color(0xFF666666),
  fontSize: 14,
  height: 1.18,
  fontWeight: FontWeight.w600,
);
const TextStyle _postDetailBodyStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 14,
  height: 1.45,
  fontWeight: FontWeight.w400,
);

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
    return null;
  }

  void _loadInitialRepliesIfNeeded() {
    if (_initialRepliesRequested) return;
    final item = widget.item;
    if (item == null || item.replyRootDiscussId.trim().isEmpty) return;
    _initialRepliesRequested = true;
    unawaited(_loadInitialReplies(item.replyRootDiscussId));
  }

  Future<void> _loadInitialReplies(String rootDiscussId) async {
    try {
      final data = await AppServicesScope.read(context).api.v1.discuss.replies(
        rootDiscussId: rootDiscussId,
        pn: 1,
        rn: originDiscussRepliesPageSize,
      );
      final page = OriginDiscussRepliesPage.fromJson(data);
      final loaded = _controller.seedRepliesPage(
        rootDiscussId: rootDiscussId,
        page: page,
      );
      if (!loaded && mounted) showGenesisToast(context, 'Load replies failed');
    } catch (_) {
      if (mounted) showGenesisToast(context, 'Load replies failed');
    }
  }

  Future<void> _loadMoreReplies(OriginDiscussListItem item) async {
    try {
      await _controller.loadMoreReplies(
        rootDiscussId: item.replyRootDiscussId,
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

  Future<void> _openReplyComposer(
    OriginDiscussListItem item, {
    Map<String, dynamic>? reply,
  }) async {
    final replyToName = reply == null ? '' : _replyAuthorName(reply);
    await showOriginDiscussReplyComposer(
      context: context,
      controller: _controller,
      item: item,
      parentDiscussId: reply == null ? null : asString(reply['discuss_id']),
      replyToUid: reply == null ? null : _replyAuthorUid(reply),
      replyToUsername: reply == null ? null : replyToName,
      placeholder: replyToName.trim().isEmpty
          ? 'Write a reply'
          : 'Reply to $replyToName',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Post Detail'),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final item = _currentItem;
          if (item == null) {
            return widget.item == null
                ? const Center(child: Text('Post unavailable'))
                : const Center(child: CircularProgressIndicator());
          }

          final bottomPadding =
              _postInputReservedHeight + GenesisSafeAreaInsets.bottom(context);
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
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEDEDED),
                      ),
                    ),
                    _PostDetailReplies(
                      controller: _controller,
                      item: item,
                      onReplyTap: (reply) =>
                          unawaited(_openReplyComposer(item, reply: reply)),
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

  String _replyAuthorUid(Map<String, dynamic> reply) {
    final author = reply['author'] is Map ? asJsonMap(reply['author']) : null;
    return asString(author?['uid'], fallback: asString(reply['uid']));
  }

  String _replyAuthorName(Map<String, dynamic> reply) {
    final author = reply['author'] is Map ? asJsonMap(reply['author']) : null;
    final uid = _replyAuthorUid(reply);
    return asString(
      author?['name'] ??
          author?['user_name'] ??
          author?['nickname'] ??
          author?['display_name'] ??
          reply['author_name'] ??
          reply['user_name'],
      fallback: formatUidForDisplay(uid, fallback: 'User'),
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
    return DiscussPagePostRow(
      controller: controller,
      item: item,
      showReplyPreview: false,
      onItemReplyTap: (_) => onReplyTap(),
    );
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
  final void Function(Map<String, dynamic> reply) onReplyTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final replyCount = math.max(item.replyCount, item.latestReplies.length);
    final isInitialReplyLoading =
        item.latestReplies.isEmpty && controller.isReplyLoading(item.discussId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Replies $replyCount',
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        if (isInitialReplyLoading)
          const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          for (final entry in item.latestReplies.indexed) ...[
            _PostReplyRow(
              controller: controller,
              reply: entry.$2,
              onReplyTap: () => onReplyTap(entry.$2),
            ),
            if (entry.$1 != item.latestReplies.length - 1)
              const SizedBox(height: 28),
          ],
        if (!isInitialReplyLoading && controller.hasMoreReplies(item)) ...[
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
                          color: Color(0xFF2F4F7A),
                          fontSize: 12,
                          height: 1.25,
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
  const _PostReplyRow({
    required this.controller,
    required this.reply,
    required this.onReplyTap,
  });

  final OriginDiscussListController controller;
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
              SizedBox(
                width: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              data.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _postDetailNameStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DiscussStoryBadge(count: data.storyCount),
                        ],
                      ),
                    ),
                    if (data.dateLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(data.dateLabel, style: _postDetailMetaStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                _replyDisplayContentSpan(reply),
                style: _postDetailBodyStyle,
              ),
              if (data.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PostImageGrid(urls: data.imageUrls),
              ],
              const SizedBox(height: 8),
              _ReplyActionRow(
                controller: controller,
                discussId: data.discussId,
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
    required this.controller,
    required this.discussId,
    required this.likeCount,
    required this.replyCount,
    required this.isLiked,
    required this.onReplyTap,
  });

  final OriginDiscussListController controller;
  final String discussId;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final VoidCallback onReplyTap;

  @override
  Widget build(BuildContext context) {
    final normalizedDiscussId = discussId.trim();
    final likePending = controller.isLikePending(normalizedDiscussId);
    final activeColor = isLiked
        ? const Color(0xFFFF2442)
        : const Color(0xFF7D8178);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          key: ValueKey('post-detail-reply-like-$normalizedDiscussId'),
          behavior: HitTestBehavior.opaque,
          onTap: likePending ? null : () => _toggleLike(context),
          child: _PostDetailActionCluster(
            iconAsset: isLiked
                ? _postDetailLikeFilledAsset
                : _postDetailLikeOutlineAsset,
            count: likeCount,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onReplyTap,
          child: _PostDetailActionCluster(
            iconAsset: _postDetailReplyAsset,
            count: replyCount,
            color: _postDetailMetaStyle.color ?? const Color(0xFF8B8B8B),
          ),
        ),
        const Spacer(),
        GenesisMoreActionMenuButton(
          key: ValueKey('post-detail-reply-report-$normalizedDiscussId'),
          buttonSize: 28,
          iconSize: 18,
          items: [
            genesisReportMenuItem(
              context: context,
              targetType: 'discuss',
              targetId: normalizedDiscussId,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final normalizedDiscussId = discussId.trim();
    if (normalizedDiscussId.isEmpty ||
        controller.isLikePending(normalizedDiscussId)) {
      return;
    }
    if (!await ensureGenesisLogin(context)) return;
    if (!context.mounted) return;

    final previousLiked = isLiked;
    final previousCount = likeCount;
    final nextLiked = !previousLiked;
    final nextCount = previousLiked ? previousCount - 1 : previousCount + 1;

    controller.applyLikeState(
      discussId: normalizedDiscussId,
      isLiked: nextLiked,
      likeCount: nextCount,
    );
    controller.setLikePending(normalizedDiscussId, true);
    try {
      final api = AppServicesScope.read(context).api.v1.discuss;
      if (nextLiked) {
        await api.like(discussId: normalizedDiscussId);
      } else {
        await api.unlike(discussId: normalizedDiscussId);
      }
    } catch (_) {
      controller.applyLikeState(
        discussId: normalizedDiscussId,
        isLiked: previousLiked,
        likeCount: previousCount,
      );
      if (context.mounted) showGenesisToast(context, 'Like failed');
    } finally {
      controller.setLikePending(normalizedDiscussId, false);
    }
  }
}

class _PostDetailActionCluster extends StatelessWidget {
  const _PostDetailActionCluster({
    required this.iconAsset,
    required this.count,
    required this.color,
  });

  static const double _iconSize = 15;

  final String iconAsset;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 10, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            iconAsset,
            width: _iconSize,
            height: _iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostDetailCommentBar extends StatelessWidget {
  const _PostDetailCommentBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey<String>('post-detail-comment-input-bar'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Write a reply',
                style: TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
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
      size: 40,
      borderRadius: GenesisAvatarRadii.user,
    );
    if (data.authorUid.trim().isEmpty || data.authorDeleted) return avatar;
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
  const _PostImageGrid({required this.urls});

  static const int _maxVisibleImages = 6;
  static const double _imageSize = 80;
  static const double _imageGap = 6;

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final visibleUrls = urls.take(_maxVisibleImages).toList(growable: false);
    return Wrap(
      spacing: _imageGap,
      runSpacing: _imageGap,
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
              width: _imageSize,
              height: _imageSize,
              borderRadius: GenesisImageRadii.content,
            ),
          ),
      ],
    );
  }
}

class _ReplyViewData {
  const _ReplyViewData({
    required this.discussId,
    required this.authorUid,
    required this.authorDeleted,
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
      discussId: asString(json['discuss_id']),
      authorUid: uid,
      authorDeleted: entityDeleted(author?['deleted']),
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

  final String discussId;
  final String authorUid;
  final bool authorDeleted;
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

TextSpan _replyDisplayContentSpan(Map<String, dynamic> json) {
  final content = asString(json['content']);
  final parentDiscussId = asString(json['parent_discuss_id']).trim();
  final rootDiscussId = asString(json['root_discuss_id']).trim();
  final replyToUid = asString(json['reply_to_uid']).trim();
  final replyToUsername = asString(json['reply_to_username']).trim();
  final replyToName = replyToUsername.isNotEmpty ? replyToUsername : replyToUid;
  if (parentDiscussId.isEmpty ||
      rootDiscussId.isEmpty ||
      parentDiscussId == rootDiscussId ||
      replyToName.isEmpty) {
    return TextSpan(text: content);
  }
  return TextSpan(
    children: [
      TextSpan(
        text: '@$replyToName ',
        style: const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xFF4B6192),
        ),
      ),
      TextSpan(text: content),
    ],
  );
}

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
