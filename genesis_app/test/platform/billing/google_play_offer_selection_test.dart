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

  test('selects the regular offer when only purchase option is specified', () {
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

    expect(selected?.offerId, isNull);
    expect(selected?.offerToken, 'regular-token');
  });
}
