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
        oldWidget.controller.hasClients &&
        oldWidget.controller.position.maxScrollExtent -
                oldWidget.controller.position.pixels <=
            24;
    final anchorLocalId = oldWidget.centerLocalId.trim();
    final anchorTop = _messageTop(anchorLocalId);
    super.didUpdateWidget(oldWidget);
    _pruneMessageLayoutKeys();

    _anchorRestoreGeneration += 1;
    if (!keepsController) return;
    final generation = _anchorRestoreGeneration;
    if (wasNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _anchorRestoreGeneration) return;
        if (!widget.controller.hasClients) return;
        widget.controller.jumpTo(widget.controller.position.maxScrollExtent);
      });
      return;
    }
    if (anchorLocalId.isEmpty ||
        anchorLocalId != widget.centerLocalId.trim() ||
        anchorTop == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _anchorRestoreGeneration) return;
      final nextAnchorTop = _messageTop(anchorLocalId);
      if (nextAnchorTop == null || !widget.controller.hasClients) return;
      final delta = nextAnchorTop - anchorTop;
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
          physics: const ChatBottomAnchoringScrollPhysics(),
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
    if (localId.isEmpty) return null;
    final messageContext = _messageLayoutKeys[localId]?.currentContext;
    final renderObject = messageContext?.findRenderObject();
    if (renderObject is! RenderBox || !_hasLaidOutRenderPath(renderObject)) {
      return null;
    }
    final top = renderObject.localToGlobal(Offset.zero).dy;
    return top.isFinite ? top : null;
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
  });

  final double bottomTolerance;

  @override
  ChatBottomAnchoringScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ChatBottomAnchoringScrollPhysics(
      parent: buildParent(ancestor),
      bottomTolerance: bottomTolerance,
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
