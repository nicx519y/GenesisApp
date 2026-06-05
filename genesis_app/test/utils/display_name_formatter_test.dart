import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/display_name_formatter.dart';

void main() {
  test('originDisplayName adds one hash prefix', () {
    expect(originDisplayName('Origin One'), '#Origin One');
    expect(originDisplayName('#Origin One'), '#Origin One');
    expect(originDisplayName('', fallback: 'o_1'), '#o_1');
    expect(originDisplayName('   '), '');
  });

  test('formatUidForDisplay lowercases only the uid prefix', () {
    expect(formatUidForDisplay('U_ABC123'), 'u_ABC123');
    expect(formatUidForDisplay(' u_ABC123 '), 'u_ABC123');
    expect(formatUidForDisplay('', fallback: 'U_FALLBACK'), 'u_FALLBACK');
    expect(formatUidForDisplay('USER_ABC'), 'USER_ABC');
  });
}
