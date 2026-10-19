import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/ui/text/genesis_text_input_formatters.dart';

void main() {
  test(
    'formatter keeps paste and deletion selections valid across replacements',
    () {
      const formatter = GenesisDisplaySafeTextInputFormatter();
      var oldValue = TextEditingValue.empty;
      for (final source in [
        'a\u0993\u20E2b',
        'a\u302C\u{13212}\u05B9\u2060\uA673b',
        'a😀b',
        'a\uD800b',
        '',
      ]) {
        for (var base = 0; base <= source.length; base++) {
          final result = formatter.formatEditUpdate(
            oldValue,
            TextEditingValue(
              text: source,
              selection: TextSelection(
                baseOffset: base,
                extentOffset: source.length - base,
              ),
              composing: TextRange(start: 0, end: source.length),
            ),
          );
          expect(
            result.selection.baseOffset,
            inInclusiveRange(0, result.text.length),
          );
          expect(
            result.selection.extentOffset,
            inInclusiveRange(0, result.text.length),
          );
          if (result.text != source) expect(result.composing, TextRange.empty);
          oldValue = result;
        }
      }
      final splitComposing = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: 'a😀b',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      expect(splitComposing.selection.extentOffset, 3);
      expect(splitComposing.composing, TextRange.empty);
    },
  );

  test('replacement maps every source offset into the transformed text', () {
    const source = '\u{302C}\u{13212}\u{05B9}\u{2060}\u{A673}';
    for (var offset = 0; offset <= source.length; offset++) {
      final result = genesisDisplaySafeTextEditingValue(
        TextEditingValue(
          text: source,
          selection: TextSelection.collapsed(offset: offset),
        ),
      );
      expect(result.text, '°ₒ✩');
      expect(result.selection.baseOffset, offset == 0 ? 0 : 3);
    }
  });

  test(
    'reverse selection survives replacement and invalid ranges are repaired',
    () {
      const source = 'a\u{302C}\u{13212}\u{05B9}\u{2060}\u{A673}z';
      final result = genesisDisplaySafeTextEditingValue(
        const TextEditingValue(
          text: source,
          selection: TextSelection(
            baseOffset: 7,
            extentOffset: 1,
            isDirectional: true,
          ),
          composing: TextRange(start: 1, end: 7),
        ),
      );
      expect(
        result.selection,
        const TextSelection(
          baseOffset: 4,
          extentOffset: 1,
          isDirectional: true,
        ),
      );
      expect(result.composing, TextRange.empty);
      final invalid = genesisDisplaySafeTextEditingValue(
        const TextEditingValue(
          text: 'abc',
          selection: TextSelection.collapsed(offset: 28),
          composing: TextRange(start: 1, end: 10),
        ),
      );
      expect(invalid.selection.extentOffset, 3);
      expect(invalid.composing, TextRange.empty);
    },
  );

  test('valid no-selection and composing states are preserved', () {
    const absent = TextEditingValue(text: 'a\uD800');
    expect(
      genesisDisplaySafeTextEditingValue(absent).selection,
      absent.selection,
    );
    const composing = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    expect(genesisDisplaySafeTextEditingValue(composing), composing);
  });

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
