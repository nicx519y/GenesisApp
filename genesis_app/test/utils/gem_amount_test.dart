import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/gem_amount.dart';

void main() {
  group('requireGemCent', () {
    test('accepts integer cent values', () {
      expect(requireGemCent(1250, fieldName: 'balance_cent'), 1250);
      expect(requireGemCent(-10, fieldName: 'amount_cent'), -10);
    });

    test('rejects missing and non-integer values', () {
      for (final value in <Object?>[null, 10.0, '10', true]) {
        expect(
          () => requireGemCent(value, fieldName: 'balance_cent'),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  group('formatGemCent', () {
    test('always renders one decimal place without floating point', () {
      expect(formatGemCent(10000), '100.0');
      expect(formatGemCent(100), '1.0');
      expect(formatGemCent(10), '0.1');
      expect(formatGemCent(1), '0.0');
      expect(formatGemCent(0), '0.0');
      expect(formatGemCent(123456), '1,234.6');
      expect(formatGemCent(-10), '-0.1');
      expect(formatGemCent(-1), '0.0');
    });

    test('rounds cent values to the nearest tenth of a Gem', () {
      expect(formatGemCent(104), '1.0');
      expect(formatGemCent(105), '1.1');
      expect(formatGemCent(-104), '-1.0');
      expect(formatGemCent(-105), '-1.1');
    });
  });

  group('formatWholeGemCent', () {
    test('renders grouped whole Gems without a decimal point', () {
      expect(formatWholeGemCent(10000), '100');
      expect(formatWholeGemCent(123456), '1,235');
      expect(formatWholeGemCent(-10000), '-100');
      expect(formatWholeGemCent(0), '0');
    });

    test('rounds cent values to the nearest whole Gem', () {
      expect(formatWholeGemCent(149), '1');
      expect(formatWholeGemCent(150), '2');
      expect(formatWholeGemCent(-149), '-1');
      expect(formatWholeGemCent(-150), '-2');
    });
  });
}
