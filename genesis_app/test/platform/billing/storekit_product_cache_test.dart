import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
// ignore: implementation_imports
import 'package:in_app_purchase_storekit/src/in_app_purchase_apis.dart';

class _Host extends Fake implements InAppPurchase2API {
  var loads = 0;
  bool? force;
  List<String>? invalidated;
  SK2ProductPurchaseOptionsMessage? options;
  final product = SK2ProductMessage(
    id: 'sku',
    displayName: 'Gems',
    displayPrice: r'$1.00',
    localizedDescription: 'Gems',
    price: 1,
    type: SK2ProductTypeMessage.consumable,
    priceLocale: SK2PriceLocaleMessage(
      currencyCode: 'USD',
      currencySymbol: r'$',
    ),
    purchaseSignature: 'native-purchase-terms',
    cacheHit: true,
    cacheAgeMs: 500,
  );
  @override
  Future<List<SK2ProductMessage>> loadProducts(
    List<String> identifiers,
    bool forceRefresh,
  ) async {
    loads++;
    force = forceRefresh;
    return [product];
  }

  @override
  Future<void> invalidateProducts(List<String>? identifiers) async {
    invalidated = identifiers;
  }

  @override
  Future<SK2ProductPurchaseResultMessage> purchase(
    String id, {
    SK2ProductPurchaseOptionsMessage? options,
  }) async {
    this.options = options;
    return SK2ProductPurchaseResultMessage.success;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Host host;
  setUp(() {
    host = _Host();
    setInAppPurchaseHostApis(api2: host);
  });
  tearDown(() => setInAppPurchaseHostApis(api2: InAppPurchase2API()));
  test(
    'StoreKit lookup and purchase reuse native signature without Dart caching',
    () async {
      final platform = InAppPurchaseStoreKitPlatform();
      final response = await platform.queryProductDetails({'sku'});
      final details = response.productDetails.single as AppStoreProduct2Details;
      expect(details.sk2Product.purchaseSignature, 'native-purchase-terms');
      expect(details.sk2Product.cacheHit, true);
      expect(details.sk2Product.cacheAgeMs, 500);
      await platform.buyNonConsumable(
        purchaseParam: Sk2PurchaseParam(productDetails: details),
      );
      expect(host.loads, 1);
      expect(host.options?.expectedSignature, 'native-purchase-terms');
      await platform.queryProductDetails({'sku'});
      expect(
        host.loads,
        2,
        reason: 'Dart delegates every lookup to native ownership.',
      );
    },
  );
  test('explicit force query and invalidation reach native owner', () async {
    await SK2Product.loadProducts(['sku'], forceRefresh: true);
    expect(host.force, true);
    await SK2Product.invalidateProducts(['sku']);
    expect(host.invalidated, ['sku']);
  });
}
