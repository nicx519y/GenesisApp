import Foundation

/// A format locale controls presentation; its default currency need not be the
/// currency of the StoreKit product's price format style.
@available(iOS 15.0, macOS 12.0, *)
func storeKitPriceCurrency(for style: Decimal.FormatStyle.Currency) -> (
  code: String, symbol: String
) {
  let formatter = NumberFormatter()
  formatter.locale = style.locale
  formatter.numberStyle = .currency
  formatter.currencyCode = style.currencyCode
  return (style.currencyCode, formatter.currencySymbol ?? style.currencyCode)
}
