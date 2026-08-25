part of 'origin_world_page.dart';

class _OriginDetailDraggableSheet extends StatefulWidget {
  const _OriginDetailDraggableSheet({
    required this.origin,
    required this.minChildSize,
    required this.expandRequest,
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
  });

  static const double defaultInitialChildSize = 0.22;

  final OriginDetail origin;
  final double minChildSize;
  final int expandRequest;
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

  @override
  State<_OriginDetailDraggableSheet> createState() =>
      _OriginDetailDraggableSheetState();
}

class _OriginDetailDraggableSheetState
    extends State<_OriginDetailDraggableSheet> {
  static const double _absoluteMaxChildSize = 1.0;
  static const double _topOverlayTopOffset = 8.0;
  static const double _expandedTopOverlayGap = 20.0;
  static const double _extentUpdateEpsilon = 0.001;
  static const int _extentSettleFrameCount = 2;
  static const _snapAnimationDuration = Duration(milliseconds: 260);
  static const double _sheetPageSwipeThreshold = 40;
  static const double _sheetPageFlingVelocity = 400;

  late final DraggableScrollableController _sheetController;
  final Completer<void> _sheetReady = Completer<void>();
  ScrollController? _sheetScrollController;
  OriginDiscussListController? _discussController;
  late _OriginInitialDialoguePreview? _initialDialoguePreview;
  var _currentUid = '';
  var _sheetPageIndex = 0;
  var _horizontalDragDistance = 0.0;
  var _isFullyExpanded = false;
  var _isRaised = false;
  var _extentCommandGeneration = 0;
  var _sheetReadyCheckScheduled = false;
  var _autoExpansionInterruptionScheduled = false;
  var _autoExpansionPaintCompletionScheduled = false;
  Timer? _extentSettleTimer;
  Completer<void>? _extentSettleCompleter;

  double get _minChildSize => widget.minChildSize.clamp(0.08, 0.42).toDouble();

  double get _effectiveInitialChildSize => _minChildSize;

  double _expandedChildSize(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight = viewportHeight;
    if (sheetHostHeight <= 0) return _minChildSize;
    final expandedTop =
        GenesisSafeAreaInsets.top(context) +
        _topOverlayTopOffset +
        genesisSearchFieldHeight +
        _expandedTopOverlayGap;
    return (1.0 - expandedTop / sheetHostHeight)
        .clamp(_minChildSize, _absoluteMaxChildSize)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
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
      if (oldWidget.origin.oid != widget.origin.oid) {
        _sheetPageIndex = 0;
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
    if (oldWidget.expandRequest != widget.expandRequest) {
      _expandToMaxChildSize();
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

  void _handleSheetHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _handleSheetHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleSheetHorizontalDragCancel() {
    _horizontalDragDistance = 0;
  }

  void _handleSheetHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _horizontalDragDistance;
    _horizontalDragDistance = 0;
    if (distance.abs() < _sheetPageSwipeThreshold &&
        velocity.abs() < _sheetPageFlingVelocity) {
      return;
    }
    final direction = velocity.abs() >= _sheetPageFlingVelocity
        ? velocity
        : distance;
    final nextIndex = direction < 0 ? 1 : 0;
    if (nextIndex == _sheetPageIndex) return;

    if (nextIndex == 1) _ensureDiscussController();
    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    setState(() => _sheetPageIndex = nextIndex);
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: nextIndex == 1 ? 'worldo_detail_intro' : 'worldo_detail_sheet',
      object1: widget.origin.oid,
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
      CopyWorldProgressSection(originId: widget.origin.oid),
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
          8,
          originDetailSheetHorizontalPaddingForTesting,
          24,
        ),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
    ];
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
                    child: GestureDetector(
                      key: const ValueKey<String>('origin-detail-sheet-pages'),
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _handleSheetHorizontalDragStart,
                      onHorizontalDragUpdate: _handleSheetHorizontalDragUpdate,
                      onHorizontalDragEnd: _handleSheetHorizontalDragEnd,
                      onHorizontalDragCancel: _handleSheetHorizontalDragCancel,
                      child: CustomScrollView(
                        controller: scrollController,
                        key: PageStorageKey<String>(
                          'origin-detail-bottom-sheet-${widget.origin.oid}',
                        ),
                        physics: const ClampingScrollPhysics(),
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _OriginSheetHeaderDelegate(
                              topPadding: 0,
                              pageIndex: _sheetPageIndex,
                            ),
                          ),
                          if (widget.autoExpansionPending)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: KeyedSubtree(
                                key: const ValueKey<String>(
                                  'origin-opening-sheet-tombstone',
                                ),
                                child: initialDialoguePreview != null
                                    ? const _OriginInitialDialogueLoadingContent()
                                    : const _OriginRoleSetupLoadingContent(),
                              ),
                            )
                          else if (_sheetPageIndex == 0) ...[
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
                                onEditProfileRole: widget.onEditProfileRole,
                                onCustomizeRole: widget.onCustomizeRole,
                              ),
                            ),
                          ] else
                            ..._originInfoSlivers(),
                        ],
                      ),
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

class _OriginSheetDragHandle extends StatelessWidget {
  const _OriginSheetDragHandle({this.pageIndex});

  static const Color _activeColor = Color(0xFF666666);
  static const Color _inactiveDotColor = Color(0xFFB7B7B7);
  static const Color _loadingHandleColor = Color(0xFFD2D2D2);

  final int? pageIndex;

  Widget _buildHandle({required Color color, Key? key}) {
    return Container(
      key: key,
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPageIndex = pageIndex;
    if (currentPageIndex == null) {
      return SizedBox(
        height: 14,
        child: Center(child: _buildHandle(color: _loadingHandleColor)),
      );
    }

    final activeHandle = _buildHandle(
      key: const ValueKey<String>('origin-sheet-page-handle'),
      color: _activeColor,
    );
    final inactiveDot = Container(
      key: const ValueKey<String>('origin-sheet-page-dot'),
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: _inactiveDotColor,
        shape: BoxShape.circle,
      ),
    );

    return SizedBox(
      height: 14,
      child: Center(
        child: Row(
          key: const ValueKey<String>('origin-sheet-page-indicator'),
          mainAxisSize: MainAxisSize.min,
          children: currentPageIndex == 0
              ? [activeHandle, const SizedBox(width: 8), inactiveDot]
              : [inactiveDot, const SizedBox(width: 8), activeHandle],
        ),
      ),
    );
  }
}

class _OriginSheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OriginSheetHeaderDelegate({
    required this.topPadding,
    required this.pageIndex,
  });

  final double topPadding;
  final int pageIndex;

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
    return ColoredBox(
      color: originWorldDetailSheetBackgroundColor,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: topPadding + originDetailSheetHandleTopOffsetForTesting,
            child: _OriginSheetDragHandle(pageIndex: pageIndex),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _OriginSheetHeaderDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.pageIndex != pageIndex;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Text(
                originDisplayName(origin.name, fallback: origin.oid),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B6192),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: GenesisMoreActionMenuButton(
                buttonSize: 18 * 1.25,
                items: [
                  genesisReportMenuItem(
                    context: context,
                    targetType: 'origin',
                    targetId: origin.oid,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GenesisPairedMetaRow(
          leftLabel: 'OID',
          leftValue: origin.oid,
          leftDisplayValue: origin.deleted ? deletedEntityDisplayText : null,
          leftCopyEnabled: !origin.deleted,
          rightText: 'Originator: ${formatUidForDisplay(originator)}',
          rightOnTap: ownerUid.isEmpty || origin.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
        ),
        if (canEditOrigin) const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Latest Version: V$version${age.isEmpty ? '' : ' · $age'}',
                style: CopyableIdLabel.textStyle,
              ),
            ),
            if (canEditOrigin)
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
        ),
        const SizedBox(height: 18),
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
              key: const ValueKey<String>('origin-info-stat-character'),
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: origin.characterCount,
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
      iconSize: 14,
      iconAssetScale: 1,
      iconVerticalOffset: 0,
      iconColor: const Color(0xFF111111),
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w400,
        color: Color(0xFF111111),
      ),
    );
  }
}

class _OriginInlineEditAction extends StatelessWidget {
  const _OriginInlineEditAction({required this.onTap});

  static const Color _color = Color(0xFF4B6192);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('origin-inline-edit-worldo'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              editPencilLineIconAsset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(_color, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
            const Text(
              'Edit Worldo',
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: _color,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
