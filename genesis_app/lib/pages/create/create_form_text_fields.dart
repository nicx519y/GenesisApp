part of 'create_form_library.dart';

typedef CreateKeyboardSafeFocusRegionBuilder =
    Widget Function(BuildContext context, FocusNode focusNode);

class CreateKeyboardSafeFocusRegion extends StatefulWidget {
  const CreateKeyboardSafeFocusRegion({
    super.key,
    required this.builder,
    this.focusNode,
  });

  final CreateKeyboardSafeFocusRegionBuilder builder;
  final FocusNode? focusNode;

  @override
  State<CreateKeyboardSafeFocusRegion> createState() =>
      _CreateKeyboardSafeFocusRegionState();
}

class _CreateKeyboardSafeFocusRegionState
    extends State<CreateKeyboardSafeFocusRegion>
    with WidgetsBindingObserver {
  late final FocusNode _internalFocusNode;
  late FocusNode _observedFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _internalFocusNode = FocusNode();
    _observedFocusNode = _focusNode;
    _observedFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant CreateKeyboardSafeFocusRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _observedFocusNode.removeListener(_handleFocusChanged);
      _observedFocusNode = _focusNode;
      _observedFocusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _observedFocusNode.removeListener(_handleFocusChanged);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_observedFocusNode.hasFocus) _ensureRegionVisible();
  }

  @override
  void didChangeMetrics() {
    if (_observedFocusNode.hasFocus) _ensureRegionVisible();
  }

  void _ensureRegionVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_observedFocusNode.hasFocus) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focusNode);

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;
}

class CreateTextFieldBlock extends StatefulWidget {
  const CreateTextFieldBlock({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLength,
    this.showCounter = true,
    this.counterInside = false,
    this.note,
    this.supportLeading,
    this.minLines = 1,
    this.maxLines,
    this.prefix,
    this.requiredIndicator = false,
    this.labelSize = 13,
    this.labelFontWeight = FontWeight.w600,
    this.labelInputGap = 10,
    this.fieldBorderRadius = 8,
    this.fieldPadding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 10,
    ),
    this.minimumHeight,
    this.inputFontSize = 13,
    this.hintFontSize,
    this.inputLineHeight = 1.42,
    this.textAlign = TextAlign.start,
    this.prefixGap = 8,
    this.supportLineGap = 8,
    this.supportItemGap = 12,
    this.supportTextStyle,
    this.supportTextColor,
    this.supportIconColor,
    this.supportIconSize = 16,
    this.supportIconGap = 5,
    this.counterTextStyle,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.scrollPadding,
    this.visibilityBottomPadding = 0,
    this.inputFormatters = const [],
    this.focusNode,
    this.nextFocusNode,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final bool showCounter;
  final bool counterInside;
  final String? note;
  final Widget? supportLeading;
  final int minLines;
  final int? maxLines;
  final Widget? prefix;
  final bool requiredIndicator;
  final double labelSize;
  final FontWeight labelFontWeight;
  final double labelInputGap;
  final double fieldBorderRadius;
  final EdgeInsets fieldPadding;
  final double? minimumHeight;
  final double inputFontSize;
  final double? hintFontSize;
  final double inputLineHeight;
  final TextAlign textAlign;
  final double prefixGap;
  final double supportLineGap;
  final double supportItemGap;
  final TextStyle? supportTextStyle;
  final Color? supportTextColor;
  final Color? supportIconColor;
  final double supportIconSize;
  final double supportIconGap;
  final TextStyle? counterTextStyle;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsets? scrollPadding;
  final double visibilityBottomPadding;
  final List<TextInputFormatter> inputFormatters;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  @override
  State<CreateTextFieldBlock> createState() => _CreateTextFieldBlockState();
}

class _CreateTextFieldBlockState extends State<CreateTextFieldBlock> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_normalizeControllerText);
    _normalizeControllerText();
  }

  @override
  void didUpdateWidget(covariant CreateTextFieldBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_normalizeControllerText);
      widget.controller.addListener(_normalizeControllerText);
      _normalizeControllerText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_normalizeControllerText);
    super.dispose();
  }

  void _normalizeControllerText() {
    if (_isSingleLine) return;
    final value = widget.controller.value;
    final sanitized = genesisConsecutiveNewlineLimitedTextEditingValue(value);
    if (sanitized == value) return;
    widget.controller.value = sanitized;
  }

  void _handleEditingComplete(FocusNode focusNode) {
    final customHandler = widget.onEditingComplete;
    if (customHandler != null) {
      customHandler();
      return;
    }

    final nextFocusNode = widget.nextFocusNode;
    if (nextFocusNode != null && nextFocusNode.canRequestFocus) {
      nextFocusNode.requestFocus();
      return;
    }

    if (!focusNode.nextFocus()) {
      focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CreateKeyboardSafeFocusRegion(
      focusNode: widget.focusNode,
      builder: (context, focusNode) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty) ...[
            GenesisFieldLabel(
              text: widget.label,
              requiredIndicator: widget.requiredIndicator,
              // 必填星号统一用粉色,与弹窗/上传框里的粉色图标同色。
              requiredColor: context.genesisCreateColors.successText,
              style: TextStyle(
                color: context.genesisCreateColors.text,
                fontSize: widget.labelSize,
                fontWeight: widget.labelFontWeight,
                height: 1.2,
              ),
            ),
            // Field internal spacing: label -> input box.
            SizedBox(height: widget.labelInputGap),
          ],
          GenesisFieldSurface(
            constraints: widget.minimumHeight == null
                ? null
                : BoxConstraints(minHeight: widget.minimumHeight!),
            backgroundColor: context.genesisCreateColors.fieldFill,
            borderRadius: BorderRadius.circular(widget.fieldBorderRadius),
            showBorder: false,
            padding: widget.fieldPadding,
            alignment: _isSingleLine ? Alignment.center : Alignment.topCenter,
            child: Row(
              crossAxisAlignment: _isSingleLine
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  SizedBox(width: widget.prefixGap),
                ],
                Expanded(
                  child: TextFieldTapRegion(
                    groupId: createFormTextFieldTapRegionGroup,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: focusNode,
                      scrollPadding:
                          widget.scrollPadding ??
                          const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            kMinInteractiveDimension,
                          ),
                      onChanged: widget.onChanged,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      keyboardType: _resolvedKeyboardType,
                      textInputAction: _resolvedTextInputAction,
                      onEditingComplete: _shouldHandleEditingComplete
                          ? () => _handleEditingComplete(focusNode)
                          : null,
                      onSubmitted: widget.onSubmitted,
                      inputFormatters: [
                        if (!_isSingleLine)
                          const GenesisConsecutiveNewlineLimiter(),
                        ...widget.inputFormatters,
                      ],
                      maxLength: widget.maxLength,
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      textAlign: widget.textAlign,
                      cursorColor: context.genesisCreateColors.text,
                      style: GenesisTypography.withFallback(
                        TextStyle(
                          color: context.genesisCreateColors.text,
                          fontSize: widget.inputFontSize,
                          height: widget.inputLineHeight,
                        ),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: widget.hintText,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: GenesisTypography.withFallback(
                          TextStyle(
                            color: context.genesisCreateColors.hint,
                            fontSize:
                                widget.hintFontSize ?? widget.inputFontSize,
                            letterSpacing: 0,
                            height: widget.inputLineHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showsCounterInside) ...[
                  SizedBox(width: 8),
                  _CreateFieldCounter(
                    counter: _counterText,
                    textStyle: widget.counterTextStyle,
                  ),
                ],
              ],
            ),
          ),
          if (_hasSupportLine) ...[
            SizedBox(height: widget.supportLineGap),
            _CreateFieldSupportLine(
              note: widget.note,
              counter: _showsCounterOutside ? _counterText : null,
              leading: widget.supportLeading,
              itemGap: widget.supportItemGap,
              noteTextStyle: widget.supportTextStyle,
              noteTextColor: widget.supportTextColor,
              noteIconColor: widget.supportIconColor,
              noteIconSize: widget.supportIconSize,
              noteIconGap: widget.supportIconGap,
              counterTextStyle: widget.counterTextStyle,
            ),
          ],
          if (widget.visibilityBottomPadding > 0)
            SizedBox(height: widget.visibilityBottomPadding),
        ],
      ),
    );
  }

  bool get _hasNote => widget.note?.trim().isNotEmpty == true;

  bool get _hasSupportLine =>
      widget.supportLeading != null || _hasNote || _showsCounterOutside;

  bool get _showsCounterInside =>
      widget.counterInside && widget.maxLength != null && widget.showCounter;

  bool get _showsCounterOutside =>
      !widget.counterInside && widget.maxLength != null && widget.showCounter;

  String get _counterText =>
      '${widget.controller.text.characters.length} / ${widget.maxLength}';

  bool get _isSingleLine =>
      (widget.maxLines ?? widget.minLines) == 1 && widget.minLines == 1;

  TextInputAction get _resolvedTextInputAction {
    final action = widget.textInputAction;
    if (action != null) return action;
    return _isSingleLine ? TextInputAction.done : TextInputAction.newline;
  }

  TextInputType get _resolvedKeyboardType {
    return _isSingleLine ? TextInputType.text : TextInputType.multiline;
  }

  bool get _shouldHandleEditingComplete {
    if (widget.onEditingComplete != null) return true;
    return _resolvedTextInputAction != TextInputAction.newline;
  }
}

class _CreateFieldSupportLine extends StatelessWidget {
  const _CreateFieldSupportLine({
    required this.note,
    required this.counter,
    required this.leading,
    required this.itemGap,
    required this.noteTextStyle,
    required this.noteTextColor,
    required this.noteIconColor,
    required this.noteIconSize,
    required this.noteIconGap,
    required this.counterTextStyle,
  });

  final String? note;
  final String? counter;
  final Widget? leading;
  final double itemGap;
  final TextStyle? noteTextStyle;
  final Color? noteTextColor;
  final Color? noteIconColor;
  final double noteIconSize;
  final double noteIconGap;
  final TextStyle? counterTextStyle;

  @override
  Widget build(BuildContext context) {
    final normalizedNote = note?.trim() ?? '';
    final hasNote = normalizedNote.isNotEmpty;
    if (!hasNote && leading == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: _CreateFieldCounter(
          counter: counter ?? '',
          textStyle: counterTextStyle,
        ),
      );
    }
    if (!hasNote && leading != null) {
      return SizedBox(
        height: 32,
        child: Stack(
          children: [
            Align(alignment: Alignment.topLeft, child: leading),
            if (counter != null)
              Align(
                alignment: Alignment.topRight,
                child: _CreateFieldCounter(
                  counter: counter!,
                  textStyle: counterTextStyle,
                ),
              ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) leading!,
        if (leading != null && hasNote) SizedBox(width: itemGap),
        if (hasNote)
          Expanded(
            child: CreateFormNote(
              note: normalizedNote,
              textStyle: noteTextStyle,
              textColor: noteTextColor,
              iconColor: noteIconColor,
              iconSize: noteIconSize,
              iconGap: noteIconGap,
            ),
          )
        else
          const Spacer(),
        if (counter != null) ...[
          SizedBox(width: itemGap),
          _CreateFieldCounter(counter: counter!, textStyle: counterTextStyle),
        ],
      ],
    );
  }
}

class CreateFormNote extends StatelessWidget {
  const CreateFormNote({
    super.key,
    required this.note,
    this.markdown = false,
    this.textStyle,
    this.textColor,
    this.iconColor,
    this.iconSize = 16,
    this.iconGap = 5,
  });

  final String note;
  final bool markdown;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? iconColor;
  final double iconSize;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: SvgPicture.asset(
            createFormInfoIconAsset,
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(
              iconColor ?? context.genesisCreateColors.note,
              BlendMode.srcIn,
            ),
          ),
        ),
        SizedBox(width: iconGap),
        Expanded(
          child: _CreateFormNoteText(
            note: note,
            markdown: markdown,
            textStyle: textStyle,
            textColor: textColor,
          ),
        ),
      ],
    );
  }
}

class _CreateFormNoteText extends StatelessWidget {
  const _CreateFormNoteText({
    required this.note,
    required this.markdown,
    required this.textStyle,
    required this.textColor,
  });

  final String note;
  final bool markdown;
  final TextStyle? textStyle;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = (textStyle ?? createFormSupportTextStyle).copyWith(
      color: textColor ?? textStyle?.color ?? context.genesisCreateColors.note,
    );
    if (!markdown) {
      return Text(note, softWrap: true, style: baseStyle);
    }

    final platform = Theme.of(context).platform;
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _markdownSpans(note, platform),
      ),
    );
  }

  List<InlineSpan> _markdownSpans(String value, TargetPlatform platform) {
    final spans = <InlineSpan>[];
    var index = 0;
    while (index < value.length) {
      final boldStart = value.indexOf('**', index);
      final italicStart = value.indexOf('*', index);
      final nextStart = _nextMarkdownStart(boldStart, italicStart);
      if (nextStart < 0) {
        spans.add(TextSpan(text: value.substring(index)));
        break;
      }
      if (nextStart > index) {
        spans.add(TextSpan(text: value.substring(index, nextStart)));
      }

      if (boldStart == nextStart) {
        final end = value.indexOf('**', nextStart + 2);
        if (end < 0) {
          spans.add(TextSpan(text: value.substring(nextStart)));
          break;
        }
        spans.add(
          TextSpan(
            text: value.substring(nextStart + 2, end),
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        );
        index = end + 2;
      } else {
        final end = value.indexOf('*', nextStart + 1);
        if (end < 0) {
          spans.add(TextSpan(text: value.substring(nextStart)));
          break;
        }
        spans.addAll(
          _inlineEmphasisSpans(value.substring(nextStart + 1, end), platform),
        );
        index = end + 1;
      }
    }
    return spans;
  }

  int _nextMarkdownStart(int boldStart, int italicStart) {
    final normalizedItalicStart = italicStart == boldStart
        ? _valueNotFound
        : italicStart;
    if (boldStart < 0) return normalizedItalicStart;
    if (normalizedItalicStart < 0) return boldStart;
    return boldStart < normalizedItalicStart
        ? boldStart
        : normalizedItalicStart;
  }
}

List<InlineSpan> _inlineEmphasisSpans(String text, TargetPlatform platform) {
  final style = GenesisTypography.inlineEmphasis(
    TextStyle(),
    platform: platform,
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

const int _valueNotFound = -1;

class _CreateFieldCounter extends StatelessWidget {
  const _CreateFieldCounter({required this.counter, this.textStyle});

  final String counter;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      counter,
      textAlign: TextAlign.right,
      style: (textStyle ?? createFormSupportTextStyle).copyWith(
        color: textStyle?.color ?? context.genesisCreateColors.muted,
      ),
    );
  }
}
