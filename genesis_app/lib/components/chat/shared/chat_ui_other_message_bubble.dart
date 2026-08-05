part of 'chat_ui_library.dart';

class ChatOtherMessageBubble extends StatelessWidget {
  const ChatOtherMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onAvatarTap,
    this.onLongPressStart,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final VoidCallback? onAvatarTap;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = _normalBubbleMaxWidth(context, style);
    final senderName = genesisDisplaySafeText(message.senderName);
    final currentTime = genesisDisplaySafeText(message.currentTime).trim();
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAvatarTap,
                child: _isNpcSender(message.senderId)
                    ? const ChatNpcAvatar()
                    : ChatAvatar(
                        label: chatInitials(message.senderName),
                        imageUrl: message.avatarUrl,
                        colors: style.otherAvatarColors,
                        seed: message.senderName,
                        borderColor: message.isPlayerControlledRole
                            ? GenesisColors.brand
                            : null,
                        style: style,
                      ),
              ),
            ],
          ),
          SizedBox(width: style.avatarBubbleGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (style.showSenderNameAboveOtherBubble) ...[
                  SizedBox(
                    width: maxBubbleWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: message.isPlayerControlledRole
                                ? style.senderNameTextStyle.copyWith(
                                    color: GenesisColors.brand,
                                  )
                                : style.senderNameTextStyle,
                          ),
                        ),
                        if (currentTime.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            currentTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: style.senderNameTextStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: ChatMessageBubble(
                    message: message,
                    style: style,
                    onLongPressStart: onLongPressStart,
                  ),
                ),
              ],
            ),
          ),
          _ChatAvatarSideSpacer(style: style),
        ],
      ),
    );
  }
}
