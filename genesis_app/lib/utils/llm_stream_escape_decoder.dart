/// Decodes escaped LLM stream text without exposing incomplete trailing
/// sequences while a response is still arriving.
String decodeLlmStreamTextForDisplay(String raw, {required bool isStreaming}) {
  final output = StringBuffer();
  var index = 0;

  String preserveTrailing(int start) {
    if (!isStreaming) output.write(raw.substring(start));
    return output.toString();
  }

  while (index < raw.length) {
    final codeUnit = raw.codeUnitAt(index);
    if (codeUnit != _backslashCodeUnit) {
      output.writeCharCode(codeUnit);
      index += 1;
      continue;
    }

    if (index + 1 >= raw.length) return preserveTrailing(index);
    final escapeCodeUnit = raw.codeUnitAt(index + 1);
    if (escapeCodeUnit != _unicodeEscapeCodeUnit) {
      output.write(_simpleEscape(escapeCodeUnit));
      index += 2;
      continue;
    }

    final unicodeEnd = index + 6;
    if (unicodeEnd > raw.length) return preserveTrailing(index);
    final unicodeCodeUnit = _hexCodeUnit(raw, index + 2);
    if (unicodeCodeUnit == null) {
      output.write('u');
      index += 2;
      continue;
    }

    if (_isHighSurrogate(unicodeCodeUnit)) {
      final lowSurrogateStart = unicodeEnd;
      if (lowSurrogateStart >= raw.length) return preserveTrailing(index);
      if (raw.codeUnitAt(lowSurrogateStart) != _backslashCodeUnit ||
          lowSurrogateStart + 1 >= raw.length ||
          raw.codeUnitAt(lowSurrogateStart + 1) != _unicodeEscapeCodeUnit) {
        output.write(raw.substring(index, unicodeEnd));
        index = unicodeEnd;
        continue;
      }
      final lowSurrogateEnd = lowSurrogateStart + 6;
      if (lowSurrogateEnd > raw.length) return preserveTrailing(index);
      final lowSurrogate = _hexCodeUnit(raw, lowSurrogateStart + 2);
      if (lowSurrogate == null || !_isLowSurrogate(lowSurrogate)) {
        output.write(raw.substring(index, unicodeEnd));
        index = unicodeEnd;
        continue;
      }
      output.writeCharCode(unicodeCodeUnit);
      output.writeCharCode(lowSurrogate);
      index = lowSurrogateEnd;
      continue;
    }

    if (_isLowSurrogate(unicodeCodeUnit)) {
      output.write(raw.substring(index, unicodeEnd));
      index = unicodeEnd;
      continue;
    }

    output.writeCharCode(unicodeCodeUnit);
    index = unicodeEnd;
  }
  return output.toString();
}

const int _backslashCodeUnit = 0x5C;
const int _unicodeEscapeCodeUnit = 0x75;

String _simpleEscape(int codeUnit) {
  return switch (codeUnit) {
    0x62 => '\b',
    0x66 => '\f',
    0x6E => '\n',
    0x72 => '\r',
    0x74 => '\t',
    _ => String.fromCharCode(codeUnit),
  };
}

int? _hexCodeUnit(String value, int start) {
  var result = 0;
  for (var offset = 0; offset < 4; offset += 1) {
    final digit = _hexValue(value.codeUnitAt(start + offset));
    if (digit == null) return null;
    result = result * 16 + digit;
  }
  return result;
}

int? _hexValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
  if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
  return null;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
