part of 'origin_world_page.dart';

const int _originOpeningSheetPageIndex = 0;
const int _originInfoSheetPageIndex = 1;
const double _originSheetInteractionEpsilon = 0.001;
const int _originOpeningKeyboardSettleFrameCount = 10;

enum _OriginOpeningKeyboardPhase {
  idle,
  preparing,
  opening,
  open,
  closing,
  restoring,
}

@immutable
class _OriginOpeningKeyboardLayout {
  const _OriginOpeningKeyboardLayout({
    required this.sheetHeight,
    required this.composerTop,
  });

  final double sheetHeight;
  final double composerTop;
}

@immutable
class _OriginOpeningKeyboardContentBounds {
  const _OriginOpeningKeyboardContentBounds({
    required this.top,
    required this.bottom,
  });

  final double top;
  final double bottom;
}

@visibleForTesting
double originOpeningEffectiveKeyboardInsetForTesting({
  required double rawKeyboardInset,
  required double bottomSafeAreaInset,
}) {
  return math.max(0.0, rawKeyboardInset - bottomSafeAreaInset);
}

@visibleForTesting
double originOpeningKeyboardProgressForTesting({
  required double currentInset,
  required double startInset,
  required double endInset,
}) {
  final distance = endInset - startInset;
  if (distance.abs() < 0.5) return currentInset >= endInset ? 1 : 0;
  return ((currentInset - startInset) / distance).clamp(0.0, 1.0).toDouble();
}

@visibleForTesting
double originOpeningKeyboardComposerTopForTesting({
  required double startTop,
  required double sheetHeight,
  required double composerHeight,
  required double keyboardInset,
  required double progress,
}) {
  final endTop = sheetHeight - keyboardInset - composerHeight;
  return startTop + (endTop - startTop) * progress.clamp(0.0, 1.0);
}

@visibleForTesting
double originOpeningKeyboardVisibleComposerTopForTesting({
  required double animatedTop,
  required double sheetHeight,
  required double composerHeight,
  required double actualKeyboardInset,
}) {
  final inset = actualKeyboardInset.clamp(0.0, sheetHeight).toDouble();
  if (inset <= 0.5) return animatedTop;
  final keyboardBoundTop = sheetHeight - inset - composerHeight;
  return math.min(animatedTop, keyboardBoundTop);
}

@visibleForTesting
double originOpeningKeyboardContentTargetOffsetForTesting({
  required double layoutOffset,
  required double preservedOffset,
  required double contentTop,
  required double contentBottom,
  required double composerTop,
  required double gap,
}) {
  final contentHeight = math.max(0.0, contentBottom - contentTop);
  final naturalContentTop = contentTop + layoutOffset;
  final availableHeight = composerTop - gap - naturalContentTop;
  if (contentHeight <= availableHeight) {
    return contentTop < 0 ? naturalContentTop : preservedOffset;
  }
  return layoutOffset + contentBottom - composerTop + gap;
}

@visibleForTesting
double originOpeningKeyboardAdditionalScrollExtentForTesting({
  required double targetOffset,
  required double maxScrollExtent,
}) {
  return math.max(0.0, targetOffset - maxScrollExtent);
}

@visibleForTesting
double originOpeningKeyboardFlowRestingOffsetForTesting({
  required double layoutOffset,
  required double contentBottom,
  required double sheetHeight,
  required double composerHeight,
  required double gap,
}) {
  final flowComposerTop = sheetHeight - composerHeight;
  return math.max(0.0, layoutOffset + contentBottom - flowComposerTop + gap);
}

@visibleForTesting
double originOpeningKeyboardSettledTargetInsetForTesting({
  required double nativeTargetInset,
  required double actualInset,
  required int stableFrameCount,
}) {
  if (stableFrameCount >= _originOpeningKeyboardSettleFrameCount &&
      actualInset > 0.5) {
    return actualInset;
  }
  return nativeTargetInset;
}

@visibleForTesting
double originOpeningKeyboardLogicalCoordinateAtStartForTesting({
  required double logicalCoordinate,
  required double startVisualOffset,
}) {
  return logicalCoordinate - startVisualOffset;
}

class _OriginWorldSheetFrameNotifier extends ChangeNotifier {
  void notifyFrame() => notifyListeners();
}

enum _OriginRoleEditorPhase {
  idle,
  preparing,
  opening,
  open,
  suspended,
  closingCommit,
  closingCancel,
  restoring,
}

@immutable
class _OriginRoleEditorLayout {
  const _OriginRoleEditorLayout({
    required this.viewHeight,
    required this.cardBottom,
  });

  final double viewHeight;
  final double cardBottom;
}

@visibleForTesting
double originRoleEditorTargetScrollOffsetForTesting({
  required double startScrollOffset,
  required double cardBottom,
  required double viewHeight,
  required double keyboardInset,
  double keyboardGap = 30,
}) {
  final keyboardTop = viewHeight - keyboardInset;
  final desiredBottom = keyboardTop - keyboardGap;
  return startScrollOffset + cardBottom - desiredBottom;
}

@visibleForTesting
double originRoleEditorAdditionalScrollExtentForTesting({
  required double targetScrollOffset,
  required double minScrollExtent,
  required double currentMaxScrollExtent,
  required double retainedAdditionalExtent,
}) {
  final baseMaxScrollExtent = math.max(
    minScrollExtent,
    currentMaxScrollExtent - retainedAdditionalExtent,
  );
  return math.max(0.0, targetScrollOffset - baseMaxScrollExtent);
}

class _OriginRoleEditorInteractionController extends ChangeNotifier {
  static const int _keyboardSettleFrameCount = 10;

  _OriginRoleEditorInteractionController({
    required this.readKeyboardInset,
    required this.readLayout,
    required this.readSheetExtent,
    required this.restoreSheetExtent,
    required this.onCommit,
  }) {
    _keyboardAnimationSubscription = GenesisKeyboardAnimationEvents.targets
        .listen(_handleKeyboardAnimationTarget, onError: (_) {});
  }

  static const double keyboardGap = 30;

  final double Function() readKeyboardInset;
  final _OriginRoleEditorLayout? Function() readLayout;
  final double Function() readSheetExtent;
  final ValueChanged<double> restoreSheetExtent;
  final ValueChanged<OriginCustomRoleDraft> onCommit;
  final _OriginWorldSheetFrameNotifier _frameNotifier =
      _OriginWorldSheetFrameNotifier();

  StreamSubscription<GenesisKeyboardAnimationTarget>?
  _keyboardAnimationSubscription;
  ScrollController? _scrollController;
  var _phase = _OriginRoleEditorPhase.idle;
  var _disposed = false;
  var _hasFieldFocus = false;
  var _internalInteractionActive = false;
  var _protectedFocusLoss = false;
  var _keyboardInset = 0.0;
  var _targetInset = 0.0;
  var _targetKnown = false;
  var _startScrollOffset = 0.0;
  var _visualScrollOffset = 0.0;
  var _targetScrollOffset = 0.0;
  var _closingStartInset = 0.0;
  var _closingStartVisualOffset = 0.0;
  var _additionalScrollExtent = 0.0;
  var _sheetExtent = 0.0;
  var _stableFrameCount = 0;
  var _settleScheduled = false;
  var _commitRetryScheduled = false;
  var _lastNativeGeneration = -1;
  _OriginRoleEditorLayout? _layout;
  _OriginRoleEditorPhase? _restoredPhase;

  _OriginRoleEditorPhase get phase => _phase;
  bool get editing => _phase != _OriginRoleEditorPhase.idle;
  bool get contentScrollEnabled => !editing;
  double get additionalScrollExtent => _additionalScrollExtent;
  Listenable get frameListenable => _frameNotifier;

  void attachScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  bool beginEditing() {
    if (_disposed || editing) return false;
    final layout = readLayout();
    final controller = _scrollController;
    if (layout == null || controller == null || !controller.hasClients) {
      return false;
    }
    _layout = layout;
    _startScrollOffset = controller.offset;
    _visualScrollOffset = _startScrollOffset;
    _targetScrollOffset = _startScrollOffset;
    _additionalScrollExtent = 0;
    _keyboardInset = readKeyboardInset();
    _targetInset = _keyboardInset;
    _targetKnown = _keyboardInset > 0.5;
    _sheetExtent = readSheetExtent();
    _stableFrameCount = 0;
    _hasFieldFocus = false;
    _protectedFocusLoss = false;
    _internalInteractionActive = false;
    _phase = _OriginRoleEditorPhase.preparing;
    _notifyChanged();
    return true;
  }

  void reset() {
    if (_disposed) return;
    final controller = _scrollController;
    if (editing && controller != null && controller.hasClients) {
      controller.jumpTo(
        _startScrollOffset.clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        ),
      );
    }
    _phase = _OriginRoleEditorPhase.idle;
    _layout = null;
    _keyboardInset = 0;
    _targetInset = 0;
    _targetKnown = false;
    _additionalScrollExtent = 0;
    _hasFieldFocus = false;
    _internalInteractionActive = false;
    _protectedFocusLoss = false;
    _notifyFrameChanged();
    _notifyChanged();
  }

  void confirmEditing(OriginCustomRoleDraft draft) {
    if (_disposed || !editing || _isClosing) return;
    onCommit(draft);
    _beginClosing(_OriginRoleEditorPhase.closingCommit);
  }

  void cancelEditing() {
    if (_disposed || !editing || _isClosing) return;
    _beginClosing(_OriginRoleEditorPhase.closingCancel);
  }

  void handleFieldFocusChanged(bool hasFocus) {
    if (_disposed || !editing) return;
    _hasFieldFocus = hasFocus;
    if (hasFocus) {
      _protectedFocusLoss = false;
      if (_phase == _OriginRoleEditorPhase.suspended) {
        _prepareForReopenedKeyboard();
      }
      return;
    }
    if (_internalInteractionActive) {
      _protectedFocusLoss = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !editing || _hasFieldFocus || _protectedFocusLoss) {
        return;
      }
      cancelEditing();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void setInternalInteractionActive(bool active) {
    if (_disposed || !editing) return;
    _internalInteractionActive = active;
    if (active) _protectedFocusLoss = true;
    if (!active && _hasFieldFocus) _protectedFocusLoss = false;
  }

  void handleKeyboardMetrics(double rawInset) {
    if (_disposed || !editing) return;
    final inset = rawInset.clamp(0.0, double.infinity).toDouble();
    final wasInset = _keyboardInset;
    if (inset > wasInset + 0.5 &&
        (_phase == _OriginRoleEditorPhase.preparing ||
            _phase == _OriginRoleEditorPhase.suspended)) {
      _phase = _OriginRoleEditorPhase.opening;
      _notifyChanged();
    } else if (inset + 0.5 < wasInset && !_isClosing) {
      if (_internalInteractionActive || _protectedFocusLoss) {
        _beginClosing(
          _OriginRoleEditorPhase.restoring,
          restoredPhase: _OriginRoleEditorPhase.suspended,
        );
      } else {
        _beginClosing(_OriginRoleEditorPhase.closingCancel);
      }
    }
    _keyboardInset = inset;
    if ((_keyboardInset - wasInset).abs() < 0.5) {
      _stableFrameCount += 1;
    } else {
      _stableFrameCount = 0;
    }
    if (_phase == _OriginRoleEditorPhase.opening) {
      if (!_targetKnown && inset > 0.5) {
        _configureTarget(inset);
      }
      if (_targetKnown) {
        final progress = originOpeningKeyboardProgressForTesting(
          currentInset: inset,
          startInset: 0,
          endInset: _targetInset,
        );
        _visualScrollOffset = lerpDouble(
          _startScrollOffset,
          _targetScrollOffset,
          progress,
        )!;
      } else {
        _configureTarget(inset);
        _visualScrollOffset = _targetScrollOffset;
      }
      _notifyFrameChanged();
      if (_stableFrameCount >= _keyboardSettleFrameCount && inset > 0.5) {
        _configureTarget(inset);
        _visualScrollOffset = _targetScrollOffset;
        _notifyFrameChanged();
        _commitOpenPosition();
      }
    } else if (_isClosing || _phase == _OriginRoleEditorPhase.restoring) {
      final progress = _closingStartInset <= 0.5
          ? 1.0
          : (1 - inset / _closingStartInset).clamp(0.0, 1.0).toDouble();
      _visualScrollOffset = lerpDouble(
        _closingStartVisualOffset,
        _startScrollOffset,
        progress,
      )!;
      _notifyFrameChanged();
      if (inset <= 0.5 && _stableFrameCount >= _keyboardSettleFrameCount) {
        _finishClosing();
      }
    }
    if (_phase == _OriginRoleEditorPhase.opening || _isClosing) {
      _scheduleSettleCheck();
    }
  }

  void _prepareForReopenedKeyboard() {
    final layout = readLayout();
    final controller = _scrollController;
    if (layout == null || controller == null || !controller.hasClients) return;
    _layout = layout;
    _startScrollOffset = controller.offset;
    _visualScrollOffset = _startScrollOffset;
    _targetScrollOffset = _startScrollOffset;
    _additionalScrollExtent = 0;
    _keyboardInset = readKeyboardInset();
    _targetInset = _keyboardInset;
    _targetKnown = _keyboardInset > 0.5;
    _stableFrameCount = 0;
    _phase = _OriginRoleEditorPhase.preparing;
    _notifyChanged();
  }

  bool get _isClosing =>
      _phase == _OriginRoleEditorPhase.closingCommit ||
      _phase == _OriginRoleEditorPhase.closingCancel ||
      _phase == _OriginRoleEditorPhase.restoring;

  void _handleKeyboardAnimationTarget(GenesisKeyboardAnimationTarget target) {
    if (_disposed || target.generation <= _lastNativeGeneration) return;
    _lastNativeGeneration = target.generation;
    if (!editing) return;
    if (target.direction == GenesisKeyboardAnimationDirection.closing) {
      if (!_isClosing) {
        if (_internalInteractionActive || _protectedFocusLoss) {
          _beginClosing(
            _OriginRoleEditorPhase.restoring,
            restoredPhase: _OriginRoleEditorPhase.suspended,
          );
        } else {
          _beginClosing(_OriginRoleEditorPhase.closingCancel);
        }
      }
      return;
    }
    if (_isClosing) return;
    _targetKnown = true;
    _configureTarget(target.endInset);
    _phase = _OriginRoleEditorPhase.opening;
    _stableFrameCount = 0;
    _notifyChanged();
    handleKeyboardMetrics(readKeyboardInset());
  }

  void _configureTarget(double inset) {
    final layout = _layout;
    if (layout == null) return;
    _targetInset = inset.clamp(0.0, double.infinity).toDouble();
    _targetScrollOffset = originRoleEditorTargetScrollOffsetForTesting(
      startScrollOffset: _startScrollOffset,
      cardBottom: layout.cardBottom,
      viewHeight: layout.viewHeight,
      keyboardInset: _targetInset,
      keyboardGap: keyboardGap,
    );
    final controller = _scrollController;
    if (controller != null && controller.hasClients) {
      _additionalScrollExtent =
          originRoleEditorAdditionalScrollExtentForTesting(
            targetScrollOffset: _targetScrollOffset,
            minScrollExtent: controller.position.minScrollExtent,
            currentMaxScrollExtent: controller.position.maxScrollExtent,
            retainedAdditionalExtent: _additionalScrollExtent,
          );
    }
    _notifyFrameChanged();
  }

  void _commitOpenPosition() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    if (_targetScrollOffset < controller.position.minScrollExtent) {
      // There is no leading scroll extent to commit when a short page needs
      // the editor to move down. Keep the equivalent paint translation until
      // the keyboard closes; outer scrolling is locked for the edit session.
      _visualScrollOffset = _targetScrollOffset;
      _phase = _OriginRoleEditorPhase.open;
      _notifyFrameChanged();
      _notifyChanged();
      return;
    }
    final missing = _targetScrollOffset - controller.position.maxScrollExtent;
    if (missing > 0.5) {
      _additionalScrollExtent += missing + 0.5;
      _notifyFrameChanged();
      _scheduleCommitRetry();
      return;
    }
    controller.jumpTo(
      _targetScrollOffset.clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
    _visualScrollOffset = controller.offset;
    _phase = _OriginRoleEditorPhase.open;
    _notifyFrameChanged();
    _notifyChanged();
  }

  void _scheduleCommitRetry() {
    if (_commitRetryScheduled) return;
    _commitRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commitRetryScheduled = false;
      if (!_disposed && _phase == _OriginRoleEditorPhase.opening) {
        _commitOpenPosition();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _beginClosing(
    _OriginRoleEditorPhase closingPhase, {
    _OriginRoleEditorPhase? restoredPhase,
  }) {
    if (_disposed || !editing) return;
    _closingStartInset = math.max(_keyboardInset, readKeyboardInset());
    _closingStartVisualOffset = _visualScrollOffset;
    _restoredPhase = restoredPhase;
    _stableFrameCount = 0;
    _phase = closingPhase;
    _notifyChanged();
    if (_closingStartInset <= 0.5) {
      _keyboardInset = 0;
      _stableFrameCount = _keyboardSettleFrameCount;
      _finishClosing();
    }
  }

  void _finishClosing() {
    if (_phase == _OriginRoleEditorPhase.restoring && _restoredPhase == null) {
      return;
    }
    final finalPhase = _restoredPhase ?? _OriginRoleEditorPhase.idle;
    _phase = _OriginRoleEditorPhase.restoring;
    _notifyChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _phase != _OriginRoleEditorPhase.restoring) return;
      final controller = _scrollController;
      if (controller != null && controller.hasClients) {
        controller.jumpTo(
          _startScrollOffset.clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          ),
        );
      }
      if (_sheetExtent > 0) restoreSheetExtent(_sheetExtent);
      _visualScrollOffset = _startScrollOffset;
      _additionalScrollExtent = 0;
      _keyboardInset = 0;
      _targetInset = 0;
      _targetKnown = false;
      _stableFrameCount = 0;
      _restoredPhase = null;
      _phase = finalPhase;
      _notifyFrameChanged();
      _notifyChanged();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scheduleSettleCheck() {
    if (_settleScheduled || !editing) return;
    _settleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      if (_disposed || !editing) return;
      handleKeyboardMetrics(readKeyboardInset());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  double contentTranslation(double actualScrollOffset) {
    return editing ? actualScrollOffset - _visualScrollOffset : 0;
  }

  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  void _notifyFrameChanged() {
    if (!_disposed) _frameNotifier.notifyFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_keyboardAnimationSubscription?.cancel());
    _frameNotifier.dispose();
    super.dispose();
  }
}

class _OriginWorldSheetInteractionController extends ChangeNotifier {
  _OriginWorldSheetInteractionController({
    required this.canPrepareKeyboard,
    required this.readKeyboardInset,
    required this.readKeyboardSafeAreaInset,
    required this.readKeyboardLayout,
    required this.readKeyboardContentBounds,
    required this.readSheetExtent,
    required this.readFallbackExpandedSheetExtent,
    required this.restoreSheetExtent,
    required this.readContentToComposerGap,
    required this.onPageSelected,
  }) {
    _keyboardAnimationSubscription = GenesisKeyboardAnimationEvents.targets
        .listen(_handleKeyboardAnimationTarget, onError: (_) {});
  }

  final bool Function() canPrepareKeyboard;
  final double Function() readKeyboardInset;
  final double Function() readKeyboardSafeAreaInset;
  final _OriginOpeningKeyboardLayout? Function() readKeyboardLayout;
  final _OriginOpeningKeyboardContentBounds? Function()
  readKeyboardContentBounds;
  final double Function() readSheetExtent;
  final double Function() readFallbackExpandedSheetExtent;
  final ValueChanged<double> restoreSheetExtent;
  final double? Function() readContentToComposerGap;
  final ValueChanged<int> onPageSelected;

  final PageController pageController = PageController(
    initialPage: _originOpeningSheetPageIndex,
  );
  final ScrollController openingPreviewScrollController = ScrollController();
  final ScrollController infoPreviewScrollController = ScrollController();
  final _OriginWorldSheetFrameNotifier _keyboardFrameNotifier =
      _OriginWorldSheetFrameNotifier();

  ScrollController? _sheetScrollController;
  StreamSubscription<GenesisKeyboardAnimationTarget>?
  _keyboardAnimationSubscription;
  var _disposed = false;
  var _currentPage = _originOpeningSheetPageIndex;
  var _composerHeight = 0.0;
  var _keyboardPhase = _OriginOpeningKeyboardPhase.idle;
  var _keyboardInset = 0.0;
  var _keyboardTargetInset = 0.0;
  var _keyboardProgress = 0.0;
  var _keyboardSheetHeight = 0.0;
  var _keyboardStartComposerTop = 0.0;
  var _keyboardContentTop = 0.0;
  var _keyboardContentBottom = 0.0;
  var _keyboardContentToComposerGap = 0.0;
  var _keyboardNormalScrollOffset = 0.0;
  var _keyboardStartVisualOffset = 0.0;
  var _keyboardAdditionalScrollExtent = 0.0;
  var _keyboardSheetExtent = 0.0;
  var _keyboardClosingVisualOffset = 0.0;
  var _keyboardClosingTargetVisualOffset = 0.0;
  var _keyboardClosingTargetComposerTop = 0.0;
  var _keyboardScrollCommitted = false;
  var _keyboardCommitRetryScheduled = false;
  var _keyboardStableFrameCount = 0;
  var _keyboardSettleCheckScheduled = false;
  var _keyboardChangingHeight = false;
  var _keyboardAnimationTargetKnown = false;
  var _keyboardChangeStartInset = 0.0;
  var _keyboardChangeStartComposerTop = 0.0;
  var _keyboardChangeStartVisualOffset = 0.0;
  var _keyboardLastNativeGeneration = -1;
  GenesisKeyboardAnimationTarget? _pendingKeyboardAnimationTarget;

  int get currentPage => _currentPage;
  double get composerHeight => _composerHeight;
  _OriginOpeningKeyboardPhase get keyboardPhase => _keyboardPhase;
  double get keyboardInset => _keyboardInset;
  double get keyboardTargetInset => _keyboardTargetInset;
  double get keyboardProgress => _keyboardProgress;
  double get keyboardStartComposerTop => _keyboardStartComposerTop;
  double get keyboardChangeStartComposerTop => _keyboardChangeStartComposerTop;
  double get keyboardNormalScrollOffset => _keyboardNormalScrollOffset;
  double get keyboardAdditionalScrollExtent => _keyboardAdditionalScrollExtent;
  bool get keyboardChangingHeight => _keyboardChangingHeight;
  bool get keyboardMode => _keyboardPhase != _OriginOpeningKeyboardPhase.idle;
  bool get keyboardTransitionActive =>
      _keyboardPhase == _OriginOpeningKeyboardPhase.opening ||
      _keyboardPhase == _OriginOpeningKeyboardPhase.open ||
      _keyboardPhase == _OriginOpeningKeyboardPhase.closing;
  bool get contentScrollEnabled =>
      !keyboardMode || _keyboardPhase == _OriginOpeningKeyboardPhase.open;
  Listenable get keyboardFrameListenable => _keyboardFrameNotifier;

  double get page {
    return pageController.hasClients
        ? pageController.page ?? _currentPage.toDouble()
        : _currentPage.toDouble();
  }

  void attachSheetScrollController(ScrollController controller) {
    _sheetScrollController = controller;
  }

  ScrollController pageScrollControllerFor(int pageIndex) {
    if (pageIndex == _currentPage && _sheetScrollController != null) {
      return _sheetScrollController!;
    }
    return pageIndex == _originOpeningSheetPageIndex
        ? openingPreviewScrollController
        : infoPreviewScrollController;
  }

  void resetForContentChange({required bool resetPage}) {
    resetKeyboard(clearFocus: true);
    if (resetPage) {
      _currentPage = _originOpeningSheetPageIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !pageController.hasClients) return;
        pageController.jumpToPage(_originOpeningSheetPageIndex);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    if (resetPage) _notifyChanged();
  }

  bool handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.horizontal ||
        !pageController.hasClients) {
      return false;
    }
    selectPage(page.round());
    return false;
  }

  bool selectPage(int pageIndex) {
    if (keyboardMode || pageIndex == _currentPage) return false;
    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    _currentPage = pageIndex;
    onPageSelected(pageIndex);
    _notifyChanged();
    return true;
  }

  bool isCollapsedRoleActionVisible({required bool sheetRaised}) {
    final isOpeningPageSettled =
        _currentPage == _originOpeningSheetPageIndex &&
        (page - _originOpeningSheetPageIndex).abs() <=
            _originSheetInteractionEpsilon;
    return isOpeningPageSettled && !sheetRaised && !keyboardMode;
  }

  double expandedOpeningComposerProgress({
    required double sheetExtent,
    required double minChildSize,
    required bool autoExpansionPending,
  }) {
    final raisedProgress = ((sheetExtent - minChildSize) / 0.04)
        .clamp(0.0, 1.0)
        .toDouble();
    final openingProgress = (1.0 - page.clamp(0.0, 1.0)).toDouble();
    if (autoExpansionPending) return 0;
    return raisedProgress * openingProgress;
  }

  void updateComposerHeight(double height) {
    if ((_composerHeight - height).abs() < 0.5) return;
    _composerHeight = height;
    _notifyChanged();
  }

  double composerTop(
    double sheetHeight, {
    required double actualKeyboardInset,
  }) {
    final animatedTop = originOpeningKeyboardComposerTopForTesting(
      startTop:
          _keyboardPhase == _OriginOpeningKeyboardPhase.closing ||
              _keyboardPhase == _OriginOpeningKeyboardPhase.restoring
          ? _keyboardClosingTargetComposerTop
          : _keyboardChangingHeight
          ? _keyboardChangeStartComposerTop
          : _keyboardStartComposerTop,
      sheetHeight: sheetHeight,
      composerHeight: _composerHeight,
      keyboardInset: _keyboardTargetInset,
      progress: _keyboardProgress,
    );
    return originOpeningKeyboardVisibleComposerTopForTesting(
      animatedTop: animatedTop,
      sheetHeight: sheetHeight,
      composerHeight: _composerHeight,
      actualKeyboardInset: actualKeyboardInset,
    );
  }

  double composerTranslation() {
    if (!keyboardMode || _keyboardSheetHeight <= 0) return 0;
    return composerTop(
          _keyboardSheetHeight,
          actualKeyboardInset: _keyboardInset,
        ) -
        _keyboardStartComposerTop;
  }

  double contentTranslation(double actualContentOffset) {
    return keyboardMode
        ? actualContentOffset - keyboardVisualScrollOffset()
        : 0.0;
  }

  void handleKeyboardMetrics(double inset) {
    if (_disposed || !keyboardMode) return;
    if (!_keyboardChangingHeight &&
        inset > _keyboardInset + 0.5 &&
        _keyboardPhase == _OriginOpeningKeyboardPhase.open) {
      _resumeKeyboardFromCurrentVisualState(inset);
    } else if (!_keyboardChangingHeight &&
        inset + 0.5 < _keyboardInset &&
        (_keyboardPhase == _OriginOpeningKeyboardPhase.open ||
            _keyboardPhase == _OriginOpeningKeyboardPhase.opening)) {
      _beginKeyboardClosing();
    }
    _updateKeyboardInset(inset);
  }

  void handleComposerFocusChanged(bool hasFocus) {
    if (hasFocus) {
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
        _resumeKeyboardFromCurrentVisualState(_keyboardTargetInset);
        return;
      }
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.restoring) {
        resetKeyboard(settleAtFlowEnd: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _prepareKeyboardTransition();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
      _prepareKeyboardTransition();
    } else {
      _beginKeyboardClosing();
    }
  }

  void _handleKeyboardAnimationTarget(GenesisKeyboardAnimationTarget target) {
    if (_disposed || target.generation <= _keyboardLastNativeGeneration) {
      return;
    }
    _keyboardLastNativeGeneration = target.generation;
    final safeAreaInset = readKeyboardSafeAreaInset();
    final startInset = originOpeningEffectiveKeyboardInsetForTesting(
      rawKeyboardInset: target.startInset,
      bottomSafeAreaInset: safeAreaInset,
    );
    final endInset = originOpeningEffectiveKeyboardInsetForTesting(
      rawKeyboardInset: target.endInset,
      bottomSafeAreaInset: safeAreaInset,
    );
    if (!keyboardMode) {
      _pendingKeyboardAnimationTarget =
          target.direction != GenesisKeyboardAnimationDirection.closing &&
              endInset > 0.5
          ? GenesisKeyboardAnimationTarget(
              generation: target.generation,
              direction: target.direction,
              startInset: startInset,
              endInset: endInset,
              duration: target.duration,
            )
          : null;
      return;
    }
    _pendingKeyboardAnimationTarget = null;
    final isClosing =
        target.direction == GenesisKeyboardAnimationDirection.closing;
    if (isClosing) {
      _beginKeyboardClosing();
      _keyboardTargetInset = math.max(_keyboardTargetInset, startInset);
    } else if (target.direction == GenesisKeyboardAnimationDirection.changing) {
      _keyboardAnimationTargetKnown = true;
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.preparing) {
        _keyboardTargetInset = endInset;
        _updateKeyboardInset(readKeyboardInset());
        return;
      }
      final currentTop =
          readKeyboardLayout()?.composerTop ?? _keyboardStartComposerTop;
      final currentVisualOffset = keyboardVisualScrollOffset();
      final currentInset = readKeyboardInset();
      _keyboardChangingHeight = true;
      _keyboardChangeStartInset = currentInset;
      _keyboardChangeStartComposerTop = currentTop;
      _keyboardChangeStartVisualOffset = currentVisualOffset;
      _keyboardTargetInset = endInset;
      _keyboardProgress = 0;
      _keyboardScrollCommitted = false;
      _keyboardStableFrameCount = 0;
      _keyboardPhase = _OriginOpeningKeyboardPhase.opening;
      _notifyChanged();
    } else {
      _keyboardAnimationTargetKnown = true;
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
        _resumeKeyboardFromCurrentVisualState(endInset);
        _updateKeyboardInset(readKeyboardInset());
        return;
      }
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.open &&
          (endInset - _keyboardInset).abs() > 0.5) {
        _resumeKeyboardFromCurrentVisualState(endInset);
        _updateKeyboardInset(readKeyboardInset());
        return;
      }
      _keyboardTargetInset = endInset;
      if (keyboardTransitionActive &&
          _keyboardPhase != _OriginOpeningKeyboardPhase.open) {
        _keyboardPhase = _OriginOpeningKeyboardPhase.opening;
      }
      _notifyChanged();
    }
    _updateKeyboardInset(readKeyboardInset());
  }

  void _resumeKeyboardFromCurrentVisualState(double targetInset) {
    if (_disposed || !keyboardTransitionActive) return;
    final currentTop =
        readKeyboardLayout()?.composerTop ?? _keyboardStartComposerTop;
    final currentVisualOffset = keyboardVisualScrollOffset();
    _keyboardChangingHeight = true;
    _keyboardChangeStartInset = _keyboardInset;
    _keyboardChangeStartComposerTop = currentTop;
    _keyboardChangeStartVisualOffset = currentVisualOffset;
    _keyboardTargetInset = math.max(targetInset, _keyboardInset);
    _keyboardProgress = 0;
    _keyboardScrollCommitted = false;
    _keyboardStableFrameCount = 0;
    _keyboardPhase = _OriginOpeningKeyboardPhase.opening;
    _notifyChanged();
  }

  void _prepareKeyboardTransition() {
    if (_disposed || keyboardMode || !canPrepareKeyboard()) return;
    final layout = readKeyboardLayout();
    if (layout == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _prepareKeyboardTransition();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    final contentToComposerGap = readContentToComposerGap();
    if (contentToComposerGap == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _prepareKeyboardTransition();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    final normalController = _sheetScrollController;
    _keyboardSheetHeight = layout.sheetHeight;
    _keyboardStartComposerTop = layout.composerTop;
    _keyboardNormalScrollOffset =
        normalController != null && normalController.hasClients
        ? normalController.offset
        : 0;
    _keyboardStartVisualOffset = _keyboardNormalScrollOffset;
    _keyboardClosingTargetVisualOffset = _keyboardNormalScrollOffset;
    _keyboardClosingTargetComposerTop = _keyboardStartComposerTop;
    _keyboardContentToComposerGap = contentToComposerGap;
    final sheetExtent = readSheetExtent();
    _keyboardSheetExtent = sheetExtent > 0
        ? sheetExtent
        : readFallbackExpandedSheetExtent();
    _keyboardInset = readKeyboardInset();
    final pendingTarget = _pendingKeyboardAnimationTarget;
    _pendingKeyboardAnimationTarget = null;
    final hasPendingTarget =
        pendingTarget != null && pendingTarget.endInset > 0.5;
    _keyboardAnimationTargetKnown = hasPendingTarget;
    _keyboardTargetInset = hasPendingTarget
        ? pendingTarget.endInset
        : math.max(0, _keyboardInset);
    _keyboardProgress = 0;
    _keyboardStableFrameCount = 0;
    _keyboardScrollCommitted = false;
    _keyboardChangingHeight = false;
    _keyboardPhase = _OriginOpeningKeyboardPhase.preparing;
    _notifyChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activateKeyboardTransition();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _activateKeyboardTransition() {
    if (_disposed || _keyboardPhase != _OriginOpeningKeyboardPhase.preparing) {
      return;
    }
    final contentBounds = readKeyboardContentBounds();
    if (contentBounds == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _activateKeyboardTransition();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    _captureKeyboardContentBounds(contentBounds);
    final scrollController = _sheetScrollController;
    if (scrollController != null && scrollController.hasClients) {
      _keyboardAdditionalScrollExtent =
          originOpeningKeyboardAdditionalScrollExtentForTesting(
            targetOffset: _keyboardTargetScrollOffset(),
            maxScrollExtent: scrollController.position.maxScrollExtent,
          );
    }
    final currentInset = readKeyboardInset();
    final hasPendingKeyboardTarget = _keyboardTargetInset > currentInset + 0.5;
    _keyboardChangingHeight = hasPendingKeyboardTarget;
    _keyboardChangeStartInset = currentInset;
    _keyboardChangeStartComposerTop = _keyboardStartComposerTop;
    _keyboardChangeStartVisualOffset = _keyboardStartVisualOffset;
    _keyboardInset = currentInset;
    _keyboardTargetInset = math.max(_keyboardTargetInset, currentInset);
    _keyboardProgress = 0;
    _keyboardScrollCommitted = false;
    _keyboardStableFrameCount = 0;
    _keyboardPhase = _OriginOpeningKeyboardPhase.opening;
    _notifyChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _keyboardPhase != _OriginOpeningKeyboardPhase.opening) {
        return;
      }
      _updateKeyboardInset(readKeyboardInset());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _beginKeyboardClosing() {
    if (_disposed || !keyboardMode) return;
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.preparing) {
      resetKeyboard();
      return;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing ||
        _keyboardPhase == _OriginOpeningKeyboardPhase.restoring) {
      return;
    }
    _keyboardClosingVisualOffset = keyboardVisualScrollOffset();
    _keyboardClosingTargetVisualOffset = _keyboardFlowRestingScrollOffset();
    _keyboardClosingTargetComposerTop = _keyboardStartComposerTop;
    _keyboardChangingHeight = false;
    _keyboardPhase = _OriginOpeningKeyboardPhase.closing;
    _notifyChanged();
    _updateKeyboardInset(readKeyboardInset());
  }

  void _updateKeyboardInset(double rawInset) {
    if (_disposed || !keyboardMode) return;
    final inset = rawInset.clamp(0.0, double.infinity).toDouble();
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
      // The keyboard spacer and the underlying sliver extent can both settle
      // after focus is lost. Keep the flow-resting destination based on the
      // current layout instead of the snapshot taken on the first close frame.
      _keyboardClosingTargetVisualOffset = _keyboardFlowRestingScrollOffset();
    }
    final targetReady =
        _keyboardAnimationTargetKnown ||
        _keyboardStableFrameCount >= _originOpeningKeyboardSettleFrameCount;
    if (targetReady &&
        !_keyboardChangingHeight &&
        _keyboardPhase != _OriginOpeningKeyboardPhase.closing &&
        inset > _keyboardTargetInset) {
      _keyboardTargetInset = inset;
    }
    final targetInset = _keyboardTargetInset;
    final progress =
        !targetReady && _keyboardPhase == _OriginOpeningKeyboardPhase.opening
        ? 0.0
        : _keyboardChangingHeight
        ? originOpeningKeyboardProgressForTesting(
            currentInset: inset,
            startInset: _keyboardChangeStartInset,
            endInset: targetInset,
          )
        : targetInset <= 0.5
        ? (inset > 0.5 ? 1.0 : 0.0)
        : (inset / targetInset).clamp(0.0, 1.0).toDouble();
    final unchanged = (_keyboardInset - inset).abs() < 0.5;
    if (!unchanged) _keyboardStableFrameCount = 0;
    if ((_keyboardInset - inset).abs() < 0.01 &&
        (_keyboardProgress - progress).abs() < 0.001) {
      _finishKeyboardTransitionIfNeeded();
      if (_keyboardStableFrameCount < _originOpeningKeyboardSettleFrameCount) {
        _scheduleKeyboardSettleCheck();
      }
      return;
    }
    _keyboardInset = inset;
    _keyboardProgress = progress;
    _notifyKeyboardFrameChanged();
    _finishKeyboardTransitionIfNeeded();
    if (_keyboardStableFrameCount < _originOpeningKeyboardSettleFrameCount) {
      _scheduleKeyboardSettleCheck();
    }
  }

  void _scheduleKeyboardSettleCheck() {
    if (_keyboardSettleCheckScheduled || !keyboardMode) return;
    _keyboardSettleCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardSettleCheckScheduled = false;
      if (_disposed || !keyboardMode) return;
      final currentInset = readKeyboardInset();
      if ((_keyboardInset - currentInset).abs() < 0.5) {
        _keyboardStableFrameCount += 1;
      } else {
        _keyboardStableFrameCount = 0;
      }
      _updateKeyboardInset(currentInset);
      if ((_keyboardPhase == _OriginOpeningKeyboardPhase.opening ||
              _keyboardPhase == _OriginOpeningKeyboardPhase.closing) &&
          _keyboardStableFrameCount < _originOpeningKeyboardSettleFrameCount) {
        _scheduleKeyboardSettleCheck();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _finishKeyboardTransitionIfNeeded() {
    if (_disposed) return;
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.opening &&
        _keyboardStableFrameCount >= _originOpeningKeyboardSettleFrameCount &&
        _keyboardInset > 0.5) {
      final settledContentBounds = readKeyboardContentBounds();
      final settledTargetInset =
          originOpeningKeyboardSettledTargetInsetForTesting(
            nativeTargetInset: _keyboardTargetInset,
            actualInset: _keyboardInset,
            stableFrameCount: _keyboardStableFrameCount,
          );
      if ((_keyboardTargetInset - settledTargetInset).abs() >
              _originSheetInteractionEpsilon ||
          _keyboardProgress < 1) {
        // Native keyboard-frame notifications and Flutter's final viewInsets
        // can differ slightly around the bottom safe area. The settled Flutter
        // inset is the authoritative final geometry.
        _keyboardTargetInset = settledTargetInset;
        _keyboardProgress = 1;
        _notifyKeyboardFrameChanged();
      }
      if (settledContentBounds == null) {
        _scheduleKeyboardCommitRetry();
        return;
      }
      _captureKeyboardContentBounds(settledContentBounds);
      if (!_commitKeyboardScroll()) return;
      _keyboardChangingHeight = false;
      _keyboardPhase = _OriginOpeningKeyboardPhase.open;
      _notifyChanged();
      return;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing &&
        _keyboardInset <= 0.5 &&
        _keyboardStableFrameCount >= _originOpeningKeyboardSettleFrameCount) {
      _keyboardClosingTargetVisualOffset = _keyboardFlowRestingScrollOffset();
      _keyboardPhase = _OriginOpeningKeyboardPhase.restoring;
      _notifyChanged();
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed ||
            _keyboardPhase != _OriginOpeningKeyboardPhase.restoring) {
          return;
        }
        resetKeyboard(settleAtFlowEnd: true);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _captureKeyboardContentBounds(
    _OriginOpeningKeyboardContentBounds bounds,
  ) {
    // Sliver geometry is expressed in the scroll view's logical coordinate
    // space and is independent of its current paint correction. Convert it to
    // the visual coordinate at focus entry exactly once.
    _keyboardContentTop =
        originOpeningKeyboardLogicalCoordinateAtStartForTesting(
          logicalCoordinate: bounds.top,
          startVisualOffset: _keyboardStartVisualOffset,
        );
    _keyboardContentBottom =
        originOpeningKeyboardLogicalCoordinateAtStartForTesting(
          logicalCoordinate: bounds.bottom,
          startVisualOffset: _keyboardStartVisualOffset,
        );
  }

  bool _commitKeyboardScroll() {
    final controller = _sheetScrollController;
    if (_keyboardScrollCommitted) return true;
    if (controller == null || !controller.hasClients) {
      _scheduleKeyboardCommitRetry();
      return false;
    }
    final position = controller.position;
    final target = math.max(
      position.minScrollExtent,
      _keyboardTargetScrollOffset(),
    );
    final missingExtent = target - position.maxScrollExtent;
    if (missingExtent > 0) {
      _keyboardAdditionalScrollExtent += missingExtent + 0.5;
      _notifyKeyboardFrameChanged();
      _scheduleKeyboardCommitRetry();
      return false;
    }
    controller.jumpTo(target);
    _keyboardScrollCommitted = true;
    return true;
  }

  void _scheduleKeyboardCommitRetry() {
    if (_keyboardCommitRetryScheduled) return;
    _keyboardCommitRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardCommitRetryScheduled = false;
      if (_disposed ||
          _keyboardPhase != _OriginOpeningKeyboardPhase.opening ||
          _keyboardProgress < 0.999) {
        return;
      }
      _finishKeyboardTransitionIfNeeded();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  double _keyboardTargetScrollOffset() {
    final sheetHeight =
        readKeyboardLayout()?.sheetHeight ?? _keyboardSheetHeight;
    if (sheetHeight <= 0) return _keyboardStartVisualOffset;
    final targetComposerTop = originOpeningKeyboardComposerTopForTesting(
      startTop: _keyboardStartComposerTop,
      sheetHeight: sheetHeight,
      composerHeight: _composerHeight,
      keyboardInset: _keyboardTargetInset,
      progress: 1,
    );
    return originOpeningKeyboardContentTargetOffsetForTesting(
      layoutOffset: _keyboardStartVisualOffset,
      preservedOffset: _keyboardChangingHeight
          ? _keyboardChangeStartVisualOffset
          : _keyboardStartVisualOffset,
      contentTop: _keyboardContentTop,
      contentBottom: _keyboardContentBottom,
      composerTop: targetComposerTop,
      gap: _keyboardContentToComposerGap,
    );
  }

  double _keyboardFlowRestingScrollOffset() {
    final controller = _sheetScrollController;
    if (controller == null || !controller.hasClients) {
      return _keyboardNormalScrollOffset;
    }
    final position = controller.position;
    final keyboardSpacerExtent =
        _keyboardTargetInset + _keyboardAdditionalScrollExtent;
    final normalMaxScrollExtent = math.max(
      position.minScrollExtent,
      position.maxScrollExtent - keyboardSpacerExtent,
    );
    return normalMaxScrollExtent;
  }

  double keyboardVisualScrollOffset() {
    final controller = _sheetScrollController;
    final controllerOffset = controller != null && controller.hasClients
        ? controller.offset
        : _keyboardNormalScrollOffset;
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.preparing) {
      return _keyboardNormalScrollOffset;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.restoring) {
      return _keyboardClosingTargetVisualOffset;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
      final closeProgress = 1 - _keyboardProgress;
      return _keyboardClosingVisualOffset +
          (_keyboardClosingTargetVisualOffset - _keyboardClosingVisualOffset) *
              closeProgress;
    }
    if (_keyboardScrollCommitted ||
        _keyboardPhase == _OriginOpeningKeyboardPhase.open) {
      return controllerOffset;
    }
    if (_keyboardChangingHeight) {
      return _keyboardChangeStartVisualOffset +
          (_keyboardTargetScrollOffset() - _keyboardChangeStartVisualOffset) *
              _keyboardProgress;
    }
    return _keyboardStartVisualOffset +
        (_keyboardTargetScrollOffset() - _keyboardStartVisualOffset) *
            _keyboardProgress;
  }

  void resetKeyboard({bool clearFocus = false, bool settleAtFlowEnd = false}) {
    if (_disposed) return;
    final restoreExtent = keyboardMode ? _keyboardSheetExtent : 0.0;
    if (clearFocus) FocusManager.instance.primaryFocus?.unfocus();
    if (restoreExtent > 0) restoreSheetExtent(restoreExtent);
    final scrollController = _sheetScrollController;
    if (keyboardMode &&
        scrollController != null &&
        scrollController.hasClients) {
      final position = scrollController.position;
      scrollController.jumpTo(
        (settleAtFlowEnd
                ? _keyboardClosingTargetVisualOffset
                : _keyboardNormalScrollOffset)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    _keyboardPhase = _OriginOpeningKeyboardPhase.idle;
    _keyboardInset = 0;
    _keyboardTargetInset = 0;
    _keyboardProgress = 0;
    _keyboardStableFrameCount = 0;
    _keyboardSettleCheckScheduled = false;
    _keyboardScrollCommitted = false;
    _keyboardCommitRetryScheduled = false;
    _keyboardChangingHeight = false;
    _keyboardAnimationTargetKnown = false;
    _keyboardStartVisualOffset = 0;
    _keyboardClosingTargetVisualOffset = 0;
    _keyboardClosingTargetComposerTop = 0;
    _keyboardAdditionalScrollExtent = 0;
    _keyboardContentTop = 0;
    _keyboardContentBottom = 0;
    _keyboardContentToComposerGap = 0;
    _keyboardSheetExtent = 0;
    _keyboardSheetHeight = 0;
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  void _notifyKeyboardFrameChanged() {
    if (!_disposed) _keyboardFrameNotifier.notifyFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_keyboardAnimationSubscription?.cancel());
    pageController.dispose();
    openingPreviewScrollController.dispose();
    infoPreviewScrollController.dispose();
    _keyboardFrameNotifier.dispose();
    super.dispose();
  }
}
