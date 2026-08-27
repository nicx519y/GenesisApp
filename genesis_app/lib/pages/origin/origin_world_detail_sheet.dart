part of 'origin_world_page.dart';

const int _originOpeningSheetPageIndex = 0;
const int _originInfoSheetPageIndex = 1;

double _originDetailExpandedChildSize(
  BuildContext context, {
  required double minChildSize,
}) {
  final viewportHeight = MediaQuery.sizeOf(context).height;
  if (viewportHeight <= 0) return minChildSize;
  final expandedTop = originWorldDetailExpandedSheetTopFor(
    topSafeArea: GenesisSafeAreaInsets.top(context),
  );
  return (1.0 - expandedTop / viewportHeight)
      .clamp(minChildSize, 1.0)
      .toDouble();
}

class _OriginDetailDraggableSheet extends StatefulWidget {
  const _OriginDetailDraggableSheet({
    required this.origin,
    required this.copyWorldProgressSummaries,
    required this.minChildSize,
    required this.initiallyExpanded,
    required this.autoExpansionPending,
    required this.onRaisedChanged,
    required this.onFullyExpanded,
    required this.onAutoExpansionInterrupted,
    required this.onOriginChanged,
    required this.launching,
    required this.profileRole,
    required this.onSelectRole,
    required this.onSelectProfileRole,
    required this.onFillProfileRole,
  });

  static const double defaultInitialChildSize = 0.35;

  final OriginDetail origin;
  final List<WorldSummaryLatestItem> copyWorldProgressSummaries;
  final double minChildSize;
  final bool initiallyExpanded;
  final bool autoExpansionPending;
  final ValueChanged<bool> onRaisedChanged;
  final VoidCallback onFullyExpanded;
  final VoidCallback onAutoExpansionInterrupted;
  final VoidCallback onOriginChanged;
  final bool launching;
  final OriginCustomRoleDraft? profileRole;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final OriginRoleProfileLoader? onFillProfileRole;

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

  late final DraggableScrollableController _sheetController;
  late final PageController _pageController;
  late final ScrollController _openingPreviewScrollController;
  late final ScrollController _infoPreviewScrollController;
  final Completer<void> _sheetReady = Completer<void>();
  ScrollController? _sheetScrollController;
  OriginDiscussListController? _discussController;
  late _OriginInitialDialoguePreview? _initialDialoguePreview;
  var _currentUid = '';
  var _currentPage = _originOpeningSheetPageIndex;
  var _isFullyExpanded = false;
  var _isRaised = false;
  var _extentCommandGeneration = 0;
  var _sheetReadyCheckScheduled = false;
  var _autoExpansionInterruptionScheduled = false;
  var _autoExpansionPaintCompletionScheduled = false;
  Timer? _extentSettleTimer;
  Completer<void>? _extentSettleCompleter;

  double get _minChildSize => widget.minChildSize.clamp(0.08, 1.0).toDouble();

  double _expandedChildSize(BuildContext context) {
    return _originDetailExpandedChildSize(
      context,
      minChildSize: _minChildSize,
    ).clamp(_minChildSize, _absoluteMaxChildSize).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _pageController = PageController(initialPage: _currentPage);
    _openingPreviewScrollController = ScrollController();
    _infoPreviewScrollController = ScrollController();
    _initialDialoguePreview = _originFirstInitialDialoguePreview(widget.origin);
    if (widget.initiallyExpanded && widget.autoExpansionPending) {
      _completeInitialExpansionAfterPaint();
    }
  }

  @override
  void didUpdateWidget(covariant _OriginDetailDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.origin, widget.origin)) {
      _initialDialoguePreview = _originFirstInitialDialoguePreview(
        widget.origin,
      );
      if (oldWidget.origin.oid != widget.origin.oid) {
        _currentPage = _originOpeningSheetPageIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(_originOpeningSheetPageIndex);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
        final discussController = _discussController;
        if (discussController != null) {
          _configureDiscuss(discussController);
          unawaited(discussController.refreshFirstPage());
          unawaited(_loadCurrentUid());
        }
      }
    }
    if (oldWidget.minChildSize != widget.minChildSize) {
      _syncRaisedStateAfterBuild();
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
    _openingPreviewScrollController.dispose();
    _infoPreviewScrollController.dispose();
    _discussController?.dispose();
    super.dispose();
  }

  void _expandToMaxChildSize() {
    _cancelExtentSettleWait();
    final commandGeneration = ++_extentCommandGeneration;
    unawaited(
      _animateToRequestedExtent(
        commandGeneration: commandGeneration,
        expanded: true,
      ),
    );
  }

  void _completeInitialExpansionAfterPaint() {
    unawaited(() async {
      await _sheetReady.future;
      await _waitForNextFrame();
      if (!mounted ||
          !widget.autoExpansionPending ||
          !_sheetController.isAttached ||
          !_isAtExpandedExtent()) {
        return;
      }
      widget.onFullyExpanded();
    }());
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

  void _expandOpeningRoleCards() {
    _expandToMaxChildSize();
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
    final draggedUp = (details.primaryVelocity ?? 0) < -200;
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
    if (notification is ScrollStartNotification &&
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

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.horizontal ||
        !_pageController.hasClients) {
      return false;
    }
    _selectPage((_pageController.page ?? _currentPage.toDouble()).round());
    return false;
  }

  void _selectPage(int page) {
    if (page == _currentPage) return;
    if (page == _originInfoSheetPageIndex) _ensureDiscussController();
    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    setState(() => _currentPage = page);
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: page == _originInfoSheetPageIndex
          ? 'worldo_detail_intro'
          : 'worldo_detail_sheet',
      object1: widget.origin.oid,
    );
  }

  Widget _buildAnimatedPageIndicator() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
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
      builder: (context, child) {
        final sheetExtent = _sheetController.isAttached
            ? _sheetController.size
            : widget.initiallyExpanded
            ? _expandedChildSize(context)
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

  OriginDiscussListController _ensureDiscussController() {
    final existing = _discussController;
    if (existing != null) return existing;
    final controller = OriginDiscussListController();
    _discussController = controller;
    _configureDiscuss(controller);
    unawaited(controller.loadInitialIfNeeded());
    unawaited(_loadCurrentUid());
    return controller;
  }

  void _configureDiscuss(OriginDiscussListController controller) {
    controller.configure(
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

  List<Widget> _originInfoSlivers() {
    final discussController = _ensureDiscussController();
    final children = <Widget>[
      _OriginInfoTitleRow(origin: widget.origin),
      const SizedBox(height: 8),
      _OriginSheetHeaderContent(
        origin: widget.origin,
        currentUid: _currentUid,
        onOriginChanged: widget.onOriginChanged,
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
      CopyWorldProgressSection(
        originId: widget.origin.oid,
        summaries: widget.copyWorldProgressSummaries,
      ),
      const SizedBox(height: originDetailSectionGapForTesting),
      _DiscussSection(origin: widget.origin, controller: discussController),
      const SizedBox(height: originDetailSectionGapForTesting),
      _OriginCharactersSection(characters: widget.origin.characters),
    ]);
    return [
      SliverPadding(
        key: PageStorageKey<String>('origin-intro-${widget.origin.oid}'),
        padding: EdgeInsets.fromLTRB(
          originDetailSheetHorizontalPaddingForTesting,
          6,
          originDetailSheetHorizontalPaddingForTesting,
          24,
        ),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ];
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
                child: const _OriginSheetLoadingContent(),
              ),
            )
          else ...[
            ..._originWorldoBriefSlivers(widget.origin),
            if (initialDialoguePreview != null)
              ..._originInitialDialogueSlivers(
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
                onFillProfileRole: widget.onFillProfileRole,
                onBeginProfileRoleEditing: _expandOpeningRoleCards,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPage(ScrollController scrollController) {
    return KeyedSubtree(
      key: const ValueKey<String>('origin-detail-sheet-page-Info'),
      child: CustomScrollView(
        controller: scrollController,
        key: PageStorageKey<String>(
          'origin-detail-info-bottom-sheet-${widget.origin.oid}',
        ),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: const _OriginSheetHeaderDelegate(topPadding: 0),
          ),
          ..._originInfoSlivers(),
        ],
      ),
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
    final initialChildSize =
        (widget.initiallyExpanded ? maxChildSize : minChildSize)
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
              final bottomInset = GenesisSafeAreaInsets.bottom(context);
              final keyboardInset = MediaQuery.viewInsetsOf(
                context,
              ).bottom.clamp(0.0, MediaQuery.sizeOf(context).height).toDouble();
              return DecoratedBox(
                key: const ValueKey<String>('origin-detail-sheet-surface'),
                decoration: BoxDecoration(
                  color: originWorldDetailSheetBackgroundColor,
                  borderRadius: GenesisRadii.sheet,
                ),
                child: ClipRRect(
                  borderRadius: GenesisRadii.sheet,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(overscroll: false),
                    child: Stack(
                      children: [
                        NotificationListener<ScrollEndNotification>(
                          onNotification: _handlePageScrollEnd,
                          child: Padding(
                            key: const ValueKey<String>(
                              'origin-detail-sheet-keyboard-safe-content',
                            ),
                            padding: EdgeInsets.only(bottom: keyboardInset),
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
                                    : page == _originOpeningSheetPageIndex
                                    ? _openingPreviewScrollController
                                    : _infoPreviewScrollController;
                                return page == _originOpeningSheetPageIndex
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
                          top:
                              originDetailSheetPageIndicatorTopOffsetForTesting,
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
    return Container(
      key: const ValueKey<String>('origin-opening-select-role-gradient'),
      height: 52 + bottomInset,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            originWorldDetailSheetBackgroundColor,
            originWorldDetailSheetBackgroundColor,
            originWorldDetailSheetBackgroundColor.withValues(alpha: 0),
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
                key: const ValueKey<String>('origin-opening-select-role-arrow'),
                width: 14,
                height: 8,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF111111),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Select your role',
                key: ValueKey<String>('origin-opening-select-role-label'),
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginSheetPageIndicator extends StatelessWidget {
  const _OriginSheetPageIndicator({required this.page});

  static const Color _activeColor = Color(0xFF666666);
  static const Color _inactiveColor = Color(0xFFB7B7B7);

  final double page;

  @override
  Widget build(BuildContext context) {
    final infoProgress = page.clamp(0.0, 1.0);
    final infoSelected = infoProgress >= 0.5;

    return SizedBox(
      height: 14,
      child: Center(
        child: Row(
          key: const ValueKey<String>('origin-sheet-page-indicator'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _OriginSheetPageIndicatorSegment(
              containerKey: ValueKey<String>(
                infoSelected
                    ? 'origin-sheet-page-inactive-segment'
                    : 'origin-sheet-page-active-segment',
              ),
              selectionProgress: 1 - infoProgress,
            ),
            const SizedBox(width: 8),
            _OriginSheetPageIndicatorSegment(
              containerKey: ValueKey<String>(
                infoSelected
                    ? 'origin-sheet-page-active-segment'
                    : 'origin-sheet-page-inactive-segment',
              ),
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
    required this.containerKey,
    required this.selectionProgress,
  });

  final Key containerKey;
  final double selectionProgress;

  static const double _combinedSegmentWidth = 46;
  static const double _inactiveWidth = _combinedSegmentWidth / 3;
  static const double _activeWidth = _combinedSegmentWidth * 2 / 3;

  @override
  Widget build(BuildContext context) {
    final progress = selectionProgress.clamp(0.0, 1.0);
    return Container(
      key: containerKey,
      width: lerpDouble(_inactiveWidth, _activeWidth, progress),
      height: 5,
      decoration: BoxDecoration(
        color: Color.lerp(
          _OriginSheetPageIndicator._inactiveColor,
          _OriginSheetPageIndicator._activeColor,
          progress,
        ),
        borderRadius: BorderRadius.circular(3),
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
    return const SizedBox.expand(
      child: ColoredBox(color: originWorldDetailSheetBackgroundColor),
    );
  }

  @override
  bool shouldRebuild(covariant _OriginSheetHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding;
  }
}

class _OriginSheetHeaderContent extends StatelessWidget {
  const _OriginSheetHeaderContent({
    required this.origin,
    required this.currentUid,
    required this.onOriginChanged,
  });

  final OriginDetail origin;
  final String currentUid;
  final VoidCallback onOriginChanged;

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
    final metaStyle = CopyableIdLabel.textStyle.copyWith(height: 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OriginPreviewImage(
              url: _resolveAssetUrl(origin.mapImage),
              width: 120,
              height: 180,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originDisplayName(origin.name, fallback: origin.oid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B6192),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CopyableIdLabel(
                    label: 'OID',
                    value: origin.oid,
                    displayValue: origin.deleted
                        ? deletedEntityDisplayText
                        : null,
                    enabled: !origin.deleted,
                    customTextStyle: metaStyle,
                  ),
                  GenesisInlineMetaLabel(
                    text: 'Originator: ${formatUidForDisplay(originator)}',
                    onTap: ownerUid.isEmpty || origin.ownerDeleted
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.userInfo,
                            arguments: {'uid': ownerUid},
                          ),
                    trailingIcon: ownerUid.isEmpty || origin.ownerDeleted
                        ? null
                        : Icons.chevron_right,
                    style: metaStyle,
                    trailingIconSize: genesisCopyableIdIconSize,
                    trailingGap: 4,
                  ),
                  GenesisInlineMetaLabel(
                    text:
                        'Latest Version: V$version'
                        '${age.isEmpty ? '' : ' · $age'}',
                    style: metaStyle,
                    trailingIconSize: genesisCopyableIdIconSize,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    key: const ValueKey<String>('origin-info-stats-row'),
                    children: [
                      _OriginInfoStat(
                        key: const ValueKey<String>('origin-info-stat-copy'),
                        iconAsset: copyStatIconAsset,
                        value: origin.copyCount,
                      ),
                      const SizedBox(width: 20),
                      _OriginInfoStat(
                        key: const ValueKey<String>('origin-info-stat-connect'),
                        iconAsset: connectStatIconAsset,
                        value: origin.interactCount,
                      ),
                      const SizedBox(width: 20),
                      _OriginInfoStat(
                        key: const ValueKey<String>(
                          'origin-info-stat-character',
                        ),
                        iconAsset: characterStatIconAsset,
                        preserveIconAssetColor: true,
                        value: origin.characterCount,
                      ),
                    ],
                  ),
                  if (canEditOrigin) ...[
                    const SizedBox(height: 10),
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

class _OriginInfoTitleRow extends StatelessWidget {
  const _OriginInfoTitleRow({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'Info',
            key: ValueKey<String>('origin-info-title'),
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        GenesisMoreActionMenuButton(
          key: const ValueKey<String>('origin-info-report-menu'),
          buttonSize: 18 * 1.25,
          items: [
            genesisReportMenuItem(
              context: context,
              targetType: 'origin',
              targetId: origin.oid,
            ),
          ],
        ),
      ],
    );
  }
}

class _OriginInfoStat extends StatelessWidget {
  const _OriginInfoStat({
    super.key,
    required this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  });

  final String iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 12,
      iconAssetScale: 1,
      iconVerticalOffset: 0,
      iconColor: const Color(0xFF111111),
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
        color: Color(0xFF111111),
      ),
    );
  }
}

class _OriginInlineEditAction extends StatelessWidget {
  const _OriginInlineEditAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GenesisPrimaryButton(
      key: const ValueKey('origin-inline-edit-worldo'),
      label: 'Edit Worldo',
      onPressed: onTap,
      height: 34,
      width: 92,
      backgroundColor: const Color(0xFFFF2442),
      disabledBackgroundColor: const Color(0xFFFF2442).withValues(alpha: 0.62),
      foregroundColor: Colors.white,
      fontSize: 14,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
