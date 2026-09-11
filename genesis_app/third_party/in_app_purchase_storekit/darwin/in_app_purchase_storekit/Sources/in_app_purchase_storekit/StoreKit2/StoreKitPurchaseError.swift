import Foundation
import StoreKit

/// Retains structured native errors through Pigeon without serializing NSError.
@available(iOS 15.0, macOS 12.0, *)
func storeKitPurchaseErrorDetails(_ error: Error) -> [String: String] {
  let native = error as NSError
  var details = [
    "domain": native.domain,
    "nativeCode": String(native.code),
    "message": native.localizedDescription,
  ]
  func underlying(_ error: Error) {
    let native = error as NSError
    details["underlyingDomain"] = native.domain
    details["underlyingCode"] = String(native.code)
    details["underlyingMessage"] = native.localizedDescription
  }
  if let cause = native.userInfo[NSUnderlyingErrorKey] as? Error {
    underlying(cause)
  }
  if let purchase = error as? Product.PurchaseError {
    switch purchase {
    case .invalidQuantity: details["storeKitCode"] = "invalid_quantity"
    case .productUnavailable: details["storeKitCode"] = "product_unavailable"
    case .purchaseNotAllowed: details["storeKitCode"] = "purchase_not_allowed"
    case .ineligibleForOffer: details["storeKitCode"] = "ineligible_for_offer"
    case .invalidOfferIdentifier: details["storeKitCode"] = "invalid_offer_identifier"
    case .invalidOfferPrice: details["storeKitCode"] = "invalid_offer_price"
    case .invalidOfferSignature: details["storeKitCode"] = "invalid_offer_signature"
    case .missingOfferParameters: details["storeKitCode"] = "missing_offer_parameters"
    default:
      // New SDK cases retain their name even when built against an older SDK.
      details["storeKitCode"] = String(describing: purchase)
    }
  } else if let store = error as? StoreKitError {
    switch store {
    case .unknown: details["storeKitCode"] = "unknown"
    case .userCancelled: details["storeKitCode"] = "user_cancelled"
    case .networkError(let cause):
      details["storeKitCode"] = "network_error"
      underlying(cause)
    case .systemError(let cause):
      details["storeKitCode"] = "system_error"
      underlying(cause)
    case .notAvailableInStorefront: details["storeKitCode"] = "not_available_in_storefront"
    default:
      // Covers availability-gated notEntitled/unsupported and future cases.
      details["storeKitCode"] = String(describing: store)
    }
  }
  return details
}
