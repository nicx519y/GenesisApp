part of 'origin_world_page.dart';

const int _originOpeningPageIndex = 0;
const int _originInfoPageIndex = 1;

const _originDetailSheetBorderRadius = mapDetailSheetBorderRadius;

BoxDecoration _originDetailSheetDecoration(BuildContext context) {
  return mapDetailSheetDecoration(context);
}

class _OriginDetailDraggableSheet extends StatefulWidget {
  const _OriginDetailDraggableSheet({
    required this.origin,
    required this.minChildSize,
    required this.collapseRequest,
    required this.expandRequest,
    required this.requestedPage,
    required this.pageRequest,
    required this.onPageChanged,
    required this.autoExpansionPending,
    required this.onRaisedChanged,
    required this.onFullyExpanded,
    required this.onAutoExpansionInterrupted,
    required this.onOriginChanged,
    required this.launching,
    required this.profileRole,
    required this.onSelectRole,
    required this.onSelectProfileRole,
    required this.onEditProfileRole,
    required this.onCustomizeRole,
    required this.onLaunch,
  });

  static const double defaultInitialChildSize = 0.22;

  final OriginDetail origin;
  final double minChildSize;
  final int collapseRequest;
  final int expandRequest;
  final int requestedPage;
  final int pageRequest;
  final ValueChanged<int> onPageChanged;
  final bool autoExpansionPending;
  final ValueChanged<bool> onRaisedChanged;
  final VoidCallback onFullyExpanded;
  final VoidCallback onAutoExpansionInterrupted;
  final VoidCallback onOriginChanged;
  final bool launching;
  final OriginCustomRoleDraft? profileRole;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final VoidCallback onEditProfileRole;
  final VoidCallback onCustomizeRole;
  final VoidCallback onLaunch;

  @override
  State<_OriginDetailDraggableSheet> createState() =>
      _OriginDetailDraggableSheetState();
}

class _OriginDetailDraggableSheetState
    extends State<_OriginDetailDraggableSheet> {
  static const double _absoluteMaxChildSize = 1.0;
  static const double _extentUpdateEpsilon = 0.001;
  static const int _extentSettleFrameCount = 2;
  static const _snapAnimationDuration = Duration(milliseconds: 260);
  static const _pageAnimationDuration = Duration(milliseconds: 260);

  late final DraggableScrollableController _sheetController;
  late final PageController _pageController;
  late final ScrollController _infoPreviewScrollController;
  late final ScrollController _openingPreviewScrollController;
  final Completer<void> _sheetReady = Completer<void>();
  ScrollController? _sheetScrollController;
  late _OriginInitialDialoguePreview? _initialDialoguePreview;
  var _isFullyExpanded = false;
  var _isRaised = false;
  var _extentCommandGeneration = 0;
  var _sheetReadyCheckScheduled = false;
  var _autoExpansionInterruptionScheduled = false;
  var _autoExpansionPaintCompletionScheduled = false;
  Timer? _extentSettleTimer;
  Completer<void>? _extentSettleCompleter;
  late int _currentPage;

  double get _minChildSize => widget.minChildSize.clamp(0.08, 0.42).toDouble();

  double get _effectiveInitialChildSize => _minChildSize;

  double _expandedChildSize(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight = viewportHeight;
    if (sheetHostHeight <= 0) return _minChildSize;
    final expandedTop = mapDetailSheetExpandedTop(context);
    return (1.0 - expandedTop / sheetHostHeight)
        .clamp(_minChildSize, _absoluteMaxChildSize)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _currentPage = widget.requestedPage.clamp(0, 1).toInt();
    _pageController = PageController(initialPage: _currentPage);
    _infoPreviewScrollController = ScrollController();
    _openingPreviewScrollController = ScrollController();
    _initialDialoguePreview = _originFirstInitialDialoguePreview(widget.origin);
    if (widget.expandRequest > 0) {
      _expandToMaxChildSize();
    }
  }

  @override
  void didUpdateWidget(covariant _OriginDetailDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.origin, widget.origin)) {
      _initialDialoguePreview = _originFirstInitialDialoguePreview(
        widget.origin,
      );
    }
    if (oldWidget.minChildSize != widget.minChildSize) {
      _syncRaisedStateAfterBuild();
    }
    if (oldWidget.collapseRequest != widget.collapseRequest) {
      _collapseToMinChildSize();
    } else if (oldWidget.expandRequest != widget.expandRequest) {
      _expandToMaxChildSize();
    }
    if (oldWidget.pageRequest != widget.pageRequest) {
      _showRequestedPage();
    }
  }

  @override
  void dispose() {
    _extentCommandGeneration += 1;
    _cancelExtentSettleWait();
    if (!_sheetReady.isCompleted) {
      _sheetReady.complete();
    }
    _sheetController.dispose();
    _pageController.dispose();
    _infoPreviewScrollController.dispose();
    _openingPreviewScrollController.dispose();
    super.dispose();
  }

  void _collapseToMinChildSize() {
    _cancelExtentSettleWait();
    final commandGeneration = ++_extentCommandGeneration;
    unawaited(
      _animateToRequestedExtent(
        commandGeneration: commandGeneration,
        expanded: false,
      ),
    );
  }

  void _showRequestedPage() {
    final requestedPage = widget.requestedPage.clamp(0, 1).toInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestedPage == _currentPage) return;
      if (!_pageController.hasClients) return;
      unawaited(
        _pageController.animateToPage(
          requestedPage,
          duration: _pageAnimationDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _selectPage(int page) {
    if (_currentPage == page) return;
    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    setState(() => _currentPage = page);
    widget.onPageChanged(page);
  }

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.horizontal ||
        !_pageController.hasClients) {
      return false;
    }
    _selectPage((_pageController.page ?? _currentPage).round());
    return false;
  }

  void _expandToMaxChildSize() {
    _requestExpandedExtent(revealOpeningRoleCards: false);
  }

  void _expandOpeningRoleCards() {
    _requestExpandedExtent(revealOpeningRoleCards: true);
  }

  void _handleCollapsedRoleDragStart(DragStartDetails details) {
    _cancelExtentSettleWait();
    _extentCommandGeneration += 1;
  }

  void _handleCollapsedRoleDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (viewportHeight <= 0) return;
    final nextExtent =
        (_sheetController.size - details.delta.dy / viewportHeight)
            .clamp(_minChildSize, _expandedChildSize(context))
            .toDouble();
    _sheetController.jumpTo(nextExtent);
  }

  void _handleCollapsedRoleDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final draggedUp = details.primaryVelocity != null
        ? details.primaryVelocity! < -200
        : false;
    final raisedEnough = _sheetController.size > _minChildSize + 0.04;
    if (draggedUp || raisedEnough) {
      _expandOpeningRoleCards();
    } else {
      _collapseToMinChildSize();
    }
  }

  void _handleCollapsedRoleDragCancel() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size > _minChildSize + 0.04) {
      _expandOpeningRoleCards();
    } else {
      _collapseToMinChildSize();
    }
  }

  void _requestExpandedExtent({required bool revealOpeningRoleCards}) {
    _cancelExtentSettleWait();
    final commandGeneration = ++_extentCommandGeneration;
    unawaited(
      revealOpeningRoleCards
          ? _expandAndRevealOpeningRoleCards(commandGeneration)
          : _animateToRequestedExtent(
              commandGeneration: commandGeneration,
              expanded: true,
            ),
    );
  }

  Future<void> _expandAndRevealOpeningRoleCards(int commandGeneration) async {
    await _animateToRequestedExtent(
      commandGeneration: commandGeneration,
      expanded: true,
    );
  }

  Future<void> _animateToRequestedExtent({
    required int commandGeneration,
    required bool expanded,
  }) async {
    final isAutomaticExpansion = expanded && widget.autoExpansionPending;
    await _sheetReady.future;
    if (!_isExtentCommandCurrent(commandGeneration) ||
        !_sheetController.isAttached) {
      _reportInterruptedAutomaticExpansion(isAutomaticExpansion);
      return;
    }

    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    if (!mounted) return;
    final targetExtent = expanded ? _expandedChildSize(context) : _minChildSize;
    if ((_sheetController.size - targetExtent).abs() > _extentUpdateEpsilon) {
      unawaited(
        _sheetController
            .animateTo(
              targetExtent,
              duration: _snapAnimationDuration,
              curve: Curves.easeOutCubic,
            )
            .catchError((Object error, StackTrace stackTrace) {
              if (_isExtentCommandCurrent(commandGeneration)) {
                debugPrint(
                  '[OriginWorldPage] detail sheet extent animation '
                  'interrupted: $error\n$stackTrace',
                );
              }
            }),
      );
      await _waitForExtentAnimation();
    }

    if (!_isExtentCommandCurrent(commandGeneration) ||
        !_sheetController.isAttached ||
        !mounted) {
      _reportInterruptedAutomaticExpansion(isAutomaticExpansion);
      return;
    }
    for (var frame = 0; frame < _extentSettleFrameCount; frame += 1) {
      _jumpToCurrentRequestedExtent(expanded: expanded);
      await _waitForNextFrame();
      if (!_isExtentCommandCurrent(commandGeneration) ||
          !_sheetController.isAttached ||
          !mounted) {
        _reportInterruptedAutomaticExpansion(isAutomaticExpansion);
        return;
      }
    }
    _jumpToCurrentRequestedExtent(expanded: expanded);
  }

  Future<void> _waitForExtentAnimation() {
    _cancelExtentSettleWait();
    final completer = Completer<void>();
    _extentSettleCompleter = completer;
    _extentSettleTimer = Timer(_snapAnimationDuration, () {
      if (!identical(_extentSettleCompleter, completer)) return;
      _extentSettleTimer = null;
      _extentSettleCompleter = null;
      completer.complete();
    });
    return completer.future;
  }

  void _cancelExtentSettleWait() {
    _extentSettleTimer?.cancel();
    _extentSettleTimer = null;
    final completer = _extentSettleCompleter;
    _extentSettleCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _reportInterruptedAutomaticExpansion(bool isAutomaticExpansion) {
    if (!isAutomaticExpansion ||
        !mounted ||
        !widget.autoExpansionPending ||
        _autoExpansionInterruptionScheduled) {
      return;
    }
    _autoExpansionInterruptionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoExpansionInterruptionScheduled = false;
      if (!mounted || !widget.autoExpansionPending) return;
      widget.onAutoExpansionInterrupted();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _jumpToCurrentRequestedExtent({required bool expanded}) {
    if (!mounted || !_sheetController.isAttached) return;
    final targetExtent = expanded ? _expandedChildSize(context) : _minChildSize;
    if ((_sheetController.size - targetExtent).abs() <= _extentUpdateEpsilon) {
      return;
    }
    _sheetController.jumpTo(targetExtent);
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.ensureVisualUpdate();
    return completer.future;
  }

  bool _isExtentCommandCurrent(int commandGeneration) {
    return mounted && commandGeneration == _extentCommandGeneration;
  }

  bool _handleSheetScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _extentCommandGeneration += 1;
      _cancelExtentSettleWait();
      _reportInterruptedAutomaticExpansion(widget.autoExpansionPending);
    }
    return false;
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    final maxChildSize = _expandedChildSize(context);
    final extent = notification.extent
        .clamp(_minChildSize, maxChildSize)
        .toDouble();
    final isFullyExpanded =
        (maxChildSize - extent).abs() <= _extentUpdateEpsilon;
    final isRaised = extent > _minChildSize + _extentUpdateEpsilon;
    _updateRaisedState(isRaised);
    if (isFullyExpanded && !_isFullyExpanded) {
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'worldo_detail_sheet',
        object1: widget.origin.oid,
      );
    }
    if (isFullyExpanded) {
      _scheduleAutomaticExpansionCompletionAfterPaint();
    }
    _isFullyExpanded = isFullyExpanded;
    return false;
  }

  void _scheduleAutomaticExpansionCompletionAfterPaint() {
    if (!widget.autoExpansionPending ||
        _autoExpansionPaintCompletionScheduled) {
      return;
    }
    final commandGeneration = _extentCommandGeneration;
    _autoExpansionPaintCompletionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoExpansionPaintCompletionScheduled = false;
      if (!mounted || !widget.autoExpansionPending) return;
      if (!_isExtentCommandCurrent(commandGeneration) ||
          !_sheetController.isAttached ||
          !_isAtExpandedExtent()) {
        _reportInterruptedAutomaticExpansion(true);
        return;
      }
      widget.onFullyExpanded();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _isAtExpandedExtent() {
    if (!mounted || !_sheetController.isAttached) return false;
    return (_sheetController.size - _expandedChildSize(context)).abs() <=
        _extentUpdateEpsilon;
  }

  void _syncRaisedStateAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetController.isAttached) return;
      _updateRaisedState(
        _sheetController.size > _minChildSize + _extentUpdateEpsilon,
      );
    });
  }

  void _updateRaisedState(bool isRaised) {
    if (isRaised == _isRaised) return;
    _isRaised = isRaised;
    widget.onRaisedChanged(isRaised);
  }

  void _handleSheetScrollControllerReady(ScrollController scrollController) {
    _sheetScrollController = scrollController;
    _scheduleSheetReadyCheck();
  }

  Widget _buildOpeningPage(
    ScrollController scrollController,
    _OriginInitialDialoguePreview? initialDialoguePreview,
  ) {
    return KeyedSubtree(
      key: const ValueKey<String>('origin-detail-sheet-page-Opening'),
      child: CustomScrollView(
        controller: scrollController,
        key: PageStorageKey<String>(
          'origin-detail-bottom-sheet-${widget.origin.oid}',
        ),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: const _OriginSheetHeaderDelegate(topPadding: 0),
          ),
          if (widget.autoExpansionPending)
            SliverFillRemaining(
              hasScrollBody: false,
              child: KeyedSubtree(
                key: const ValueKey<String>('origin-opening-sheet-tombstone'),
                child: initialDialoguePreview != null
                    ? const _OriginInitialDialogueLoadingContent()
                    : const _OriginRoleSetupLoadingContent(),
              ),
            )
          else ...[
            ..._originWorldoBriefSlivers(context, widget.origin),
            if (initialDialoguePreview != null)
              ..._originInitialDialogueSlivers(
                context,
                widget.origin,
                initialDialoguePreview,
              ),
            SliverToBoxAdapter(
              child: _OriginSetupRoleSection(
                characters: widget.origin.characters,
                launching: widget.launching,
                profileRole: widget.profileRole,
                onSelectRole: widget.onSelectRole,
                onSelectProfileRole: widget.onSelectProfileRole,
                onEditProfileRole: widget.onEditProfileRole,
                onCustomizeRole: widget.onCustomizeRole,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPage(ScrollController scrollController) {
    return _OriginIntroList(
      origin: widget.origin,
      topPadding: 0,
      onOriginChanged: widget.onOriginChanged,
      scrollController: scrollController,
      embeddedInSheet: true,
      onClose: _collapseToMinChildSize,
    );
  }

  /// Info 页的 Enter world 常驻底 bar:只有浮窗完全拉起后可见;
  /// 页面左右切换时它随 Info 页平移进出(不做渐隐)。
  Widget _buildInfoLaunchBar(double bottomInset) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sheetController, _pageController]),
      builder: (context, _) {
        final maxChildSize = _expandedChildSize(context);
        final extent = _sheetController.isAttached
            ? _sheetController.size
            : _minChildSize;
        final expandProgress = ((extent - (maxChildSize - 0.05)) / 0.05)
            .clamp(0.0, 1.0)
            .toDouble();
        final page = _pageController.hasClients
            ? _pageController.page ?? _currentPage.toDouble()
            : _currentPage.toDouble();
        final infoProgress = page.clamp(0.0, 1.0).toDouble();
        final interactive = expandProgress >= 0.99 && infoProgress >= 0.99;
        return IgnorePointer(
          key: const ValueKey<String>('origin-info-launch-bar-visibility'),
          ignoring: !interactive,
          child: Opacity(
            opacity: expandProgress,
            child: FractionalTranslation(
              translation: Offset(1.0 - infoProgress, 0),
              child: _OriginInfoLaunchBar(
                bottomInset: bottomInset,
                launching: widget.launching,
                onLaunch: widget.onLaunch,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedPageIndicator() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final page = _pageController.hasClients
            ? _pageController.page ?? _currentPage.toDouble()
            : _currentPage.toDouble();
        return _OriginSheetPageIndicator(page: page);
      },
    );
  }

  Widget _buildCollapsedOpeningRoleAction(double bottomInset) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sheetController, _pageController]),
      builder: (context, _) {
        final sheetExtent = _sheetController.isAttached
            ? _sheetController.size
            : _minChildSize;
        final raisedProgress = ((sheetExtent - _minChildSize) / 0.04)
            .clamp(0.0, 1.0)
            .toDouble();
        final page = _pageController.hasClients
            ? _pageController.page ?? _currentPage.toDouble()
            : _currentPage.toDouble();
        final openingProgress = (1.0 - page.clamp(0.0, 1.0)).toDouble();
        final opacity = ((1.0 - raisedProgress) * openingProgress)
            .clamp(0.0, 1.0)
            .toDouble();
        return IgnorePointer(
          key: const ValueKey<String>('origin-opening-select-role-visibility'),
          ignoring: opacity < 0.99,
          child: Opacity(
            opacity: opacity,
            child: _OriginCollapsedOpeningRoleAction(
              bottomInset: bottomInset,
              onTap: _expandOpeningRoleCards,
              onVerticalDragStart: _handleCollapsedRoleDragStart,
              onVerticalDragUpdate: _handleCollapsedRoleDragUpdate,
              onVerticalDragEnd: _handleCollapsedRoleDragEnd,
              onVerticalDragCancel: _handleCollapsedRoleDragCancel,
            ),
          ),
        );
      },
    );
  }

  void _scheduleSheetReadyCheck() {
    if (_sheetReady.isCompleted || _sheetReadyCheckScheduled) return;
    _sheetReadyCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetReadyCheckScheduled = false;
      if (!mounted) {
        if (!_sheetReady.isCompleted) _sheetReady.complete();
        return;
      }
      final scrollController = _sheetScrollController;
      if (_sheetController.isAttached &&
          scrollController != null &&
          scrollController.hasClients) {
        _sheetReady.complete();
        return;
      }
      _scheduleSheetReadyCheck();
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final minChildSize = _minChildSize;
    final maxChildSize = _expandedChildSize(context);
    final initialChildSize = _effectiveInitialChildSize
        .clamp(minChildSize, maxChildSize)
        .toDouble();
    final initialDialoguePreview = _initialDialoguePreview;
    return IgnorePointer(
      ignoring: widget.autoExpansionPending,
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: _handleSheetNotification,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleSheetScrollNotification,
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: initialChildSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            snap: true,
            snapAnimationDuration: _snapAnimationDuration,
            builder: (context, scrollController) {
              _handleSheetScrollControllerReady(scrollController);
              // 安全区只垫在内容页下面;底部两条覆盖层(Select your role /
              // Enter world)贴到浮窗物理底边,安全区改为它们的内边距,
              // 这样按钮不会浮得太高。
              final bottomInset = GenesisSafeAreaInsets.bottom(
                context,
                minimum: originWorldDetailBottomSafeAreaMinimum,
              );
              return DecoratedBox(
                key: const ValueKey<String>('origin-detail-sheet-surface'),
                decoration: _originDetailSheetDecoration(context),
                child: ClipRRect(
                  borderRadius: _originDetailSheetBorderRadius,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(overscroll: false),
                    child: Stack(
                      children: [
                        Padding(
                          key: const ValueKey<String>(
                            'origin-detail-bottom-safe-area',
                          ),
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: NotificationListener<ScrollEndNotification>(
                            onNotification: _handlePageScrollEnd,
                            child: PageView.builder(
                              key: const ValueKey<String>(
                                'origin-detail-sheet-pages',
                              ),
                              controller: _pageController,
                              itemCount: 2,
                              physics: const PageScrollPhysics(),
                              itemBuilder: (context, page) {
                                final pageScrollController =
                                    page == _currentPage
                                    ? scrollController
                                    : page == _originOpeningPageIndex
                                    ? _openingPreviewScrollController
                                    : _infoPreviewScrollController;
                                return page == _originOpeningPageIndex
                                    ? _buildOpeningPage(
                                        pageScrollController,
                                        initialDialoguePreview,
                                      )
                                    : _buildInfoPage(pageScrollController);
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: originDetailSheetHandleTopOffsetForTesting,
                          child: IgnorePointer(
                            child: _buildAnimatedPageIndicator(),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildCollapsedOpeningRoleAction(bottomInset),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildInfoLaunchBar(bottomInset),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OriginCollapsedOpeningRoleAction extends StatelessWidget {
  const _OriginCollapsedOpeningRoleAction({
    required this.bottomInset,
    required this.onTap,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
  });

  final double bottomInset;
  final VoidCallback onTap;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    // 设计稿的收起态浮窗高 300,这条 108 高、34% 实底的渐变条只在那种高度下
    // 才不碍事;实机收起高度更矮,长渐变会把下层正文半透出来,所以压矮并把
    // 实底段加长。贴着浮窗底边摆放,安全区收进内边距,免得整块浮得太高。
    return Container(
      height: 52 + bottomInset,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            colors.pageBackground,
            colors.pageBackground,
            colors.pageBackground.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: GestureDetector(
        key: const ValueKey<String>('origin-opening-select-role-action'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragStart: onVerticalDragStart,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        onVerticalDragCancel: onVerticalDragCancel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.string(
                '<svg viewBox="0 0 16 9"><path d="M1.5 7.5 L8 2 L14.5 7.5" fill="none" stroke="white" stroke-width="1.8" stroke-linecap="round"/></svg>',
                width: 14,
                height: 8,
                colorFilter: ColorFilter.mode(
                  colors.foregroundStrong.withValues(alpha: 0.55),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Select your role',
                style: TextStyle(
                  color: colors.foregroundStrong.withValues(alpha: 0.72),
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginIntroList extends StatefulWidget {
  const _OriginIntroList({
    required this.origin,
    required this.topPadding,
    required this.onOriginChanged,
    this.scrollController,
    this.embeddedInSheet = false,
    this.onClose,
  });

  final OriginDetail origin;
  final double topPadding;
  final VoidCallback onOriginChanged;
  final ScrollController? scrollController;
  final bool embeddedInSheet;
  final VoidCallback? onClose;

  @override
  State<_OriginIntroList> createState() => _OriginIntroListState();
}

class _OriginIntroListState extends State<_OriginIntroList> {
  late final OriginDiscussListController _discussController;
  var _currentUid = '';

  @override
  void initState() {
    super.initState();
    _discussController = OriginDiscussListController();
    _configureDiscuss();
    unawaited(_discussController.loadInitialIfNeeded());
    unawaited(_loadCurrentUid());
  }

  @override
  void didUpdateWidget(covariant _OriginIntroList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin.oid != widget.origin.oid) {
      _configureDiscuss();
      unawaited(_discussController.refreshFirstPage());
      unawaited(_loadCurrentUid());
    }
  }

  @override
  void dispose() {
    _discussController.dispose();
    super.dispose();
  }

  void _configureDiscuss() {
    _discussController.configure(
      oid: widget.origin.oid,
      loader: ({required String oid, required int pn, required int rn}) =>
          loadOriginDiscussPage(context, oid, pn: pn, rn: rn),
    );
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.read(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _OriginSheetHeaderContent(
        origin: widget.origin,
        currentUid: _currentUid,
        onOriginChanged: widget.onOriginChanged,
        showPageHeading: false,
        showStandaloneHeaderActions: !widget.embeddedInSheet,
      ),
      const SizedBox(height: originDetailSectionGapForTesting),
      _WorldViewSection(origin: widget.origin),
    ];
    if (_originPreviewTick(widget.origin) case final tick?) {
      children.addAll([
        const SizedBox(height: originDetailSectionGapForTesting),
        _LaunchPreviewSection(origin: widget.origin, previewTick: tick),
      ]);
    }
    children.addAll([
      const SizedBox(height: originDetailSectionGapForTesting),
      _DiscussSection(origin: widget.origin, controller: _discussController),
      const SizedBox(height: originDetailSectionGapForTesting),
      _OriginCharactersSection(characters: widget.origin.characters),
    ]);
    if (widget.embeddedInSheet) {
      // Enter world 改为浮窗底部常驻 bar,列表末尾只留出让位高度。
      children.add(const SizedBox(height: _originInfoLaunchBarHeight + 12));
    }
    final scrollKey = PageStorageKey<String>(
      'origin-intro-${widget.origin.oid}',
    );
    if (widget.embeddedInSheet) {
      return CustomScrollView(
        key: scrollKey,
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _OriginInfoPinnedHeaderDelegate(
              origin: widget.origin,
              onClose: widget.onClose,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: originDetailSheetHorizontalPaddingForTesting,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      );
    }
    return ListView(
      key: scrollKey,
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        originDetailSheetHorizontalPaddingForTesting,
        widget.topPadding + 8,
        originDetailSheetHorizontalPaddingForTesting,
        24,
      ),
      physics: const ClampingScrollPhysics(),
      children: children,
    );
  }
}

/// Info 页常驻底 bar 在安全区之上占用的高度(10 + 40),
/// 底部安全区由 bar 自己的内边距吸收,列表让位时不必计入。
const double _originInfoLaunchBarHeight = 50;

class _OriginInfoLaunchBar extends StatelessWidget {
  const _OriginInfoLaunchBar({
    required this.bottomInset,
    required this.launching,
    required this.onLaunch,
  });

  final double bottomInset;
  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    // 底 bar 样式:通底色、无分隔线,贴着浮窗底边,安全区收进内边距。
    return Container(
      key: const ValueKey<String>('origin-info-launch-action'),
      padding: EdgeInsets.fromLTRB(
        originDetailSheetHorizontalPaddingForTesting,
        10,
        originDetailSheetHorizontalPaddingForTesting,
        bottomInset,
      ),
      color: colors.pageBackground,
      child: GenesisPrimaryButton(
        label: 'Enter world',
        onPressed: launching ? null : onLaunch,
        height: 40,
        borderRadius: BorderRadius.circular(14),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // 主按钮组件的标准字号(15),不再压小一档。
        fontSize: 15,
        fontWeight: FontWeight.w700,
        isLoading: launching,
        loadingSize: 22,
        loadingStrokeWidth: 2.4,
      ),
    );
  }
}

class _OriginSheetPageHeading extends StatelessWidget {
  const _OriginSheetPageHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // 与 world 浮窗固定头的标题行同规格:26 高、底部 12,navigationTitle/1.3。
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 26,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                key: ValueKey<String>('origin-detail-sheet-page-$title'),
                style: GenesisTypography.navigationTitle.copyWith(
                  height: worldDetailLineHeight,
                  color: context.genesisColors.textPrimary,
                ),
              ),
            ),
            if (trailing case final trailing?) trailing,
          ],
        ),
      ),
    );
  }
}

class _OriginInfoCover extends StatelessWidget {
  const _OriginInfoCover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return _OriginPreviewImage(
      key: const ValueKey<String>('origin-info-cover'),
      url: url,
      width: 120,
      height: 180,
      borderRadius: 8,
    );
  }
}

class _OriginInfoTag extends StatelessWidget {
  const _OriginInfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final highlighted = label.trim().toLowerCase() == 'trending';
    return GenesisTag(
      label: label,
      tone: highlighted ? GenesisTagTone.accent : GenesisTagTone.neutral,
      size: GenesisTagSize.compact,
    );
  }
}

class _OriginSheetPageIndicator extends StatelessWidget {
  const _OriginSheetPageIndicator({required this.page});

  final double page;

  @override
  Widget build(BuildContext context) {
    final infoProgress = page.clamp(0.0, 1.0);
    return SizedBox(
      key: const ValueKey<String>('origin-detail-sheet-page-indicator'),
      height: 14,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OriginSheetPageIndicatorSegment(
              key: const ValueKey<String>(
                'origin-detail-sheet-indicator-opening',
              ),
              selectionProgress: 1 - infoProgress,
            ),
            const SizedBox(width: 5),
            _OriginSheetPageIndicatorSegment(
              key: const ValueKey<String>('origin-detail-sheet-indicator-info'),
              selectionProgress: infoProgress,
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginSheetPageIndicatorSegment extends StatelessWidget {
  const _OriginSheetPageIndicatorSegment({
    super.key,
    required this.selectionProgress,
  });

  final double selectionProgress;

  @override
  Widget build(BuildContext context) {
    final progress = selectionProgress.clamp(0.0, 1.0);
    final colors = context.genesisColors;
    return Container(
      width: 4 + 22 * progress,
      height: 4,
      decoration: BoxDecoration(
        color: Color.lerp(colors.dragHandle, colors.foregroundStrong, progress),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _OriginSheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OriginSheetHeaderDelegate({required this.topPadding});

  final double topPadding;

  @override
  double get minExtent => topPadding + originDetailSheetHeaderHeightForTesting;

  @override
  double get maxExtent => topPadding + originDetailSheetHeaderHeightForTesting;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: ColoredBox(color: context.genesisColors.pageBackground),
    );
  }

  @override
  bool shouldRebuild(covariant _OriginSheetHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding;
  }
}

class _OriginInfoPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OriginInfoPinnedHeaderDelegate({
    required this.origin,
    required this.onClose,
  });

  final OriginDetail origin;
  final VoidCallback? onClose;

  @override
  double get minExtent => originInfoPinnedHeaderHeightForTesting;

  @override
  double get maxExtent => originInfoPinnedHeaderHeightForTesting;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      key: const ValueKey<String>('origin-info-pinned-header'),
      color: context.genesisColors.pageBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: originDetailSheetHorizontalPaddingForTesting,
        ),
        child: Column(
          children: [
            const SizedBox(height: originDetailSheetHeaderHeightForTesting),
            _OriginSheetPageHeading(
              title: 'Info',
              trailing: _OriginInfoHeaderActions(
                origin: origin,
                onClose: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OriginInfoPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.origin != origin || oldDelegate.onClose != onClose;
  }
}

class _OriginSheetHeaderContent extends StatelessWidget {
  const _OriginSheetHeaderContent({
    required this.origin,
    required this.currentUid,
    required this.onOriginChanged,
    required this.showPageHeading,
    this.showStandaloneHeaderActions = true,
  });

  final OriginDetail origin;
  final String currentUid;
  final VoidCallback onOriginChanged;
  final bool showPageHeading;
  final bool showStandaloneHeaderActions;

  @override
  Widget build(BuildContext context) {
    final originator = origin.ownerDeleted
        ? deletedEntityDisplayText
        : origin.originator.trim().isEmpty
        ? '-'
        : formatUidForDisplay(origin.originator);
    final ownerUid = origin.ownerUid.trim();
    final canEditOrigin =
        currentUid.trim().isNotEmpty && currentUid.trim() == ownerUid;
    final version = origin.versionNum <= 0 ? 1 : origin.versionNum;
    final age = formatGenesisDateTime(origin.updatedAt, fallback: '');
    // 与已加载世界的详情页 meta 行同规格(worldDetailMetaTextStyle):
    // 11/400/1.3,textSecondary。
    final metaStyle = worldDetailMetaTextStyle.copyWith(
      color: context.genesisColors.textSecondary,
    );
    final headerActions = _OriginInfoHeaderActions(origin: origin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPageHeading)
          _OriginSheetPageHeading(title: 'Info', trailing: headerActions),
        if (!showPageHeading && showStandaloneHeaderActions)
          Align(alignment: Alignment.centerRight, child: headerActions),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OriginInfoCover(url: _resolveAssetUrl(origin.mapImage)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originDisplayName(origin.name, fallback: origin.oid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GenesisTypography.contentTitle.copyWith(
                      fontSize: 16,
                      height: worldDetailLineHeight,
                      color: context.genesisColors.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (origin.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final tag in origin.tags)
                          if (tag.trim().isNotEmpty)
                            _OriginInfoTag(label: tag.trim()),
                      ],
                    ),
                  ],
                  const SizedBox(height: 7),
                  CopyableIdLabel(
                    label: 'OID',
                    value: origin.oid,
                    displayValue: origin.deleted
                        ? deletedEntityDisplayText
                        : null,
                    enabled: !origin.deleted,
                    customTextStyle: metaStyle,
                    customIconColor: context.genesisColors.textSecondary,
                    // 与 world 详情页同款复制图标与尺寸,跟 11px 正文对齐。
                    copyIconAsset: copyIdIconAsset,
                    copyIconSize: worldDetailMetaIconSize,
                    trailingGap: 4,
                  ),
                  GenesisInlineMetaLabel(
                    // 与 world 详情页一致:正常创建者带 @ 前缀,
                    // 已删除/缺省(-)不带。
                    text:
                        'Creator: ${origin.ownerDeleted || originator == '-' ? originator : '@${formatUidForDisplay(originator)}'}',
                    onTap: ownerUid.isEmpty || origin.ownerDeleted
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.userInfo,
                            arguments: {'uid': ownerUid},
                          ),
                    style: metaStyle,
                    trailingIcon: ownerUid.isEmpty || origin.ownerDeleted
                        ? null
                        : Icons.chevron_right,
                    trailingIconColor: context.genesisColors.textSecondary,
                    trailingIconSize: 12,
                    trailingGap: 3,
                  ),
                  // 与上两行同用 meta 组件,三行才有一致的 3px 垂直节奏
                  // (裸 Text 没有那份内边距,行距会显得不均)。
                  GenesisInlineMetaLabel(
                    text:
                        'Latest Version: V$version'
                        '${age.isEmpty ? '' : ' · $age'}',
                    style: metaStyle,
                    // 无尾图标,但最小行高与上两行的图标尺寸取齐。
                    trailingIconSize: worldDetailMetaIconSize,
                  ),
                  if (canEditOrigin) ...[
                    const SizedBox(height: 12),
                    _OriginInlineEditAction(
                      onTap: () async {
                        await Navigator.of(context).pushNamed(
                          RouteNames.edit,
                          arguments: {'origin_id': origin.oid},
                        );
                        if (!context.mounted) return;
                        onOriginChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OriginInfoHeaderActions extends StatelessWidget {
  const _OriginInfoHeaderActions({required this.origin, this.onClose});

  final OriginDetail origin;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OriginInfoHeaderCircle(
          key: const ValueKey<String>('origin-info-more-button'),
          child: GenesisMoreActionMenuButton(
            buttonSize: 26,
            iconSize: 14,
            iconColor: context.genesisColors.textSecondary,
            items: [
              genesisReportMenuItem(
                context: context,
                targetType: 'origin',
                targetId: origin.oid,
              ),
            ],
          ),
        ),
        if (onClose case final onClose?) ...[
          const SizedBox(width: 7),
          _OriginInfoHeaderCircle(
            key: const ValueKey<String>('origin-info-close-button'),
            onTap: onClose,
            child: GenesisCloseIcon(
              size: 12,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}

class _OriginInfoHeaderCircle extends StatelessWidget {
  const _OriginInfoHeaderCircle({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        // 与 world 浮窗固定头的圆形操作钮同底色。
        color: context.genesisWorldColors.closeSurface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
    final onTap = this.onTap;
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _OriginInlineEditAction extends StatelessWidget {
  const _OriginInlineEditAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('origin-inline-edit-worldo'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.genesisColors.foregroundStrong.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.20,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              editPencilLineIconAsset,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(
                context.genesisColors.foregroundStrong,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Edit Worldo',
              style: TextStyle(
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
                color: context.genesisColors.foregroundStrong,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
