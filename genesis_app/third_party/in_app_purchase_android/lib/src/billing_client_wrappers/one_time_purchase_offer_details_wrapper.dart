// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// Dart wrapper around [`com.android.billingclient.api.ProductDetails.OneTimePurchaseOfferDetails`](https://developer.android.com/reference/com/android/billingclient/api/ProductDetails.OneTimePurchaseOfferDetails).
///
/// Represents the offer details to buy a one-time purchase product.
@immutable
class OneTimePurchaseOfferDetailsWrapper {
  /// Creates a [OneTimePurchaseOfferDetailsWrapper].
  const OneTimePurchaseOfferDetailsWrapper({
    required this.formattedPrice,
    required this.priceAmountMicros,
    required this.priceCurrencyCode,
    this.offerId,
    this.offerToken,
    this.purchaseOptionId,
  });

  /// Formatted price for the payment, including its currency sign.
  ///
  /// For tax exclusive countries, the price doesn't include tax.
  final String formattedPrice;

  /// The price for the payment in micro-units, where 1,000,000 micro-units
  /// equal one unit of the currency.
  ///
  /// For example, if price is "€7.99", price_amount_micros is "7990000". This
  /// value represents the localized, rounded price for a particular currency.
  final int priceAmountMicros;

  /// The ISO 4217 currency code for price.
  ///
  /// For example, if price is specified in British pounds sterling, currency
  /// code is "GBP".
  final String priceCurrencyCode;

  /// The offer ID, when this is a configured offer rather than a purchase option.
  final String? offerId;

  /// The token required to launch this selected one-time purchase offer.
  final String? offerToken;

  /// The purchase option ID associated with this offer.
  final String? purchaseOptionId;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is OneTimePurchaseOfferDetailsWrapper &&
        other.formattedPrice == formattedPrice &&
        other.priceAmountMicros == priceAmountMicros &&
        other.priceCurrencyCode == priceCurrencyCode &&
        other.offerId == offerId &&
        other.offerToken == offerToken &&
        other.purchaseOptionId == purchaseOptionId;
  }

  @override
  int get hashCode {
    return Object.hash(
      formattedPrice.hashCode,
      priceAmountMicros.hashCode,
      priceCurrencyCode.hashCode,
      offerId.hashCode,
      offerToken.hashCode,
      purchaseOptionId.hashCode,
    );
  }
}
