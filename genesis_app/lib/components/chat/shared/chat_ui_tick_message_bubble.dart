part of 'chat_ui_library.dart';

class ChatTickMessageBubble extends StatelessWidget {
  const ChatTickMessageBubble({
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
    return ChatSystemMessage(
      text: _tickAdvanceText(message),
      fullWidth: true,
      singleLine: true,
      textAlign: TextAlign.left,
      bubbleKey: const ValueKey('chat-tick-message-bubble'),
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}
