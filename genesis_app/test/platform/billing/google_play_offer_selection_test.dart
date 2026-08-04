import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

void main() {
  test('selects the requested eligible one-time offer', () {
    final selected = selectGooglePlayOneTimeOffer(
      const <OneTimePurchaseOfferDetailsWrapper>[
        OneTimePurchaseOfferDetailsWrapper(
          formattedPrice: r'HK$28.00',
          priceAmountMicros: 28000000,
          priceCurrencyCode: 'HKD',
          purchaseOptionId: '500-gems-new',
          offerId: '500-gems-new-discount',
          offerToken: 'offer-token-1',
        ),
      ],
      purchaseOptionId: '500-gems-new',
      offerId: '500-gems-new-discount',
    );

    expect(selected?.offerToken, 'offer-token-1');
  });

  test('returns no offer when the requested offer is not eligible', () {
    final selected = selectGooglePlayOneTimeOffer(
      const <OneTimePurchaseOfferDetailsWrapper>[
        OneTimePurchaseOfferDetailsWrapper(
          formattedPrice: r'HK$28.00',
          priceAmountMicros: 28000000,
          priceCurrencyCode: 'HKD',
          purchaseOptionId: '500-gems-new',
          offerId: '500-gems-new-discount',
          offerToken: 'offer-token-1',
        ),
      ],
      purchaseOptionId: '500-gems-new',
      offerId: 'other-offer',
    );

    expect(selected, isNull);
  });

  test('does not select a discount when the backend gives no selector', () {
    final selected =
        selectGooglePlayOneTimeOffer(const <OneTimePurchaseOfferDetailsWrapper>[
          OneTimePurchaseOfferDetailsWrapper(
            formattedPrice: r'HK$28.00',
            priceAmountMicros: 28000000,
            priceCurrencyCode: 'HKD',
            purchaseOptionId: '500-gems-new',
            offerToken: 'regular-token',
          ),
          OneTimePurchaseOfferDetailsWrapper(
            formattedPrice: r'HK$16.32',
            priceAmountMicros: 16320000,
            priceCurrencyCode: 'HKD',
            purchaseOptionId: '500-gems-new',
            offerId: '500-gems-new-discount',
            offerToken: 'discount-token',
          ),
        ]);

    expect(selected, isNull);
  });

  test('returns no offer when only purchase option is specified', () {
    final selected =
        selectGooglePlayOneTimeOffer(const <OneTimePurchaseOfferDetailsWrapper>[
          OneTimePurchaseOfferDetailsWrapper(
            formattedPrice: r'HK$16.32',
            priceAmountMicros: 16320000,
            priceCurrencyCode: 'HKD',
            purchaseOptionId: '500-gems-new',
            offerId: '500-gems-new-discount',
            offerToken: 'discount-token',
          ),
          OneTimePurchaseOfferDetailsWrapper(
            formattedPrice: r'HK$28.00',
            priceAmountMicros: 28000000,
            priceCurrencyCode: 'HKD',
            purchaseOptionId: '500-gems-new',
            offerToken: 'regular-token',
          ),
        ], purchaseOptionId: '500-gems-new');

    expect(selected, isNull);
  });

  test('returns no offer when only offer id is specified', () {
    final selected =
        selectGooglePlayOneTimeOffer(const <OneTimePurchaseOfferDetailsWrapper>[
          OneTimePurchaseOfferDetailsWrapper(
            formattedPrice: r'HK$16.32',
            priceAmountMicros: 16320000,
            priceCurrencyCode: 'HKD',
            purchaseOptionId: '500-gems-new',
            offerId: '500-gems-new-discount',
            offerToken: 'discount-token',
          ),
        ], offerId: '500-gems-new-discount');

    expect(selected, isNull);
  });

  test('returns no offer when the matched offer has no token', () {
    final selected = selectGooglePlayOneTimeOffer(
      const <OneTimePurchaseOfferDetailsWrapper>[
        OneTimePurchaseOfferDetailsWrapper(
          formattedPrice: r'HK$16.32',
          priceAmountMicros: 16320000,
          priceCurrencyCode: 'HKD',
          purchaseOptionId: '500-gems-new',
          offerId: '500-gems-new-discount',
        ),
      ],
      purchaseOptionId: '500-gems-new',
      offerId: '500-gems-new-discount',
    );

    expect(selected, isNull);
  });

  test('normalizes Google BillingResponse callback errors', () {
    expect(
      googlePlayPurchaseErrorCode(
        code: 'purchase_error',
        message: 'BillingResponse.networkError',
      ),
      'network_error',
    );
    expect(
      googlePlayPurchaseErrorCode(code: 'purchase_error'),
      'purchase_error',
    );
  });

  test('maps Google unfetched products to their exact status names', () {
    expect(googlePlayUnfetchedProductErrorCode(0), 'unknown');
    expect(googlePlayUnfetchedProductErrorCode(2), 'invalid_product_id_format');
    expect(googlePlayUnfetchedProductErrorCode(3), 'product_not_found');
    expect(googlePlayUnfetchedProductErrorCode(4), 'no_eligible_offer');
    expect(googlePlayUnfetchedProductErrorCode(999), 'unknown');
  });

  test('maps Google query responses to their exact response names', () {
    const expected = <BillingResponse, String>{
      BillingResponse.serviceTimeout: 'service_timeout',
      BillingResponse.featureNotSupported: 'feature_not_supported',
      BillingResponse.serviceDisconnected: 'service_disconnected',
      BillingResponse.ok: 'unknown',
      BillingResponse.userCanceled: 'user_canceled',
      BillingResponse.serviceUnavailable: 'service_unavailable',
      BillingResponse.billingUnavailable: 'billing_unavailable',
      BillingResponse.itemUnavailable: 'item_unavailable',
      BillingResponse.developerError: 'developer_error',
      BillingResponse.error: 'error',
      BillingResponse.itemAlreadyOwned: 'item_already_owned',
      BillingResponse.itemNotOwned: 'item_not_owned',
      BillingResponse.networkError: 'network_error',
    };

    expect(expected.keys, containsAll(BillingResponse.values));
    for (final entry in expected.entries) {
      expect(
        googlePlayBillingQueryErrorCode(entry.key),
        entry.value,
        reason: entry.key.name,
      );
    }
  });
}
