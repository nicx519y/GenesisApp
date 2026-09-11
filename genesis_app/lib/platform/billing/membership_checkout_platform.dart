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
  StoreMembershipCheckoutPlatform({
    InAppPurchase? store,
    Future<PurchasesResultWrapper> Function()? googleQuery,
  }) : _override = store,
       _googleQuery = googleQuery;
  final InAppPurchase? _override;
  final Future<PurchasesResultWrapper> Function()? _googleQuery;
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
        'accountUuid': product.accountUuid,
        'purchaseToken': product.upgradePurchaseToken,
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
      if (detail is GooglePlayProductDetails &&
          product.upgradePurchaseToken != null) {
        return _GoogleMembershipUpgrade(
          product: detail,
          accountUuid: product.accountUuid!,
          previousPurchase: await _previousGooglePurchase(product),
        );
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

  Future<GooglePlayPurchaseDetails> _previousGooglePurchase(
    MembershipProduct product,
  ) async {
    final result =
        await (_googleQuery?.call() ??
            _store
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
                .querySubscriptionPurchases());
    if (result.responseCode != BillingResponse.ok) {
      throw BillingPlatformException(
        result.responseCode.name,
        result.billingResult.debugMessage ?? '',
        {'subResponseCode': result.billingResult.subResponseCode},
      );
    }
    final matches = result.purchasesList
        .where(
          (purchase) => purchase.purchaseToken == product.upgradePurchaseToken,
        )
        .toList();
    if (matches.length != 1 ||
        !matches.single.products.contains(product.storeProductId)) {
      throw const BillingPlatformException(
        'membership_upgrade_purchase_missing',
      );
    }
    final purchase = matches.single;
    if (purchase.obfuscatedAccountId?.toLowerCase() != product.accountUuid) {
      throw const BillingPlatformException(
        'membership_upgrade_account_mismatch',
      );
    }
    if (purchase.purchaseState != PurchaseStateWrapper.purchased ||
        !purchase.isAcknowledged ||
        purchase.pendingPurchaseUpdate != null) {
      throw const BillingPlatformException('membership_upgrade_not_ready');
    }
    return GooglePlayPurchaseDetails.fromPurchase(
      purchase,
    ).singleWhere((detail) => detail.productID == product.storeProductId);
  }

  @override
  Future<bool> launch(
    Object product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
  }) async {
    final upgrade = product is _GoogleMembershipUpgrade ? product : null;
    if (upgrade != null) {
      if (accountUuid != upgrade.accountUuid) {
        throw const BillingPlatformException(
          'membership_upgrade_account_mismatch',
        );
      }
      product = upgrade.product;
    }
    if (product is! ProductDetails || !_subscription(product)) {
      throw const BillingPlatformException('invalid_membership_product');
    }
    final param = product is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(
            throwOnBillingFailure: true,
            productDetails: product,
            offerToken: product.offerToken,
            applicationUserName: accountUuid,
            changeSubscriptionParam: upgrade == null
                ? null
                : ChangeSubscriptionParam(
                    oldPurchaseDetails: upgrade.previousPurchase,
                    replacementMode: ReplacementMode.chargeFullPrice,
                  ),
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
        'oldProductId': upgrade?.previousPurchase.productID,
        'oldPurchaseToken':
            upgrade?.previousPurchase.verificationData.serverVerificationData,
        'oldAccountUuid':
            upgrade?.previousPurchase.billingClientPurchase.obfuscatedAccountId,
        'replacementMode': param.changeSubscriptionParam?.replacementMode?.name,
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

class _GoogleMembershipUpgrade {
  const _GoogleMembershipUpgrade({
    required this.product,
    required this.accountUuid,
    required this.previousPurchase,
  });

  final GooglePlayProductDetails product;
  final String accountUuid;
  final GooglePlayPurchaseDetails previousPurchase;
}
