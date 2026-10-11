import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/membership_product_store.dart';
import '../../support/membership_fixtures.dart';

const yearlyPrice = MembershipStorePrice(
  formattedPrice: '₩120,000',
  amountMicros: 120000000000,
  currencyCode: 'KRW',
  currencySymbol: '₩',
);
const monthlyPrice = MembershipStorePrice(
  formattedPrice: '₩12,000',
  amountMicros: 12000000000,
  currencyCode: 'KRW',
  currencySymbol: '₩',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MembershipCatalog catalog(MembershipPricesLoader loader) => MembershipCatalog(
    provider: MembershipProvider.google,
    loadProducts: (_) async => MembershipProductList(
      products: [membershipProduct(yearly: true), membershipProduct()],
    ),
    loadStorePrices: loader,
  );
  test(
    'store currency and prices replace API display values and savings',
    () async {
      final source = catalog(
        (_) async => {'pro_yearly': yearlyPrice, 'pro_monthly': monthlyPrice},
      );
      final result = await source.load();
      expect(result.offers.first.price!.formattedPrice, '₩120,000');
      expect(result.offers.last.price!.formattedPrice, '₩12,000');
      expect(result.offers.first.price!.monthlyEquivalent('ko', 12), '₩10,000');
      expect(membershipYearlySavings(result.offers.first, result.offers), 17);
      // Checkout identities and server data are preserved separately.
      expect(
        (await source.readCheckoutProducts()).products.first.priceCurrencyCode,
        'USD',
      );
    },
  );
  test(
    'partial store result falls back to API price for missing plan',
    () async {
      final result = await catalog(
        (_) async => {'pro_monthly': monthlyPrice},
      ).load();
      expect(result.offers.first.price!.currencyCode, 'USD');
      expect(result.offers.first.storePrice, isNull);
      expect(result.offers.last.price!.currencyCode, 'KRW');
      expect(
        membershipYearlySavings(result.offers.first, result.offers),
        isNull,
      );
    },
  );
  test('store failure exposes server price and entry retries lookup', () async {
    var calls = 0;
    final source = catalog((_) async {
      if (++calls == 1) throw StateError('offline');
      return {'pro_yearly': yearlyPrice};
    });
    expect(
      (await source.load()).offers.every(
        (offer) =>
            offer.price!.currencyCode == 'USD' && offer.storePrice == null,
      ),
      isTrue,
    );
    expect(
      (await source.loadForEntry()).offers.first.price!.currencyCode,
      'KRW',
    );
  });
}
