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
          return ChatOldestEdgeContent(
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

class ChatOldestEdgeContent extends StatelessWidget {
  const ChatOldestEdgeContent({
    super.key,
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
