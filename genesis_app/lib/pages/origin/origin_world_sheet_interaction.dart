part of 'origin_world_page.dart';

const int _originOpeningSheetPageIndex = 0;
const int _originInfoSheetPageIndex = 1;
const double _originSheetInteractionEpsilon = 0.001;
const int _originOpeningKeyboardSettleFrameCount = 10;
const Duration _originOpeningKeyboardClosingDuration = Duration(
  milliseconds: 260,
);

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
double originOpeningKeyboardRawProgressForTesting({
  required double currentRawInset,
  required double targetLayoutInset,
  required double bottomSafeAreaInset,
}) {
  final targetRawInset = targetLayoutInset + bottomSafeAreaInset;
  if (targetRawInset <= 0.5) return currentRawInset > 0.5 ? 1 : 0;
  return (currentRawInset / targetRawInset).clamp(0.0, 1.0).toDouble();
}

@visibleForTesting
double originOpeningKeyboardClosingAnimationProgressForTesting({
  required double startProgress,
  required double animationValue,
}) {
  final start = startProgress.clamp(0.0, 1.0).toDouble();
  final elapsed = animationValue.clamp(0.0, 1.0).toDouble();
  return start * (1 - elapsed);
}

@visibleForTesting
bool originOpeningKeyboardShouldIgnoreNativeTargetForTesting({
  required bool closingOrRestoring,
  required GenesisKeyboardAnimationDirection direction,
}) {
  return closingOrRestoring &&
      direction != GenesisKeyboardAnimationDirection.closing;
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
double originOpeningKeyboardLayoutSpacerExtentForTesting({
  required double additionalScrollExtent,
}) {
  return math.max(0.0, additionalScrollExtent);
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

class _OriginWorldSheetInteractionController extends ChangeNotifier {
  _OriginWorldSheetInteractionController({
    required TickerProvider vsync,
    required this.canPrepareKeyboard,
    required this.readKeyboardInset,
    required this.readRawKeyboardInset,
    required this.readKeyboardSafeAreaInset,
    required this.readKeyboardLayout,
    required this.readKeyboardContentBounds,
    required this.readSheetExtent,
    required this.readFallbackExpandedSheetExtent,
    required this.restoreSheetExtent,
    required this.readContentToComposerGap,
    required this.onPageSelected,
  }) {
    _keyboardClosingAnimationController = AnimationController(
      vsync: vsync,
      duration: _originOpeningKeyboardClosingDuration,
    )..addListener(_handleKeyboardClosingAnimationTick);
    _keyboardAnimationSubscription = GenesisKeyboardAnimationEvents.targets
        .listen(_handleKeyboardAnimationTarget, onError: (_) {});
  }

  final bool Function() canPrepareKeyboard;
  final double Function() readKeyboardInset;
  final double Function() readRawKeyboardInset;
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
  late final AnimationController _keyboardClosingAnimationController;

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
  var _keyboardNormalMaxScrollExtent = 0.0;
  var _keyboardStartVisualOffset = 0.0;
  var _keyboardAdditionalScrollExtent = 0.0;
  var _keyboardSheetExtent = 0.0;
  var _keyboardClosingVisualOffset = 0.0;
  var _keyboardClosingTargetComposerTop = 0.0;
  var _keyboardClosingRawInset = 0.0;
  var _keyboardClosingStartProgress = 0.0;
  var _keyboardClosingLayoutGeneration = 0;
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
  double get keyboardLayoutSpacerExtent =>
      originOpeningKeyboardLayoutSpacerExtentForTesting(
        additionalScrollExtent: _keyboardAdditionalScrollExtent,
      );
  bool get keyboardChangingHeight => _keyboardChangingHeight;
  bool get keyboardMode =>
      _keyboardPhase != _OriginOpeningKeyboardPhase.idle &&
      _keyboardPhase != _OriginOpeningKeyboardPhase.restoring;
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
    if (identical(_sheetScrollController, controller)) return;
    _sheetScrollController?.removeListener(_trackFocusedContentOffset);
    _sheetScrollController = controller;
    controller.addListener(_trackFocusedContentOffset);
  }

  void _trackFocusedContentOffset() {
    final controller = _sheetScrollController;
    if (_disposed ||
        controller == null ||
        !controller.hasClients ||
        _keyboardPhase != _OriginOpeningKeyboardPhase.open ||
        readRawKeyboardInset() <= 0.5) {
      return;
    }
    _keyboardClosingVisualOffset = controller.offset;
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
          actualKeyboardInset:
              _keyboardPhase == _OriginOpeningKeyboardPhase.closing ||
                  _keyboardPhase == _OriginOpeningKeyboardPhase.restoring
              ? 0
              : _keyboardInset,
        ) -
        _keyboardStartComposerTop;
  }

  double contentTranslation(double actualContentOffset) {
    return _keyboardPhase != _OriginOpeningKeyboardPhase.idle
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
        resetKeyboard(preserveContentPosition: true);
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
    if (originOpeningKeyboardShouldIgnoreNativeTargetForTesting(
      closingOrRestoring:
          _keyboardPhase == _OriginOpeningKeyboardPhase.closing ||
          _keyboardPhase == _OriginOpeningKeyboardPhase.restoring,
      direction: target.direction,
    )) {
      return;
    }
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
    _keyboardClosingLayoutGeneration += 1;
    _keyboardClosingAnimationController.stop();
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
    if (normalController != null && normalController.hasClients) {
      final position = normalController.position;
      _keyboardNormalScrollOffset = position.pixels;
      _keyboardNormalMaxScrollExtent = math.max(
        position.minScrollExtent,
        position.maxScrollExtent - _keyboardAdditionalScrollExtent,
      );
    } else {
      _keyboardNormalScrollOffset = 0;
      _keyboardNormalMaxScrollExtent = 0;
    }
    _keyboardStartVisualOffset = _keyboardNormalScrollOffset;
    _keyboardClosingVisualOffset = _keyboardNormalScrollOffset;
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
      final missingExtent =
          originOpeningKeyboardAdditionalScrollExtentForTesting(
            targetOffset: _keyboardTargetScrollOffset(),
            maxScrollExtent: scrollController.position.maxScrollExtent,
          );
      if (missingExtent > 0) {
        // The current max extent can already contain range retained from the
        // previous keyboard close. Never replace that range with the newly
        // missing amount: shrinking it while positioned at the bottom makes
        // ScrollPosition clamp before the opening animation begins.
        _keyboardAdditionalScrollExtent += missingExtent + 0.5;
      }
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
    if (_keyboardPhase != _OriginOpeningKeyboardPhase.open) {
      _keyboardClosingVisualOffset = keyboardVisualScrollOffset();
    }
    final requiredRetainedExtent = math.max(
      0.0,
      _keyboardClosingVisualOffset - _keyboardNormalMaxScrollExtent,
    );
    if (requiredRetainedExtent > _keyboardAdditionalScrollExtent) {
      // Establish the zero-keyboard range before closing changes the layout.
      // Waiting until the restoring frame would let a bottom-aligned position
      // clamp once on the first keyboard close, then expand again.
      _keyboardAdditionalScrollExtent = requiredRetainedExtent + 0.5;
      _notifyKeyboardFrameChanged();
    }
    // Losing focus must not select a new content destination. Keep the exact
    // visual offset that was visible on the final focused frame while the
    // composer and keyboard return to their zero-inset layout.
    _keyboardClosingTargetComposerTop = _keyboardStartComposerTop;
    _keyboardClosingRawInset = readRawKeyboardInset();
    _keyboardClosingStartProgress = _keyboardProgress
        .clamp(0.0, 1.0)
        .toDouble();
    _keyboardChangingHeight = false;
    _keyboardPhase = _OriginOpeningKeyboardPhase.closing;
    _notifyChanged();
    unawaited(_keyboardClosingAnimationController.forward(from: 0));
    _updateKeyboardInset(readKeyboardInset());
  }

  void _handleKeyboardClosingAnimationTick() {
    if (_disposed || _keyboardPhase != _OriginOpeningKeyboardPhase.closing) {
      return;
    }
    final progress = originOpeningKeyboardClosingAnimationProgressForTesting(
      startProgress: _keyboardClosingStartProgress,
      animationValue: Curves.easeOutCubic.transform(
        _keyboardClosingAnimationController.value,
      ),
    );
    _keyboardProgress = progress;
    _notifyKeyboardFrameChanged();
    _finishKeyboardTransitionIfNeeded();
  }

  void _updateKeyboardInset(double layoutInset) {
    if (_disposed || !keyboardMode) return;
    final inset = layoutInset.clamp(0.0, double.infinity).toDouble();
    final currentRawInset = readRawKeyboardInset()
        .clamp(0.0, double.infinity)
        .toDouble();
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
        : _keyboardPhase == _OriginOpeningKeyboardPhase.closing
        ? _keyboardProgress
        : _keyboardChangingHeight
        ? originOpeningKeyboardProgressForTesting(
            currentInset: inset,
            startInset: _keyboardChangeStartInset,
            endInset: targetInset,
          )
        : originOpeningKeyboardRawProgressForTesting(
            currentRawInset: currentRawInset,
            targetLayoutInset: targetInset,
            bottomSafeAreaInset: readKeyboardSafeAreaInset(),
          );
    final unchanged = _keyboardPhase == _OriginOpeningKeyboardPhase.closing
        ? (_keyboardClosingRawInset - currentRawInset).abs() < 0.5
        : (_keyboardInset - inset).abs() < 0.5;
    if (!unchanged) _keyboardStableFrameCount = 0;
    _keyboardClosingRawInset = currentRawInset;
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
      final currentRawInset = readRawKeyboardInset();
      final metricsUnchanged =
          _keyboardPhase == _OriginOpeningKeyboardPhase.closing
          ? (_keyboardClosingRawInset - currentRawInset).abs() < 0.5
          : (_keyboardInset - currentInset).abs() < 0.5;
      if (metricsUnchanged) {
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
        _keyboardProgress <= _originSheetInteractionEpsilon &&
        _keyboardInset <= 0.5 &&
        readRawKeyboardInset() <= 0.5 &&
        _keyboardStableFrameCount >= _originOpeningKeyboardSettleFrameCount) {
      _keyboardPhase = _OriginOpeningKeyboardPhase.restoring;
      _notifyChanged();
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed ||
            _keyboardPhase != _OriginOpeningKeyboardPhase.restoring) {
          return;
        }
        _finishKeyboardRestoreWithoutMovingContent();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _finishKeyboardRestoreWithoutMovingContent() {
    if (_disposed || _keyboardPhase != _OriginOpeningKeyboardPhase.restoring) {
      return;
    }
    final controller = _sheetScrollController;
    if (controller == null || !controller.hasClients) {
      resetKeyboard(preserveContentPosition: true);
      return;
    }
    final position = controller.position;
    final retainedOffset = _keyboardClosingVisualOffset.clamp(
      position.minScrollExtent,
      double.infinity,
    );
    final missingExtent = retainedOffset - position.maxScrollExtent;
    if (missingExtent > 0.01) {
      // The focused alignment can sit beyond the ordinary zero-keyboard
      // boundary on devices with different bottom system insets. Retain only
      // the exact missing range so leaving keyboard mode does not clamp the
      // content to a different position.
      _keyboardAdditionalScrollExtent += missingExtent + 0.5;
      _notifyChanged();
      _notifyKeyboardFrameChanged();
      final generation = ++_keyboardClosingLayoutGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed ||
            generation != _keyboardClosingLayoutGeneration ||
            _keyboardPhase != _OriginOpeningKeyboardPhase.restoring) {
          return;
        }
        _finishKeyboardRestoreWithoutMovingContent();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    controller.jumpTo(
      retainedOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    resetKeyboard(preserveContentPosition: true);
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
    _keyboardClosingVisualOffset = target;
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

  double keyboardVisualScrollOffset() {
    final controller = _sheetScrollController;
    final controllerOffset = controller != null && controller.hasClients
        ? controller.offset
        : _keyboardNormalScrollOffset;
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.preparing) {
      return _keyboardNormalScrollOffset;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.restoring) {
      return _keyboardClosingVisualOffset;
    }
    if (_keyboardPhase == _OriginOpeningKeyboardPhase.closing) {
      return _keyboardClosingVisualOffset;
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

  void resetKeyboard({
    bool clearFocus = false,
    bool preserveContentPosition = false,
  }) {
    if (_disposed) return;
    _keyboardClosingLayoutGeneration += 1;
    _keyboardClosingAnimationController.stop();
    final restoreExtent = keyboardMode ? _keyboardSheetExtent : 0.0;
    if (clearFocus) FocusManager.instance.primaryFocus?.unfocus();
    if (restoreExtent > 0) restoreSheetExtent(restoreExtent);
    final scrollController = _sheetScrollController;
    if (keyboardMode &&
        scrollController != null &&
        scrollController.hasClients) {
      final position = scrollController.position;
      if (!preserveContentPosition) {
        scrollController.jumpTo(
          _keyboardNormalScrollOffset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
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
    _keyboardNormalMaxScrollExtent = 0;
    _keyboardClosingTargetComposerTop = 0;
    _keyboardClosingRawInset = 0;
    _keyboardClosingStartProgress = 0;
    if (!preserveContentPosition) _keyboardAdditionalScrollExtent = 0;
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
    _sheetScrollController?.removeListener(_trackFocusedContentOffset);
    unawaited(_keyboardAnimationSubscription?.cancel());
    _keyboardClosingAnimationController.dispose();
    pageController.dispose();
    openingPreviewScrollController.dispose();
    infoPreviewScrollController.dispose();
    _keyboardFrameNotifier.dispose();
    super.dispose();
  }
}
