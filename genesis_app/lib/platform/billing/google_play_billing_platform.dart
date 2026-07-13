import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'billing_models.dart';

abstract interface class BillingPlatform {
  BillingProvider get provider;

  Stream<List<BillingPurchase>> get purchaseStream;

  Future<bool> isAvailable();

  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  });

  Future<bool> buyConsumable({
    required BillingStoreProduct product,
    required String billingAccountId,
  });

  Future<List<BillingPurchase>> queryPastPurchases({
    required String billingAccountId,
  });

  Future<void> finalizePurchase(BillingPurchase purchase);
}

class GooglePlayBillingPlatform implements BillingPlatform {
  GooglePlayBillingPlatform({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  BillingProvider get provider => BillingProvider.googlePlay;

  @override
  Stream<List<BillingPurchase>> get purchaseStream {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<List<BillingPurchase>>.empty();
    }
    return _inAppPurchase.purchaseStream.map(
      (purchases) => purchases.map(_toBillingPurchase).toList(growable: false),
    );
  }

  @override
  Future<bool> isAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const BillingProductQueryResult.failure('platform_unavailable');
    }
    try {
      final response = await _inAppPurchase.queryProductDetails({
        storeProductId,
      });
      if (response.error != null) {
        debugPrint(
          '[Billing] product query failed id=$storeProductId '
          'code=${response.error!.code}',
        );
        return BillingProductQueryResult.failure(response.error!.code);
      }
      for (final product in response.productDetails) {
        if (product is! GooglePlayProductDetails ||
            product.id != storeProductId) {
          continue;
        }
        final type = switch (product.productDetails.productType) {
          ProductType.inapp => BillingStoreProductType.inApp,
          ProductType.subs => BillingStoreProductType.subscription,
        };
        if (type != expectedType) continue;
        _logGoogleProductDetails(product);
        final selectedOffer = selectGooglePlayOneTimeOffer(
          product.productDetails.oneTimePurchaseOfferDetailsList,
          purchaseOptionId: purchaseOptionId,
          offerId: offerId,
        );
        if (type == BillingStoreProductType.inApp &&
            (purchaseOptionId?.trim().isNotEmpty == true ||
                offerId?.trim().isNotEmpty == true) &&
            (selectedOffer == null ||
                selectedOffer.offerToken?.trim().isEmpty != false)) {
          debugPrint(
            '[Billing] requested offer unavailable id=$storeProductId '
            'purchaseOption=$purchaseOptionId offer=$offerId '
            'availableOffers=${product.productDetails.oneTimePurchaseOfferDetailsList?.length ?? 0}',
          );
          return const BillingProductQueryResult.failure('offer_not_available');
        }
        debugPrint(
          '[Billing] product ready id=$storeProductId '
          'type=${type.value} purchaseOption=${selectedOffer?.purchaseOptionId} '
          'offer=${selectedOffer?.offerId} '
          'hasOfferToken=${selectedOffer?.offerToken?.isNotEmpty == true}',
        );
        return BillingProductQueryResult.success(
          BillingStoreProduct(
            id: product.id,
            type: type,
            nativeProduct: product,
            purchaseOptionId: selectedOffer?.purchaseOptionId,
            offerId: selectedOffer?.offerId,
            offerToken: selectedOffer?.offerToken,
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
    if (nativeProduct is! GooglePlayProductDetails) {
      throw const BillingPlatformException('invalid_google_product');
    }
    if (product.type != BillingStoreProductType.inApp) {
      throw const BillingPlatformException('unsupported_product_type');
    }
    final purchaseParam = GooglePlayPurchaseParam(
      productDetails: nativeProduct,
      applicationUserName: billingAccountId,
      offerToken: product.offerToken,
    );
    final platform = InAppPurchasePlatform.instance;
    if (platform is InAppPurchaseAndroidPlatform) {
      debugPrint(
        '[Billing] launch purchase id=${nativeProduct.id} '
        'offer=${product.offerId} '
        'hasOfferToken=${product.offerToken?.isNotEmpty == true} '
        'platform=${platform.runtimeType}',
      );
      final result = await platform.launchBillingFlow(
        product: nativeProduct.id,
        offerToken: product.offerToken,
        accountId: billingAccountId,
      );
      if (result.responseCode != BillingResponse.ok) {
        throw BillingPlatformException(
          'purchase_${result.responseCode.name}',
          result.debugMessage ?? '',
        );
      }
      return true;
    }

    final accepted = await _inAppPurchase.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: false,
    );
    debugPrint(
      '[Billing] launch purchase accepted=$accepted '
      'platform=${platform.runtimeType}',
    );
    if (!accepted) {
      throw const BillingPlatformException('purchase_rejected');
    }
    return true;
  }

  @override
  Future<List<BillingPurchase>> queryPastPurchases({
    required String billingAccountId,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const <BillingPurchase>[];
    }
    final addition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases(
      applicationUserName: billingAccountId,
    );
    if (response.error != null) {
      throw BillingPlatformException(
        response.error!.code,
        response.error!.message,
      );
    }
    return response.pastPurchases
        .map(_toBillingPurchase)
        .toList(growable: false);
  }

  @override
  Future<void> finalizePurchase(BillingPurchase purchase) async {
    final nativePurchase = purchase.nativePurchase;
    if (nativePurchase is! PurchaseDetails) {
      throw const BillingPlatformException('invalid_google_purchase');
    }
    final addition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await addition.consumePurchase(nativePurchase);
    if (result.responseCode != BillingResponse.ok) {
      throw BillingPlatformException(
        'consume_${result.responseCode.name}',
        result.debugMessage ?? '',
      );
    }
  }
}

void _logGoogleProductDetails(GooglePlayProductDetails product) {
  final details = product.productDetails;
  debugPrint(
    '[Billing][ProductDetails] '
    'id=${details.productId} '
    'type=${details.productType} '
    'title="${details.title}" '
    'name="${details.name}" '
    'description="${details.description}" '
    'price="${product.price}" '
    'rawPrice=${product.rawPrice} '
    'currency=${product.currencyCode}',
  );

  final legacyOffer = details.oneTimePurchaseOfferDetails;
  debugPrint(
    '[Billing][ProductDetails] legacyOneTimeOffer='
    '${_formatOneTimeOffer(legacyOffer)}',
  );

  final oneTimeOffers =
      details.oneTimePurchaseOfferDetailsList ??
      const <OneTimePurchaseOfferDetailsWrapper>[];
  debugPrint(
    '[Billing][ProductDetails] oneTimeOffers.count=${oneTimeOffers.length}',
  );
  for (var index = 0; index < oneTimeOffers.length; index++) {
    debugPrint(
      '[Billing][ProductDetails] oneTimeOffer[$index]='
      '${_formatOneTimeOffer(oneTimeOffers[index])}',
    );
  }

  final subscriptionOffers =
      details.subscriptionOfferDetails ??
      const <SubscriptionOfferDetailsWrapper>[];
  debugPrint(
    '[Billing][ProductDetails] subscriptionOffers.count='
    '${subscriptionOffers.length}',
  );
  for (var index = 0; index < subscriptionOffers.length; index++) {
    final offer = subscriptionOffers[index];
    debugPrint(
      '[Billing][ProductDetails] subscriptionOffer[$index] '
      'basePlanId=${offer.basePlanId} offerId=${offer.offerId} '
      'offerToken=${_maskBillingToken(offer.offerIdToken)} '
      'tags=${offer.offerTags} '
      'pricingPhases=${offer.pricingPhases.map(_formatPricingPhase).toList()}',
    );
  }
}

String _formatOneTimeOffer(OneTimePurchaseOfferDetailsWrapper? offer) {
  if (offer == null) return 'null';
  return '{'
      'formattedPrice="${offer.formattedPrice}", '
      'priceAmountMicros=${offer.priceAmountMicros}, '
      'currency=${offer.priceCurrencyCode}, '
      'purchaseOptionId=${offer.purchaseOptionId}, '
      'offerId=${offer.offerId}, '
      'offerToken=${_maskBillingToken(offer.offerToken)}'
      '}';
}

String _formatPricingPhase(PricingPhaseWrapper phase) {
  return '{'
      'price="${phase.formattedPrice}", '
      'priceAmountMicros=${phase.priceAmountMicros}, '
      'currency=${phase.priceCurrencyCode}, '
      'period=${phase.billingPeriod}, '
      'cycleCount=${phase.billingCycleCount}, '
      'recurrence=${phase.recurrenceMode}'
      '}';
}

String _maskBillingToken(String? token) {
  final value = token?.trim() ?? '';
  if (value.isEmpty) return 'null';
  if (value.length <= 8) return '<redacted length=${value.length}>';
  return '<redacted ${value.substring(0, 4)}...'
      '${value.substring(value.length - 4)} length=${value.length}>';
}

OneTimePurchaseOfferDetailsWrapper? selectGooglePlayOneTimeOffer(
  List<OneTimePurchaseOfferDetailsWrapper>? offers, {
  String? purchaseOptionId,
  String? offerId,
}) {
  final requestedPurchaseOptionId = purchaseOptionId?.trim() ?? '';
  final requestedOfferId = offerId?.trim() ?? '';
  final availableOffers =
      offers ?? const <OneTimePurchaseOfferDetailsWrapper>[];
  if (requestedPurchaseOptionId.isEmpty && requestedOfferId.isEmpty) {
    return null;
  }
  for (final offer in availableOffers) {
    if (requestedPurchaseOptionId.isNotEmpty &&
        offer.purchaseOptionId != requestedPurchaseOptionId) {
      continue;
    }
    if (requestedOfferId.isNotEmpty && offer.offerId != requestedOfferId) {
      continue;
    }
    if (requestedOfferId.isEmpty && offer.offerId?.trim().isNotEmpty == true) {
      continue;
    }
    return offer;
  }
  return null;
}

BillingPurchase _toBillingPurchase(PurchaseDetails purchase) {
  final status = switch (purchase.status) {
    PurchaseStatus.pending => BillingPurchaseStatus.pending,
    PurchaseStatus.purchased => BillingPurchaseStatus.purchased,
    PurchaseStatus.restored => BillingPurchaseStatus.restored,
    PurchaseStatus.canceled => BillingPurchaseStatus.canceled,
    PurchaseStatus.error => BillingPurchaseStatus.error,
  };
  final googlePurchase = purchase is GooglePlayPurchaseDetails
      ? purchase.billingClientPurchase
      : null;
  return BillingPurchase(
    provider: BillingProvider.googlePlay,
    productId: purchase.productID,
    purchaseToken: purchase.verificationData.serverVerificationData,
    transactionId: purchase.purchaseID ?? googlePurchase?.orderId ?? '',
    originalTransactionId: '',
    originalJson:
        googlePurchase?.originalJson ??
        purchase.verificationData.localVerificationData,
    purchaseTime: purchase.transactionDate ?? '',
    status: status,
    errorCode: purchase.error?.code,
    errorMessage: purchase.error?.message,
    nativePurchase: purchase,
  );
}
