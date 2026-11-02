import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
// ignore: implementation_imports
import 'package:in_app_purchase_android/src/product_cache_recovery.dart';

void main() {
  const ok = BillingResultWrapper(responseCode: BillingResponse.ok);
  ProductDetailsWrapper product(
    ProductType type, {
    String title = 'Gems',
    int micros = 1000000,
  }) => ProductDetailsWrapper(
    description: '',
    name: 'Gems',
    productId: 'sku',
    oneTimePurchaseOfferDetails: OneTimePurchaseOfferDetailsWrapper(
      formattedPrice: '\$1',
      priceAmountMicros: micros,
      priceCurrencyCode: 'USD',
    ),
    productType: type,
    title: title,
  );

  for (final type in [ProductType.inapp, ProductType.subs]) {
    test('refills native cache once for $type', () async {
      final expected = product(type);
      var launches = 0;
      var queries = 0;
      final result = await launchWithProductCacheRecovery(
        expected: expected,
        launch: () async {
          if (++launches == 1) throw PlatformException(code: 'NOT_FOUND');
          return ok;
        },
        query: (request) async {
          queries++;
          expect(request.productId, 'sku');
          expect(request.productType, type);
          return ProductDetailsResponseWrapper(
            billingResult: ok,
            productDetailsList: [product(type)],
          );
        },
      );
      expect(result, ok);
      expect(queries, 1);
      expect(launches, 2);
    });
  }

  test('does not query on successful launch or other failures', () async {
    for (final code in [null, 'ERROR', 'USER_CANCELED']) {
      final future = launchWithProductCacheRecovery(
        expected: product(ProductType.inapp),
        launch: () async {
          if (code != null) throw PlatformException(code: code);
          return ok;
        },
        query: (_) async => throw StateError('Unexpected query'),
      );
      if (code == null) {
        expect(await future, ok);
      } else {
        await expectLater(
          future,
          throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
        );
      }
    }
  });

  test('second NOT_FOUND is propagated without another query', () async {
    var launches = 0;
    var queries = 0;
    final expected = product(ProductType.inapp);
    await expectLater(
      launchWithProductCacheRecovery(
        expected: expected,
        launch: () async {
          launches++;
          throw PlatformException(code: 'NOT_FOUND');
        },
        query: (_) async {
          queries++;
          return ProductDetailsResponseWrapper(
            billingResult: ok,
            productDetailsList: [expected],
          );
        },
      ),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'NOT_FOUND'),
      ),
    );
    expect(launches, 2);
    expect(queries, 1);
  });

  test('presentation changes do not invalidate purchasing terms', () {
    expect(
      samePurchaseTerms(
        product(ProductType.inapp),
        product(ProductType.inapp, title: 'New name'),
      ),
      true,
    );
    expect(
      samePurchaseTerms(
        product(ProductType.inapp),
        product(ProductType.inapp, micros: 2000000),
      ),
      false,
    );
  });

  test('late cache lookup cannot launch an expired checkout', () async {
    final wait = Completer<ProductDetailsResponseWrapper>();
    var active = true;
    var launches = 0;
    final expected = product(ProductType.inapp);
    final future = launchWithProductCacheRecovery(
      expected: expected,
      load: (_) => wait.future,
      beforeLaunch: () => active,
      launch: () async {
        launches++;
        return ok;
      },
      query: (_) async => throw StateError('Unexpected recovery'),
    );
    active = false;
    wait.complete(
      ProductDetailsResponseWrapper(
        billingResult: ok,
        productDetailsList: [expected],
      ),
    );
    await expectLater(
      future,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'checkout_aborted',
        ),
      ),
    );
    expect(launches, 0);
  });

  test('changed native cache stops before the first payment launch', () async {
    var launches = 0;
    final future = launchWithProductCacheRecovery(
      expected: product(ProductType.inapp),
      load: (_) async => ProductDetailsResponseWrapper(
        billingResult: ok,
        productDetailsList: [product(ProductType.inapp, micros: 2000000)],
      ),
      launch: () async {
        launches++;
        return ok;
      },
      query: (_) async => throw StateError('Unexpected recovery'),
    );
    await expectLater(
      future,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'product_details_changed',
        ),
      ),
    );
    expect(launches, 0);
  });

  for (final scenario in ['missing', 'changed', 'query_failed']) {
    test('does not relaunch when refresh is $scenario', () async {
      var launches = 0;
      final expected = product(ProductType.inapp);
      await expectLater(
        launchWithProductCacheRecovery(
          expected: expected,
          launch: () async {
            launches++;
            throw PlatformException(code: 'NOT_FOUND');
          },
          query: (_) async => ProductDetailsResponseWrapper(
            billingResult: scenario == 'query_failed'
                ? const BillingResultWrapper(
                    responseCode: BillingResponse.error,
                  )
                : ok,
            productDetailsList: scenario == 'missing'
                ? []
                : [
                    scenario == 'changed'
                        ? product(ProductType.inapp, micros: 2000000)
                        : expected,
                  ],
          ),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            {
              'missing': 'product_not_found',
              'changed': 'product_details_changed',
              'query_failed': 'product_cache_refresh_failed',
            }[scenario],
          ),
        ),
      );
      expect(launches, 1);
    });
  }
}
