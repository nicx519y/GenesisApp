import 'package:flutter/foundation.dart';

import '../../l10n/genesis_l10n.dart';
import '../../components/gems/gem_purchase_catalog.dart';
import '../../network/api_exception.dart';
import '../../network/models/gem_product.dart';
import '../../utils/store_price_display_policy.dart';
import '../membership/membership_catalog.dart';

/// Ephemeral, read-only evidence from the prices actually applied to purchase UI.
/// No account, transaction, or payment credentials are retained or uploaded.
final billingPriceDiagnostics = BillingPriceDiagnostics();

@immutable
class BillingPriceLine {
  const BillingPriceLine({
    required this.productKey,
    required this.storeProductId,
    required this.backendAmount,
    required this.backendCurrency,
    required this.storeAmountMicros,
    required this.storeCurrency,
    required this.storeSymbol,
    required this.storeFormatted,
    required this.storeLookup,
    required this.displayText,
    required this.displayCurrency,
    required this.displaySource,
    required this.displayReason,
    this.gemsCent,
  });

  final String productKey;
  final int? gemsCent;
  final String storeProductId;
  final String backendAmount;
  final String backendCurrency;
  final int? storeAmountMicros;
  final String? storeCurrency;
  final String? storeSymbol;
  final String? storeFormatted;
  final String storeLookup;
  final String displayText;
  final String displayCurrency;
  final String displaySource;
  final String displayReason;

  bool get currenciesDiffer =>
      storeCurrency != null &&
      storeCurrency!.isNotEmpty &&
      backendCurrency.isNotEmpty &&
      storeCurrency != backendCurrency;
}

@immutable
class BillingPriceCapture {
  const BillingPriceCapture({
    required this.surface,
    required this.snapshotSource,
    required this.capturedAt,
    required this.lines,
    this.error,
  });

  final String surface;
  final String snapshotSource;
  final DateTime capturedAt;
  final List<BillingPriceLine> lines;
  final String? error;
}

class BillingPriceDiagnostics extends ChangeNotifier {
  final Map<String, BillingPriceCapture> _captures = {};

  List<BillingPriceCapture> get captures => List.unmodifiable(
    _captures.values.toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt)),
  );

  String _key(String surface, String source) => '$surface|$source';

  void recordGems({
    required String surface,
    required String snapshotSource,
    required List<GemProduct> products,
    Map<String, String> lookupStatuses = const {},
  }) {
    _captures[_key(surface, snapshotSource)] = BillingPriceCapture(
      surface: surface,
      snapshotSource: snapshotSource,
      capturedAt: DateTime.now().toUtc(),
      lines: List.unmodifiable([
        for (final product in products)
          BillingPriceLine(
            productKey: product.productId,
            gemsCent: product.totalGemsCent,
            storeProductId: defaultTargetPlatform == TargetPlatform.iOS
                ? product.appleProductId
                : product.googleProductId,
            backendAmount: '${product.priceAmount}',
            backendCurrency: product.priceCurrencyCode,
            storeAmountMicros: product.storeAmountMicros,
            storeCurrency: product.storeCurrencyCode,
            storeSymbol: product.storeCurrencySymbol,
            storeFormatted: product.storeFormattedPrice,
            storeLookup: snapshotSource == 'fresh'
                ? lookupStatuses[product.productId] ?? 'unknown'
                : 'not queried for this snapshot',
            displayText:
                product.productId.trim() == 'gem_pack_500' &&
                    !product.canPurchase
                ? GenesisL10n.current.meSoldOut
                : product.displaysStorePrice
                ? trimZeroPriceDecimals(product.storeFormattedPrice!)
                : formatGemPrice(
                    product.priceAmount,
                    product.priceCurrencyCode,
                  ),
            displayCurrency: product.displaysStorePrice
                ? product.storeCurrencyCode ?? ''
                : product.priceCurrencyCode,
            displaySource:
                product.productId.trim() == 'gem_pack_500' &&
                    !product.canPurchase
                ? 'sold out ($snapshotSource)'
                : product.displaysStorePrice
                ? 'store ($snapshotSource)'
                : 'backend ($snapshotSource)',
            displayReason:
                product.productId.trim() == 'gem_pack_500' &&
                    !product.canPurchase
                ? 'product sold out'
                : product.storeFormattedPrice == null
                ? 'store quote missing'
                : product.displaysStorePrice
                ? 'store currency allowed by display policy'
                : 'store currency excluded by display policy',
          ),
      ]),
    );
    notifyListeners();
  }

  void recordMembership({
    required String surface,
    required String snapshotSource,
    required List<MembershipOffer> offers,
    String? lookupError,
  }) {
    _captures[_key(surface, snapshotSource)] = BillingPriceCapture(
      surface: surface,
      snapshotSource: snapshotSource,
      capturedAt: DateTime.now().toUtc(),
      lines: List.unmodifiable([
        for (final offer in offers)
          BillingPriceLine(
            productKey: offer.product.planCode,
            storeProductId: offer.product.storeProductId,
            backendAmount: offer.product.priceAmount?.toString() ?? 'null',
            backendCurrency: offer.product.priceCurrencyCode,
            storeAmountMicros: offer.storePrice?.amountMicros,
            storeCurrency: offer.storePrice?.currencyCode,
            storeSymbol: offer.storePrice?.currencySymbol,
            storeFormatted: offer.storePrice?.formattedPrice,
            storeLookup: snapshotSource == 'fresh'
                ? lookupError ??
                      (!offer.requiresStorePrice
                          ? 'not configured'
                          : offer.storePrice == null
                          ? 'not returned/invalid'
                          : 'ok')
                : 'not queried for this snapshot',
            displayText: offer.price?.formattedPrice ?? '(unavailable)',
            displayCurrency: offer.price?.currencyCode ?? '',
            displaySource:
                offer.storePrice != null &&
                    useStorePriceForDisplay(offer.storePrice!.currencyCode)
                ? 'store ($snapshotSource)'
                : offer.price == null
                ? 'unavailable ($snapshotSource)'
                : 'backend ($snapshotSource)',
            displayReason: offer.storePrice == null
                ? 'store quote missing'
                : useStorePriceForDisplay(offer.storePrice!.currencyCode)
                ? 'store currency allowed by display policy'
                : 'store currency excluded by display policy',
          ),
      ]),
    );
    notifyListeners();
  }

  void recordFailure(String surface, Object error) {
    final previous = captures
        .where((capture) => capture.surface == surface)
        .firstOrNull;
    _captures[_key(
      surface,
      previous?.snapshotSource ?? 'none',
    )] = BillingPriceCapture(
      surface: surface,
      snapshotSource: previous?.snapshotSource ?? 'none',
      capturedAt: previous?.capturedAt ?? DateTime.now().toUtc(),
      lines: previous?.lines ?? const [],
      error: error is ApiException
          ? 'ApiException kind=${error.kind.name} code=${error.code ?? '-'} http=${error.statusCode ?? '-'} client=${error.clientFailureCode?.value ?? '-'}'
          : '${error.runtimeType}',
    );
    notifyListeners();
  }

  void clear() {
    _captures.clear();
    notifyListeners();
  }
}
