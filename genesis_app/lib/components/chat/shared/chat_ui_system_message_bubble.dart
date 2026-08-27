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
    this.backgroundColor,
    this.textStyle,
    this.leadingIconColor,
    this.softItalic = false,
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
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final Color? leadingIconColor;
  final bool softItalic;
  final Key bubbleKey;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsSceneColumn = style.useScenePlateBubbleGeometry;
        final maxBubbleWidth =
            fullWidth || useFullAvailableWidth || fillsSceneColumn
            ? constraints.maxWidth
            : _normalBubbleMaxWidthForWidth(constraints.maxWidth, style);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: fullWidth || fillsSceneColumn ? maxBubbleWidth : 0,
              maxWidth: maxBubbleWidth,
            ),
            child: GestureDetector(
              onLongPressStart: onLongPressStart,
              child: Container(
                key: bubbleKey,
                margin: style.systemMessageMargin,
                padding: style.systemMessagePadding,
                decoration: BoxDecoration(
                  color: backgroundColor ?? style.systemMessageBackgroundColor,
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
                        style: textStyle ?? style.systemMessageTextStyle,
                        softItalic: softItalic,
                      )
                    : _SystemMessageWithLeadingIcon(
                        iconAsset: leadingIconAsset!,
                        text: text,
                        textAlign: textAlign,
                        style: style,
                        textStyle: textStyle,
                        iconColor: leadingIconColor,
                        softItalic: softItalic,
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
    this.textStyle,
    this.iconColor,
    this.softItalic = false,
  });

  final String iconAsset;
  final String text;
  final TextAlign textAlign;
  final ChatUiStyleConfig style;
  final TextStyle? textStyle;
  final Color? iconColor;
  final bool softItalic;

  @override
  Widget build(BuildContext context) {
    final resolvedTextStyle = textStyle ?? style.systemMessageTextStyle;
    final resolvedIconColor =
        iconColor ?? resolvedTextStyle.color ?? Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: SvgPicture.asset(
            iconAsset,
            width: 13,
            height: 13,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(resolvedIconColor, BlendMode.srcIn),
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _InlineMarkdownText(
            text: text,
            textAlign: textAlign,
            style: resolvedTextStyle,
            softItalic: softItalic,
          ),
        ),
      ],
    );
  }
}
