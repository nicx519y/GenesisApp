// ignore_for_file: use_key_in_widget_constructors

part of 'world_sections_library.dart';

class WorldTickPendingEventPage extends StatelessWidget {
  const WorldTickPendingEventPage({required this.tickNumber});

  final int tickNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatTickHeader(label: 'Tick $tickNumber', style: kLocationChatStyle),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey<String>('world-event-pending-tombstone'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          decoration: BoxDecoration(
            color: GenesisColors.darkRaisedBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorldTickPendingSkeletonLine(widthFactor: 0.28, height: 10),
              SizedBox(height: 12),
              WorldTickPendingSkeletonLine(widthFactor: 0.92),
              SizedBox(height: 8),
              WorldTickPendingSkeletonLine(widthFactor: 0.76),
              SizedBox(height: 18),
              WorldTickPendingSkeletonLine(widthFactor: 0.34, height: 10),
              SizedBox(height: 12),
              WorldTickPendingSkeletonLine(widthFactor: 0.86),
              SizedBox(height: 8),
              WorldTickPendingSkeletonLine(widthFactor: 0.58),
            ],
          ),
        ),
      ],
    );
  }
}

class WorldTickPendingSkeletonLine extends StatelessWidget {
  const WorldTickPendingSkeletonLine({
    required this.widthFactor,
    this.height = 12,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GenesisColors.darkFaintFill,
          borderRadius: BorderRadius.circular(4),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class WorldTickEventCardPage extends StatefulWidget {
  const WorldTickEventCardPage({
    super.key,
    this.scrollController,
    this.child,
    this.itemCount,
    this.itemBuilder,
    this.alignLastItemToTop = false,
    required this.resetRevision,
    required this.hasTopEdgePage,
    required this.hasBottomEdgePage,
    required this.padding,
    required this.onTurnPage,
  }) : assert(
         child != null || (itemCount != null && itemBuilder != null),
         'Provide child or itemCount/itemBuilder.',
       ),
       assert(
         child == null || (itemCount == null && itemBuilder == null),
         'child and itemCount/itemBuilder are mutually exclusive.',
       ),
       assert(itemCount == null || itemCount >= 0);

  final ScrollController? scrollController;
  final Widget? child;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final bool alignLastItemToTop;
  final int resetRevision;
  final bool hasTopEdgePage;
  final bool hasBottomEdgePage;
  final EdgeInsetsGeometry padding;
  final ValueChanged<int> onTurnPage;

  @override
  State<WorldTickEventCardPage> createState() => WorldTickEventCardPageState();
}

class WorldTickEventCardPageState extends State<WorldTickEventCardPage> {
  static const double _turnDragThreshold = 56;
  static const double _edgeArrowMinSize = 18;
  static const double _edgeArrowMaxSize = 24;

  late ScrollController _scrollController;
  late bool _ownsScrollController;
  final GlobalKey _lastItemCenterKey = GlobalKey();
  var _startAligned = false;
  var _dragDeltaY = 0.0;
  var _dragStartedAtTop = true;
  var _dragStartedAtBottom = true;
  var _topPullDistance = 0.0;
  var _bottomPullDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _setScrollController(_effectiveExternalController);
  }

  @override
  void didUpdateWidget(covariant WorldTickEventCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetRevision != widget.resetRevision) {
      _startAligned = false;
      _syncScrollController();
      _jumpScrollToTop();
    } else {
      _syncScrollController();
    }
  }

  bool get _alignLastItemToTop =>
      !_startAligned &&
      widget.alignLastItemToTop &&
      widget.itemBuilder != null &&
      (widget.itemCount ?? 0) > 0;

  ScrollController? get _effectiveExternalController {
    // A centered viewport puts earlier sub-ticks at negative offsets. The
    // sheet controller treats pixels <= 0 as a request to resize the sheet,
    // so keep those offsets on a regular controller until the actual start.
    if (_alignLastItemToTop && (widget.itemCount ?? 0) > 1) return null;
    return widget.scrollController;
  }

  void _syncScrollController() {
    final next = _effectiveExternalController;
    if (next == _scrollController || (next == null && _ownsScrollController)) {
      return;
    }
    final previous = _scrollController;
    final ownedPrevious = _ownsScrollController;
    _setScrollController(next);
    if (ownedPrevious) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        widget.scrollController == null ||
        !_alignLastItemToTop ||
        !_ownsScrollController ||
        notification.metrics.extentBefore > 0) {
      return false;
    }
    // Rebase at the real beginning: offset zero now means the first item,
    // allowing the next downward drag to collapse the sheet normally.
    setState(() {
      _startAligned = true;
      _syncScrollController();
    });
    _jumpScrollToTop();
    return false;
  }

  @override
  void dispose() {
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  void _setScrollController(ScrollController? controller) {
    _ownsScrollController = controller == null;
    _scrollController =
        controller ??
        _WorldTickScrollController(
          trailingExtent: () {
            if (!_alignLastItemToTop) return null;
            final sliver = _lastItemCenterKey.currentContext
                ?.findRenderObject();
            return sliver is RenderSliver
                ? sliver.geometry?.scrollExtent
                : null;
          },
        );
  }

  void _jumpScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        0.0.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  bool get _atTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentBefore <= 0;
  }

  bool get _atBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter <= 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!mounted) return;
    _dragDeltaY = 0;
    _dragStartedAtTop = _atTop;
    _dragStartedAtBottom = _atBottom;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted) return;
    _dragDeltaY += event.delta.dy;
    _setEdgePullDistance(
      top: _dragStartedAtTop && widget.hasTopEdgePage
          ? math.max(0, _dragDeltaY)
          : 0,
      bottom: _dragStartedAtBottom && widget.hasBottomEdgePage
          ? math.max(0, -_dragDeltaY)
          : 0,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!mounted) return;
    final dragDeltaY = _dragDeltaY;
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
    if (dragDeltaY <= -_turnDragThreshold && _dragStartedAtBottom) {
      widget.onTurnPage(1);
    } else if (widget.scrollController == null &&
        dragDeltaY >= _turnDragThreshold &&
        _dragStartedAtTop) {
      widget.onTurnPage(-1);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!mounted) return;
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _setEdgePullDistance({required double top, required double bottom}) {
    if (!mounted) return;
    final nextTop = top.clamp(0, _turnDragThreshold).toDouble();
    final nextBottom = bottom.clamp(0, _turnDragThreshold).toDouble();
    if (nextTop == _topPullDistance && nextBottom == _bottomPullDistance) {
      return;
    }
    setState(() {
      _topPullDistance = nextTop;
      _bottomPullDistance = nextBottom;
    });
  }

  Widget _buildEdgeArrow({
    required bool top,
    required double pullDistance,
    required IconData icon,
    required Key key,
  }) {
    if (pullDistance <= 0) {
      return const SizedBox.shrink();
    }
    final progress = (pullDistance / _turnDragThreshold).clamp(0.0, 1.0);
    final iconSize =
        _edgeArrowMinSize +
        ((_edgeArrowMaxSize - _edgeArrowMinSize) * progress);
    final offset = 6 + (8 * progress);
    return Positioned(
      top: top ? offset : null,
      bottom: top ? null : offset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.3 + (0.7 * progress),
          child: Align(
            alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
            child: Icon(
              icon,
              key: key,
              size: iconSize,
              color: GenesisColors.darkTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignLastItemToTop = _alignLastItemToTop;
    return NotificationListener<ScrollEndNotification>(
      onNotification: _handleScrollEnd,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomScrollView(
                controller: _scrollController,
                center: alignLastItemToTop ? _lastItemCenterKey : null,
                physics: WorldTickCardScrollPhysics(
                  allowLeadingOverscroll: widget.hasTopEdgePage,
                  allowTrailingOverscroll: widget.hasBottomEdgePage,
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: alignLastItemToTop
                    ? _buildLastItemCenteredSlivers(context)
                    : [
                        SliverPadding(
                          padding: widget.padding,
                          sliver: widget.itemBuilder == null
                              ? SliverToBoxAdapter(child: widget.child)
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    widget.itemBuilder!,
                                    childCount: widget.itemCount,
                                  ),
                                ),
                        ),
                      ],
              ),
            ),
            _buildEdgeArrow(
              top: true,
              pullDistance: _topPullDistance,
              icon: Icons.keyboard_arrow_down_rounded,
              key: const ValueKey<String>('world-event-top-edge-arrow'),
            ),
            _buildEdgeArrow(
              top: false,
              pullDistance: _bottomPullDistance,
              icon: Icons.keyboard_arrow_up_rounded,
              key: const ValueKey<String>('world-event-bottom-edge-arrow'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLastItemCenteredSlivers(BuildContext context) {
    final itemBuilder = widget.itemBuilder!;
    final itemCount = widget.itemCount!;
    final resolvedPadding = widget.padding.resolve(Directionality.of(context));
    return [
      if (itemCount > 1)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            resolvedPadding.left,
            resolvedPadding.top,
            resolvedPadding.right,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => itemBuilder(context, itemCount - index - 2),
              childCount: itemCount - 1,
            ),
          ),
        ),
      SliverPadding(
        key: _lastItemCenterKey,
        padding: EdgeInsets.fromLTRB(
          resolvedPadding.left,
          resolvedPadding.top,
          resolvedPadding.right,
          resolvedPadding.bottom,
        ),
        sliver: SliverToBoxAdapter(child: itemBuilder(context, itemCount - 1)),
      ),
    ];
  }
}

// The centered sliver keeps the latest item cheap to locate in long histories.
// Its default maximum offset is at least zero, even when that would leave a
// viewport-sized gap after a short last item. Bound scrolling by real content.
class _WorldTickScrollController extends ScrollController {
  _WorldTickScrollController({required this.trailingExtent})
    : super(keepScrollOffset: false);

  final double? Function() trailingExtent;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _WorldTickScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    trailingExtent: trailingExtent,
  );
}

class _WorldTickScrollPosition extends ScrollPositionWithSingleContext {
  _WorldTickScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.trailingExtent,
  }) : super(keepScrollOffset: false);

  final double? Function() trailingExtent;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final trailing = trailingExtent();
    return super.applyContentDimensions(
      minScrollExtent,
      trailing == null
          ? maxScrollExtent
          : math.max(
              minScrollExtent,
              math.min(maxScrollExtent, trailing - viewportDimension),
            ),
    );
  }
}

class WorldTickCardScrollPhysics extends BouncingScrollPhysics {
  const WorldTickCardScrollPhysics({
    required this.allowLeadingOverscroll,
    required this.allowTrailingOverscroll,
    super.parent,
  });

  final bool allowLeadingOverscroll;
  final bool allowTrailingOverscroll;

  @override
  WorldTickCardScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WorldTickCardScrollPhysics(
      allowLeadingOverscroll: allowLeadingOverscroll,
      allowTrailingOverscroll: allowTrailingOverscroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  double frictionFactor(double overscrollFraction) {
    return super.frictionFactor(overscrollFraction) * 0.5;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!allowLeadingOverscroll &&
        value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (!allowTrailingOverscroll &&
        position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

const TextStyle _worldEventContentLabelStyle = TextStyle(
  fontSize: 13,
  height: 1.3,
  fontWeight: FontWeight.w600,
  color: GenesisColors.darkTextPrimary,
);

const TextStyle _worldEventContentTextStyle = TextStyle(
  fontSize: 13,
  height: 1.3,
  fontWeight: FontWeight.w400,
  color: GenesisColors.darkTextSecondary,
);

const TextStyle _worldEventContentTimestampStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: GenesisColors.darkTextSecondary,
);

String? worldTickParagraphTimestamp(Map<String, dynamic> tick) {
  final result = tick['tick_result'];
  if (result is! Map) return null;
  final paragraphs = result['paragraphs'];
  if (paragraphs is! List) return null;
  for (final paragraph in paragraphs) {
    if (paragraph is! Map) continue;
    final timestamp = '${paragraph['timestamp'] ?? ''}'.trim();
    if (timestamp.isNotEmpty) return formatGenesisTimestamp(timestamp);
  }
  return null;
}

class WorldEventsLoadingMoreIndicator extends StatelessWidget {
  const WorldEventsLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: GenesisColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}
