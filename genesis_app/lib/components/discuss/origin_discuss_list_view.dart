part of 'origin_discuss_library.dart';

class OriginDiscussList extends StatelessWidget {
  const OriginDiscussList({
    super.key,
    required this.controller,
    this.count,
    this.showHeader = true,
    this.enableViewMore = true,
    this.collapseInitialItems = true,
    this.showActions = false,
    this.showReplies = false,
    this.imageTapOpensViewer = false,
    this.disableAvatarProfileTap = false,
    this.onAuthorTap,
    this.onViewMoreTap,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final int? count;
  final bool showHeader;
  final bool enableViewMore;
  final bool collapseInitialItems;
  final bool showActions;
  final bool showReplies;
  final bool imageTapOpensViewer;
  final bool disableAvatarProfileTap;
  final OriginDiscussItemTap? onAuthorTap;
  final Future<void> Function()? onViewMoreTap;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final comments = collapseInitialItems
            ? controller.visibleItems
            : controller.items;
        final shouldShowViewMore = collapseInitialItems
            ? controller.shouldShowViewMore
            : controller.hasMore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _DiscussHeader(count: count ?? controller.totalAll),
            if (controller.isInitialLoading && comments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (controller.error != null && comments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: TextButton(
                  onPressed: controller.retryInitial,
                  child: const Text('Retry'),
                ),
              )
            else if (comments.isEmpty)
              SizedBox(height: showHeader ? 12 : 0)
            else
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: Column(
                  children: [
                    for (final entry in comments.indexed) ...[
                      OriginDiscussCommentRow(
                        controller: controller,
                        item: entry.$2,
                        showActions: showActions,
                        showReplies: showReplies,
                        imageTapOpensViewer: imageTapOpensViewer,
                        disableAvatarProfileTap: disableAvatarProfileTap,
                        onAuthorTap: onAuthorTap,
                        onViewMoreTap: onViewMoreTap,
                        onItemReplyTap: onItemReplyTap,
                        onReplyTap: onReplyTap,
                        onViewAllRepliesTap: onViewAllRepliesTap,
                      ),
                      if (entry.$1 != comments.length - 1)
                        const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            if (enableViewMore && shouldShowViewMore) ...[
              const SizedBox(height: 16),
              _ViewMoreButton(
                controller: controller,
                onTap: collapseInitialItems
                    ? onViewMoreTap ?? controller.viewMore
                    : controller.loadNextPage,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ViewMoreButton extends StatelessWidget {
  const _ViewMoreButton({required this.controller, required this.onTap});

  final OriginDiscussListController controller;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        key: const ValueKey('origin-discuss-view-more'),
        behavior: HitTestBehavior.opaque,
        onTap: controller.isLoadingMore ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: controller.isLoadingMore
              ? const SizedBox.square(
                  key: ValueKey('origin-discuss-view-more-loading'),
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'View More >',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: context.genesisColors.textFaint,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DiscussHeader extends StatelessWidget {
  const _DiscussHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          discussIconAsset,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 6),
        Text(
          'Discuss (${formatStatCount(count)})',
          style: TextStyle(
            color: context.genesisColors.textPrimary,
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
