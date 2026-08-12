part of 'chat_ui_library.dart';

class ChatAiContentDisclaimerMessageBubble extends StatelessWidget {
  const ChatAiContentDisclaimerMessageBubble({
    super.key,
    required this.message,
  });

  final ChatMessageVm message;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>(
        'chat-ai-content-disclaimer-message-${message.localId}',
      ),
      child: AiContentDisclaimer(text: message.text),
    );
  }
}
