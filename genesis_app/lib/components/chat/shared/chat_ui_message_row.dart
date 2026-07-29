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
    this.style,
  });

  final ChatMessageVm message;
  final bool showDateDivider;
  final List<ChatMessageVm> imageViewerMessages;
  final VoidCallback? onAvatarTap;
  final ChatMessageLongPressStart? onMessageLongPressStart;
  final ChatMessageTap? onFailedMessageTap;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    if (message.isImage) {
      return ChatImageMessage(
        message: message,
        imageViewerMessages: imageViewerMessages,
        style: style,
        onLongPressStart: onMessageLongPressStart == null
            ? null
            : (details) => onMessageLongPressStart!(context, message, details),
      );
    }
    if (message.isSystem) {
      return ChatSystemMessage(
        text: message.isTick ? _tickAdvanceText(message) : message.text,
        fullWidth: message.isTick || message.isNarrator,
        singleLine: message.isTick,
        textAlign: message.isTick || message.isNarrator
            ? TextAlign.left
            : TextAlign.center,
        leadingIconAsset: message.isNarrator ? paragraphIconAsset : null,
        bubbleKey: message.isTick
            ? const ValueKey('chat-tick-message-bubble')
            : const ValueKey('chat-system-message-bubble'),
        style: style,
        onLongPressStart: onMessageLongPressStart == null
            ? null
            : (details) => onMessageLongPressStart!(context, message, details),
      );
    }

    final row = message.isMe
        ? _buildMe(context, style)
        : _buildOther(context, style);
    if (!showDateDivider) return row;

    return Column(
      children: [
        ChatDateDivider(time: message.createdAt, style: style),
        row,
      ],
    );
  }

  Widget _buildMe(BuildContext context, ChatUiStyleConfig style) {
    final maxBubbleWidth = _normalBubbleMaxWidth(context, style);
    final showFailedBadge = message.status == 'failed';
    final showSendingBadge = message.status == 'sending';
    final showStatusText =
        message.status != 'sent' && !showFailedBadge && !showSendingBadge;
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChatAvatarSideSpacer(style: style),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showFailedBadge) ...[
                      GestureDetector(
                        key: ValueKey('chat-message-retry-${message.localId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onFailedMessageTap == null
                            ? null
                            : () => onFailedMessageTap!(message),
                        child: ChatFailedBadge(style: style),
                      ),
                      SizedBox(width: style.badgeBubbleGap),
                    ] else if (showSendingBadge) ...[
                      ChatSendingBadge(style: style),
                      SizedBox(width: style.badgeBubbleGap),
                    ],
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                        child: ChatMessageBubble(
                          message: message,
                          style: style,
                          onTap: showFailedBadge && onFailedMessageTap != null
                              ? () => onFailedMessageTap!(message)
                              : null,
                          onLongPressStart: onMessageLongPressStart == null
                              ? null
                              : (details) => onMessageLongPressStart!(
                                  context,
                                  message,
                                  details,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showStatusText) ...[
                  SizedBox(height: style.statusTextTopGap),
                  Text(
                    genesisDisplaySafeText(message.status),
                    style: style.statusTextStyle,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: style.avatarBubbleGap),
          ChatAvatar(
            label: chatInitials(message.senderName),
            imageUrl: message.avatarUrl,
            colors: style.selfAvatarColors,
            seed: message.senderName,
            borderColor: message.isPlayerControlledRole
                ? GenesisColors.brand
                : null,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _buildOther(BuildContext context, ChatUiStyleConfig style) {
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
                    onLongPressStart: onMessageLongPressStart == null
                        ? null
                        : (details) => onMessageLongPressStart!(
                            context,
                            message,
                            details,
                          ),
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
