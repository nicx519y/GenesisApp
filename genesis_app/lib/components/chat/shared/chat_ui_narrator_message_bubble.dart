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
    final usesConfiguredSystemStyle =
        usesScenePlate && style.useConfiguredScenePlateSystemStyle;
    return ChatSystemMessage(
      text: message.text,
      fullWidth: true,
      textAlign: TextAlign.left,
      leadingIconAsset: paragraphIconAsset,
      backgroundColor: usesScenePlate
          ? usesConfiguredSystemStyle
                ? style.systemMessageBackgroundColor
                : const Color(0x80151517)
          : null,
      textStyle: usesScenePlate
          ? usesConfiguredSystemStyle
                ? style.systemMessageTextStyle
                : TextStyle(
                    color: Colors.white.withValues(alpha: 0.73),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  )
          : null,
      leadingIconColor: usesScenePlate
          ? Colors.white.withValues(alpha: 0.60)
          : null,
      softItalic: usesScenePlate,
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}
