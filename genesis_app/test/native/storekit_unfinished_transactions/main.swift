import Foundation
import StoreKit

// Compile together with the production StoreKitUnfinishedTransaction.swift.
@available(macOS 12.0, *)
struct PurchaseGateTransaction: StoreKitUnfinishedTransaction {
  var productID = "test-subscription"
  var productType: Product.ProductType = .autoRenewable
  var expirationDate: Date? = Date(timeIntervalSince1970: 1_000)
  var signedDate = Date(timeIntervalSince1970: 2_000)
}

if #available(macOS 12.0, *) {
  var checks = 0
  func check(
    _ name: String,
    _ transaction: PurchaseGateTransaction,
    productID: String = "test-subscription",
    productType: Product.ProductType = .autoRenewable,
    blocks: Bool
  ) {
    precondition(
      storeKitUnfinishedTransactionBlocksPurchase(
        transaction, productID: productID, productType: productType) == blocks,
      name)
    checks += 1
  }

  let expired = PurchaseGateTransaction()
  check("Apple-confirmed expired period permits a new purchase", expired, blocks: false)
  check("another product never blocks", expired, productID: "other-subscription", blocks: false)

  var active = expired
  active.expirationDate = Date(timeIntervalSince1970: 3_000)
  check("active unfinished subscription delegates to Apple", active, blocks: false)
  var atExpiry = expired
  atExpiry.expirationDate = atExpiry.signedDate
  check("exact expiry boundary permits purchase", atExpiry, blocks: false)
  var unknownExpiry = expired
  unknownExpiry.expirationDate = nil
  check("missing expiry delegates to Apple", unknownExpiry, blocks: false)
  var oldSignature = expired
  oldSignature.signedDate = Date(timeIntervalSince1970: 500)
  check("old signature delegates to Apple", oldSignature, blocks: false)

  for type in [Product.ProductType.consumable, .nonConsumable, .nonRenewable] {
    var other = expired
    other.productType = type
    check(
      "non-auto-renewable keeps original guard: \(type)", other, productType: type, blocks: true)
    check("subscription request delegates to Apple: \(type)", other, blocks: false)
    check("product type mismatch stays blocked: \(type)", expired, productType: type, blocks: true)
    check(
      "other SKU remains independent: \(type)", other,
      productID: "other-product", productType: type, blocks: false)
  }

  // All historical subscription periods delegate eligibility to StoreKit.
  for transactions in [[expired, active], [active, expired], [expired, unknownExpiry]] {
    precondition(
      !transactions.contains {
        storeKitUnfinishedTransactionBlocksPurchase(
          $0, productID: "test-subscription", productType: .autoRenewable)
      })
    checks += 1
  }
  precondition(
    !Array(repeating: expired, count: 12).contains {
      storeKitUnfinishedTransactionBlocksPurchase(
        $0, productID: "test-subscription", productType: .autoRenewable)
    })
  checks += 1
  print("StoreKit unfinished-transaction gate: \(checks) checks passed")
}
