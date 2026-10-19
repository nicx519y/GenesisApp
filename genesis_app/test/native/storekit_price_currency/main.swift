import Foundation

// Compile together with the production StoreKitPriceCurrency.swift.
if #available(macOS 13.0, *) {
  let cases = [
    ("CNY", "ko_KR"),
    ("TWD", "ko_KR"),
    ("HKD", "ko_KR"),
    ("CNY", "en_US"),
    ("USD", "fr_FR"),
    ("KRW", "ko_KR"),
  ]
  for (code, localeId) in cases {
    let style = Decimal.FormatStyle.Currency(code: code).locale(Locale(identifier: localeId))
    let result = storeKitPriceCurrency(for: style)
    precondition(result.code == code, "Product currency must win over locale: \(code)/\(localeId)")
    precondition(!result.symbol.isEmpty, "Missing currency symbol: \(code)/\(localeId)")
    if code != "KRW" {
      precondition(!result.symbol.contains("₩"), "A non-KRW product must not acquire the won symbol")
    }
  }
  let chinesePrice = Decimal.FormatStyle.Currency(code: "CNY").locale(Locale(identifier: "ko_KR"))
  precondition(chinesePrice.locale.currency?.identifier == "KRW")
  precondition(storeKitPriceCurrency(for: chinesePrice).code == "CNY")
  print("StoreKit price currency: \(cases.count) cases passed")
}
