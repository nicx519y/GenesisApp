part of 'chat_ui_library.dart';

class ChatSystemMessage extends StatelessWidget {
  const ChatSystemMessage({
    super.key,
    required this.text,
    this.fullWidth = false,
    this.useFullAvailableWidth = false,
    this.singleLine = false,
    this.textAlign = TextAlign.center,
    this.leadingIconAsset,
    this.bubbleKey = const ValueKey('chat-system-message-bubble'),
    this.onLongPressStart,
    this.style,
  });

  final String text;
  final bool fullWidth;
  final bool useFullAvailableWidth;
  final bool singleLine;
  final TextAlign textAlign;
  final String? leadingIconAsset;
  final Key bubbleKey;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = fullWidth || useFullAvailableWidth
            ? constraints.maxWidth
            : _normalBubbleMaxWidthForWidth(constraints.maxWidth, style);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: fullWidth ? maxBubbleWidth : 0,
              maxWidth: maxBubbleWidth,
            ),
            child: GestureDetector(
              onLongPressStart: onLongPressStart,
              child: Container(
                key: bubbleKey,
                margin: style.systemMessageMargin,
                padding: style.systemMessagePadding,
                decoration: BoxDecoration(
                  color: style.systemMessageBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    style.systemMessageBorderRadius,
                  ),
                ),
                child: leadingIconAsset == null
                    ? _InlineMarkdownText(
                        text: text,
                        maxLines: singleLine ? 1 : null,
                        overflow: singleLine ? TextOverflow.ellipsis : null,
                        textAlign: textAlign,
                        style: style.systemMessageTextStyle,
                      )
                    : _SystemMessageWithLeadingIcon(
                        iconAsset: leadingIconAsset!,
                        text: text,
                        textAlign: textAlign,
                        style: style,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SystemMessageWithLeadingIcon extends StatelessWidget {
  const _SystemMessageWithLeadingIcon({
    required this.iconAsset,
    required this.text,
    required this.textAlign,
    required this.style,
  });

  final String iconAsset;
  final String text;
  final TextAlign textAlign;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final iconColor = style.systemMessageTextStyle.color ?? Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: SvgPicture.asset(
            iconAsset,
            width: 14,
            height: 14,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _InlineMarkdownText(
            text: text,
            textAlign: textAlign,
            style: style.systemMessageTextStyle,
          ),
        ),
      ],
    );
  }
}
