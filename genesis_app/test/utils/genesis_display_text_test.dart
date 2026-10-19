import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_display_text.dart';

void main() {
  tearDown(() => onMalformedDisplayText = null);

  test('diagnostic contains only bounded metadata and never original text', () {
    final reports = <MalformedDisplayText>[];
    onMalformedDisplayText = reports.add;
    final text = 'private body 😀${List.filled(20, '\uD800').join()}';
    final result = genesisSafeDisplayText(text, source: 'world.character.name');
    expect(result, 'private body 😀${List.filled(20, '�').join()}');
    expect(reports.single.offsets, List.generate(8, (i) => 15 + i));
    expect(reports.single.length, text.length);
    expect(reports.single.toString(), isNot(contains('private body')));
  });

  test('valid text is unchanged and unreported', () {
    onMalformedDisplayText = (_) => fail('valid text reported');
    const text = '👨‍👩‍👧‍👦 🇨🇳 e\u0301\r\n';
    expect(genesisSafeDisplayText(text, source: 'world.tick.body'), text);
  });
}
