part of 'chat_ui_library.dart';

class ChatSystemMessage extends StatelessWidget {
  const ChatSystemMessage({
    super.key,
    required this.text,
    this.fullWidth = false,
    this.singleLine = false,
    this.textAlign = TextAlign.center,
    this.leadingIconAsset,
    this.bubbleKey = const ValueKey('chat-system-message-bubble'),
    this.onLongPressStart,
    this.style,
  });

  final String text;
  final bool fullWidth;
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
        final maxBubbleWidth = fullWidth
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

class _InlineMarkdownText extends StatelessWidget {
  const _InlineMarkdownText({
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.useBaseColorForEmphasis = false,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool useBaseColorForEmphasis;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final textStyle = GenesisTypography.withFallback(style);
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: _inlineMarkdownSpans(
          genesisDisplaySafeText(text),
          textStyle,
          platform,
          useBaseColorForEmphasis: useBaseColorForEmphasis,
        ),
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

List<InlineSpan> _inlineMarkdownSpans(
  String text,
  TextStyle baseStyle,
  TargetPlatform platform, {
  bool useBaseColorForEmphasis = false,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  while (index < text.length) {
    final marker = text[index];
    if (marker == '*' && !_isRepeatedMarker(text, index, marker)) {
      final end = _findInlineItalicEnd(text, index + 1, marker);
      if (end != -1 && end > index + 1) {
        flushPlain();
        spans.addAll(
          _inlineEmphasisSpans(
            text.substring(index + 1, end),
            baseStyle,
            platform,
            color: useBaseColorForEmphasis
                ? baseStyle.color
                : const Color(0xFF888888),
          ),
        );
        index = end + 1;
        continue;
      }
    }
    buffer.write(marker);
    index += 1;
  }

  flushPlain();
  return spans;
}

List<InlineSpan> _inlineEmphasisSpans(
  String text,
  TextStyle baseStyle,
  TargetPlatform platform, {
  Color? color,
}) {
  final style = GenesisTypography.inlineEmphasis(
    baseStyle,
    platform: platform,
    color: color,
  );
  if (platform != TargetPlatform.iOS) {
    return <InlineSpan>[TextSpan(text: text, style: style)];
  }

  return _emphasisTextPieces(text)
      .map(
        (piece) => piece.trim().isEmpty
            ? TextSpan(text: piece, style: style)
            : _skewedInlineEmphasisSpan(piece, style),
      )
      .toList(growable: false);
}

InlineSpan _skewedInlineEmphasisSpan(String text, TextStyle style) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(GenesisTypography.iosInlineEmphasisSkew),
      transformHitTests: false,
      child: Text(text, style: style),
    ),
  );
}

List<String> _emphasisTextPieces(String text) {
  final pieces = <String>[];
  for (final match in RegExp(r'\s+|[^\s]+').allMatches(text)) {
    final piece = match.group(0)!;
    if (piece.trim().isEmpty || !_shouldSplitEmphasisPiece(piece)) {
      pieces.add(piece);
      continue;
    }
    pieces.addAll(piece.runes.map(String.fromCharCode));
  }
  return pieces;
}

bool _shouldSplitEmphasisPiece(String piece) {
  var runeCount = 0;
  for (final rune in piece.runes) {
    runeCount += 1;
    if (rune > 0x7F || runeCount > 16) return true;
  }
  return false;
}

bool _isRepeatedMarker(String text, int index, String marker) {
  return (index > 0 && text[index - 1] == marker) ||
      (index + 1 < text.length && text[index + 1] == marker);
}

int _findInlineItalicEnd(String text, int start, String marker) {
  for (var index = start; index < text.length; index += 1) {
    if (text[index] == marker && !_isRepeatedMarker(text, index, marker)) {
      return index;
    }
  }
  return -1;
}

String _tickAdvanceText(ChatMessageVm message) {
  final tick = message.tickNo > 0 ? '${message.tickNo}' : '';
  final time = message.text.trim();
  final prefix = tick.isEmpty ? 'Tick' : 'Tick $tick';
  return time.isEmpty ? prefix : '$prefix · $time';
}

String chatInitials(String value) {
  return initialsForAvatarName(genesisDisplaySafeText(value));
}

bool _isNpcSender(String senderId) {
  return senderId.trim().toLowerCase() == 'char_npc';
}

String firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
