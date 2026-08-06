part of 'chat_ui_library.dart';

class ChatUserEnterLocationMessageBubble extends StatelessWidget {
  const ChatUserEnterLocationMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final payload = message.timelinePayload;
    if (payload is! ChatUserEnterLocationPayloadVm) {
      return const SizedBox.shrink();
    }
    return ChatSystemMessage(
      text: payload.text,
      fullWidth: true,
      textAlign: TextAlign.left,
      bubbleKey: ValueKey<String>(
        'chat-user-enter-location-message-${message.localId}',
      ),
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}
