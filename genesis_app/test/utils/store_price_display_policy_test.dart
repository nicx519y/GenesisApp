import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/store_price_display_policy.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/platform/billing/membership_product_store.dart';

void main() {
  for (final example in [
    ('NT\$200.00', 'NT\$200'),
    ('NT\$1,310.00', 'NT\$1,310'),
    ('200,00 €', '200 €'),
    ('1.310,00 €', '1.310 €'),
    ('CA\$13.99', 'CA\$13.99'),
    ('6,90 €', '6,90 €'),
    ('₩1,000', '₩1,000'),
    ('¥1.000', '¥1.000'),
  ]) {
    test('price zero decimals ${example.$1}', () {
      expect(trimZeroPriceDecimals(example.$1), example.$2);
    });
  }
  test(
    'subscription total and monthly display trim zeros without mutating quote',
    () {
      final price = MembershipDisplayPrice.fromStore(
        const MembershipStorePrice(
          formattedPrice: 'NT\$2,400.00',
          amountMicros: 2400000000,
          currencyCode: 'TWD',
          currencySymbol: 'NT\$',
        ),
      );
      expect(price.formattedPrice, 'NT\$2,400');
      expect(price.monthlyEquivalent('zh_TW', 12), 'NT\$200');
      expect(price.storeFormattedPrice, 'NT\$2,400.00');
      expect(price.amount, 2400);
    },
  );
}
