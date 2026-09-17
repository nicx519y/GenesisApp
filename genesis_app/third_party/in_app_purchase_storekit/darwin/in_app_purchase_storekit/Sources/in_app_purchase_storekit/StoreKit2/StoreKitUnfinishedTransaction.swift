// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import StoreKit

/// The verified fields used by the purchase gate. Keeping this read-only also
/// lets the native regression tests exercise the production decision directly.
@available(iOS 15.0, macOS 12.0, *)
protocol StoreKitUnfinishedTransaction {
  var productID: String { get }
  var productType: Product.ProductType { get }
  var expirationDate: Date? { get }
  var signedDate: Date { get }
}

@available(iOS 15.0, macOS 12.0, *)
extension Transaction: StoreKitUnfinishedTransaction {}

/// Call only for a verified transaction from Transaction.unfinished.
/// This decides whether to block a new purchase, never whether to finish an old
/// transaction or grant an entitlement. The backend owns receipt settlement.
@available(iOS 15.0, macOS 12.0, *)
func storeKitUnfinishedTransactionBlocksPurchase(
  _ transaction: StoreKitUnfinishedTransaction,
  productID: String,
  productType: Product.ProductType
) -> Bool {
  // Subscription eligibility belongs to StoreKit. A historical transaction,
  // regardless of expiry, must not prevent invoking Product.purchase.
  guard productType != .autoRenewable else { return false }
  return transaction.productID == productID
}
