import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:genesis_flutter_android/platform/billing/pending_purchase_store.dart';

class _FakeBillingPlatform implements BillingPlatform {
  final StreamController<List<BillingPurchase>> _controller =
      StreamController<List<BillingPurchase>>.broadcast(sync: true);
  BillingProductQueryResult queryResult = BillingProductQueryResult.success(
    const BillingStoreProduct(
      id: 'worldo_gems_500',
      type: BillingStoreProductType.inApp,
      nativeProduct: Object(),
    ),
  );
  bool available = true;
  bool buyAccepted = true;
  bool consumeFails = false;
  int queryCount = 0;
  int buyCount = 0;
  int consumeCount = 0;
  String? queriedPurchaseOptionId;
  String? queriedOfferId;
  String? purchasedOfferToken;
  List<BillingPurchase> pastPurchases = const <BillingPurchase>[];

  @override
  BillingProvider get provider => BillingProvider.googlePlay;

  @override
  Stream<List<BillingPurchase>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> buyConsumable({
    required BillingStoreProduct product,
    required String billingAccountId,
  }) async {
    buyCount += 1;
    purchasedOfferToken = product.offerToken;
    expect(product.id, 'worldo_gems_500');
    expect(product.type, BillingStoreProductType.inApp);
    expect(billingAccountId, '4b74ec68-7abc-4cce-a223-e997e31dc811');
    return buyAccepted;
  }

  @override
  Future<void> finalizePurchase(BillingPurchase purchase) async {
    consumeCount += 1;
    if (consumeFails) {
      throw const BillingPlatformException('consume_network_error');
    }
  }

  @override
  Future<List<BillingPurchase>> queryPastPurchases({
    required String billingAccountId,
  }) async => pastPurchases;

  @override
  Future<BillingProductQueryResult> queryProduct(
    String storeProductId,
    BillingStoreProductType expectedType, {
    String? purchaseOptionId,
    String? offerId,
  }) async {
    queryCount += 1;
    queriedPurchaseOptionId = purchaseOptionId;
    queriedOfferId = offerId;
    expect(storeProductId, 'worldo_gems_500');
    expect(expectedType, BillingStoreProductType.inApp);
    return queryResult;
  }

  void emit(BillingPurchase purchase) => _controller.add([purchase]);

  Future<void> close() => _controller.close();
}

void main() {
  late _FakeBillingPlatform platform;
  late MemoryBillingPendingPurchaseStore pendingStore;
  late List<GemPurchaseReportRequest> reports;
  late List<BillingUiEvent> uiEvents;
  late GooglePlayBillingService service;
  var refreshCount = 0;
  var reportError = false;

  setUp(() {
    platform = _FakeBillingPlatform();
    pendingStore = MemoryBillingPendingPurchaseStore();
    reports = <GemPurchaseReportRequest>[];
    uiEvents = <BillingUiEvent>[];
    refreshCount = 0;
    reportError = false;
    service = GooglePlayBillingService(
      platform: platform,
      pendingPurchaseStore: pendingStore,
      loadBillingAccountId: () async => '4b74ec68-7abc-4cce-a223-e997e31dc811',
      loadProductCatalog: () async => [_product],
      reportPurchase: (request) async {
        reports.add(request);
        if (reportError) {
          throw ApiException(
            message: 'offline',
            kind: ApiExceptionKind.transport,
          );
        }
        return const GemPurchaseReport(
          reportId: 'gpr_1',
          orderId: 'gpo_1',
          reportStatus: 'verified',
          orderStatus: 'granted',
          granted: true,
          grantedGems: 550,
          walletBalance: 980,
        );
      },
      refreshWallet: () async => refreshCount += 1,
      readUid: () async => 'u_1',
    );
    service.events.listen(uiEvents.add);
  });

  tearDown(() async {
    service.dispose();
    await platform.close();
  });

  test(
    'purchased reports, refreshes, consumes, and ignores duplicate callback',
    () async {
      await service.purchaseGem(_product);
      platform.emit(_purchase(BillingPurchaseStatus.purchased));
      await _settle();

      expect(platform.queryCount, 1);
      expect(platform.buyCount, 1);
      expect(reports, hasLength(1));
      expect(reports.single.purchaseToken, 'purchase-token-1');
      expect(refreshCount, 1);
      expect(platform.consumeCount, 1);
      expect(await pendingStore.loadAll(), isEmpty);
      expect(uiEvents.single.kind, BillingUiEventKind.success);

      platform.emit(_purchase(BillingPurchaseStatus.purchased));
      await _settle();
      expect(reports, hasLength(1));
      expect(platform.consumeCount, 1);
    },
  );

  test('pending callback does not persist a paid purchase', () async {
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.pending));
    await _settle();

    expect(await pendingStore.loadAll(), isEmpty);
    expect(platform.consumeCount, 0);
    expect(uiEvents.single.kind, BillingUiEventKind.pending);
  });

  test('server report failure keeps the received purchase for retry', () async {
    reportError = true;
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    final pending = await pendingStore.loadAll();
    expect(pending, hasLength(1));
    expect(pending.single.status, BillingPendingPurchaseStatus.received);
    expect(pending.single.retryCount, 1);
    expect(platform.consumeCount, 0);
    expect(uiEvents.single.kind, BillingUiEventKind.deferred);
  });

  test(
    'consume failure keeps a granted purchase until the next retry',
    () async {
      platform.consumeFails = true;
      await service.purchaseGem(_product);
      platform.emit(_purchase(BillingPurchaseStatus.purchased));
      await _settle();

      final granted = await pendingStore.loadAll();
      expect(granted.single.status, BillingPendingPurchaseStatus.granted);
      expect(refreshCount, 1);
      expect(platform.consumeCount, 1);

      platform.consumeFails = false;
      platform.emit(_purchase(BillingPurchaseStatus.purchased));
      await _settle();

      expect(await pendingStore.loadAll(), isEmpty);
      expect(platform.consumeCount, 2);
      expect(reports, hasLength(1));
    },
  );

  test('recovery clears a checkout that Google no longer reports', () async {
    await service.purchaseGem(_product);
    expect(service.state.value.hasBusyPurchase, isTrue);

    await service.recover(BillingRecoverySource.foreground);

    expect(service.state.value.hasBusyPurchase, isFalse);
  });

  test(
    'passes the selected Google offer through to the purchase flow',
    () async {
      platform.queryResult = BillingProductQueryResult.success(
        const BillingStoreProduct(
          id: 'worldo_gems_500',
          type: BillingStoreProductType.inApp,
          nativeProduct: Object(),
          purchaseOptionId: '500-gems-new',
          offerId: '500-gems-new-discount',
          offerToken: 'offer-token-1',
        ),
      );
      const product = GemProduct(
        productId: 'gem_pack_500',
        appleProductId: 'com.worldo.gems.500',
        googleProductId: 'worldo_gems_500',
        googlePurchaseOptionId: '500-gems-new',
        googleOfferId: '500-gems-new-discount',
        baseGems: 500,
        bonusGems: 50,
        priceCurrencyCode: 'USD',
        priceAmount: 149,
        canPurchase: true,
        activityType: 'none',
      );

      await service.purchaseGem(product);

      expect(platform.queriedPurchaseOptionId, '500-gems-new');
      expect(platform.queriedOfferId, '500-gems-new-discount');
      expect(platform.purchasedOfferToken, 'offer-token-1');
    },
  );
}

const _product = GemProduct(
  productId: 'gem_pack_500',
  appleProductId: 'com.worldo.gems.500',
  googleProductId: 'worldo_gems_500',
  baseGems: 500,
  bonusGems: 50,
  priceCurrencyCode: 'USD',
  priceAmount: 149,
  canPurchase: true,
  activityType: 'none',
);

BillingPurchase _purchase(BillingPurchaseStatus status) {
  return BillingPurchase(
    provider: BillingProvider.googlePlay,
    productId: 'worldo_gems_500',
    purchaseToken: 'purchase-token-1',
    transactionId: 'GPA.1',
    originalTransactionId: '',
    originalJson: '{"purchaseToken":"purchase-token-1"}',
    purchaseTime: '1000',
    status: status,
    nativePurchase: Object(),
  );
}

Future<void> _settle() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
