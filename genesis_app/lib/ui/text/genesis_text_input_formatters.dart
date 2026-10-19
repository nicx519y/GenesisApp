import 'package:flutter/services.dart';

class GenesisDisplaySafeTextInputFormatter extends TextInputFormatter {
  const GenesisDisplaySafeTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return genesisDisplaySafeTextEditingValue(newValue);
  }
}

class GenesisConsecutiveNewlineLimiter extends TextInputFormatter {
  const GenesisConsecutiveNewlineLimiter({this.maxConsecutiveNewlines = 2});

  final int maxConsecutiveNewlines;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return genesisConsecutiveNewlineLimitedTextEditingValue(
      newValue,
      maxConsecutiveNewlines: maxConsecutiveNewlines,
    );
  }
}

TextEditingValue genesisDisplaySafeTextEditingValue(TextEditingValue value) {
  final offsets = List<int>.filled(value.text.length + 1, 0);
  final text = _transformDisplaySafeText(value.text, offsets: offsets);
  final selection = value.selection;
  final nextSelection =
      selection.baseOffset == -1 && selection.extentOffset == -1
      ? selection
      : TextSelection(
          baseOffset: offsets[selection.baseOffset.clamp(0, value.text.length)],
          extentOffset:
              offsets[selection.extentOffset.clamp(0, value.text.length)],
          affinity: selection.affinity,
          isDirectional: selection.isDirectional,
        );
  final composing = value.composing;
  final validComposing =
      composing.isValid &&
      composing.isNormalized &&
      composing.end <= text.length &&
      _isCodePointBoundary(text, composing.start) &&
      _isCodePointBoundary(text, composing.end);
  return value.copyWith(
    text: text,
    selection: nextSelection,
    composing: text == value.text && validComposing
        ? composing
        : TextRange.empty,
  );
}

bool _isCodePointBoundary(String text, int offset) =>
    offset <= 0 ||
    offset >= text.length ||
    !(text.codeUnitAt(offset - 1) >= 0xD800 &&
        text.codeUnitAt(offset - 1) <= 0xDBFF &&
        text.codeUnitAt(offset) >= 0xDC00 &&
        text.codeUnitAt(offset) <= 0xDFFF);

TextEditingValue genesisConsecutiveNewlineLimitedTextEditingValue(
  TextEditingValue value, {
  int maxConsecutiveNewlines = 2,
}) {
  final text = genesisLimitConsecutiveNewlines(
    value.text,
    maxConsecutiveNewlines: maxConsecutiveNewlines,
  );
  if (text == value.text) return value;

  return TextEditingValue(
    text: text,
    selection: _shiftSelectionForConsecutiveNewlineLimit(
      value,
      maxConsecutiveNewlines,
    ),
    composing: TextRange.empty,
  );
}

String genesisDisplaySafeText(String text) => _transformDisplaySafeText(text);

String _transformDisplaySafeText(String text, {List<int>? offsets}) {
  final buffer = StringBuffer();
  var index = 0;
  var outputOffset = 0;
  while (index < text.length) {
    final replacement = _decorativeReplacementAt(text, index);
    final rune = replacement == null ? _displaySafeRuneAt(text, index) : null;
    final output = replacement?.text ?? String.fromCharCode(rune!.codePoint);
    final length = replacement?.sourceLength ?? rune!.sourceLength;
    buffer.write(output);
    outputOffset += output.length;
    // Interior offsets snap to the end of this complete replacement/code point.
    if (offsets != null) {
      for (var i = index + 1; i <= index + length; i++) {
        offsets[i] = outputOffset;
      }
    }
    index += length;
  }
  return buffer.toString();
}

String genesisLimitConsecutiveNewlines(
  String text, {
  int maxConsecutiveNewlines = 2,
}) {
  if (text.isEmpty || maxConsecutiveNewlines < 1) return text;
  return text.replaceAll(
    RegExp('\\n{${maxConsecutiveNewlines + 1},}'),
    ''.padLeft(maxConsecutiveNewlines, '\n'),
  );
}

_DisplaySafeRune _displaySafeRuneAt(String text, int index) {
  final codeUnit = text.codeUnitAt(index);
  if (codeUnit < 0xD800 || codeUnit > 0xDFFF) {
    return _DisplaySafeRune(codeUnit, 1);
  }
  if (codeUnit > 0xDBFF) {
    return const _DisplaySafeRune(0xFFFD, 1);
  }
  if (index + 1 >= text.length) {
    return const _DisplaySafeRune(0xFFFD, 1);
  }

  final next = text.codeUnitAt(index + 1);
  if (next < 0xDC00 || next > 0xDFFF) {
    return const _DisplaySafeRune(0xFFFD, 1);
  }
  return _DisplaySafeRune(
    0x10000 + ((codeUnit - 0xD800) << 10) + (next - 0xDC00),
    2,
  );
}

TextSelection _shiftSelectionForConsecutiveNewlineLimit(
  TextEditingValue value,
  int maxConsecutiveNewlines,
) {
  final selection = value.selection;
  if (!selection.isValid) {
    return TextSelection.collapsed(
      offset: genesisLimitConsecutiveNewlines(
        value.text,
        maxConsecutiveNewlines: maxConsecutiveNewlines,
      ).length,
    );
  }

  return TextSelection(
    baseOffset: _newlineLimitedOffsetBefore(
      value.text,
      selection.baseOffset,
      maxConsecutiveNewlines,
    ),
    extentOffset: _newlineLimitedOffsetBefore(
      value.text,
      selection.extentOffset,
      maxConsecutiveNewlines,
    ),
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
  );
}

int _newlineLimitedOffsetBefore(
  String text,
  int offset,
  int maxConsecutiveNewlines,
) {
  final clampedOffset = offset.clamp(0, text.length);
  return genesisLimitConsecutiveNewlines(
    text.substring(0, clampedOffset),
    maxConsecutiveNewlines: maxConsecutiveNewlines,
  ).length;
}

_DecorativeReplacement? _decorativeReplacementAt(String text, int index) {
  for (final replacement in _decorativeReplacements) {
    if (text.startsWith(replacement.source, index)) return replacement;
  }
  return null;
}

const List<_DecorativeReplacement> _decorativeReplacements =
    <_DecorativeReplacement>[
      _DecorativeReplacement('\u{0993}\u{20E2}', '▤▤▤'),
      _DecorativeReplacement(
        '\u{302C}\u{13212}\u{05B9}\u{2060}\u{A673}',
        '°ₒ✩',
      ),
    ];

class _DecorativeReplacement {
  const _DecorativeReplacement(this.source, this.text);

  final String source;
  final String text;

  int get sourceLength => source.length;
}

class _DisplaySafeRune {
  const _DisplaySafeRune(this.codePoint, this.sourceLength);

  final int codePoint;
  final int sourceLength;
}
