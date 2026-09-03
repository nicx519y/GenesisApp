part of 'origin_world_page.dart';

class _OriginSliverPaintTranslation extends SingleChildRenderObjectWidget {
  const _OriginSliverPaintTranslation({
    required this.translation,
    required Widget sliver,
  }) : super(child: sliver);

  final Offset translation;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOriginSliverPaintTranslation(translation);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderOriginSliverPaintTranslation renderObject,
  ) {
    renderObject.translation = translation;
  }
}

class _RenderOriginSliverPaintTranslation extends RenderProxySliver {
  _RenderOriginSliverPaintTranslation(this._translation);

  Offset _translation;

  set translation(Offset value) {
    if (value == _translation) return;
    _translation = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final sliver = child;
    if (sliver == null) return;
    context.paintChild(sliver, offset + _translation);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    transform.translateByDouble(_translation.dx, _translation.dy, 0, 1);
  }
}

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
    required this.minChildSize,
    required this.initiallyExpanded,
    required this.autoExpansionPending,
    required this.onRaisedChanged,
    required this.onFullyExpanded,
    required this.onAutoExpansionInterrupted,
    required this.onOriginChanged,
    required this.activeLaunchSource,
    required this.launchedPresetRoles,
    required this.onEnterLaunchedWorld,
    required this.profileRole,
    required this.onSelectRole,
    required this.onSaveProfileRole,
    required this.onSelectProfileRole,
    required this.locationChatRole,
    required this.onSelectLocationChatRole,
    required this.onSendLocationChatMessage,
  });

  static const double defaultInitialChildSize = 0.35;

  final OriginDetail origin;
  final double minChildSize;
  final bool initiallyExpanded;
  final bool autoExpansionPending;
  final ValueChanged<bool> onRaisedChanged;
  final VoidCallback onFullyExpanded;
  final VoidCallback onAutoExpansionInterrupted;
  final VoidCallback onOriginChanged;
  final OriginLaunchSource? activeLaunchSource;
  final List<OriginMyLaunchPresetCharacter>? launchedPresetRoles;
  final ValueChanged<OriginMyLaunchPresetCharacter> onEnterLaunchedWorld;
  final OriginCustomRoleDraft? profileRole;
  final Future<void> Function(OriginCharacter character) onSelectRole;
  final ValueChanged<OriginCustomRoleDraft> onSaveProfileRole;
  final Future<void> Function(OriginCustomRoleDraft role) onSelectProfileRole;
  final _OriginLocationChatRoleOption locationChatRole;
  final ValueChanged<String> onSelectLocationChatRole;
  final Future<bool> Function(
    String locationId,
    String message,
    ChatMentionCatalog mentionCatalog,
  )
  onSendLocationChatMessage;

  @override
  State<_OriginDetailDraggableSheet> createState() =>
      _OriginDetailDraggableSheetState();
}

class _OriginDetailDraggableSheetState
    extends State<_OriginDetailDraggableSheet>
    with WidgetsBindingObserver {
  static const double _absoluteMaxChildSize = 1.0;
  static const double _extentUpdateEpsilon = _originSheetInteractionEpsilon;
  static const int _extentSettleFrameCount = 2;
  static const _snapAnimationDuration = Duration(milliseconds: 260);

  late final DraggableScrollableController _sheetController;
  late final _OriginWorldSheetInteractionController _sheetInteraction;
  final ValueNotifier<bool> _roleEditing = ValueNotifier<bool>(false);
  final GlobalKey _roleSectionKey = GlobalKey(
    debugLabel: 'origin-opening-role-section',
  );
  final GlobalKey _openingPageStackKey = GlobalKey(
    debugLabel: 'origin-opening-page-stack',
  );
  final GlobalKey _openingKeyboardContentStartKey = GlobalKey(
    debugLabel: 'origin-opening-keyboard-content-start',
  );
  final GlobalKey _openingKeyboardMessageEndKey = GlobalKey(
    debugLabel: 'origin-opening-keyboard-message-end',
  );
  final GlobalKey _expandedOpeningComposerSubtreeKey = GlobalKey(
    debugLabel: 'origin-expanded-opening-composer-subtree',
  );
  final GlobalKey _expandedOpeningComposerMeasureKey = GlobalKey(
    debugLabel: 'origin-expanded-opening-composer-measure',
  );
  final Completer<void> _sheetReady = Completer<void>();
  ScrollController? _sheetScrollController;
  OriginDiscussListController? _discussController;
  late _OriginInitialDialoguePreview? _initialDialoguePreview;
  var _currentUid = '';
  var _isFullyExpanded = false;
  var _isRaised = false;
  var _extentCommandGeneration = 0;
  var _sheetReadyCheckScheduled = false;
  var _autoExpansionInterruptionScheduled = false;
  var _autoExpansionPaintCompletionScheduled = false;
  Timer? _extentSettleTimer;
  Completer<void>? _extentSettleCompleter;

  PageController get _pageController => _sheetInteraction.pageController;
  int get _currentPage => _sheetInteraction.currentPage;
  bool get _openingComposerDocked => _sheetInteraction.openingComposerDocked;
  double get _expandedOpeningComposerHeight => _sheetInteraction.composerHeight;
  bool get _openingKeyboardMode => _sheetInteraction.keyboardMode;
  _OriginOpeningKeyboardPhase get _openingKeyboardPhase =>
      _sheetInteraction.keyboardPhase;
  double get _openingKeyboardTargetInset =>
      _sheetInteraction.keyboardTargetInset;
  double get _openingKeyboardNormalScrollOffset =>
      _sheetInteraction.keyboardNormalScrollOffset;
  double get _openingKeyboardAdditionalScrollExtent =>
      _sheetInteraction.keyboardAdditionalScrollExtent;

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
    WidgetsBinding.instance.addObserver(this);
    _isRaised = widget.initiallyExpanded;
    _sheetController = DraggableScrollableController();
    _initialDialoguePreview = _originFirstInitialDialoguePreview(widget.origin);
    _sheetInteraction = _OriginWorldSheetInteractionController(
      canPrepareKeyboard: () => mounted && !widget.autoExpansionPending,
      readKeyboardInset: _currentOpeningKeyboardInset,
      readKeyboardLayout: _readOpeningKeyboardLayout,
      readKeyboardContentBounds: _readOpeningKeyboardContentBounds,
      readSheetExtent: () =>
          _sheetController.isAttached ? _sheetController.size : 0,
      readFallbackExpandedSheetExtent: () => _expandedChildSize(context),
      restoreSheetExtent: _restoreOpeningKeyboardSheetExtent,
      readContentToComposerGap: () =>
          _initialDialoguePreview?.messages.isNotEmpty == true
          ? originDetailSectionGapForTesting
          : 0,
      onPageSelected: _handleInteractionPageSelected,
    )..addListener(_handleSheetInteractionChanged);
    _scheduleDiscussPreloadAfterPaint();
    if (widget.initiallyExpanded && widget.autoExpansionPending) {
      _completeInitialExpansionAfterPaint();
    }
  }

  @override
  void didUpdateWidget(covariant _OriginDetailDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.origin, widget.origin)) {
      final originChanged = oldWidget.origin.oid != widget.origin.oid;
      _sheetInteraction.resetForContentChange(resetPage: originChanged);
      _initialDialoguePreview = _originFirstInitialDialoguePreview(
        widget.origin,
      );
      if (originChanged) {
        _roleEditing.value = false;
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
    WidgetsBinding.instance.removeObserver(this);
    _cancelExtentSettleWait();
    if (!_sheetReady.isCompleted) {
      _sheetReady.complete();
    }
    _sheetInteraction
      ..removeListener(_handleSheetInteractionChanged)
      ..dispose();
    _sheetController.dispose();
    _roleEditing.dispose();
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

  void _focusOpeningRoleCards() {
    unawaited(_focusOpeningRoleCardsAfterExpansion());
  }

  Future<void> _focusOpeningRoleCardsAfterExpansion() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _cancelExtentSettleWait();
    final commandGeneration = ++_extentCommandGeneration;
    await _animateToRequestedExtent(
      commandGeneration: commandGeneration,
      expanded: true,
    );
    if (!_isExtentCommandCurrent(commandGeneration) || !mounted) return;
    final scrollController = _sheetScrollController;
    final roleContext = _roleSectionKey.currentContext;
    final renderObject = roleContext?.findRenderObject();
    if (scrollController == null ||
        !scrollController.hasClients ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }
    final desiredTop =
        originWorldDetailExpandedSheetTopFor(
          topSafeArea: GenesisSafeAreaInsets.top(context),
        ) +
        originDetailSheetHeaderHeightForTesting +
        8;
    final roleTop = renderObject.localToGlobal(Offset.zero).dy;
    final position = scrollController.position;
    final target = (position.pixels + roleTop - desiredTop)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    await scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleRoleEditingChanged(bool editing) {
    if (_roleEditing.value == editing) return;
    _roleEditing.value = editing;
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
    _sheetInteraction.attachSheetScrollController(scrollController);
    _scheduleSheetReadyCheck();
  }

  void _handleSheetInteractionChanged() {
    if (mounted) setState(() {});
  }

  void _handleInteractionPageSelected(int page) {
    if (page == _originInfoSheetPageIndex) _ensureDiscussController();
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: page == _originInfoSheetPageIndex
          ? 'worldo_detail_intro'
          : 'worldo_detail_sheet',
      object1: widget.origin.oid,
    );
  }

  void _scheduleDiscussPreloadAfterPaint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureDiscussController();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _sheetInteraction.handleKeyboardMetrics(_currentOpeningKeyboardInset());
  }

  double _currentOpeningKeyboardInset() {
    final view = View.maybeOf(context);
    if (view == null) return _sheetInteraction.keyboardInset;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  _OriginOpeningKeyboardLayout? _readOpeningKeyboardLayout() {
    if (!mounted) return null;
    final stackBox =
        _openingPageStackKey.currentContext?.findRenderObject() as RenderBox?;
    final composerBox =
        _expandedOpeningComposerMeasureKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (stackBox == null ||
        !stackBox.hasSize ||
        composerBox == null ||
        !composerBox.hasSize) {
      return null;
    }
    return _OriginOpeningKeyboardLayout(
      sheetHeight: stackBox.size.height,
      composerTop: stackBox
          .globalToLocal(composerBox.localToGlobal(Offset.zero))
          .dy,
    );
  }

  _OriginOpeningKeyboardContentBounds? _readOpeningKeyboardContentBounds() {
    if (!mounted) return null;
    final stackBox =
        _openingPageStackKey.currentContext?.findRenderObject() as RenderBox?;
    final startBox =
        _openingKeyboardContentStartKey.currentContext?.findRenderObject()
            as RenderBox?;
    final endBox =
        _openingKeyboardMessageEndKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (stackBox == null ||
        !stackBox.hasSize ||
        startBox == null ||
        !startBox.hasSize ||
        endBox == null ||
        !endBox.hasSize) {
      return null;
    }
    return _OriginOpeningKeyboardContentBounds(
      top: stackBox.globalToLocal(startBox.localToGlobal(Offset.zero)).dy,
      bottom: stackBox
          .globalToLocal(endBox.localToGlobal(Offset(0, endBox.size.height)))
          .dy,
    );
  }

  void _restoreOpeningKeyboardSheetExtent(double extent) {
    if (!_sheetController.isAttached ||
        (_sheetController.size - extent).abs() <= _extentUpdateEpsilon) {
      return;
    }
    _sheetController.jumpTo(extent);
  }

  void _handleOpeningComposerFocusChanged(bool hasFocus) {
    _sheetInteraction.handleComposerFocusChanged(hasFocus);
  }

  void _reportOpeningComposerDocked(bool docked) {
    _sheetInteraction.reportOpeningComposerDocked(docked);
  }

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    return _sheetInteraction.handlePageScrollEnd(notification);
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
      animation: Listenable.merge([
        _sheetController,
        _pageController,
        _roleEditing,
      ]),
      child: _OriginCollapsedOpeningRoleAction(
        bottomInset: bottomInset,
        onTap: _expandOpeningRoleCards,
        onVerticalDragStart: _handleCollapsedRoleDragStart,
        onVerticalDragUpdate: _handleCollapsedRoleDragUpdate,
        onVerticalDragEnd: _handleCollapsedRoleDragEnd,
        onVerticalDragCancel: _handleCollapsedRoleDragCancel,
      ),
      builder: (context, child) {
        final visible =
            !_roleEditing.value &&
            _sheetInteraction.isCollapsedRoleActionVisible(
              sheetRaised: _isRaised,
            );
        return IgnorePointer(
          key: const ValueKey<String>('origin-opening-select-role-visibility'),
          ignoring: !visible,
          child: Opacity(opacity: visible ? 1 : 0, child: child),
        );
      },
    );
  }

  Widget _buildExpandedOpeningComposer(String locationId) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _sheetController,
        _pageController,
        _roleEditing,
      ]),
      child: KeyedSubtree(
        key: _expandedOpeningComposerSubtreeKey,
        child: KeyedSubtree(
          key: const ValueKey<String>('origin-expanded-opening-composer'),
          child: SizedBox(
            key: _expandedOpeningComposerMeasureKey,
            child: _OriginLocationChatLaunchComposer(
              key: ValueKey<String>(
                'origin-sheet-chat-composer-${widget.origin.oid}-$locationId',
              ),
              launching: widget.activeLaunchSource != null,
              sending:
                  widget.activeLaunchSource ==
                  OriginLaunchSource.openingMessage,
              role: widget.locationChatRole,
              mentionCatalog: _originLocationChatMentionCatalog(
                widget.origin,
                selectedRoleId: widget.locationChatRole.id,
              ),
              onSelectRole: _focusOpeningRoleCards,
              onSend: (message, mentionCatalog) =>
                  widget.onSendLocationChatMessage(
                    locationId,
                    message,
                    mentionCatalog,
                  ),
              style: _originDetailSheetChatComposerStyle,
              roleForegroundColor: originWorldDetailSheetPrimaryTextColor,
              roleMutedColor: originWorldDetailSheetTertiaryTextColor,
              roleBackgroundColor: kLocationChatStyle.inputBackgroundColor,
              showShortcuts: false,
              enableMentionSheet: false,
              roleBorderRadius: 8,
              bottomSafeAreaInset: MediaQuery.viewInsetsOf(context).bottom > 0
                  ? 0
                  : GenesisSafeAreaInsets.bottom(context),
              onInputDockHeightChanged: _handleExpandedInputDockHeightChanged,
              onFocusChanged: _handleOpeningComposerFocusChanged,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final opacity = _expandedOpeningComposerProgress(context);
        return IgnorePointer(
          key: const ValueKey<String>(
            'origin-expanded-opening-composer-visibility',
          ),
          ignoring: opacity < 0.99,
          child: Opacity(opacity: opacity, child: child),
        );
      },
    );
  }

  double _expandedOpeningComposerProgress(BuildContext context) {
    if (_roleEditing.value) return 0;
    final sheetExtent = _sheetController.isAttached
        ? _sheetController.size
        : widget.initiallyExpanded
        ? _expandedChildSize(context)
        : _minChildSize;
    return _sheetInteraction.expandedOpeningComposerProgress(
      sheetExtent: sheetExtent,
      minChildSize: _minChildSize,
      autoExpansionPending: widget.autoExpansionPending,
    );
  }

  void _handleExpandedInputDockHeightChanged(double _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height =
          _expandedOpeningComposerMeasureKey.currentContext?.size?.height;
      if (height == null) return;
      _sheetInteraction.updateComposerHeight(height);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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
      _DiscussSection(origin: widget.origin, controller: discussController),
    ]);
    return [
      SliverPadding(
        key: PageStorageKey<String>('origin-intro-${widget.origin.oid}'),
        padding: EdgeInsets.fromLTRB(
          originDetailSheetHorizontalPaddingForTesting,
          6,
          originDetailSheetHorizontalPaddingForTesting,
          0,
        ),
        sliver: SliverList(delegate: SliverChildListDelegate(children)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          originDetailSheetHorizontalPaddingForTesting,
          originDetailSectionGapForTesting,
          originDetailSheetHorizontalPaddingForTesting,
          24,
        ),
        sliver: _OriginCharactersSection(characters: widget.origin.characters),
      ),
    ];
  }

  Widget _buildOpeningPage(
    ScrollController scrollController,
    _OriginInitialDialoguePreview? initialDialoguePreview,
    String locationChatLocationId,
  ) {
    final hasOpeningBrief = _originWorldoBrief(widget.origin).isNotEmpty;
    final openingComposer = locationChatLocationId.isEmpty
        ? null
        : RepaintBoundary(
            child: _buildExpandedOpeningComposer(locationChatLocationId),
          );
    final composerLifted = _openingKeyboardMode;
    final flowComposer = composerLifted ? null : openingComposer;
    return AnimatedBuilder(
      animation: _roleEditing,
      builder: (context, _) {
        final roleEditing = _roleEditing.value;
        return KeyedSubtree(
          key: const ValueKey<String>('origin-detail-sheet-page-Opening'),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            resizeToAvoidBottomInset: !roleEditing && !_openingKeyboardMode,
            bottomNavigationBar:
                !roleEditing && !composerLifted && _openingComposerDocked
                ? flowComposer
                : null,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final contentScrollEnabled =
                    _sheetInteraction.contentScrollEnabled;
                return Stack(
                  key: _openingPageStackKey,
                  children: [
                    CustomScrollView(
                      controller: scrollController,
                      key: PageStorageKey<String>(
                        'origin-detail-bottom-sheet-${widget.origin.oid}',
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: contentScrollEnabled
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      slivers: [
                        const PinnedHeaderSliver(
                          child: _OriginSheetPinnedHeader(topPadding: 0),
                        ),
                        if (widget.autoExpansionPending)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: KeyedSubtree(
                              key: const ValueKey<String>(
                                'origin-opening-sheet-tombstone',
                              ),
                              child: const _OriginSheetLoadingContent(),
                            ),
                          )
                        else ...[
                          if (widget.launchedPresetRoles?.isNotEmpty == true)
                            SliverToBoxAdapter(
                              child: IgnorePointer(
                                ignoring: _openingKeyboardMode,
                                child: Opacity(
                                  opacity: _openingKeyboardMode ? 0 : 1,
                                  child: _OriginLaunchedWorldsSection(
                                    roles: widget.launchedPresetRoles!,
                                    onEnterWorld: widget.onEnterLaunchedWorld,
                                  ),
                                ),
                              ),
                            ),
                          AnimatedBuilder(
                            animation:
                                _sheetInteraction.keyboardFrameListenable,
                            child: SliverMainAxisGroup(
                              slivers: [
                                if (_openingKeyboardMode &&
                                    !hasOpeningBrief &&
                                    initialDialoguePreview == null)
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      key: _openingKeyboardContentStartKey,
                                    ),
                                  ),
                                ..._originWorldoBriefSlivers(
                                  widget.origin,
                                  contentStartKey:
                                      _openingKeyboardMode && hasOpeningBrief
                                      ? _openingKeyboardContentStartKey
                                      : null,
                                ),
                                if (initialDialoguePreview != null &&
                                    initialDialoguePreview.messages.isNotEmpty)
                                  ..._originInitialDialogueSlivers(
                                    context,
                                    widget.origin,
                                    initialDialoguePreview,
                                    contentStartKey:
                                        _openingKeyboardMode && !hasOpeningBrief
                                        ? _openingKeyboardContentStartKey
                                        : null,
                                    messageEndKey: _openingKeyboardMode
                                        ? _openingKeyboardMessageEndKey
                                        : null,
                                    eager: _openingKeyboardMode,
                                  )
                                else ...[
                                  if (initialDialoguePreview != null)
                                    ..._originInitialDialogueSlivers(
                                      context,
                                      widget.origin,
                                      initialDialoguePreview,
                                      contentStartKey:
                                          _openingKeyboardMode &&
                                              !hasOpeningBrief
                                          ? _openingKeyboardContentStartKey
                                          : null,
                                      eager: _openingKeyboardMode,
                                    ),
                                  if (_openingKeyboardMode)
                                    SliverToBoxAdapter(
                                      child: SizedBox(
                                        key: _openingKeyboardMessageEndKey,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            builder: (context, child) {
                              final actualContentOffset =
                                  scrollController.hasClients
                                  ? scrollController.offset
                                  : _openingKeyboardNormalScrollOffset;
                              return _OriginSliverPaintTranslation(
                                translation: Offset(
                                  0,
                                  _sheetInteraction.contentTranslation(
                                    actualContentOffset,
                                  ),
                                ),
                                sliver: child!,
                              );
                            },
                          ),
                          if (openingComposer != null)
                            SliverLayoutBuilder(
                              key: const ValueKey<String>(
                                'origin-opening-composer-layout-boundary',
                              ),
                              builder: (context, constraints) {
                                if (!_openingKeyboardMode) {
                                  final effectiveDocked = _sheetInteraction
                                      .effectiveOpeningComposerDocked;
                                  _reportOpeningComposerDocked(
                                    originOpeningComposerShouldDockForTesting(
                                      remainingPaintExtent:
                                          constraints.remainingPaintExtent,
                                      composerHeight:
                                          _expandedOpeningComposerHeight,
                                      currentlyDocked: effectiveDocked,
                                    ),
                                  );
                                }
                                return SliverToBoxAdapter(
                                  child:
                                      _openingComposerDocked || composerLifted
                                      ? SizedBox(
                                          key: const ValueKey<String>(
                                            'origin-opening-composer-placeholder',
                                          ),
                                          height:
                                              _expandedOpeningComposerHeight,
                                        )
                                      : flowComposer ?? const SizedBox.shrink(),
                                );
                              },
                            ),
                          SliverToBoxAdapter(
                            child: IgnorePointer(
                              ignoring: _openingKeyboardMode,
                              child: Opacity(
                                opacity: _openingKeyboardMode ? 0 : 1,
                                child: _OriginSetupRoleSection(
                                  key: _roleSectionKey,
                                  scrollController: scrollController,
                                  characters: widget.origin.characters,
                                  launchBusy: widget.activeLaunchSource != null,
                                  launching:
                                      widget.activeLaunchSource ==
                                      OriginLaunchSource.openingSelect,
                                  profileRole: widget.profileRole,
                                  selectedRoleId: widget.locationChatRole.id,
                                  onSelectedRoleChanged:
                                      widget.onSelectLocationChatRole,
                                  onSelectRole: widget.onSelectRole,
                                  onSaveProfileRole: widget.onSaveProfileRole,
                                  onSelectProfileRole:
                                      widget.onSelectProfileRole,
                                  onRoleEditingChanged:
                                      _handleRoleEditingChanged,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: IgnorePointer(
                              ignoring: _openingKeyboardMode,
                              child: Opacity(
                                opacity: _openingKeyboardMode ? 0 : 1,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _roleEditing,
                                  builder: (context, editing, child) =>
                                      SizedBox(
                                        height: editing
                                            ? _OriginSetupRoleSection
                                                      ._cardWidth +
                                                  _OriginSetupRoleSection
                                                      ._buttonHeight
                                            : 0,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          if (_openingKeyboardMode)
                            AnimatedBuilder(
                              animation:
                                  _sheetInteraction.keyboardFrameListenable,
                              builder: (context, _) => SliverToBoxAdapter(
                                child: SizedBox(
                                  height:
                                      _openingKeyboardTargetInset +
                                      _openingKeyboardAdditionalScrollExtent,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                    if (_openingKeyboardMode &&
                        _openingKeyboardPhase !=
                            _OriginOpeningKeyboardPhase.open)
                      const Positioned.fill(
                        child: AbsorbPointer(
                          child: ColoredBox(color: Colors.transparent),
                        ),
                      ),
                    if (composerLifted && openingComposer != null)
                      AnimatedBuilder(
                        animation: _sheetInteraction.keyboardFrameListenable,
                        child: openingComposer,
                        builder: (context, child) => Positioned(
                          left: 0,
                          right: 0,
                          top: _sheetInteraction.composerTop(
                            constraints.maxHeight,
                          ),
                          child: child!,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
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
          const PinnedHeaderSliver(
            child: _OriginSheetPinnedHeader(topPadding: 0),
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
    final locationChatLocationId = _originLaunchChatLocationId(widget.origin);
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
              final bottomInset = GenesisSafeAreaInsets.bottom(
                context,
                minimum: 24,
              );
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
                        ValueListenableBuilder<bool>(
                          valueListenable: _roleEditing,
                          child: NotificationListener<ScrollEndNotification>(
                            onNotification: _handlePageScrollEnd,
                            child: PageView.builder(
                              key: const ValueKey<String>(
                                'origin-detail-sheet-pages',
                              ),
                              controller: _pageController,
                              itemCount: 2,
                              physics: _openingKeyboardMode
                                  ? const NeverScrollableScrollPhysics()
                                  : const PageScrollPhysics(),
                              itemBuilder: (context, page) {
                                final pageScrollController = _sheetInteraction
                                    .pageScrollControllerFor(page);
                                return page == _originOpeningSheetPageIndex
                                    ? _buildOpeningPage(
                                        pageScrollController,
                                        initialDialoguePreview,
                                        locationChatLocationId,
                                      )
                                    : _buildInfoPage(pageScrollController);
                              },
                            ),
                          ),
                          builder: (context, roleEditing, child) {
                            final roleEditorKeyboardInset = roleEditing
                                ? MediaQuery.viewInsetsOf(context).bottom
                                      .clamp(
                                        0.0,
                                        MediaQuery.sizeOf(context).height,
                                      )
                                      .toDouble()
                                : 0.0;
                            return Padding(
                              key: const ValueKey<String>(
                                'origin-detail-sheet-keyboard-safe-content',
                              ),
                              padding: EdgeInsets.only(
                                bottom: roleEditorKeyboardInset,
                              ),
                              child: child,
                            );
                          },
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
          colors: const [
            originWorldDetailSheetBackgroundColor,
            originWorldDetailSheetBackgroundColor,
            Color(0x00151517),
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
                  originWorldDetailSheetSelectRoleArrowColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Select your role',
                key: ValueKey<String>('origin-opening-select-role-label'),
                style: TextStyle(
                  color: originWorldDetailSheetSecondaryTextColor,
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

  static const Color _activeColor = originWorldDetailSheetPrimaryTextColor;
  static const Color _inactiveColor = originWorldDetailSheetTertiaryTextColor;

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

class _OriginSheetPinnedHeader extends StatelessWidget {
  const _OriginSheetPinnedHeader({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: topPadding + originDetailSheetHeaderHeightForTesting,
      child: const ColoredBox(color: originWorldDetailSheetBackgroundColor),
    );
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
    final metaStyle = CopyableIdLabel.textStyle.copyWith(
      height: 1.2,
      color: originWorldDetailSheetSecondaryTextColor,
    );

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
                      color: originWorldDetailSheetSoftWhiteColor,
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
                    customIconColor: originWorldDetailSheetSecondaryTextColor,
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
                    trailingIconColor: originWorldDetailSheetSecondaryTextColor,
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
            'Detail',
            key: ValueKey<String>('origin-info-title'),
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: originWorldDetailSheetPrimaryTextColor,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        GenesisMoreActionMenuButton(
          key: const ValueKey<String>('origin-info-report-menu'),
          buttonSize: 18 * 1.25,
          iconColor: originWorldDetailSheetPrimaryTextColor,
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
    required this.value,
  });

  final String iconAsset;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      iconAsset: iconAsset,
      iconSize: 12,
      iconColor: originWorldDetailSheetSecondaryTextColor,
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
        color: originWorldDetailSheetSecondaryTextColor,
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
