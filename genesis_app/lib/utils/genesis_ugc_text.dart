/// Normalizes user-generated text before it crosses a network or persistence
/// boundary.
///
/// This deliberately does not interpret Markdown, HTML, or Unicode escape
/// text. Literal backslashes are left unchanged because the JSON encoder owns
/// the only transport-escaping layer.
String normalizeGenesisUgcTextForSubmission(String text) {
  return _normalizeGenesisUgcText(text);
}

/// Normalizes user-generated text before it is displayed.
///
/// This is for live input and local drafts that have not crossed the submission
/// boundary. Returned server content must use
/// [decodeGenesisUgcTextForDisplay] instead.
String normalizeGenesisUgcTextForDisplay(String text) {
  return _normalizeGenesisUgcText(text);
}

/// Normalizes UGC returned by the server without interpreting JSON escapes.
///
/// `jsonDecode` has already removed the JSON transport layer. Literal `\n`
/// remains two visible characters, while raw JSON `\n` that represented a real
/// line feed has already become an LF character.
String decodeGenesisUgcTextForDisplay(String text) {
  return _normalizeGenesisUgcText(text);
}

/// Applies the UGC submission rule recursively to JSON-compatible values.
Object? normalizeGenesisUgcValueForSubmission(Object? value) {
  if (value is String) return normalizeGenesisUgcTextForSubmission(value);
  if (value is List) {
    return value
        .map(normalizeGenesisUgcValueForSubmission)
        .toList(growable: false);
  }
  if (value is Map) {
    return <Object?, Object?>{
      for (final entry in value.entries)
        entry.key: normalizeGenesisUgcValueForSubmission(entry.value),
    };
  }
  return value;
}

/// Applies [decodeGenesisUgcTextForDisplay] recursively to JSON-compatible UGC
/// values returned by the server.
Object? decodeGenesisUgcValueForDisplay(Object? value) {
  if (value is String) return decodeGenesisUgcTextForDisplay(value);
  if (value is List) {
    return value.map(decodeGenesisUgcValueForDisplay).toList(growable: false);
  }
  if (value is Map) {
    return <Object?, Object?>{
      for (final entry in value.entries)
        entry.key: decodeGenesisUgcValueForDisplay(entry.value),
    };
  }
  return value;
}

String _normalizeGenesisUgcText(String text) {
  if (text.isEmpty) return text;

  final normalizedNewlines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final output = StringBuffer();
  var index = 0;
  while (index < normalizedNewlines.length) {
    final codeUnit = normalizedNewlines.codeUnitAt(index);
    if (codeUnit < 0xD800 || codeUnit > 0xDFFF) {
      output.writeCharCode(codeUnit);
      index += 1;
      continue;
    }
    if (codeUnit <= 0xDBFF && index + 1 < normalizedNewlines.length) {
      final lowSurrogate = normalizedNewlines.codeUnitAt(index + 1);
      if (lowSurrogate >= 0xDC00 && lowSurrogate <= 0xDFFF) {
        output.writeCharCode(
          0x10000 + ((codeUnit - 0xD800) << 10) + (lowSurrogate - 0xDC00),
        );
        index += 2;
        continue;
      }
    }
    output.writeCharCode(0xFFFD);
    index += 1;
  }
  return output.toString();
}

bool isGenesisUgcTextBlank(String text) =>
    _normalizeGenesisUgcText(text).trim().isEmpty;
