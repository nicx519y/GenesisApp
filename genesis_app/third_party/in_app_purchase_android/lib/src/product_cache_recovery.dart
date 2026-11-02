import 'package:flutter/services.dart';

import '../billing_client_wrappers.dart';

/// NOT_FOUND is thrown before native launch when the plugin's SKU cache is
/// missing. Refill that cache once; never retry ambiguous payment failures.
Future<BillingResultWrapper> launchWithProductCacheRecovery({
  required ProductDetailsWrapper? expected,
  Future<ProductDetailsResponseWrapper> Function(ProductWrapper)? load,
  bool Function()? beforeLaunch,
  void Function(String, String?)? diagnostic,
  required Future<BillingResultWrapper> Function() launch,
  required Future<ProductDetailsResponseWrapper> Function(ProductWrapper) query,
}) async {
  if (expected != null && load != null) {
    final response = await load(
      ProductWrapper(
        productId: expected.productId,
        productType: expected.productType,
      ),
    );
    _validateProduct(response, expected);
  }
  Future<BillingResultWrapper> guardedLaunch() {
    if (beforeLaunch != null && !beforeLaunch()) {
      throw PlatformException(code: 'checkout_aborted');
    }
    return launch();
  }

  try {
    return await guardedLaunch();
  } on PlatformException catch (error) {
    diagnostic?.call('launch_failed', error.code);
    if (error.code != 'NOT_FOUND' || expected == null) rethrow;
    diagnostic?.call('cache_recovery_start', error.code);
    final response = await query(
      ProductWrapper(
        productId: expected.productId,
        productType: expected.productType,
      ),
    );
    try {
      _validateProduct(response, expected);
      final result = await guardedLaunch();
      diagnostic?.call('cache_recovery_result', result.responseCode.name);
      return result;
    } on PlatformException catch (error) {
      diagnostic?.call('cache_recovery_failed', error.code);
      rethrow;
    }
  }
}

void _validateProduct(
  ProductDetailsResponseWrapper response,
  ProductDetailsWrapper expected,
) {
  if (response.billingResult.responseCode != BillingResponse.ok) {
    throw PlatformException(
      code: 'product_cache_refresh_failed',
      details: {'responseCode': response.billingResult.responseCode.name},
    );
  }
  final matches = response.productDetailsList.where(
    (product) =>
        product.productId == expected.productId &&
        product.productType == expected.productType,
  );
  if (matches.isEmpty) throw PlatformException(code: 'product_not_found');
  if (matches.length != 1 || !samePurchaseTerms(matches.single, expected)) {
    throw PlatformException(code: 'product_details_changed');
  }
}

/// Names and descriptions are presentation, not permission to change a charge.
bool samePurchaseTerms(ProductDetailsWrapper a, ProductDetailsWrapper b) {
  ProductDetailsWrapper terms(ProductDetailsWrapper p) => ProductDetailsWrapper(
    description: '',
    name: '',
    title: '',
    productId: p.productId,
    productType: p.productType,
    oneTimePurchaseOfferDetails: p.oneTimePurchaseOfferDetails,
    oneTimePurchaseOfferDetailsList: p.oneTimePurchaseOfferDetailsList,
    subscriptionOfferDetails: p.subscriptionOfferDetails,
  );
  return terms(a) == terms(b);
}
