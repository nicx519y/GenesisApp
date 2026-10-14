import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/gems/gem_store_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

class Store implements BillingPlatform {
  Store(this.provider);
  @override
  final BillingProvider provider;
  int calls = 0;
  int amount = 12000000000;
  String currency = 'KRW';
  String formatted = '₩12,000';
  bool available = true;
  String? option;
  String? offer;
  String? id;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  }) async {
    calls++;
    option = purchaseOptionId;
    offer = offerId;
    id = storeProductId;
    return BillingProductQueryResult.success(
      BillingStoreProduct(
        id: storeProductId,
        type: expectedType,
        nativeProduct: Object(),
        formattedPrice: formatted,
        priceAmountMicros: amount,
        priceCurrencyCode: currency,
        priceCurrencySymbol: '₩',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GemProduct product() => GemProduct.fromJson({
  'product_id': 'pack',
  'apple_product_id': 'apple-pack',
  'google_product_id': 'google-pack',
  'base_gems_cent': 10000,
  'bonus_gems_cent': 0,
  'price_currency_code': 'USD',
  'price_amount': 999,
  'can_purchase': true,
  'google_purchase_option_id': 'option',
  'google_offer_id': 'offer',
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final provider in BillingProvider.values) {
    test(
      '$provider preload stores prices and restart reads disk without checkout tokens',
      () async {
        final store = Store(provider);
        GemStoreCatalog create([String owner = 'a']) => GemStoreCatalog(
          loadProducts: () async => [product()],
          platform: store,
          namespace: 'test',
          readOwner: () async => owner,
        );
        final source = create();
        await source.preload();
        expect(source.cached!.single.storeFormattedPrice, '₩12,000');
        expect(source.cached!.single.storeCurrencySymbol, '₩');
        expect(
          store.id,
          provider == BillingProvider.googlePlay ? 'google-pack' : 'apple-pack',
        );
        expect(
          store.offer,
          provider == BillingProvider.googlePlay ? 'offer' : null,
        );
        await source.preload();
        expect(store.calls, 1);
        final restored = await create().loadCached();
        expect(restored!.single.storeAmountMicros, 12000000000);
        expect(restored.single.storeCurrencySymbol, '₩');
        expect(store.calls, 1);
        expect(await create('b').loadCached(), isNull);
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(prefs.getKeys().single)!;
        expect(raw, contains('cached_at'));
        expect(raw, isNot(contains('offer_token')));
        expect(raw, isNot(contains('nativeProduct')));
      },
    );
  }
  test('failed store lookup never uses API price and can retry', () async {
    final store = Store(BillingProvider.googlePlay)..available = false;
    final source = GemStoreCatalog(
      loadProducts: () async => [product()],
      platform: store,
      namespace: 'test',
      readOwner: () async => 'a',
    );
    expect((await source.load()).single.storeFormattedPrice, isNull);
    expect(source.cached!.single.requiresStorePrice, isTrue);
    expect(source.lastStoreLookupStatuses['pack'], 'store unavailable');
    store.available = true;
    expect((await source.load()).single.storeCurrencyCode, 'KRW');
    expect(source.lastStoreLookupStatuses['pack'], 'ok');
  });
  test(
    'price changes update catalog and require another confirmation',
    () async {
      final store = Store(BillingProvider.googlePlay);
      final source = GemStoreCatalog(
        loadProducts: () async => [product()],
        platform: store,
        namespace: 'test',
        readOwner: () async => 'a',
      );
      final displayed = (await source.load()).single;
      expect(await source.confirm(displayed), isNotNull);
      store.amount = 13000000000;
      store.formatted = '₩13,000';
      expect(await source.confirm(displayed), isNull);
      expect(source.cached!.single.storeFormattedPrice, '₩13,000');
      store.currency = 'EUR';
      expect(await source.confirm(displayed), isNull);
    },
  );
}
