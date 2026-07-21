import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_models.dart';
import 'google_play_billing_platform.dart';

class AppStoreBillingPlatform implements BillingPlatform {
  AppStoreBillingPlatform({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;
  final Map<String, PurchaseDetails> _nativePurchasesByToken =
      <String, PurchaseDetails>{};

  @override
  BillingProvider get provider => BillingProvider.appStore;

  @override
  Stream<List<BillingPurchase>> get purchaseStream {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const Stream<List<BillingPurchase>>.empty();
    }
    return _inAppPurchase.purchaseStream.map(
      (purchases) => purchases.map(_rememberPurchase).toList(growable: false),
    );
  }

  @override
  Future<bool> isAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const BillingProductQueryResult.failure('platform_unavailable');
    }
    if (expectedType != BillingStoreProductType.inApp) {
      return const BillingProductQueryResult.failure(
        'unsupported_product_type',
      );
    }
    try {
      final response = await _inAppPurchase.queryProductDetails({
        storeProductId,
      });
      if (response.error != null) {
        debugPrint(
          '[Billing][AppStore] product query failed id=$storeProductId '
          'code=${response.error!.code}',
        );
        return BillingProductQueryResult.failure(response.error!.code);
      }
      for (final product in response.productDetails) {
        if (product.id != storeProductId) continue;
        debugPrint(
          '[Billing][AppStore] product ready id=$storeProductId '
          'price="${product.price}" rawPrice=${product.rawPrice} '
          'currency=${product.currencyCode}',
        );
        return BillingProductQueryResult.success(
          BillingStoreProduct(
            id: product.id,
            type: BillingStoreProductType.inApp,
            nativeProduct: product,
            formattedPrice: product.price,
            priceAmountMicros: (product.rawPrice * 1000000).round(),
            priceCurrencyCode: product.currencyCode,
          ),
        );
      }
      return const BillingProductQueryResult.failure('product_not_found');
    } on Object catch (error) {
      throw BillingPlatformException('query_product_failed', '$error');
    }
  }

  @override
  Future<bool> buyConsumable({
    required BillingStoreProduct product,
    required String billingAccountId,
  }) async {
    final nativeProduct = product.nativeProduct;
    if (nativeProduct is! ProductDetails) {
      throw const BillingPlatformException('invalid_app_store_product');
    }
    if (product.type != BillingStoreProductType.inApp) {
      throw const BillingPlatformException('unsupported_product_type');
    }
    final accepted = await _inAppPurchase.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: nativeProduct,
        applicationUserName: billingAccountId,
      ),
      // The StoreKit adapter requires autoConsume=true for iOS consumables.
      // Entitlement delivery remains server-owned after the purchase callback.
      autoConsume: true,
    );
    debugPrint('[Billing][AppStore] launch purchase accepted=$accepted');
    if (!accepted) {
      throw const BillingPlatformException('purchase_rejected');
    }
    return true;
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final token = purchase.purchaseToken.trim();
    final nativePurchase = _nativePurchasesByToken[token];
    if (nativePurchase == null) {
      throw const BillingPlatformException('purchase_completion_unavailable');
    }
    await _inAppPurchase.completePurchase(nativePurchase);
    _nativePurchasesByToken.remove(token);
    debugPrint('[Billing][AppStore] purchase completed id=$token');
  }

  @override
  Future<List<BillingPurchase>> queryPastPurchases({
    required String billingAccountId,
  }) async {
    return const <BillingPurchase>[];
  }

  BillingPurchase _rememberPurchase(PurchaseDetails purchase) {
    final billingPurchase = _toBillingPurchase(purchase);
    final token = billingPurchase.purchaseToken.trim();
    if (token.isNotEmpty) {
      _nativePurchasesByToken[token] = purchase;
    }
    return billingPurchase;
  }
}

BillingPurchase _toBillingPurchase(PurchaseDetails purchase) {
  final status = switch (purchase.status) {
    PurchaseStatus.pending => BillingPurchaseStatus.pending,
    PurchaseStatus.purchased => BillingPurchaseStatus.purchased,
    PurchaseStatus.restored => BillingPurchaseStatus.restored,
    PurchaseStatus.canceled => BillingPurchaseStatus.canceled,
    PurchaseStatus.error => BillingPurchaseStatus.error,
  };
  final transactionId = purchase.purchaseID ?? '';
  return BillingPurchase(
    provider: BillingProvider.appStore,
    productId: purchase.productID,
    purchaseToken: transactionId,
    transactionId: transactionId,
    originalTransactionId: '',
    originalJson: purchase.verificationData.localVerificationData,
    purchaseTime: purchase.transactionDate ?? '',
    status: status,
    errorCode: purchase.error?.code,
    errorMessage: purchase.error?.message,
  );
}
