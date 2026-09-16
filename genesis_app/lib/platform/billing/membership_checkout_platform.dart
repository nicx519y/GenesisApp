import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../../network/models/membership_product.dart';
import 'billing_models.dart';
import 'membership_product_store.dart';

abstract interface class MembershipCheckoutPlatform {
  Future<Object> prepare(MembershipProduct product);
  Future<bool> launch(
    Object product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
  });
  Future<bool> isSubscription(String productId);
  Future<void> finishAppleTransaction(String transactionId);
}

class StoreMembershipCheckoutPlatform implements MembershipCheckoutPlatform {
  StoreMembershipCheckoutPlatform({InAppPurchase? store}) : _override = store;
  final InAppPurchase? _override;
  InAppPurchase get _store => _override ?? InAppPurchase.instance;
  final Map<String, bool> _types = {};

  @override
  Future<Object> prepare(MembershipProduct product) async {
    if (kDebugMode && product.provider == MembershipProvider.google) {
      final diagnostics = jsonEncode({
        'productId': product.storeProductId,
        'planCode': product.planCode,
        'basePlanId': product.basePlanId,
        'offerId': product.offerId,
      });
      debugPrint('[Membership][google_catalog] $diagnostics');
    }
    if (!await _store.isAvailable()) {
      throw BillingPlatformException(
        product.provider == MembershipProvider.apple
            ? 'purchase_not_allowed'
            : 'store_unavailable',
      );
    }
    final response = await _queryProducts(product);
    if (response.error != null) throw response.error!;
    for (final detail in response.productDetails) {
      if (detail.id != product.storeProductId || !_subscription(detail)) {
        continue;
      }
      _types[detail.id] = true;
      if (matchMembershipStorePrice(product, [detail]) == null) continue;
      if (detail is GooglePlayProductDetails &&
          detail.offerToken?.isNotEmpty != true) {
        continue;
      }
      return detail;
    }
    throw const BillingPlatformException('membership_product_not_found');
  }

  Future<ProductDetailsResponse> _queryProducts(
    MembershipProduct product,
  ) async {
    if (product.provider != MembershipProvider.google) {
      return _store.queryProductDetails({product.storeProductId});
    }
    final response = await _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryProductDetails(
          productId: product.storeProductId,
          productType: ProductType.subs,
        );
    if (response.billingResult.responseCode != BillingResponse.ok) {
      throw BillingPlatformException(
        response.billingResult.responseCode.name,
        response.billingResult.debugMessage ?? '',
        {'subResponseCode': response.billingResult.subResponseCode},
      );
    }
    return ProductDetailsResponse(
      productDetails: response.productDetailsList
          .expand(GooglePlayProductDetails.fromProductDetails)
          .toList(),
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> launch(
    Object product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
  }) async {
    if (product is! ProductDetails || !_subscription(product)) {
      throw const BillingPlatformException('invalid_membership_product');
    }
    final param = product is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(
            throwOnBillingFailure: true,
            productDetails: product,
            offerToken: product.offerToken,
            applicationUserName: accountUuid,
            // Monthly/yearly are base plans of the same Play subscription.
            // With no replacement params, Play uses its configured switch mode.
          )
        : Sk2PurchaseParam(
            productDetails: product,
            applicationUserName: accountUuid,
            onStoreHandoff: onStoreHandoff,
          );
    if (kDebugMode && param is GooglePlayPurchaseParam) {
      final diagnostics = jsonEncode({
        'productId': param.productDetails.id,
        'accountUuid': param.applicationUserName,
        'offerToken': param.offerToken,
      });
      debugPrint('[Membership][google_launch] $diagnostics');
    }
    final accepted = await _store.buyNonConsumable(purchaseParam: param);
    // Play returns when its purchase UI is launched; StoreKit calls back from
    // native preparation before waiting for the user's purchase result.
    if (accepted && product is GooglePlayProductDetails) {
      onStoreHandoff?.call();
    }
    return accepted;
  }

  @override
  Future<bool> isSubscription(String productId) async {
    final cached = _types[productId];
    if (cached != null) return cached;
    final response = await _store.queryProductDetails({productId});
    final products = response.productDetails.where((p) => p.id == productId);
    if (products.isEmpty) {
      throw const BillingPlatformException('unknown_purchase_type');
    }
    return _types[productId] = products.any(_subscription);
  }

  bool _subscription(ProductDetails product) => switch (product) {
    GooglePlayProductDetails() =>
      product.productDetails.productType == ProductType.subs,
    AppStoreProduct2Details() =>
      product.sk2Product.type == SK2ProductType.autoRenewable,
    AppStoreProductDetails() => product.skProduct.subscriptionPeriod != null,
    _ => false,
  };

  @override
  Future<void> finishAppleTransaction(String transactionId) =>
      SK2Transaction.finish(int.parse(transactionId));
}
