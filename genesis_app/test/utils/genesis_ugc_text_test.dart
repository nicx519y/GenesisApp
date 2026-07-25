import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_ugc_text.dart';

void main() {
  test('preserves UGC backslashes and other content', () {
    const raw = r'  \n \\ \u300c *italic* 「text」  ';

    expect(normalizeGenesisUgcTextForSubmission(raw), raw);
  });

  test('normalizes platform line endings without trimming content', () {
    expect(
      normalizeGenesisUgcTextForSubmission('  first\r\nsecond\rthird  '),
      '  first\nsecond\nthird  ',
    );
  });

  test('preserves valid surrogate pairs and replaces isolated surrogates', () {
    expect(normalizeGenesisUgcTextForSubmission('😀'), '😀');
    expect(
      normalizeGenesisUgcTextForSubmission('bad \uD800 text'),
      'bad � text',
    );
    expect(
      normalizeGenesisUgcTextForSubmission('bad \uDC00 text'),
      'bad � text',
    );
  });

  test('blank validation does not change the submitted value', () {
    expect(isGenesisUgcTextBlank(' \r\n\t '), isTrue);
    expect(isGenesisUgcTextBlank(r'\n'), isFalse);
  });

  test('display normalization preserves literal escape text', () {
    const raw = r'line\nnext \\ slash \u300c';

    expect(normalizeGenesisUgcTextForDisplay(raw), raw);
  });

  test('display decoding preserves literal backslashes', () {
    expect(decodeGenesisUgcTextForDisplay(r'line\\nnext'), r'line\\nnext');
    expect(decodeGenesisUgcTextForDisplay(r'line\nnext'), r'line\nnext');
    expect(decodeGenesisUgcTextForDisplay('line\nnext'), 'line\nnext');
    expect(
      decodeGenesisUgcTextForDisplay(r'\\\\server\\path'),
      r'\\\\server\\path',
    );
  });

  test('submission and display decoding round-trip literal backslashes', () {
    const input = r'literal \n \u300c \\';
    final submitted = normalizeGenesisUgcTextForSubmission(input);

    expect(submitted, input);
    expect(decodeGenesisUgcTextForDisplay(submitted), input);
  });

  test('literal slash-n and real newline stay distinct across JSON', () {
    expect(jsonEncode({'content': r'\n'}), r'{"content":"\\n"}');
    expect(jsonEncode({'content': '\n'}), r'{"content":"\n"}');

    const input = r'line\nnext';
    final submitted = normalizeGenesisUgcTextForSubmission(input);
    final rawJson = jsonEncode({'content': submitted});
    final pulled =
        (jsonDecode(rawJson) as Map<String, dynamic>)['content'] as String;

    expect(submitted, input);
    expect(rawJson, contains(r'"content":"line\\nnext"'));
    expect(pulled, input);
    expect(decodeGenesisUgcTextForDisplay(pulled), input);

    const realNewline = 'line\nnext';
    final newlineJson = jsonEncode({'content': realNewline});
    expect(newlineJson, contains(r'"content":"line\nnext"'));
    expect(
      (jsonDecode(newlineJson) as Map<String, dynamic>)['content'],
      realNewline,
    );
  });

  test('recursively preserves strings in JSON-compatible UGC values', () {
    expect(
      normalizeGenesisUgcValueForSubmission({
        'label': r'line\nnext',
        'nested': <Object?>[r'\u300c', 1],
      }),
      {
        'label': r'line\nnext',
        'nested': <Object?>[r'\u300c', 1],
      },
    );
  });

  test('recursively preserves returned UGC backslashes', () {
    expect(
      decodeGenesisUgcValueForDisplay({
        'label': r'line\\nnext',
        'nested': <Object?>[r'\\u300c', 1],
      }),
      {
        'label': r'line\\nnext',
        'nested': <Object?>[r'\\u300c', 1],
      },
    );
  });
}
