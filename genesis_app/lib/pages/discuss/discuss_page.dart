import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/page_header.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';

class DiscussPage extends StatefulWidget {
  const DiscussPage({super.key, required this.oid, this.originId = 0});

  final String oid;
  final int originId;

  @override
  State<DiscussPage> createState() => _DiscussPageState();
}

class _DiscussPageState extends State<DiscussPage> {
  static const double _loadMoreThreshold = 600;
  static const double _postInputReservedHeight = 96;

  late final OriginDiscussListController _discussController;
  final ScrollController _scrollController = ScrollController();
  Future<OriginDetail>? _future;
  OriginDetail? _origin;

  @override
  void initState() {
    super.initState();
    _discussController = OriginDiscussListController();
    _scrollController.addListener(_handleScroll);
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
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _discussController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > _loadMoreThreshold) return;
    unawaited(_discussController.loadNextPage());
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
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Discuss'),
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
              _postInputReservedHeight + MediaQuery.paddingOf(context).bottom;
          return Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 18, 20, bottomPadding),
                    children: [
                      _DiscussOriginSummary(origin: data),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFEDEDED),
                        ),
                      ),
                      OriginDiscussList(
                        controller: _discussController,
                        showHeader: false,
                        collapseInitialItems: false,
                        enableViewMore: false,
                        showActions: true,
                        showReplies: true,
                        imageTapOpensViewer: true,
                        onItemReplyTap: _openPostDetail,
                        onReplyTap: _handleReplyListItemTap,
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  key: const ValueKey<String>('discuss-page-post-input-bar'),
                  color: const Color(0xFFF9F9F9),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: DiscussPostInput(
                        bizId: data.oid,
                        onSubmitted: () =>
                            unawaited(_discussController.refreshFirstPage()),
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
    Map<String, dynamic> _,
  ) => _openPostDetail(item);

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
}

class _DiscussPageLoadingSkeleton extends StatelessWidget {
  const _DiscussPageLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return _DiscussLoadingShimmer(
      child: ListView(
        key: const ValueKey<String>('discuss-page-loading-skeleton'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: const [
          _DiscussOriginSummarySkeleton(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
          ),
          _DiscussCommentSkeleton(),
          SizedBox(height: 22),
          _DiscussCommentSkeleton(),
          SizedBox(height: 22),
          _DiscussCommentSkeleton(compact: true),
        ],
      ),
    );
  }
}

class _DiscussOriginSummarySkeleton extends StatelessWidget {
  const _DiscussOriginSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DiscussSkeletonBone(
          width: 48,
          height: 48,
          borderRadius: GenesisImageRadii.contentValue,
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussSkeletonBone(widthFactor: 0.48, height: 14),
              SizedBox(height: 8),
              _DiscussSkeletonBone(widthFactor: 0.86, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscussCommentSkeleton extends StatelessWidget {
  const _DiscussCommentSkeleton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DiscussSkeletonBone(
          width: 30,
          height: 30,
          borderRadius: GenesisAvatarRadii.user,
        ),
        const SizedBox(width: 10),
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
          ? _decoratedBox(0)
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) => _decoratedBox(animation.value),
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

  Widget _decoratedBox(double animationValue) {
    final offset = -1.4 + animationValue * 2.8;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.8, 0),
          end: Alignment(offset + 0.8, 0),
          colors: const [
            Color(0xFFE8EBF0),
            Color(0xFFF6F7F9),
            Color(0xFFE8EBF0),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _OriginCover(url: origin.mapImage),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                originDisplayName(origin.name, fallback: origin.oid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F4F7A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'OID: ${origin.oid}${originator.isEmpty ? '' : ' · Originator: $originator'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8B8B8B),
                ),
              ),
            ],
          ),
        ),
      ],
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
      imageUrl: imageUrl,
      width: 48,
      height: 48,
      borderRadius: GenesisImageRadii.content,
    );
  }
}
