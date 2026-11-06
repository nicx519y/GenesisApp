part of 'chat_ui_library.dart';

class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    super.key,
    required this.message,
    required this.showDateDivider,
    this.visibilityKey,
    this.imageKey,
    this.imageViewerMessages = const <ChatMessageVm>[],
    this.onAvatarTap,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.selfMessageBubbleMaxWidthCap,
    this.otherMessageBubbleMaxWidthCap,
    this.applyListHorizontalPadding = false,
    this.style,
  });

  final ChatMessageVm message;
  final bool showDateDivider;
  final Key? visibilityKey;
  final Key? imageKey;
  final List<ChatMessageVm> imageViewerMessages;
  final VoidCallback? onAvatarTap;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final double? selfMessageBubbleMaxWidthCap;
  final double? otherMessageBubbleMaxWidthCap;

  /// Keeps all message rows within the same outer avatar boundaries.
  final bool applyListHorizontalPadding;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!applyListHorizontalPadding) return content;
    final padding = (style ?? ChatUiStyleConfig.standard).messageListPadding;
    return Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    Widget trackVisibility(Widget child) => visibilityKey == null
        ? child
        : KeyedSubtree(key: visibilityKey, child: child);
    if (message.isAiContentDisclaimer) {
      return trackVisibility(
        ChatAiContentDisclaimerMessageBubble(message: message),
      );
    }
    final onLongPressStart = onMessageLongPressStart == null
        ? null
        : (LongPressStartDetails details) =>
              onMessageLongPressStart!(context, message, details);
    if (message.isUserEnterLocation) {
      return trackVisibility(
        ChatUserEnterLocationMessageBubble(
          message: message,
          style: style,
          onLongPressStart: onLongPressStart,
        ),
      );
    }
    if (message.isStoryEvents) {
      return trackVisibility(
        ChatStoryEventsMessageBubble(
          message: message,
          style: style,
          onLongPressStart: onLongPressStart,
        ),
      );
    }
    if (message.isCharactersMoved) {
      return trackVisibility(
        ChatCharactersMovedMessageBubble(
          message: message,
          style: style,
          onLongPressStart: onLongPressStart,
          onLocationTap: onCharactersMovedLocationTap,
        ),
      );
    }
    if (message.isImage) {
      return trackVisibility(
        ChatImageMessage(
          key: imageKey,
          message: message,
          imageViewerMessages: imageViewerMessages,
          style: style,
          onLongPressStart: onLongPressStart,
        ),
      );
    }
    if (message.isNarrator || message.isUserNarration) {
      return trackVisibility(
        ChatNarratorMessageBubble(
          message: message,
          style: style,
          onLongPressStart: onLongPressStart,
          onFailedMessageTap: onFailedMessageTap,
        ),
      );
    }
    if (message.isTick) {
      return trackVisibility(
        ChatTickMessageBubble(
          message: message,
          style: style,
          onLongPressStart: onLongPressStart,
          onLocationTap: onCharactersMovedLocationTap,
        ),
      );
    }
    if (message.isSystem) {
      return trackVisibility(
        ChatSystemMessage(
          text: message.text,
          style: style,
          onLongPressStart: onLongPressStart,
        ),
      );
    }

    final row = message.isMe
        ? ChatSelfMessageBubble(
            message: message,
            style: style,
            maxWidthCap: selfMessageBubbleMaxWidthCap,
            onLongPressStart: onLongPressStart,
            onFailedMessageTap: onFailedMessageTap,
          )
        : ChatOtherMessageBubble(
            message: message,
            style: style,
            maxWidthCap: otherMessageBubbleMaxWidthCap,
            onAvatarTap: onAvatarTap,
            onLongPressStart: onLongPressStart,
          );
    final visibleRow = trackVisibility(row);
    if (!showDateDivider) return visibleRow;

    return Column(
      children: [
        ChatDateDivider(time: message.createdAt, style: style),
        visibleRow,
      ],
    );
  }
}
