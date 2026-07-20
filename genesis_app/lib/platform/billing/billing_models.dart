import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../network/models/gem_product.dart';

enum BillingProvider {
  googlePlay('google'),
  appStore('apple');

  const BillingProvider(this.apiValue);

  final String apiValue;
}

enum BillingProductKind { consumable, nonConsumable, subscription }

BillingProductKind billingProductKindFrom(String value) {
  return switch (value.trim().toLowerCase()) {
    'non_consumable' || 'non-consumable' => BillingProductKind.nonConsumable,
    'subscription' || 'subs' => BillingProductKind.subscription,
    _ => BillingProductKind.consumable,
  };
}

enum BillingStoreProductType { inApp, subscription }

extension BillingStoreProductTypeValue on BillingStoreProductType {
  String get value => switch (this) {
    BillingStoreProductType.inApp => 'inapp',
    BillingStoreProductType.subscription => 'subs',
  };
}

enum BillingPurchaseStatus { pending, purchased, restored, canceled, error }

enum BillingRecoverySource { direct, appStart, foreground }

extension BillingRecoverySourceValue on BillingRecoverySource {
  String get value => switch (this) {
    BillingRecoverySource.direct => 'direct',
    BillingRecoverySource.appStart => 'app_start',
    BillingRecoverySource.foreground => 'foreground',
  };
}

enum BillingPurchaseSource { buyGemsPage, buyGemsSheet }

extension BillingPurchaseSourceValue on BillingPurchaseSource {
  String get value => switch (this) {
    BillingPurchaseSource.buyGemsPage => 'buy_gems_page',
    BillingPurchaseSource.buyGemsSheet => 'buy_gems_sheet',
  };
}

enum BillingPendingPurchaseStatus {
  received,
  reported,

  // Kept for records written by versions where the client owned consumption.
  granted,
}

@immutable
class BillingStoreProduct {
  const BillingStoreProduct({
    required this.id,
    required this.type,
    required this.nativeProduct,
    this.purchaseOptionId,
    this.offerId,
    this.offerToken,
    this.formattedPrice = '',
    this.priceAmountMicros = 0,
    this.priceCurrencyCode = '',
  });

  final String id;
  final BillingStoreProductType type;
  final Object nativeProduct;
  final String? purchaseOptionId;
  final String? offerId;
  final String? offerToken;
  final String formattedPrice;
  final int priceAmountMicros;
  final String priceCurrencyCode;
}

@immutable
class BillingProductQueryResult {
  const BillingProductQueryResult.success(this.product) : errorCode = null;

  const BillingProductQueryResult.failure(this.errorCode) : product = null;

  final BillingStoreProduct? product;
  final String? errorCode;

  bool get isSuccess => product != null;
}

@immutable
class BillingPurchase {
  const BillingPurchase({
    required this.provider,
    required this.productId,
    required this.purchaseToken,
    required this.transactionId,
    required this.originalTransactionId,
    required this.originalJson,
    required this.purchaseTime,
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  final BillingProvider provider;
  final String productId;
  final String purchaseToken;
  final String transactionId;
  final String originalTransactionId;
  final String originalJson;
  final String purchaseTime;
  final BillingPurchaseStatus status;
  final String? errorCode;
  final String? errorMessage;
}

@immutable
class BillingPurchaseAttempt {
  const BillingPurchaseAttempt({
    required this.id,
    required this.product,
    required this.billingAccountId,
    required this.source,
    required this.startedAt,
  });

  final String id;
  final GemProduct product;
  final String billingAccountId;
  final BillingRecoverySource source;
  final DateTime startedAt;
}

@immutable
class BillingPendingPurchase {
  const BillingPendingPurchase({
    required this.provider,
    required this.purchaseToken,
    required this.attemptId,
    required this.billingAccountId,
    required this.productId,
    required this.storeProductId,
    required this.transactionId,
    required this.originalJson,
    required this.purchaseTime,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final BillingProvider provider;
  final String purchaseToken;
  final String attemptId;
  final String billingAccountId;
  final String productId;
  final String storeProductId;
  final String transactionId;
  final String originalJson;
  final String purchaseTime;
  final BillingPendingPurchaseStatus status;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get key => '${provider.name}:$purchaseToken';

  BillingPendingPurchase copyWith({
    BillingPendingPurchaseStatus? status,
    int? retryCount,
    DateTime? updatedAt,
  }) {
    return BillingPendingPurchase(
      provider: provider,
      purchaseToken: purchaseToken,
      attemptId: attemptId,
      billingAccountId: billingAccountId,
      productId: productId,
      storeProductId: storeProductId,
      transactionId: transactionId,
      originalJson: originalJson,
      purchaseTime: purchaseTime,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class BillingState {
  BillingState({
    this.storeAvailable = false,
    Set<String> busyProductIds = const <String>{},
  }) : busyProductIds = Set.unmodifiable(busyProductIds);

  final bool storeAvailable;
  final Set<String> busyProductIds;

  bool get hasBusyPurchase => busyProductIds.isNotEmpty;

  bool isBusy(String productId) => busyProductIds.contains(productId);
}

enum BillingUiEventKind {
  processing,
  success,
  accepted,
  failure,
  pending,
  deferred,
}

@immutable
class BillingUiEvent {
  const BillingUiEvent({
    required this.kind,
    required this.productId,
    required this.attemptId,
    required this.message,
    this.grantedGems = 0,
  });

  final BillingUiEventKind kind;
  final String productId;
  final String attemptId;
  final String message;
  final int grantedGems;
}

class BillingPlatformException implements Exception {
  const BillingPlatformException(this.code, [this.message = '']);

  final String code;
  final String message;

  @override
  String toString() => 'BillingPlatformException($code)';
}

String newBillingAttemptId() {
  final random = Random.secure().nextInt(1 << 32);
  return 'track_id_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${random.toRadixString(36)}';
}
