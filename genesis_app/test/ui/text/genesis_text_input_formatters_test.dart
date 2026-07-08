import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/text/genesis_text_input_formatters.dart';

void main() {
  test('genesisDisplaySafeText preserves valid surrogate pairs', () {
    expect(genesisDisplaySafeText('hello \uD83D\uDE00'), 'hello \uD83D\uDE00');
  });

  test('genesisDisplaySafeText replaces isolated surrogate code units', () {
    expect(genesisDisplaySafeText('bad \uD800 text'), 'bad \uFFFD text');
    expect(genesisDisplaySafeText('bad \uDC00 text'), 'bad \uFFFD text');
    expect(genesisDisplaySafeText('bad \uD800'), 'bad \uFFFD');
  });

  test('genesisDisplaySafeTextEditingValue shifts selection after cleanup', () {
    const value = TextEditingValue(
      text: 'a\uD800b',
      selection: TextSelection.collapsed(offset: 3),
    );

    final sanitized = genesisDisplaySafeTextEditingValue(value);

    expect(sanitized.text, 'a\uFFFDb');
    expect(sanitized.selection.baseOffset, 3);
    expect(sanitized.composing, TextRange.empty);
  });
}
