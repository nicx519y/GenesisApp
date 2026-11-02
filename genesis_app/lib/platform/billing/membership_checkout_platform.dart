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
import 'store_product_access.dart';

class PreparedMembershipCheckout {
  const PreparedMembershipCheckout({
    required this.nativeProduct,
    this.priceAmountMicros,
    this.priceCurrencyCode = '',
  });

  final ProductDetails nativeProduct;
  final int? priceAmountMicros;
  final String priceCurrencyCode;
}

abstract interface class MembershipCheckoutPlatform {
  // Store settlement belongs to the server; this adapter only launches or
  // inspects purchases and must not acknowledge or finish them.
  Future<PreparedMembershipCheckout> prepare(MembershipProduct product);
  Future<bool> launch(
    PreparedMembershipCheckout product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
    String? checkoutAttemptId,
  });
  Future<bool> isSubscription(String productId);
}

class StoreMembershipCheckoutPlatform implements MembershipCheckoutPlatform {
  StoreMembershipCheckoutPlatform({InAppPurchase? store}) : _override = store;
  final InAppPurchase? _override;
  InAppPurchase get _store => _override ?? InAppPurchase.instance;
  final Map<String, bool> _types = {};

  @override
  Future<PreparedMembershipCheckout> prepare(MembershipProduct product) async {
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
    if (response.error case final error?) {
      if (product.provider == MembershipProvider.google) {
        throw BillingPlatformException(
          error.code,
          error.message,
          error.details,
        );
      }
      throw error;
    }
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
      final checkoutPrice = matchMembershipCheckoutPrice(product, detail);
      return PreparedMembershipCheckout(
        nativeProduct: detail,
        priceAmountMicros: checkoutPrice?.amountMicros,
        priceCurrencyCode: checkoutPrice?.currencyCode ?? '',
      );
    }
    throw const BillingPlatformException('membership_product_not_found');
  }

  Future<ProductDetailsResponse> _queryProducts(MembershipProduct product) =>
      queryMembershipStoreProduct(_store, product);

  @override
  Future<bool> launch(
    PreparedMembershipCheckout product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
    String? checkoutAttemptId,
  }) async {
    final nativeProduct = product.nativeProduct;
    if (!_subscription(nativeProduct)) {
      throw const BillingPlatformException('invalid_membership_product');
    }
    final param = nativeProduct is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(
            throwOnBillingFailure: true,
            beforeLaunch: StoreProductAccess.canLaunch,
            onProductDiagnostic: (stage, code) => StoreProductAccess.diagnostic(
              stage,
              nativeProduct.id,
              errorCode: code,
            ),
            productDetails: nativeProduct,
            offerToken: nativeProduct.offerToken,
            applicationUserName: accountUuid,
            // Monthly/yearly are base plans of the same Play subscription.
            // With no replacement params, Play uses its configured switch mode.
          )
        : Sk2PurchaseParam(
            productDetails: nativeProduct,
            applicationUserName: accountUuid,
            onStoreHandoff: onStoreHandoff,
            checkoutAttemptId: checkoutAttemptId,
          );
    if (kDebugMode && param is GooglePlayPurchaseParam) {
      final diagnostics = jsonEncode({
        'productId': param.productDetails.id,
        'accountUuid': param.applicationUserName,
        'offerToken': param.offerToken,
      });
      debugPrint('[Membership][google_launch] $diagnostics');
    }
    final accepted = await StoreProductAccess.launch(
      () => _store.buyNonConsumable(purchaseParam: param),
    );
    if (accepted && nativeProduct is GooglePlayProductDetails) {
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
}
