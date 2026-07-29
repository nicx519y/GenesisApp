part of 'google_play_billing_service.dart';

extension _GooglePlayBillingCheckout on GooglePlayBillingService {
  Future<void> _start() async {
    _purchaseSubscription ??= _platform.purchaseStream.listen(
      (purchases) => unawaited(
        _handlePurchases(purchases, source: BillingRecoverySource.direct),
      ),
    );

    var available = false;
    try {
      available = await _platform.isAvailable();
    } catch (_) {}
    _setState(storeAvailable: available);
  }

  Future<BillingProductQueryResult> _queryStoreProduct(
    GemProduct product,
    String storeProductId,
  ) {
    final googlePurchaseOptionId = product.googlePurchaseOptionId.trim();
    final googleOfferId = product.googleOfferId.trim();
    final shouldUseGoogleOffer =
        _platform.provider == BillingProvider.googlePlay &&
        googlePurchaseOptionId.isNotEmpty &&
        googleOfferId.isNotEmpty;
    return _platform.queryProduct(
      storeProductId,
      BillingStoreProductType.inApp,
      purchaseOptionId: shouldUseGoogleOffer ? googlePurchaseOptionId : null,
      offerId: shouldUseGoogleOffer ? googleOfferId : null,
    );
  }

  Future<GemProduct?> _reloadProduct(String productId) async {
    try {
      final products = await _loadProductCatalog();
      for (final product in products) {
        if (product.productId == productId) return product;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
