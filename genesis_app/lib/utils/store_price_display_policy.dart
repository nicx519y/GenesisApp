/// Store prices are displayed only for the agreed currencies. This does not
/// change the native store quote or the amount charged at checkout.
bool useStorePriceForDisplay(String? currencyCode) => const {
  'EUR',
  'GBP',
  'AUD',
  'CAD',
  'JPY',
  'TWD',
}.contains(currencyCode?.trim().toUpperCase());

/// Remove only an all-zero decimal portion of a formatted price. Three-digit
/// grouping (for example 1,000) and nonzero decimals remain untouched.
String trimZeroPriceDecimals(String price) => price.replaceAllMapped(
  RegExp(r'([0-9])[.,]00(?![0-9.,])'),
  (match) => match.group(1)!,
);
