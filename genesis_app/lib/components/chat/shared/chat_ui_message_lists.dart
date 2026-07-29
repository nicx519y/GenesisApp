part of 'chat_ui_library.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.topTitle,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
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
          showDateDivider:
              showDateDividers &&
              shouldShowChatDateDivider(previous?.createdAt, current.createdAt),
        );
      },
    );
  }
}

class ChatAnchoredMessageList extends StatelessWidget {
  const ChatAnchoredMessageList({
    super.key,
    required this.controller,
    required this.messages,
    required this.centerLocalId,
    required this.topTitle,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.keyboardDismissBehavior,
    this.oldestEdgeNotice,
    this.oldestEdgeLoading = false,
    this.showDateDividers = true,
    this.style,
  });

  static const _bottomSliverKey = ValueKey<String>(
    'chat-anchored-message-list-bottom',
  );

  final ScrollController controller;
  final List<ChatMessageVm> messages;
  final String centerLocalId;
  final String topTitle;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? oldestEdgeNotice;
  final bool oldestEdgeLoading;
  final bool showDateDividers;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    if (messages.isEmpty) {
      return ListView(
        controller: controller,
        physics: const ChatBottomAnchoringScrollPhysics(),
        keyboardDismissBehavior:
            keyboardDismissBehavior ?? ScrollViewKeyboardDismissBehavior.manual,
        padding: style.messageListPadding,
        children: [
          _ChatOldestEdgeContent(
            topTitle: topTitle,
            notice: oldestEdgeNotice,
            loading: oldestEdgeLoading,
            style: style,
          ),
        ],
      );
    }

    final centerIndex = _resolvedCenterIndex();
    final olderCount = centerIndex;
    final newerCount = messages.length - centerIndex;
    final padding = style.messageListPadding;
    final hasOldestEdgeContent =
        topTitle.trim().isNotEmpty ||
        (oldestEdgeNotice?.trim().isNotEmpty ?? false) ||
        oldestEdgeLoading;

    if (centerIndex == 0 || !_hasNonSystemMessageBefore(centerIndex)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : 0.0;
          return SingleChildScrollView(
            controller: controller,
            physics: const ChatBottomAnchoringScrollPhysics(),
            keyboardDismissBehavior:
                keyboardDismissBehavior ??
                ScrollViewKeyboardDismissBehavior.manual,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasOldestEdgeContent)
                      _ChatOldestEdgeContent(
                        topTitle: topTitle,
                        notice: oldestEdgeNotice,
                        loading: oldestEdgeLoading,
                        style: style,
                      ),
                    for (var index = 0; index < messages.length; index += 1)
                      _buildMessageRow(index, style),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return CustomScrollView(
      controller: controller,
      center: _bottomSliverKey,
      physics: const ChatBottomAnchoringScrollPhysics(),
      keyboardDismissBehavior:
          keyboardDismissBehavior ?? ScrollViewKeyboardDismissBehavior.manual,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(
            left: padding.left,
            top: padding.top,
            right: padding.right,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == olderCount) {
                return _ChatOldestEdgeContent(
                  topTitle: topTitle,
                  notice: oldestEdgeNotice,
                  loading: oldestEdgeLoading,
                  style: style,
                );
              }
              final messageIndex = centerIndex - 1 - index;
              return _buildMessageRow(messageIndex, style);
            }, childCount: olderCount + 1),
          ),
        ),
        SliverPadding(
          key: _bottomSliverKey,
          padding: EdgeInsets.only(
            left: padding.left,
            right: padding.right,
            bottom: padding.bottom,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final messageIndex = centerIndex + index;
              return _buildMessageRow(messageIndex, style);
            }, childCount: newerCount),
          ),
        ),
      ],
    );
  }

  int _resolvedCenterIndex() {
    final normalizedCenterLocalId = centerLocalId.trim();
    if (normalizedCenterLocalId.isEmpty) return 0;
    final index = messages.indexWhere(
      (message) => message.localId == normalizedCenterLocalId,
    );
    return index < 0 ? 0 : index;
  }

  bool _hasNonSystemMessageBefore(int centerIndex) {
    for (
      var index = 0;
      index < centerIndex && index < messages.length;
      index += 1
    ) {
      if (!messages[index].isSystem) return true;
    }
    return false;
  }

  Widget _buildMessageRow(int messageIndex, ChatUiStyleConfig style) {
    final current = messages[messageIndex];
    final previous = messageIndex == 0 ? null : messages[messageIndex - 1];
    return ChatMessageRow(
      key: ValueKey(current.localId),
      message: current,
      imageViewerMessages: messages,
      style: style,
      onMessageLongPressStart: onMessageLongPressStart,
      onFailedMessageTap: onFailedMessageTap,
      showDateDivider:
          showDateDividers &&
          shouldShowChatDateDivider(previous?.createdAt, current.createdAt),
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
        oldPosition.maxScrollExtent - newPosition.pixels <= bottomTolerance;
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
