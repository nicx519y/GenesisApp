import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/membership_catalog_cache.dart';
import 'package:genesis_flutter_android/platform/billing/membership_product_store.dart';
import '../../support/membership_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'restart restores exact store display price but not checkout credentials',
    () async {
      final products = MembershipProductList(
        products: [membershipProduct(yearly: true)],
      );
      const price = MembershipStorePrice(
        formattedPrice: '₩120,000',
        amountMicros: 120000000000,
        currencyCode: 'KRW',
        currencySymbol: '₩',
      );
      await MembershipCatalogCache(namespace: 'disk').save(
        MembershipProvider.google,
        'user-a',
        products,
        prices: {'pro_yearly': price},
      );
      var calls = 0;
      final source = MembershipCatalog(
        provider: MembershipProvider.google,
        cacheStore: MembershipCatalogCache(namespace: 'disk'),
        readOwnerUid: () async => 'user-a',
        loadProducts: (_) async => products,
        loadStorePrices: (_) async {
          calls++;
          return {};
        },
      );
      final cached = await source.loadCached();
      expect(cached!.offers.single.price!.formattedPrice, '₩120,000');
      expect(
        cached.offers.single.price!.monthlyEquivalent('ko', 12),
        '₩10,000',
      );
      expect(calls, 0);
      await expectLater(source.readCheckoutProducts(), throwsStateError);
      expect(
        (await source.loadForEntry()).offers.single.price!.currencyCode,
        'USD',
      );
      expect(calls, 1);
      expect(
        await MembershipCatalogCache(
          namespace: 'disk',
        ).loadSnapshot(MembershipProvider.google, 'user-b'),
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefs.getKeys().single)!;
      expect(raw, contains('cached_at'));
      expect(raw, isNot(contains('offer_token')));
      expect(raw, isNot(contains('account_uuid')));
    },
  );
  test(
    'legacy cache displays server price without store verification',
    () async {
      await MembershipCatalogCache(namespace: 'old').save(
        MembershipProvider.google,
        null,
        MembershipProductList(products: [membershipProduct()]),
      );
      final source = MembershipCatalog(
        provider: MembershipProvider.google,
        cacheStore: MembershipCatalogCache(namespace: 'old'),
        loadProducts: (_) async => MembershipProductList(products: []),
        loadStorePrices: (_) async => {},
      );
      final restored = (await source.loadCached())!.offers.single;
      expect(restored.price!.currencyCode, 'USD');
      expect(restored.storePrice, isNull);
    },
  );
}
