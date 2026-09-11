import Foundation
import StoreKit

// Compile with the production StoreKitPurchaseError.swift, then run the binary.
func check(_ error: Error, _ code: String) {
  let details = storeKitPurchaseErrorDetails(error)
  precondition(details["storeKitCode"] == code, "Unexpected bridge output: \(details)")
  precondition(details["domain"] != nil && details["nativeCode"] != nil)
  precondition(details["message"] != nil)
}
if #available(macOS 12.0, *) {
  check(StoreKitError.userCancelled, "user_cancelled")
  check(StoreKitError.unknown, "unknown")
  check(StoreKitError.notAvailableInStorefront, "not_available_in_storefront")
  check(Product.PurchaseError.invalidQuantity, "invalid_quantity")
  check(Product.PurchaseError.productUnavailable, "product_unavailable")
  check(Product.PurchaseError.purchaseNotAllowed, "purchase_not_allowed")
  check(Product.PurchaseError.ineligibleForOffer, "ineligible_for_offer")
  check(Product.PurchaseError.invalidOfferIdentifier, "invalid_offer_identifier")
  check(Product.PurchaseError.invalidOfferPrice, "invalid_offer_price")
  check(Product.PurchaseError.invalidOfferSignature, "invalid_offer_signature")
  check(Product.PurchaseError.missingOfferParameters, "missing_offer_parameters")
  let network = storeKitPurchaseErrorDetails(StoreKitError.networkError(URLError(.timedOut)))
  precondition(network["storeKitCode"] == "network_error")
  precondition(network["underlyingDomain"] == NSURLErrorDomain)
  precondition(network["underlyingCode"] == "-1001")
  let system = storeKitPurchaseErrorDetails(StoreKitError.systemError(
    NSError(domain: SKErrorDomain, code: 18)))
  precondition(system["storeKitCode"] == "system_error")
  precondition(system["underlyingDomain"] == SKErrorDomain)
  precondition(system["underlyingCode"] == "18")
  if #available(macOS 12.3, *) { check(StoreKitError.notEntitled, "notEntitled") }
  if #available(macOS 15.4, *) { check(StoreKitError.unsupported, "unsupported") }
  for code in 0...21 {
    let native = storeKitPurchaseErrorDetails(NSError(domain: SKErrorDomain, code: code))
    precondition(native["domain"] == SKErrorDomain && native["nativeCode"] == String(code))
  }
  print("StoreKit native error bridge checks passed")
}
