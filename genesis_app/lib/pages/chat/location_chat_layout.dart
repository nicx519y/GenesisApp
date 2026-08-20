part of 'location_chat_page.dart';

extension _LocationChatLayout on _LocationChatPanelState {
  double _edgeSwipeBackWidth(BuildContext context) {
    final direction = Directionality.of(context);
    final padding = MediaQuery.paddingOf(context);
    final edgePadding = direction == TextDirection.rtl
        ? padding.right
        : padding.left;
    return math.max(_locationChatEdgeSwipeWidth, edgePadding);
  }

  void _handleEdgeSwipeBackStart(DragStartDetails details) {
    _edgeSwipeBackDragDistance = 0;
    _edgeSwipeBackTriggered = false;
  }

  void _handleEdgeSwipeBackUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final logicalDelta = Directionality.of(context) == TextDirection.rtl
        ? -delta
        : delta;
    _edgeSwipeBackDragDistance = math.max(
      0,
      _edgeSwipeBackDragDistance + logicalDelta,
    );
    if (_edgeSwipeBackDragDistance >= _locationChatEdgeSwipeTriggerDistance) {
      _triggerEdgeSwipeBack();
    }
  }

  void _handleEdgeSwipeBackEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final logicalVelocity = Directionality.of(context) == TextDirection.rtl
        ? -velocity
        : velocity;
    if (logicalVelocity >= _locationChatEdgeSwipeTriggerVelocity) {
      _triggerEdgeSwipeBack();
      return;
    }
    _resetEdgeSwipeBack();
  }

  void _triggerEdgeSwipeBack() {
    if (_edgeSwipeBackTriggered) return;
    _edgeSwipeBackTriggered = true;
    _composerFocusNode.unfocus();
    widget.onBack?.call();
  }

  void _resetEdgeSwipeBack() {
    _edgeSwipeBackDragDistance = 0;
    _edgeSwipeBackTriggered = false;
  }

  double _locationChatHeaderHeight(ChatUiStyleConfig style) {
    return GenesisSafeAreaInsets.top(context) + style.headerHeight;
  }

  double _locationChatComposerHeight(ChatUiStyleConfig style) {
    if (_composerHeight > 0) return _composerHeight;
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
    return style.composerPadding.vertical + style.inputMinHeight + bottomInset;
  }

  void _handleComposerFocusChanged() {
    if (!mounted) return;
    if (_composerFocusNode.hasFocus) {
      _scrollCoordinator.requestBottom(
        reason: LocationChatBottomReason.composerFocus,
        behavior: LocationChatBottomBehavior.jump,
      );
    }
    _setLocationChatState(() {});
  }

  void _handleDraftTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    widget.onDraftTextChanged?.call(_textController.text);
    if (_hasDraftText == hasText) return;
    _setLocationChatState(() => _hasDraftText = hasText);
  }

  void _handleComposerHeightChanged(double height) {
    if ((_composerHeight - height).abs() > 0.5) {
      _setLocationChatState(() => _composerHeight = height);
    }
  }
}
