import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/billing_price_diagnostics.dart';
import 'package:genesis_flutter_android/app/membership/membership_catalog.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/platform/billing/membership_product_store.dart';

import '../../support/membership_fixtures.dart';

GemProduct _gem({required String storeCurrency, required String formatted}) =>
    GemProduct.fromJson({
      'product_id': 'gem_pack',
      'apple_product_id': 'apple_gem_pack',
      'google_product_id': 'google_gem_pack',
      'base_gems_cent': 10000,
      'bonus_gems_cent': 0,
      'price_currency_code': 'USD',
      'price_amount': 999,
      'can_purchase': true,
    }).withStorePrice(
      formatted: formatted,
      micros: 12000000,
      currency: storeCurrency,
      symbol: storeCurrency == 'KRW' ? '₩' : r'$',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(billingPriceDiagnostics.clear);
  tearDown(billingPriceDiagnostics.clear);

  test('records raw store and backend values even when UI selects backend', () {
    billingPriceDiagnostics.recordGems(
      surface: 'Gems wallet',
      snapshotSource: 'fresh',
      products: [_gem(storeCurrency: 'USD', formatted: r'$12.00')],
      lookupStatuses: const {'gem_pack': 'ok'},
    );

    final capture = billingPriceDiagnostics.captures.single;
    final line = capture.lines.single;
    expect(line.backendAmount, '999');
    expect(line.backendCurrency, 'USD');
    expect(line.storeAmountMicros, 12000000);
    expect(line.storeCurrency, 'USD');
    expect(line.storeSymbol, r'$');
    expect(line.storeFormatted, r'$12.00');
    expect(line.storeLookup, 'ok');
    expect(line.displayText, r'$9.99');
    expect(line.displaySource, 'backend (fresh)');
    expect(line.displayReason, 'store currency excluded by display policy');
    expect(line.currenciesDiffer, isFalse);
  });

  test('records store-selected quote and cache origin', () {
    billingPriceDiagnostics.recordGems(
      surface: 'Buy Gems sheet',
      snapshotSource: 'cache',
      products: [_gem(storeCurrency: 'KRW', formatted: '₩12,000')],
    );

    final line = billingPriceDiagnostics.captures.single.lines.single;
    expect(line.displayText, '₩12,000');
    expect(line.displayCurrency, 'KRW');
    expect(line.displaySource, 'store (cache)');
    expect(line.displayReason, 'store currency allowed by display policy');
    expect(line.currenciesDiffer, isTrue);
    expect(line.storeLookup, 'not queried for this snapshot');
  });

  test(
    'keeps cache and fresh page evidence for a transient price mismatch',
    () {
      billingPriceDiagnostics.recordGems(
        surface: 'Gems wallet',
        snapshotSource: 'cache',
        products: [_gem(storeCurrency: 'KRW', formatted: '₩12,000')],
      );
      billingPriceDiagnostics.recordGems(
        surface: 'Gems wallet',
        snapshotSource: 'fresh',
        products: [_gem(storeCurrency: 'USD', formatted: r'$12.00')],
        lookupStatuses: const {'gem_pack': 'ok'},
      );

      expect(
        billingPriceDiagnostics.captures.map(
          (capture) => capture.snapshotSource,
        ),
        containsAll(['cache', 'fresh']),
      );
      expect(
        billingPriceDiagnostics.captures
            .firstWhere((capture) => capture.snapshotSource == 'cache')
            .lines
            .single
            .displayText,
        '₩12,000',
      );
      expect(
        billingPriceDiagnostics.captures
            .firstWhere((capture) => capture.snapshotSource == 'fresh')
            .lines
            .single
            .displayText,
        r'$9.99',
      );
    },
  );

  test('subscription snapshot retains both quotes and latest load failure', () {
    billingPriceDiagnostics.recordMembership(
      surface: 'Subscription',
      snapshotSource: 'fresh',
      offers: [
        MembershipOffer(
          product: membershipProduct(yearly: true, priceAmount: 9999),
          storePrice: const MembershipStorePrice(
            formattedPrice: '₩120,000',
            amountMicros: 120000000000,
            currencyCode: 'KRW',
            currencySymbol: '₩',
          ),
        ),
      ],
    );
    billingPriceDiagnostics.recordFailure(
      'Subscription',
      StateError('offline'),
    );

    final capture = billingPriceDiagnostics.captures.single;
    expect(capture.error, 'StateError');
    expect(capture.lines.single.backendAmount, '9999');
    expect(capture.lines.single.storeCurrency, 'KRW');
    expect(capture.lines.single.storeSymbol, '₩');
    expect(capture.lines.single.displayText, '₩120,000');
    expect(capture.lines.single.displaySource, 'store (fresh)');
  });
}
