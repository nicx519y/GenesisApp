part of 'chat_ui_library.dart';

class ChatMessageRow extends StatelessWidget {
  const ChatMessageRow({
    super.key,
    required this.message,
    required this.showDateDivider,
    this.imageViewerMessages = const <ChatMessageVm>[],
    this.onAvatarTap,
    this.onMessageLongPressStart,
    this.onFailedMessageTap,
    this.onCharactersMovedLocationTap,
    this.style,
  });

  final ChatMessageVm message;
  final bool showDateDivider;
  final List<ChatMessageVm> imageViewerMessages;
  final VoidCallback? onAvatarTap;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? context.genesisChatTheme.standard;
    if (message.isAiContentDisclaimer) {
      return ChatAiContentDisclaimerMessageBubble(message: message);
    }
    final onLongPressStart = onMessageLongPressStart == null
        ? null
        : (LongPressStartDetails details) =>
              onMessageLongPressStart!(context, message, details);
    if (message.isUserEnterLocation) {
      return ChatUserEnterLocationMessageBubble(
        message: message,
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }
    if (message.isStoryEvents) {
      return ChatStoryEventsMessageBubble(
        message: message,
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }
    if (message.isCharactersMoved) {
      return ChatCharactersMovedMessageBubble(
        message: message,
        style: style,
        onLongPressStart: onLongPressStart,
        onLocationTap: onCharactersMovedLocationTap,
      );
    }
    if (message.isImage) {
      return ChatImageMessage(
        message: message,
        imageViewerMessages: imageViewerMessages,
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }
    if (message.isNarrator) {
      return ChatNarratorMessageBubble(
        message: message,
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }
    if (message.isTick) {
      return ChatTickMessageBubble(
        message: message,
        style: style,
        onLongPressStart: onLongPressStart,
        onLocationTap: onCharactersMovedLocationTap,
      );
    }
    if (message.isSystem) {
      return ChatSystemMessage(
        text: message.text,
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }

    final row = message.isMe
        ? ChatSelfMessageBubble(
            message: message,
            style: style,
            onLongPressStart: onLongPressStart,
            onFailedMessageTap: onFailedMessageTap,
          )
        : ChatOtherMessageBubble(
            message: message,
            style: style,
            onAvatarTap: onAvatarTap,
            onLongPressStart: onLongPressStart,
          );
    if (!showDateDivider) return row;

    return Column(
      children: [
        ChatDateDivider(time: message.createdAt, style: style),
        row,
      ],
    );
  }
}
