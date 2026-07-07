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
  final text = genesisDisplaySafeText(value.text);
  if (text == value.text) return value;

  return TextEditingValue(
    text: text,
    selection: _shiftSelectionForTransformedText(value),
    composing: TextRange.empty,
  );
}

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

String genesisDisplaySafeText(String text) {
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    final replacement = _decorativeReplacementAt(text, index);
    if (replacement != null) {
      buffer.write(replacement.text);
      index += replacement.sourceLength;
      continue;
    }

    final rune = _runeAt(text, index);
    buffer.writeCharCode(rune);
    index += rune > 0xFFFF ? 2 : 1;
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

int _runeAt(String text, int index) {
  final codeUnit = text.codeUnitAt(index);
  if (codeUnit < 0xD800 || codeUnit > 0xDBFF || index + 1 >= text.length) {
    return codeUnit;
  }

  final next = text.codeUnitAt(index + 1);
  if (next < 0xDC00 || next > 0xDFFF) return codeUnit;
  return 0x10000 + ((codeUnit - 0xD800) << 10) + (next - 0xDC00);
}

TextSelection _shiftSelectionForTransformedText(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) {
    return TextSelection.collapsed(
      offset: genesisDisplaySafeText(value.text).length,
    );
  }

  return TextSelection(
    baseOffset: _transformedOffsetBefore(value.text, selection.baseOffset),
    extentOffset: _transformedOffsetBefore(value.text, selection.extentOffset),
    affinity: selection.affinity,
    isDirectional: selection.isDirectional,
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

int _transformedOffsetBefore(String text, int offset) {
  final clampedOffset = offset.clamp(0, text.length);
  return genesisDisplaySafeText(text.substring(0, clampedOffset)).length;
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
