import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/page_header.dart';

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
                    OriginDiscussList(
                      controller: _controller,
                      showHeader: false,
                      collapseInitialItems: false,
                      enableViewMore: false,
                      showActions: true,
                      showReplies: false,
                      onItemReplyTap: (target) =>
                          unawaited(_openReplyComposer(target)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
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
                child: ColoredBox(
                  key: const ValueKey<String>('post-detail-post-input-bar'),
                  color: const Color(0xFFF9F9F9),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: DiscussPostInput(
                        bizId: item.bizId,
                        placeholder: 'Write a reply',
                        title: 'Reply',
                        submitter: (content, images) async {
                          await submitOriginDiscussReply(
                            context: context,
                            controller: _controller,
                            item: item,
                            content: content,
                            images: images,
                          );
                          return const <String, dynamic>{};
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
  final VoidCallback onReplyTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final replyCount = math.max(item.replyCount, item.latestReplies.length);
    final replies = _replyCommentItems(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Replies $replyCount',
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (item.latestReplies.isEmpty &&
            controller.isReplyLoading(item.discussId))
          const Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          for (final entry in replies.indexed) ...[
            OriginDiscussCommentRow(
              key: ValueKey('post-detail-reply-${entry.$2.discussId}'),
              controller: controller,
              item: entry.$2,
              showActions: true,
              showReplies: false,
              onItemReplyTap: (_) => onReplyTap(),
            ),
            if (entry.$1 != replies.length - 1) const SizedBox(height: 32),
          ],
          if (controller.hasMoreReplies(item)) ...[
            if (replies.isNotEmpty) const SizedBox(height: 12),
            _PostDetailRepliesLoadMore(
              item: item,
              controller: controller,
              onLoadMore: onLoadMore,
            ),
          ],
        ],
      ],
    );
  }

  List<OriginDiscussListItem> _replyCommentItems(OriginDiscussListItem root) {
    return root.latestReplies
        .map((reply) {
          final data = Map<String, dynamic>.from(reply);
          if ((data['biz_id']?.toString().trim() ?? '').isEmpty) {
            data['biz_id'] = root.bizId;
          }
          return OriginDiscussListItem.fromJson(data);
        })
        .toList(growable: false);
  }
}

class _PostDetailRepliesLoadMore extends StatelessWidget {
  const _PostDetailRepliesLoadMore({
    required this.item,
    required this.controller,
    required this.onLoadMore,
  });

  final OriginDiscussListItem item;
  final OriginDiscussListController controller;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final isLoading = controller.isReplyLoading(item.discussId);
    return Center(
      child: GestureDetector(
        key: ValueKey('post-detail-load-more-${item.discussId}'),
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : onLoadMore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'View all ${controller.replyButtonCount(item)} replies',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF888888),
                  ),
                ),
        ),
      ),
    );
  }
}
