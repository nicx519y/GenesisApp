part of 'origin_world_page.dart';

const int _originOpeningSheetPageIndex = 0;
const int _originInfoSheetPageIndex = 1;
const double _originSheetInteractionEpsilon = 0.001;

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
  if (stableFrameCount >= 2 && actualInset > 0.5) return actualInset;
  return nativeTargetInset;
}

class _OriginWorldSheetFrameNotifier extends ChangeNotifier {
  void notifyFrame() => notifyListeners();
}

class _OriginWorldSheetInteractionController extends ChangeNotifier {
  _OriginWorldSheetInteractionController({
    required this.canPrepareKeyboard,
    required this.readKeyboardInset,
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
  final _OriginOpeningKeyboardLayout? Function() readKeyboardLayout;
  final _OriginOpeningKeyboardContentBounds? Function()
  readKeyboardContentBounds;
  final double Function() readSheetExtent;
  final double Function() readFallbackExpandedSheetExtent;
  final ValueChanged<double> restoreSheetExtent;
  final double Function() readContentToComposerGap;
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
  var _keyboardChangeStartInset = 0.0;
  var _keyboardChangeStartComposerTop = 0.0;
  var _keyboardChangeStartVisualOffset = 0.0;
  var _keyboardLastNativeGeneration = -1;

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
    if (_disposed ||
        !keyboardMode ||
        target.generation <= _keyboardLastNativeGeneration) {
      return;
    }
    _keyboardLastNativeGeneration = target.generation;
    final isClosing =
        target.direction == GenesisKeyboardAnimationDirection.closing;
    if (isClosing) {
      _beginKeyboardClosing();
      _keyboardTargetInset = math.max(_keyboardTargetInset, target.startInset);
    } else if (target.direction == GenesisKeyboardAnimationDirection.changing) {
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.preparing) {
        _keyboardTargetInset = target.endInset;
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
      _keyboardTargetInset = target.endInset;
      _keyboardProgress = 0;
      _keyboardScrollCommitted = false;
      _keyboardStableFrameCount = 0;
      _keyboardPhase = _OriginOpeningKeyboardPhase.opening;
      _notifyChanged();
    } else {
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
        _resumeKeyboardFromCurrentVisualState(target.endInset);
        _updateKeyboardInset(readKeyboardInset());
        return;
      }
      if (_keyboardPhase == _OriginOpeningKeyboardPhase.open &&
          (target.endInset - _keyboardInset).abs() > 0.5) {
        _resumeKeyboardFromCurrentVisualState(target.endInset);
        _updateKeyboardInset(readKeyboardInset());
        return;
      }
      _keyboardTargetInset = target.endInset;
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
    _keyboardContentToComposerGap = readContentToComposerGap();
    final sheetExtent = readSheetExtent();
    _keyboardSheetExtent = sheetExtent > 0
        ? sheetExtent
        : readFallbackExpandedSheetExtent();
    _keyboardInset = readKeyboardInset();
    _keyboardTargetInset = math.max(0, _keyboardInset);
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
    _keyboardContentTop = contentBounds.top;
    _keyboardContentBottom = contentBounds.bottom;
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
    if (!_keyboardChangingHeight &&
        _keyboardPhase != _OriginOpeningKeyboardPhase.closing &&
        inset > _keyboardTargetInset) {
      _keyboardTargetInset = inset;
    }
    final targetInset = _keyboardTargetInset;
    final progress = _keyboardChangingHeight
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
      if (_keyboardStableFrameCount < 2) _scheduleKeyboardSettleCheck();
      return;
    }
    _keyboardInset = inset;
    _keyboardProgress = progress;
    _notifyKeyboardFrameChanged();
    _finishKeyboardTransitionIfNeeded();
    if (_keyboardStableFrameCount < 2) _scheduleKeyboardSettleCheck();
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
          _keyboardStableFrameCount < 2) {
        _scheduleKeyboardSettleCheck();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _finishKeyboardTransitionIfNeeded() {
    if (_disposed) return;
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.opening &&
        _keyboardStableFrameCount >= 2 &&
        _keyboardInset > 0.5) {
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
      if (!_commitKeyboardScroll()) return;
      _keyboardChangingHeight = false;
      _keyboardPhase = _OriginOpeningKeyboardPhase.open;
      _notifyChanged();
      return;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing &&
        _keyboardInset <= 0.5 &&
        _keyboardStableFrameCount >= 2) {
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
