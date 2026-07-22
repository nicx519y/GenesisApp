import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/llm_stream_escape_decoder.dart';

void main() {
  test('hides a trailing backslash until the escaped character arrives', () {
    expect(
      decodeLlmStreamTextForDisplay(r'Hello\', isStreaming: true),
      'Hello',
    );
    expect(
      decodeLlmStreamTextForDisplay(r'Hello\n', isStreaming: true),
      'Hello\n',
    );
  });

  test('decodes standard and general backslash escapes', () {
    expect(
      decodeLlmStreamTextForDisplay(
        r'One\nTwo\tThree\\Four\*Five',
        isStreaming: true,
      ),
      'One\nTwo\tThree\\Four*Five',
    );
  });

  test('waits for all four unicode digits before rendering', () {
    expect(decodeLlmStreamTextForDisplay(r'Hi \u4F', isStreaming: true), 'Hi ');
    expect(
      decodeLlmStreamTextForDisplay(r'Hi \u4F60', isStreaming: true),
      'Hi 你',
    );
  });

  test('waits for a complete unicode surrogate pair', () {
    expect(
      decodeLlmStreamTextForDisplay(r'Hi \uD83D', isStreaming: true),
      'Hi ',
    );
    expect(
      decodeLlmStreamTextForDisplay(r'Hi \uD83D\uDE00', isStreaming: true),
      'Hi 😀',
    );
  });

  test('preserves incomplete escape tails after the stream finishes', () {
    expect(
      decodeLlmStreamTextForDisplay(r'Hi \u12', isStreaming: false),
      r'Hi \u12',
    );
    expect(
      decodeLlmStreamTextForDisplay(r'Hi \uD83D', isStreaming: false),
      r'Hi \uD83D',
    );
  });

  test('falls back to general backslash semantics for invalid unicode', () {
    expect(
      decodeLlmStreamTextForDisplay(r'\u12G4', isStreaming: true),
      'u12G4',
    );
  });
}
