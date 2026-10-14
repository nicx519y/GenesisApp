import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
}
