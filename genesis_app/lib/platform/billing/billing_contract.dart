import 'package:flutter/foundation.dart';

import '../../network/models/gem_product.dart';
import '../../network/models/gem_purchase_report.dart';
import 'billing_models.dart';

typedef BillingAccountIdLoader = Future<String> Function();
typedef BillingProductCatalogLoader = Future<List<GemProduct>> Function();
typedef BillingPurchaseReporter =
    Future<GemPurchaseReport> Function(GemPurchaseReportRequest request);
typedef BillingWalletRefresher = Future<void> Function();
typedef BillingUidReader = Future<String?> Function();

abstract interface class BillingService {
  ValueListenable<BillingState> get state;

  Stream<BillingUiEvent> get events;

  Future<void> start();

  Future<void> purchaseGem(
    GemProduct product, {
    BillingPurchaseSource source = BillingPurchaseSource.buyGemsPage,
    String payTrackId = '',
  });

  Future<void> recover(BillingRecoverySource source);

  Future<bool> recoverStorePurchases({List<GemProduct>? productCatalog});

  void resetForSession();

  void dispose();
}
