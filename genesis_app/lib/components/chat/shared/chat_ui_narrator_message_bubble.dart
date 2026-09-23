part of 'chat_ui_library.dart';

/// Subtle outline shared by Opening and inline narrator editing.
final Border chatNarratorEditorBorder = Border.all(
  color: GenesisColors.darkFaintFill.withValues(alpha: 0.06),
);

Color chatNarratorMessageBackgroundColor(ChatUiStyleConfig style) {
  if (!style.useScenePlateBubbleGeometry ||
      style.useConfiguredScenePlateSystemStyle) {
    return style.systemMessageBackgroundColor;
  }
  return kChatNarratorBubbleColor;
}

TextStyle chatNarratorMessageTextStyle(ChatUiStyleConfig style) {
  if (style.useScenePlateBubbleGeometry &&
      !style.useConfiguredScenePlateSystemStyle) {
    return kChatNarratorTextStyle;
  }
  return style.systemMessageTextStyle.copyWith(fontSize: 14);
}

Color? chatNarratorMessageIconColor(ChatUiStyleConfig style) {
  if (!style.useScenePlateBubbleGeometry) return null;
  return style.useConfiguredScenePlateSystemStyle
      ? chatNarratorMessageTextStyle(style).color
      : Colors.white.withValues(alpha: 0.60);
}

class ChatNarratorMessageBubble extends StatelessWidget {
  const ChatNarratorMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
    this.onFailedMessageTap,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatMessageTap? onFailedMessageTap;

  @override
  Widget build(BuildContext context) {
    final usesScenePlate = style.useScenePlateBubbleGeometry;
    final narratorTextStyle = chatNarratorMessageTextStyle(style);
    final editor = ChatMessageEditorScope.controllerOf(
      context,
      message.localId,
    );
    final bubble = ChatSystemMessage(
      content: editor == null
          ? null
          : _ChatMessageTextEditor(
              messageId: message.localId,
              controller: editor,
              style: usesScenePlate
                  ? genesisSoftItalicStyle(
                      narratorTextStyle,
                      platform: Theme.of(context).platform,
                    )
                  : narratorTextStyle,
            ),
      text: message.text,
      fullWidth: true,
      textAlign: TextAlign.left,
      leadingIconAsset: paragraphIconAsset,
      backgroundColor: chatNarratorMessageBackgroundColor(style),
      border: editor == null ? null : chatNarratorEditorBorder,
      textStyle: narratorTextStyle,
      leadingIconColor: chatNarratorMessageIconColor(style),
      softItalic: usesScenePlate || message.isUserNarration,
      markdownEmphasisColor: narratorTextStyle.color ?? Colors.white,
      style: style,
      onLongPressStart: onLongPressStart,
    );
    if (!message.isUserNarration || !message.isMe) return bubble;
    final failed = message.status == 'failed';
    final sending = message.status == 'sending';
    if (!failed && !sending) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bubble,
        Align(
          alignment: Alignment.centerRight,
          child: failed
              ? Semantics(
                  button: true,
                  label: 'Retry message',
                  child: GestureDetector(
                    key: ValueKey('chat-message-retry-${message.localId}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onFailedMessageTap == null
                        ? null
                        : () => onFailedMessageTap!(message),
                    child: ChatFailedBadge(style: style),
                  ),
                )
              : ChatSendingBadge(style: style),
        ),
      ],
    );
  }
}
