import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/discuss/discuss_page_comment_list.dart';
import '../../components/discuss/genesis_discuss_theme.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';

class DiscussPage extends StatefulWidget {
  const DiscussPage({super.key, required this.oid, this.originId = 0});

  final String oid;
  final int originId;

  @override
  State<DiscussPage> createState() => _DiscussPageState();
}

class _DiscussPageState extends State<DiscussPage> {
  static const double _loadMoreThreshold = 600;
  static const double _loadMoreDragDistance = 48;
  static const double _postInputReservedHeight = 96;

  late final OriginDiscussListController _discussController;
  final ScrollController _scrollController = ScrollController();
  Future<OriginDetail>? _future;
  OriginDetail? _origin;
  double _downwardDragDistance = 0;

  @override
  void initState() {
    super.initState();
    _discussController = OriginDiscussListController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOriginDetail();
  }

  @override
  void didUpdateWidget(covariant DiscussPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      _origin = null;
      _future = _loadOriginDetail();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _discussController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification) {
      _downwardDragDistance = 0;
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.dragDetails == null) return false;
    final delta = notification.scrollDelta;
    if (delta == null || delta <= 0) return false;
    _downwardDragDistance += delta;
    if (_downwardDragDistance < _loadMoreDragDistance) return false;
    if (notification.metrics.extentAfter > _loadMoreThreshold) return false;
    _downwardDragDistance = 0;
    unawaited(_discussController.loadNextPage());
    return false;
  }

  Future<OriginDetail> _loadOriginDetail({
    bool forceDiscussRefresh = false,
  }) async {
    final api = AppServicesScope.read(context).api;
    final origin = await api.getOrigin(widget.oid);
    if (!mounted) return origin;
    _origin = origin;
    _discussController.configure(
      oid: origin.oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
    if (forceDiscussRefresh) {
      await _discussController.refreshFirstPage();
    } else {
      await _discussController.loadInitialIfNeeded();
    }
    return origin;
  }

  Future<void> _refresh() async {
    final future = _loadOriginDetail(forceDiscussRefresh: true);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final origin = _origin;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: context.genesisColors.pageBackground,
      appBar: _DiscussPageAppBar(controller: _discussController),
      body: FutureBuilder<OriginDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              origin == null) {
            return const _DiscussPageLoadingSkeleton();
          }

          if (snapshot.hasError && origin == null) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _future = _loadOriginDetail();
                }),
                child: const Text('Retry'),
              ),
            );
          }

          final data = snapshot.data ?? origin;
          if (data == null) return const SizedBox.shrink();

          final bottomPadding =
              _postInputReservedHeight + GenesisSafeAreaInsets.bottom(context);
          return Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
                      children: [
                        _DiscussOriginSummary(origin: data),
                        DiscussPageCommentList(
                          controller: _discussController,
                          onItemReplyTap: _openReplyComposer,
                          onReplyTap: _handleReplyListItemTap,
                          onViewAllRepliesTap: _openPostDetail,
                        ),
                        AnimatedBuilder(
                          animation: _discussController,
                          builder: (context, _) {
                            if (!_discussController.isLoadingMore) {
                              return const SizedBox.shrink();
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KeyedSubtree(
                  key: const ValueKey<String>('discuss-page-post-input-bar'),
                  child: SafeArea(
                    top: false,
                    child: ColoredBox(
                      color: context.genesisColors.pageBackground,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.only(top: 14, bottom: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: context.genesisColors.foregroundStrong
                                    .withValues(alpha: 0.14),
                                width: 1,
                              ),
                            ),
                          ),
                          child: DiscussPostInput(
                            key: const ValueKey<String>(
                              'discuss-page-post-input',
                            ),
                            bizId: data.oid,
                            compact: true,
                            showCurrentUserAvatar: true,
                            onSubmitted: () => unawaited(
                              _discussController.refreshFirstPage(),
                            ),
                          ),
                        ),
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

  void _handleReplyListItemTap(
    OriginDiscussListItem item,
    Map<String, dynamic> reply,
  ) => _openReplyComposerForReply(item, reply);

  void _openReplyComposer(OriginDiscussListItem item) {
    unawaited(
      showOriginDiscussReplyComposer(
        context: context,
        controller: _discussController,
        item: item,
      ),
    );
  }

  void _openReplyComposerForReply(
    OriginDiscussListItem item,
    Map<String, dynamic> reply,
  ) {
    unawaited(
      showOriginDiscussReplyComposer(
        context: context,
        controller: _discussController,
        item: item,
        parentDiscussId: asString(reply['discuss_id']),
        replyToUid: _replyAuthorUid(reply),
        replyToUsername: _replyAuthorName(reply),
      ),
    );
  }

  void _openPostDetail(OriginDiscussListItem item) {
    unawaited(
      Navigator.of(context)
          .pushNamed(
            RouteNames.postDetail,
            arguments: {'item': item, 'oid': item.bizId},
          )
          .then((_) {
            if (!mounted) return;
            unawaited(_discussController.refreshFirstPage());
          }),
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

class _DiscussPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _DiscussPageAppBar({required this.controller});

  final OriginDiscussListController controller;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final colors = context.genesisColors;
        return AppBar(
          toolbarHeight: preferredSize.height,
          backgroundColor: colors.pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                key: const ValueKey<String>('discuss-page-back-button'),
                dimension: 34,
                child: IconButton(
                  tooltip: 'Back',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.foregroundStrong.withValues(
                      alpha: 0.07,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: colors.foregroundStrong,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          titleSpacing: 0,
          title: Text(
            'Comments',
            key: const ValueKey<String>('discuss-page-title'),
            style: TextStyle(
              color: colors.foregroundStrong,
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (controller.hasLoaded)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Text(
                    '${controller.totalAll}',
                    key: const ValueKey<String>('discuss-page-comment-count'),
                    style: TextStyle(
                      color: colors.foregroundStrong.withValues(alpha: 0.50),
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DiscussPageLoadingSkeleton extends StatelessWidget {
  const _DiscussPageLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return _DiscussLoadingShimmer(
      child: ListView(
        key: const ValueKey<String>('discuss-page-loading-skeleton'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const _DiscussOriginSummarySkeleton(),
          const _DiscussCommentSkeleton(),
          const _DiscussCommentSkeleton(),
          const _DiscussCommentSkeleton(compact: true),
        ],
      ),
    );
  }
}

class _DiscussOriginSummarySkeleton extends StatelessWidget {
  const _DiscussOriginSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DiscussSkeletonBone(width: 44, height: 66, borderRadius: 9),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DiscussSkeletonBone(widthFactor: 0.48, height: 14),
                SizedBox(height: 8),
                _DiscussSkeletonBone(widthFactor: 0.86, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussCommentSkeleton extends StatelessWidget {
  const _DiscussCommentSkeleton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.14,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DiscussSkeletonBone(width: 34, height: 34, borderRadius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DiscussSkeletonBone(widthFactor: 0.34, height: 12),
                const SizedBox(height: 10),
                const _DiscussSkeletonBone(widthFactor: 0.96, height: 10),
                const SizedBox(height: 7),
                _DiscussSkeletonBone(
                  widthFactor: compact ? 0.58 : 0.82,
                  height: 10,
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    _DiscussSkeletonBone(width: 42, height: 12),
                    SizedBox(width: 16),
                    _DiscussSkeletonBone(width: 46, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussLoadingShimmer extends StatefulWidget {
  const _DiscussLoadingShimmer({required this.child});

  final Widget child;

  @override
  State<_DiscussLoadingShimmer> createState() => _DiscussLoadingShimmerState();
}

class _DiscussLoadingShimmerState extends State<_DiscussLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DiscussSkeletonAnimation(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _DiscussSkeletonAnimation extends InheritedWidget {
  const _DiscussSkeletonAnimation({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_DiscussSkeletonAnimation>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(covariant _DiscussSkeletonAnimation oldWidget) {
    return animation != oldWidget.animation;
  }
}

class _DiscussSkeletonBone extends StatelessWidget {
  const _DiscussSkeletonBone({
    this.width,
    this.widthFactor,
    required this.height,
    this.borderRadius = 4,
  }) : assert(width == null || widthFactor == null);

  final double? width;
  final double? widthFactor;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _DiscussSkeletonAnimation.maybeOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    Widget child = SizedBox(
      width: width,
      height: height,
      child: animation == null || disableAnimations
          ? _decoratedBox(context, 0)
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) =>
                  _decoratedBox(context, animation.value),
            ),
    );

    if (widthFactor case final factor?) {
      child = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: child,
      );
    }
    return child;
  }

  Widget _decoratedBox(BuildContext context, double animationValue) {
    final offset = -1.4 + animationValue * 2.8;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.8, 0),
          end: Alignment(offset + 0.8, 0),
          colors: [
            context.genesisColors.skeletonBase,
            context.genesisColors.skeletonHighlight,
            context.genesisColors.skeletonBase,
          ],
          stops: const [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}

class _DiscussOriginSummary extends StatelessWidget {
  const _DiscussOriginSummary({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final originator = formatUidForDisplay(origin.originator);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OriginCover(url: origin.mapImage),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${originDisplayName(origin.name, fallback: origin.oid)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: context.genesisDiscussColors.actionAccent,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'OID ${deletedAwareIdLabel(origin.oid, deleted: origin.deleted)}${originator.isEmpty ? '' : ' · Originator ${origin.ownerDeleted ? deletedEntityDisplayText : originator}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: context.genesisColors.foregroundStrong.withValues(
                      alpha: 0.62,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginCover extends StatelessWidget {
  const _OriginCover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveAssetUrl(url);
    return GenesisListImage(
      key: const ValueKey<String>('discuss-page-origin-cover'),
      imageUrl: imageUrl,
      width: 44,
      height: 66,
      borderRadius: BorderRadius.circular(9),
    );
  }
}
