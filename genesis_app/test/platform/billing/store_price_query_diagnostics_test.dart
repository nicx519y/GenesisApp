import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:genesis_flutter_android/platform/billing/store_price_query_diagnostics.dart';

void main() {
  setUp(storePriceQueryDiagnostics.clear);
  tearDown(storePriceQueryDiagnostics.clear);

  test('keeps raw returned quote and unmatched product IDs', () {
    storePriceQueryDiagnostics.recordResponse(
      group: 'Subscription',
      requestedIds: {'annual', 'monthly'},
      response: ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: 'annual',
            title: 'Annual',
            description: '',
            price: '₩120,000',
            rawPrice: 120000,
            currencyCode: 'KRW',
            currencySymbol: '₩',
          ),
        ],
        notFoundIDs: ['monthly'],
      ),
    );

    final capture = storePriceQueryDiagnostics.captures.single;
    expect(capture.requestedIds, ['annual', 'monthly']);
    expect(capture.notFoundIds, ['monthly']);
    expect(capture.returned.single.rawPrice, 120000);
    expect(capture.returned.single.currencyCode, 'KRW');
    expect(capture.returned.single.formattedPrice, '₩120,000');
    expect(capture.returned.single.sdkFields['price'], '₩120,000');
    expect(capture.returned.single.sdkFields['rawPrice'], 120000);
    expect(capture.returned.single.sdkFields['currencyCode'], 'KRW');
    expect(capture.status, 'ok');
  });

  test('records unavailable store without inventing a product response', () {
    storePriceQueryDiagnostics.recordUnavailable(
      group: 'Gems',
      requestedIds: {'pack'},
      status: 'store unavailable',
    );

    final capture = storePriceQueryDiagnostics.captures.single;
    expect(capture.returned, isEmpty);
    expect(capture.status, 'store unavailable');
  });

  test(
    'keeps StoreKit format currency distinct from locale default currency',
    () {
      final product = AppStoreProduct2Details.fromSK2Product(
        SK2Product(
          id: 'annual',
          displayName: 'Annual',
          displayPrice: '¥120',
          description: '',
          price: 120,
          type: SK2ProductType.autoRenewable,
          priceLocale: SK2PriceLocale(currencyCode: 'KRW', currencySymbol: '₩'),
          priceFormatStyleCurrencyCode: 'CNY',
        ),
      );

      storePriceQueryDiagnostics.recordResponse(
        group: 'Subscription',
        requestedIds: {'annual'},
        response: ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: const [],
        ),
      );

      final fields =
          storePriceQueryDiagnostics.captures.single.returned.single.sdkFields;
      final storeKit = fields['StoreKit2']! as Map<String, Object?>;
      expect(storeKit['priceFormatStyleCurrencyCode'], 'CNY');
      expect(storeKit['priceFormatStyleLocaleCurrencyCode'], 'KRW');
      expect(
        product.currencyCode,
        'KRW',
      ); // Diagnostic change must not alter display policy.
    },
  );
}
