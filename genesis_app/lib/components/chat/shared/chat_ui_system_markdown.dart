part of 'chat_ui_library.dart';

class _InlineMarkdownText extends StatelessWidget {
  const _InlineMarkdownText({
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softItalic = false,
    this.softItalicPerToken = false,
    this.emphasisColor = const Color(0xFF888888),
  }) : assert(!softItalic || !softItalicPerToken);

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softItalic;
  final bool softItalicPerToken;
  final Color emphasisColor;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final usesIosSoftItalicSkew =
        platform == TargetPlatform.iOS &&
        GenesisTypography.useIosSoftItalicSkew;
    final usesSoftItalic = softItalic || softItalicPerToken;
    final textStyle = usesSoftItalic
        ? genesisSoftItalicStyle(style, platform: platform)
        : GenesisTypography.withFallback(style);
    final displayText = genesisDisplaySafeText(text);
    final mentionCatalog = ChatMentionScope.maybeCatalogOf(context);
    final textWidget = Text.rich(
      TextSpan(
        style: textStyle,
        children: _inlineMarkdownSpans(
          displayText,
          textStyle,
          platform,
          mentionCatalog: mentionCatalog,
          emphasisColor: emphasisColor,
          suppressIosEmphasisSkew: softItalic && usesIosSoftItalicSkew,
          softItalicPlainText: softItalicPerToken && usesIosSoftItalicSkew,
        ),
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: softItalicPerToken && usesIosSoftItalicSkew
          ? displayText
          : null,
    );
    if (!softItalic) return textWidget;
    return genesisSoftItalicForPlatform(child: textWidget, platform: platform);
  }
}

List<InlineSpan> _inlineMarkdownSpans(
  String text,
  TextStyle baseStyle,
  TargetPlatform platform, {
  required ChatMentionCatalog? mentionCatalog,
  required Color emphasisColor,
  bool suppressIosEmphasisSkew = false,
  bool softItalicPlainText = false,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var index = 0;

  void flushPlain() {
    if (buffer.isEmpty) return;
    final plainText = buffer.toString();
    final mentionStyle = softItalicPlainText
        ? GenesisTypography.inlineEmphasis(
            baseStyle,
            platform: platform,
            color: baseStyle.color,
          )
        : baseStyle;
    spans.addAll(
      _chatMentionAwareSpans(
        plainText,
        mentionCatalog,
        mentionStyle,
        (piece) => softItalicPlainText
            ? _inlineEmphasisSpans(
                piece,
                baseStyle,
                platform,
                color: baseStyle.color,
              )
            : <InlineSpan>[TextSpan(text: piece)],
      ),
    );
    buffer.clear();
  }

  while (index < text.length) {
    final marker = text[index];
    if (marker == '*' && !_isRepeatedMarker(text, index, marker)) {
      final end = _findInlineItalicEnd(text, index + 1, marker);
      if (end != -1 && end > index + 1) {
        flushPlain();
        final mentionStyle = suppressIosEmphasisSkew
            ? baseStyle.copyWith(color: emphasisColor)
            : GenesisTypography.inlineEmphasis(
                baseStyle,
                platform: platform,
                color: emphasisColor,
              );
        spans.addAll(
          _chatMentionAwareSpans(
            text.substring(index + 1, end),
            mentionCatalog,
            mentionStyle,
            (piece) => suppressIosEmphasisSkew
                ? <InlineSpan>[
                    TextSpan(
                      text: piece,
                      style: baseStyle.copyWith(color: emphasisColor),
                    ),
                  ]
                : _inlineEmphasisSpans(
                    piece,
                    baseStyle,
                    platform,
                    color: emphasisColor,
                  ),
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

List<InlineSpan> _chatMentionAwareSpans(
  String text,
  ChatMentionCatalog? catalog,
  TextStyle mentionStyle,
  List<InlineSpan> Function(String text) plainSpans,
) {
  if (text.isEmpty) return const <InlineSpan>[];
  if (catalog == null || catalog.isEmpty) return plainSpans(text);
  final mentions = parseKnownChatMentions(text, catalog);
  if (mentions.isEmpty) return plainSpans(text);

  final spans = <InlineSpan>[];
  var offset = 0;
  for (final mention in mentions) {
    if (mention.start > offset) {
      spans.addAll(plainSpans(text.substring(offset, mention.start)));
    }
    spans.add(_chatMentionIconSpan(mention.entry.type, mentionStyle));
    spans.addAll(plainSpans(mention.name));
    offset = mention.end;
  }
  if (offset < text.length) {
    spans.addAll(plainSpans(text.substring(offset)));
  }
  return spans;
}

InlineSpan _chatMentionIconSpan(ChatMentionType type, TextStyle style) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: ExcludeSemantics(
      child: Icon(
        type == ChatMentionType.character
            ? Icons.person_outline_rounded
            : Icons.place_outlined,
        size: style.fontSize ?? 14,
        color: style.color,
      ),
    ),
  );
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
  if (platform != TargetPlatform.iOS ||
      !GenesisTypography.useIosSoftItalicSkew) {
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
  final time = message.text.trim();
  final prefix = _tickLabel(message);
  return time.isEmpty ? prefix : '$prefix · $time';
}

String _tickLabel(ChatMessageVm message) {
  if (message.tickNo < 0) return 'Tick';
  final subTick = message.subTickNo > 0 ? '-${message.subTickNo}' : '';
  return 'Tick ${message.tickNo}$subTick';
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
