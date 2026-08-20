part of 'chat_ui_library.dart';

class ChatNarratorMessageBubble extends StatelessWidget {
  const ChatNarratorMessageBubble({
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
    final usesScenePlate = style.useScenePlateBubbleGeometry;
    final chatTheme = context.genesisChatTheme;
    return ChatSystemMessage(
      text: message.text,
      fullWidth: true,
      textAlign: TextAlign.left,
      leadingIconAsset: paragraphIconAsset,
      backgroundColor: usesScenePlate ? chatTheme.narratorBackground : null,
      textStyle: usesScenePlate
          ? style.systemMessageTextStyle.copyWith(
              color: chatTheme.narratorForeground,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.6,
            )
          : null,
      leadingIconColor: usesScenePlate ? chatTheme.narratorIcon : null,
      softItalic: usesScenePlate,
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}
