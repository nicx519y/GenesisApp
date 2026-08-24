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
      // The plate spans the full message column and takes its inner gutter from
      // systemMessagePadding, same as the tick and story plates. It used to run
      // edge to edge, which left the text flush against the plate border.
      textStyle: usesScenePlate
          ? style.systemMessageTextStyle.copyWith(
              color: chatTheme.narratorForeground,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: kChatBodyLineHeight,
            )
          : null,
      leadingIconColor: usesScenePlate ? chatTheme.narratorIcon : null,
      softItalic: usesScenePlate,
      style: style,
      onLongPressStart: onLongPressStart,
    );
  }
}
