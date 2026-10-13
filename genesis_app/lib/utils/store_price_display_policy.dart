/// Store prices are displayed only for the agreed currencies. This does not
/// change the native store quote or the amount charged at checkout.
bool useStorePriceForDisplay(String? currencyCode) => const {
  'EUR',
  'GBP',
  'USD',
  'AUD',
  'CAD',
}.contains(currencyCode?.trim().toUpperCase());
