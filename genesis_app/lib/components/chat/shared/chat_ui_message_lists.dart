part of 'chat_ui_library.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.topTitle,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.keyboardDismissBehavior,
    this.oldestEdgeNotice,
    this.oldestEdgeLoading = false,
    this.reverse = true,
    this.showDateDividers = true,
    this.style,
  });

  final ScrollController controller;
  final List<ChatMessageVm> messages;
  final String topTitle;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? oldestEdgeNotice;
  final bool oldestEdgeLoading;
  final bool reverse;
  final bool showDateDividers;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return ListView.builder(
      controller: controller,
      reverse: reverse,
      keyboardDismissBehavior:
          keyboardDismissBehavior ?? ScrollViewKeyboardDismissBehavior.manual,
      padding: style.messageListPadding,
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        final titleIndex = reverse ? messages.length : 0;
        if (index == titleIndex) {
          return _ChatOldestEdgeContent(
            topTitle: topTitle,
            notice: oldestEdgeNotice,
            loading: oldestEdgeLoading,
            style: style,
          );
        }

        final messageIndex = reverse ? messages.length - 1 - index : index - 1;
        final current = messages[messageIndex];
        final previous = messageIndex == 0 ? null : messages[messageIndex - 1];
        return ChatMessageRow(
          key: ValueKey(current.localId),
          message: current,
          imageViewerMessages: messages,
          style: style,
          onMessageLongPressStart: onMessageLongPressStart,
          onFailedMessageTap: onFailedMessageTap,
          onCharactersMovedLocationTap: onCharactersMovedLocationTap,
          showDateDivider:
              showDateDividers &&
              shouldShowChatDateDivider(previous?.createdAt, current.createdAt),
        );
      },
    );
  }
}

class ChatAnchoredMessageList extends StatefulWidget {
  const ChatAnchoredMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.centerLocalId,
    required this.topTitle,
    this.autoFollowBottom = true,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.keyboardDismissBehavior,
    this.oldestEdgeNotice,
    this.oldestEdgeLoading = false,
    this.showDateDividers = true,
    this.style,
  });

  final ScrollController controller;
  final List<ChatMessageVm> messages;
  final String centerLocalId;
  final String topTitle;
  final bool autoFollowBottom;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? oldestEdgeNotice;
  final bool oldestEdgeLoading;
  final bool showDateDividers;
  final ChatUiStyleConfig? style;

  @override
  State<ChatAnchoredMessageList> createState() =>
      _ChatAnchoredMessageListState();
}

class _ChatAnchoredMessageListState extends State<ChatAnchoredMessageList> {
  final Map<String, GlobalKey> _messageLayoutKeys = <String, GlobalKey>{};
  int _anchorRestoreGeneration = 0;

  @override
  void didUpdateWidget(ChatAnchoredMessageList oldWidget) {
    final keepsController = oldWidget.controller == widget.controller;
    final wasNearBottom =
        keepsController &&
        widget.autoFollowBottom &&
        oldWidget.controller.hasClients &&
        oldWidget.controller.position.maxScrollExtent -
                oldWidget.controller.position.pixels <=
            24;
    final anchor = keepsController && !wasNearBottom
        ? _layoutAnchorForUpdate(oldWidget)
        : null;
    super.didUpdateWidget(oldWidget);
    _pruneMessageLayoutKeys();

    _anchorRestoreGeneration += 1;
    if (!keepsController) return;
    final generation = _anchorRestoreGeneration;
    if (wasNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _anchorRestoreGeneration) return;
        if (!widget.autoFollowBottom) return;
        if (!widget.controller.hasClients) return;
        widget.controller.jumpTo(widget.controller.position.maxScrollExtent);
      });
      return;
    }
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _anchorRestoreGeneration) return;
      final nextAnchorTop = _messageTop(anchor.localId);
      if (nextAnchorTop == null || !widget.controller.hasClients) return;
      final delta = nextAnchorTop - anchor.top;
      if (delta.abs() < precisionErrorTolerance) return;
      final position = widget.controller.position;
      final target = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - position.pixels).abs() < precisionErrorTolerance) return;
      widget.controller.jumpTo(target);
    });
  }

  ({String localId, double top})? _layoutAnchorForUpdate(
    ChatAnchoredMessageList oldWidget,
  ) {
    final previousCenterLocalId = oldWidget.centerLocalId.trim();
    if (previousCenterLocalId.isNotEmpty &&
        previousCenterLocalId == widget.centerLocalId.trim()) {
      final top = _messageTop(previousCenterLocalId);
      if (top != null) return (localId: previousCenterLocalId, top: top);
    }

    final viewportBounds = _globalBounds(context.findRenderObject());
    ({String localId, double top})? closestAnchor;
    var closestDistance = double.infinity;
    for (final message in widget.messages) {
      final messageBounds = _messageBounds(message.localId);
      if (messageBounds == null) continue;
      if (viewportBounds == null) {
        return (localId: message.localId, top: messageBounds.top);
      }
      final distance = switch (messageBounds) {
        Rect(:final bottom) when bottom < viewportBounds.top =>
          viewportBounds.top - bottom,
        Rect(:final top) when top > viewportBounds.bottom =>
          top - viewportBounds.bottom,
        _ => 0.0,
      };
      if (distance >= closestDistance) continue;
      closestDistance = distance;
      closestAnchor = (localId: message.localId, top: messageBounds.top);
      if (distance == 0) break;
    }
    return closestAnchor;
  }

  @override
  void dispose() {
    _anchorRestoreGeneration += 1;
    _messageLayoutKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? ChatUiStyleConfig.standard;
    final hasOldestEdgeContent =
        widget.topTitle.trim().isNotEmpty ||
        (widget.oldestEdgeNotice?.trim().isNotEmpty ?? false) ||
        widget.oldestEdgeLoading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;
        return SingleChildScrollView(
          controller: widget.controller,
          physics: ChatBottomAnchoringScrollPhysics(
            autoFollowBottom: widget.autoFollowBottom,
          ),
          keyboardDismissBehavior:
              widget.keyboardDismissBehavior ??
              ScrollViewKeyboardDismissBehavior.manual,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: style.messageListPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasOldestEdgeContent)
                    _ChatOldestEdgeContent(
                      topTitle: widget.topTitle,
                      notice: widget.oldestEdgeNotice,
                      loading: widget.oldestEdgeLoading,
                      style: style,
                    ),
                  for (
                    var index = 0;
                    index < widget.messages.length;
                    index += 1
                  )
                    _buildMessageRow(index, style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _pruneMessageLayoutKeys() {
    final retainedLocalIds = widget.messages
        .map((message) => message.localId)
        .toSet();
    _messageLayoutKeys.removeWhere(
      (localId, _) => !retainedLocalIds.contains(localId),
    );
  }

  double? _messageTop(String localId) {
    return _messageBounds(localId)?.top;
  }

  Rect? _messageBounds(String localId) {
    if (localId.isEmpty) return null;
    final messageContext = _messageLayoutKeys[localId]?.currentContext;
    final renderObject = messageContext?.findRenderObject();
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    return _globalBounds(renderObject);
  }

  Rect? _globalBounds(RenderObject? renderObject) {
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bounds = topLeft & renderObject.size;
    return topLeft.dx.isFinite &&
            topLeft.dy.isFinite &&
            bounds.width.isFinite &&
            bounds.height.isFinite
        ? bounds
        : null;
  }

  bool _hasLaidOutRenderPath(RenderObject renderObject) {
    RenderObject? current = renderObject;
    while (current != null) {
      if (!current.attached) return false;
      if (current is RenderBox && !current.hasSize) return false;
      current = current.parent;
    }
    return true;
  }

  Widget _buildMessageRow(int messageIndex, ChatUiStyleConfig style) {
    final current = widget.messages[messageIndex];
    final previous = messageIndex == 0
        ? null
        : widget.messages[messageIndex - 1];
    final layoutKey = _messageLayoutKeys.putIfAbsent(
      current.localId,
      GlobalKey.new,
    );
    return KeyedSubtree(
      key: layoutKey,
      child: ChatMessageRow(
        key: ValueKey(current.localId),
        message: current,
        imageViewerMessages: widget.messages,
        style: style,
        onMessageLongPressStart: widget.onMessageLongPressStart,
        onFailedMessageTap: widget.onFailedMessageTap,
        onCharactersMovedLocationTap: widget.onCharactersMovedLocationTap,
        showDateDivider:
            widget.showDateDividers &&
            shouldShowChatDateDivider(previous?.createdAt, current.createdAt),
      ),
    );
  }
}

class ChatBottomAnchoringScrollPhysics extends ClampingScrollPhysics {
  const ChatBottomAnchoringScrollPhysics({
    super.parent,
    this.bottomTolerance = 24,
    this.autoFollowBottom = true,
  });

  final double bottomTolerance;
  final bool autoFollowBottom;

  @override
  ChatBottomAnchoringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ChatBottomAnchoringScrollPhysics(
      parent: buildParent(ancestor),
      bottomTolerance: bottomTolerance,
      autoFollowBottom: autoFollowBottom,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final wasNearBottom =
        autoFollowBottom &&
        oldPosition.maxScrollExtent - oldPosition.pixels <= bottomTolerance;
    if (wasNearBottom) {
      return newPosition.maxScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

class _ChatOldestEdgeContent extends StatelessWidget {
  const _ChatOldestEdgeContent({
    required this.topTitle,
    required this.notice,
    required this.loading,
    required this.style,
  });

  final String topTitle;
  final String? notice;
  final bool loading;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final normalizedNotice = notice?.trim() ?? '';
    if (loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatTopTitle(name: topTitle, style: style),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              topTitle.trim().isEmpty ? 0 : 4,
              20,
              16,
            ),
            child: SizedBox.square(
              dimension: style.sendingBadgeSize,
              child: Padding(
                padding: EdgeInsets.all(style.sendingBadgePadding),
                child: CircularProgressIndicator(
                  strokeWidth: style.sendingBadgeStrokeWidth,
                  color: style.sendingBadgeColor,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (normalizedNotice.isEmpty) {
      return _ChatTopTitle(name: topTitle, style: style);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatTopTitle(name: topTitle, style: style),
        AiContentDisclaimer(
          text: normalizedNotice,
          padding: EdgeInsets.fromLTRB(
            20,
            topTitle.trim().isEmpty ? 0 : 4,
            20,
            16,
          ),
        ),
      ],
    );
  }
}

class _ChatTopTitle extends StatelessWidget {
  const _ChatTopTitle({required this.name, required this.style});

  final String name;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final safeName = genesisDisplaySafeText(name);
    if (safeName.trim().isEmpty) {
      return SizedBox(height: style.topTitleEmptyHeight);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: style.topTitleBottomPadding),
      child: Center(
        child: Text(
          safeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.topTitleTextStyle,
        ),
      ),
    );
  }
}
