import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/gem_product.dart';
import 'package:genesis_flutter_android/network/models/gem_purchase_report.dart';
import 'package:genesis_flutter_android/platform/billing/billing_analytics.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/billing_service.dart';
import 'package:genesis_flutter_android/platform/billing/google_play_billing_platform.dart';
import 'package:genesis_flutter_android/platform/billing/pending_purchase_store.dart';

class _FakeBillingPlatform implements BillingPlatform {
  _FakeBillingPlatform({
    this.providerValue = BillingProvider.googlePlay,
    this.expectedStoreProductId = 'worldo_gems_500',
  });

  final StreamController<List<BillingPurchase>> _controller =
      StreamController<List<BillingPurchase>>.broadcast(sync: true);
  final BillingProvider providerValue;
  final String expectedStoreProductId;
  late BillingProductQueryResult queryResult =
      BillingProductQueryResult.success(
        BillingStoreProduct(
          id: expectedStoreProductId,
          type: BillingStoreProductType.inApp,
          nativeProduct: const Object(),
        ),
      );
  bool available = true;
  bool buyAccepted = true;
  int queryCount = 0;
  int buyCount = 0;
  String? queriedPurchaseOptionId;
  String? queriedOfferId;
  String? purchasedOfferToken;
  List<BillingPurchase> pastPurchases = const <BillingPurchase>[];

  @override
  BillingProvider get provider => providerValue;

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
    expect(product.id, expectedStoreProductId);
    expect(product.type, BillingStoreProductType.inApp);
    expect(billingAccountId, '4b74ec68-7abc-4cce-a223-e997e31dc811');
    return buyAccepted;
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
    expect(storeProductId, expectedStoreProductId);
    expect(expectedType, BillingStoreProductType.inApp);
    return queryResult;
  }

  void emit(BillingPurchase purchase) => _controller.add([purchase]);

  Future<void> close() => _controller.close();
}

class _BillingAnalyticsRecord {
  const _BillingAnalyticsRecord(this.action, this.properties);

  final String action;
  final Map<String, Object?> properties;
}

class _FakeBillingAnalytics implements BillingAnalytics {
  final records = <_BillingAnalyticsRecord>[];

  @override
  void track(
    String action, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    records.add(_BillingAnalyticsRecord(action, Map.of(properties)));
  }
}

class _ControllablePendingPurchaseStore
    extends MemoryBillingPendingPurchaseStore {
  bool failNextUpsert = false;

  @override
  Future<void> upsert(BillingPendingPurchase purchase) async {
    if (failNextUpsert) {
      failNextUpsert = false;
      throw StateError('local write failed');
    }
    await super.upsert(purchase);
  }
}

void main() {
  late _FakeBillingPlatform platform;
  late _ControllablePendingPurchaseStore pendingStore;
  late List<GemPurchaseReportRequest> reports;
  late List<BillingUiEvent> uiEvents;
  late _FakeBillingAnalytics analytics;
  late GooglePlayBillingService service;
  var refreshCount = 0;
  var reportError = false;
  var reportStatus = GemPurchaseReportStatus.completed;

  setUp(() {
    platform = _FakeBillingPlatform();
    pendingStore = _ControllablePendingPurchaseStore();
    reports = <GemPurchaseReportRequest>[];
    uiEvents = <BillingUiEvent>[];
    analytics = _FakeBillingAnalytics();
    refreshCount = 0;
    reportError = false;
    reportStatus = GemPurchaseReportStatus.completed;
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
        return GemPurchaseReport(status: reportStatus, grantedGems: 550);
      },
      refreshWallet: () async => refreshCount += 1,
      readUid: () async => 'u_1',
      analytics: analytics,
    );
    service.events.listen(uiEvents.add);
  });

  tearDown(() async {
    service.dispose();
    await platform.close();
  });

  test('completed report refreshes and ignores duplicate callback', () async {
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    expect(platform.queryCount, 1);
    expect(platform.buyCount, 1);
    expect(reports, hasLength(1));
    expect(reports.single.purchaseToken, 'purchase-token-1');
    expect(refreshCount, 1);
    final reported = await pendingStore.loadAll();
    expect(reported, hasLength(1));
    expect(reported.single.status, BillingPendingPurchaseStatus.reported);
    expect(uiEvents, hasLength(2));
    expect(uiEvents.first.kind, BillingUiEventKind.processing);
    expect(uiEvents.first.message, 'Purchasing Gems');
    expect(uiEvents.last.kind, BillingUiEventKind.success);
    expect(uiEvents.last.grantedGems, 550);
    final click = analytics.records.singleWhere(
      (record) => record.action == 'product_click',
    );
    expect(click.properties['source'], 'buy_gems_page');

    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();
    expect(reports, hasLength(1));
    expect(
      analytics.records.where((record) => record.action == 'purchase_success'),
      hasLength(1),
    );
  });

  test('pending callback does not persist a paid purchase', () async {
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.pending));
    await _settle();

    expect(await pendingStore.loadAll(), isEmpty);
    expect(uiEvents.single.kind, BillingUiEventKind.pending);
    final failed = analytics.records.singleWhere(
      (record) => record.action == 'purchase_failed',
    );
    expect(failed.properties['product_id'], 'gem_pack_500');
    expect(failed.properties['reason'], 'purchase_callback_pending');
  });

  test(
    'product query failure is tracked and does not launch billing',
    () async {
      platform.queryResult = const BillingProductQueryResult.failure(
        'product_not_found',
      );

      await service.purchaseGem(_product);
      await _settle();

      expect(platform.buyCount, 0);
      final failed = analytics.records.singleWhere(
        (record) => record.action == 'purchase_failed',
      );
      expect(failed.properties['product_id'], 'gem_pack_500');
      expect(failed.properties['reason'], 'query_failed');
    },
  );

  test('billing launch rejection is tracked', () async {
    platform.buyAccepted = false;

    await service.purchaseGem(_product);
    await _settle();

    final failed = analytics.records.singleWhere(
      (record) => record.action == 'purchase_failed',
    );
    expect(failed.properties['reason'], 'launch_failed');
  });

  test('local order write failure is tracked and blocks report', () async {
    pendingStore.failNextUpsert = true;

    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    expect(reports, isEmpty);
    expect(await pendingStore.loadAll(), isEmpty);
    expect(uiEvents.last.kind, BillingUiEventKind.deferred);
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
    expect(uiEvents, hasLength(2));
    expect(uiEvents.first.kind, BillingUiEventKind.processing);
    expect(uiEvents.last.kind, BillingUiEventKind.deferred);
    final failed = analytics.records.singleWhere(
      (record) => record.action == 'purchase_failed',
    );
    expect(failed.properties['product_id'], 'gem_pack_500');
    expect(failed.properties['reason'], 'report_failed');

    reportError = false;
    await service.recover(BillingRecoverySource.foreground);
    await _settle();

    expect(reports, hasLength(2));
  });

  test(
    'report timeout closes the foreground flow and ignores late UI',
    () async {
      service.dispose();
      uiEvents = <BillingUiEvent>[];
      final reportCompleter = Completer<GemPurchaseReport>();
      service = GooglePlayBillingService(
        platform: platform,
        pendingPurchaseStore: pendingStore,
        loadBillingAccountId: () async =>
            '4b74ec68-7abc-4cce-a223-e997e31dc811',
        loadProductCatalog: () async => [_product],
        reportPurchase: (request) {
          reports.add(request);
          return reportCompleter.future;
        },
        refreshWallet: () async => refreshCount += 1,
        readUid: () async => 'u_1',
        analytics: analytics,
        reportTimeout: const Duration(milliseconds: 10),
      );
      service.events.listen(uiEvents.add);

      await service.purchaseGem(_product);
      platform.emit(_purchase(BillingPurchaseStatus.purchased));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await _settle();

      expect(uiEvents, hasLength(2));
      expect(uiEvents.first.kind, BillingUiEventKind.processing);
      expect(uiEvents.last.kind, BillingUiEventKind.failure);
      expect(uiEvents.last.message, 'purchase timeout');
      expect(service.state.value.hasBusyPurchase, isFalse);
      final failed = analytics.records.singleWhere(
        (record) => record.action == 'purchase_failed',
      );
      expect(failed.properties['product_id'], 'gem_pack_500');
      expect(failed.properties['reason'], 'timeout');

      reportCompleter.complete(
        const GemPurchaseReport(status: GemPurchaseReportStatus.completed),
      );
      await _settle();

      expect(uiEvents, hasLength(2));
      expect(refreshCount, 1);
      expect(
        (await pendingStore.loadAll()).single.status,
        BillingPendingPurchaseStatus.reported,
      );
    },
  );

  test('records only the simplified purchase telemetry stages', () async {
    platform.queryResult = BillingProductQueryResult.success(
      const BillingStoreProduct(
        id: 'worldo_gems_500',
        type: BillingStoreProductType.inApp,
        nativeProduct: Object(),
        purchaseOptionId: '500-gems-new',
        offerId: '500-gems-new-discount',
        offerToken: 'sensitive-offer-token',
        formattedPrice: r'$1.49',
        priceAmountMicros: 1490000,
        priceCurrencyCode: 'USD',
      ),
    );

    await service.purchaseGem(
      _product,
      source: BillingPurchaseSource.buyGemsSheet,
      payTrackId: 'pay_sheet_track',
    );
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    final actions = analytics.records.map((record) => record.action).toList();
    expect(
      actions,
      containsAllInOrder(<String>['product_click', 'purchase_success']),
    );
    expect(
      actions.where(
        (action) => action == 'product_click' || action == 'purchase_success',
      ),
      hasLength(actions.length),
    );
    final click = analytics.records.singleWhere(
      (record) => record.action == 'product_click',
    );
    expect(click.properties['source'], 'buy_gems_sheet');
    expect(click.properties['attempt_id'], 'pay_sheet_track');
    final success = analytics.records.singleWhere(
      (record) => record.action == 'purchase_success',
    );
    expect(success.properties['product_id'], 'gem_pack_500');
    expect(success.properties['attempt_id'], 'pay_sheet_track');
    expect(success.properties['transaction_id'], 'GPA.1');

    final serialized = analytics.records
        .expand((record) => record.properties.entries)
        .map((entry) => '${entry.key}=${entry.value}')
        .join('|');
    expect(serialized, isNot(contains('purchase-token-1')));
    expect(serialized, isNot(contains('sensitive-offer-token')));
    expect(serialized, isNot(contains('4b74ec68-7abc-4cce-a223-e997e31dc811')));
    expect(serialized, isNot(contains('original_json')));
  });

  test('accepted is terminal for report and waits for the server', () async {
    reportStatus = GemPurchaseReportStatus.accepted;
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    final reported = await pendingStore.loadAll();
    expect(reported.single.status, BillingPendingPurchaseStatus.reported);
    expect(refreshCount, 0);
    expect(uiEvents, hasLength(2));
    expect(uiEvents.first.kind, BillingUiEventKind.processing);
    expect(uiEvents.last.kind, BillingUiEventKind.accepted);
    expect(
      uiEvents.last.message,
      'Payment successful. Your Gems are being issued as quickly as possible. Please check your balance again later.',
    );

    service.resetForSession();
    platform.pastPurchases = [_purchase(BillingPurchaseStatus.purchased)];
    await service.recover(BillingRecoverySource.foreground);
    await _settle();

    expect(reports, hasLength(1));
    expect(await pendingStore.loadAll(), hasLength(1));

    platform.pastPurchases = const <BillingPurchase>[];
    await service.recover(BillingRecoverySource.foreground);
    expect(await pendingStore.loadAll(), isEmpty);
  });

  test('rejected is terminal and does not refresh the wallet', () async {
    reportStatus = GemPurchaseReportStatus.rejected;
    await service.purchaseGem(_product);
    platform.emit(_purchase(BillingPurchaseStatus.purchased));
    await _settle();

    final reported = await pendingStore.loadAll();
    expect(reported.single.status, BillingPendingPurchaseStatus.reported);
    expect(refreshCount, 0);
    expect(uiEvents, hasLength(2));
    expect(uiEvents.first.kind, BillingUiEventKind.processing);
    expect(uiEvents.last.kind, BillingUiEventKind.failure);
    expect(uiEvents.last.message, 'Purchase was refunded.');
    final failed = analytics.records.singleWhere(
      (record) => record.action == 'purchase_failed',
    );
    expect(failed.properties['product_id'], 'gem_pack_500');
    expect(failed.properties['reason'], 'report_rejected');
  });

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

  test(
    'ignores Google offer fields unless purchase option and offer id are both present',
    () async {
      const product = GemProduct(
        productId: 'gem_pack_500',
        appleProductId: 'com.worldo.gems.500',
        googleProductId: 'worldo_gems_500',
        googlePurchaseOptionId: '500-gems-new',
        baseGems: 500,
        bonusGems: 50,
        priceCurrencyCode: 'USD',
        priceAmount: 149,
        canPurchase: true,
        activityType: 'none',
      );

      await service.purchaseGem(product);

      expect(platform.queriedPurchaseOptionId, isNull);
      expect(platform.queriedOfferId, isNull);
      expect(platform.purchasedOfferToken, isNull);
    },
  );

  test(
    'app store purchases report apple store product id without token',
    () async {
      service.dispose();
      await platform.close();
      platform = _FakeBillingPlatform(
        providerValue: BillingProvider.appStore,
        expectedStoreProductId: 'com.worldo.gems.500',
      );
      reports = <GemPurchaseReportRequest>[];
      uiEvents = <BillingUiEvent>[];
      service = GooglePlayBillingService(
        platform: platform,
        pendingPurchaseStore: pendingStore,
        loadBillingAccountId: () async =>
            '4b74ec68-7abc-4cce-a223-e997e31dc811',
        loadProductCatalog: () async => [_product],
        reportPurchase: (request) async {
          reports.add(request);
          return const GemPurchaseReport(
            status: GemPurchaseReportStatus.completed,
            grantedGems: 550,
          );
        },
        refreshWallet: () async => refreshCount += 1,
        readUid: () async => 'u_1',
        analytics: analytics,
      );
      service.events.listen(uiEvents.add);

      await service.purchaseGem(_product, payTrackId: 'track_id_page_click');
      platform.emit(
        _purchase(
          BillingPurchaseStatus.purchased,
          provider: BillingProvider.appStore,
          storeProductId: 'com.worldo.gems.500',
          purchaseToken: '2000000123456789',
          transactionId: '2000000123456789',
          originalJson: '{"transactionId":"2000000123456789"}',
        ),
      );
      await _settle();

      expect(platform.queryCount, 1);
      expect(platform.buyCount, 1);
      expect(reports, hasLength(1));
      final request = reports.single;
      expect(request.provider, 'apple');
      expect(request.productId, 'gem_pack_500');
      expect(request.storeProductId, 'com.worldo.gems.500');
      expect(request.transactionId, '2000000123456789');
      expect(request.purchaseToken, isNull);
      expect(request.requestId, 'track_id_page_click');
      expect(request.payload, {'purchase_time': '1000'});
      final success = analytics.records.singleWhere(
        (record) => record.action == 'purchase_success',
      );
      expect(success.properties['transaction_id'], '2000000123456789');
    },
  );

  test(
    'app store recovery does not clear active checkout on empty purchase query',
    () async {
      service.dispose();
      await platform.close();
      platform = _FakeBillingPlatform(
        providerValue: BillingProvider.appStore,
        expectedStoreProductId: 'com.worldo.gems.500',
      );
      reports = <GemPurchaseReportRequest>[];
      service = GooglePlayBillingService(
        platform: platform,
        pendingPurchaseStore: pendingStore,
        loadBillingAccountId: () async =>
            '4b74ec68-7abc-4cce-a223-e997e31dc811',
        loadProductCatalog: () async => [_product],
        reportPurchase: (request) async {
          reports.add(request);
          return const GemPurchaseReport(
            status: GemPurchaseReportStatus.completed,
            grantedGems: 550,
          );
        },
        refreshWallet: () async => refreshCount += 1,
        readUid: () async => 'u_1',
        analytics: analytics,
      );

      await service.purchaseGem(_product, payTrackId: 'track_id_original');
      await service.recover(BillingRecoverySource.foreground);
      platform.emit(
        _purchase(
          BillingPurchaseStatus.purchased,
          provider: BillingProvider.appStore,
          storeProductId: 'com.worldo.gems.500',
          purchaseToken: '2000000123456790',
          transactionId: '2000000123456790',
        ),
      );
      await _settle();

      expect(reports, hasLength(1));
      expect(reports.single.requestId, 'track_id_original');
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

BillingPurchase _purchase(
  BillingPurchaseStatus status, {
  BillingProvider provider = BillingProvider.googlePlay,
  String storeProductId = 'worldo_gems_500',
  String purchaseToken = 'purchase-token-1',
  String transactionId = 'GPA.1',
  String originalJson = '{"purchaseToken":"purchase-token-1"}',
}) {
  return BillingPurchase(
    provider: provider,
    productId: storeProductId,
    purchaseToken: purchaseToken,
    transactionId: transactionId,
    originalTransactionId: '',
    originalJson: originalJson,
    purchaseTime: '1000',
    status: status,
  );
}

Future<void> _settle() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
