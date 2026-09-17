import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/app/telemetry/firebase_analytics_monitoring.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/network/models/membership_claim.dart';
import 'package:genesis_flutter_android/network/models/membership_guest_purchase_check.dart';
import 'package:genesis_flutter_android/platform/billing/membership_guest_claim_record.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/membership_checkout_platform.dart';
import 'package:genesis_flutter_android/platform/billing/membership_pending_store.dart';
import 'package:genesis_flutter_android/platform/billing/membership_restore_record.dart';
import 'package:genesis_flutter_android/platform/billing/membership_store_purchase.dart';

import '../../support/membership_fixtures.dart';

const accountUuid = '4b74ec68-7abc-4cce-a223-e997e31dc811';
const guest = MembershipGuestIdentity(
  accountUuid: '8b74ec68-7abc-4cce-a223-e997e31dc811',
);
const completed = MembershipPurchaseReport(
  status: MembershipReportStatus.completed,
);

class PendingStore implements MembershipPendingStore {
  final records = <String, MembershipPurchaseRecord>{};
  final confirmed = <String, MembershipPurchaseRecord>{};
  final restores = <String, MembershipRestoreRecord>{};
  final claims = <String, MembershipGuestClaimRecord>{};
  bool fail = false;
  bool failComplete = false;
  bool failRestoreCleanup = false;
  bool failClaim = false;
  bool failClaimCleanup = false;
  final completedRecords = <MembershipPurchaseRecord>[];
  Future<void> Function(MembershipPurchaseRecord)? onSave;
  Future<void> Function()? onLoad;
  @override
  Future<List<MembershipGuestClaimRecord>> loadGuestClaims() async {
    await onLoad?.call();
    return claims.values.toList();
  }

  @override
  Future<void> saveGuestClaim(MembershipGuestClaimRecord record) async {
    if (fail || failClaim) throw StateError('claim storage unavailable');
    claims[record.guest.accountUuid] = record;
  }

  @override
  Future<bool> removeUnpurchasedGuestIdentity(String accountUuid) async {
    if (fail || failClaimCleanup) throw StateError('claim cleanup unavailable');
    final claim = claims[accountUuid];
    if (claim?.hasPurchase == true ||
        claim?.ownerUid != null ||
        claim?.status != null ||
        [...records.values, ...confirmed.values].any(
          (purchase) =>
              purchase.guest?.accountUuid == accountUuid &&
              (purchase.hasReceipt ||
                  purchase.paid ||
                  purchase.state == 'pending'),
        )) {
      return false;
    }
    claims.remove(accountUuid);
    return true;
  }

  @override
  Future<void> completeGuestClaim(MembershipGuestClaimRecord record) async {
    if (fail || failClaimCleanup) throw StateError('claim cleanup unavailable');
    if (record.status != 'completed' || record.ownerUid == null) {
      throw StateError('claim is not completed');
    }
    confirmed.removeWhere(
      (_, p) => p.guest?.accountUuid == record.guest.accountUuid,
    );
    records.removeWhere(
      (_, p) => p.guest?.accountUuid == record.guest.accountUuid,
    );
    claims.remove(record.guest.accountUuid);
  }

  @override
  Future<List<MembershipPurchaseRecord>> loadConfirmedReceipts() async =>
      confirmed.values.toList();
  @override
  Future<void> complete(MembershipPurchaseRecord record) async {
    if (fail || failComplete) throw StateError('storage unavailable');
    completedRecords.add(record);
    if (record.guest != null &&
        record.paid &&
        record.hasReceipt &&
        record.reportStatus != 'rejected') {
      confirmed[record.requestId] = record;
    } else {
      confirmed.remove(record.requestId);
    }
    records.remove(record.requestId);
  }

  @override
  Future<void> saveGuestPurchase(MembershipPurchaseRecord record) async {
    if (fail || failClaim) throw StateError('guest storage unavailable');
    if (record.guest != null &&
        record.paid &&
        record.hasReceipt &&
        record.reportStatus != 'rejected') {
      confirmed[record.requestId] = record;
    } else {
      confirmed.remove(record.requestId);
    }
  }

  @override
  Future<void> removeRestore(String requestId) async {
    if (fail || failRestoreCleanup) throw StateError('storage unavailable');
    restores.remove(requestId);
  }

  @override
  Future<List<MembershipPurchaseRecord>> loadAll() async =>
      records.values.toList();
  @override
  Future<void> save(MembershipPurchaseRecord record) async {
    if (fail) throw StateError('storage unavailable');
    await onSave?.call(record);
    records[record.requestId] = record;
  }

  @override
  Future<List<MembershipRestoreRecord>> loadRestores() async =>
      restores.values.toList();
  @override
  Future<void> saveRestore(MembershipRestoreRecord record) async {
    if (fail) throw StateError('storage unavailable');
    restores[record.requestId] = record;
  }
}

class Checkout implements MembershipCheckoutPlatform {
  int launches = 0;
  int queries = 0;
  String? uuid;
  MembershipProduct? product;
  bool launchResult = true;
  Future<void> Function()? onPrepare;
  Future<void> Function()? onLaunch;
  bool autoHandoff = true;
  bool Function()? handoff;
  @override
  Future<Object> prepare(MembershipProduct product) async {
    this.product = product;
    await onPrepare?.call();
    return product;
  }

  @override
  Future<bool> launch(
    Object product,
    String accountUuid, {
    bool Function()? onStoreHandoff,
  }) async {
    launches++;
    uuid = accountUuid;
    handoff = onStoreHandoff;
    await onLaunch?.call();
    if (launchResult && autoHandoff) onStoreHandoff?.call();
    return launchResult;
  }

  @override
  Future<bool> isSubscription(String productId) async {
    queries++;
    return !productId.startsWith('gem');
  }
}

class Harness {
  String? lastAccountUuid;
  MembershipAccessState access = const MembershipAccessState();
  Future<MembershipAccessState> Function()? membershipAccessHandler;
  Harness({
    this.provider = MembershipProvider.google,
    SubscriptionAnalytics? analytics,
    Future<void> Function()? ensureStoreListening,
    Future<MembershipProductList> Function()? checkoutProducts,
    PendingStore? storage,
    bool restoreEnabled = false,
    bool claimEnabled = false,
    bool guestRecoveryEnabled = false,
    Duration retryDelay = const Duration(days: 1),
    Duration attemptTimeout = const Duration(seconds: 90),
    Duration guestRecoveryTimeout = const Duration(seconds: 15),
  }) : store = storage ?? PendingStore() {
    service = MembershipPurchaseService(
      analytics: analytics,
      ensureStoreListening: ensureStoreListening,
      platform: platform,
      store: store,
      provider: provider,
      readLoginUid: () async =>
          loginUidHandler == null ? uid : await loginUidHandler!(),
      readCheckoutProducts:
          checkoutProducts ??
          () async {
            eligibilityQueries++;
            return MembershipProductList(
              lastAccountUuid: lastAccountUuid,
              products: productsHandler == null
                  ? [product(), product(yearly: true)]
                  : await productsHandler!(),
            );
          },
      readMembershipAccess: () async => membershipAccessHandler == null
          ? access
          : await membershipAccessHandler!(),
      loadAccountUuid: () async => accountUuidHandler == null
          ? accountUuid
          : await accountUuidHandler!(),
      prepareGuest: () async {
        guestPrepares++;
        return guestHandler == null ? guest : await guestHandler!();
      },
      reportPurchase: (request) async {
        reports.add(request);
        expectSync(
          request.purchaseToken.isNotEmpty || request.transactionId.isNotEmpty,
          isTrue,
        );
        return reportHandler == null
            ? completed
            : await reportHandler!(request);
      },
      claimGuest: claimEnabled
          ? (request) async {
              claimRequests.add(request);
              expectSync(
                store.claims[request.guest.accountUuid]?.ownerUid,
                uid,
              );
              return claimHandler == null
                  ? MembershipClaimResult(
                      status: MembershipReportStatus.completed,
                    )
                  : await claimHandler!(request);
            }
          : null,
      loadSignedTransaction: (request) async {
        signedTransactionQueries++;
        return signedTransactionHandler == null
            ? 'test.header.signature'
            : await signedTransactionHandler!(request);
      },
      checkGuestPurchase: guestRecoveryEnabled
          ? (uuid) async {
              guestChecks.add(uuid);
              return guestCheckHandler == null
                  ? const MembershipGuestPurchaseCheck(hasUnboundOrder: true)
                  : await guestCheckHandler!(uuid);
            }
          : null,
      discoverGuestPurchases: guestRecoveryEnabled
          ? () async {
              guestDiscoveries++;
              return guestPurchasesHandler == null
                  ? guestPurchases
                  : await guestPurchasesHandler!();
            }
          : null,
      queryRestorePurchases: restoreEnabled
          ? (ids) async {
              restoreQueries++;
              return storeQuery == null ? recoverable : await storeQuery!();
            }
          : null,
      queryPurchases: () async {
        recoverQueries++;
        return recoverable;
      },
      refreshWallet: () async {
        refreshes++;
        await walletRefreshHandler?.call();
      },
      otherPurchaseBusy: () => gemsBusy,
      retryDelay: retryDelay,
      attemptTimeout: attemptTimeout,
      guestRecoveryTimeout: guestRecoveryTimeout,
    );
    addTearDown(service.dispose);
  }
  final MembershipProvider provider;
  final PendingStore store;
  final Checkout platform = Checkout();
  late final MembershipPurchaseService service;
  String? uid = 'user-test';
  List<MembershipStorePurchase> guestPurchases = [];
  Future<List<MembershipStorePurchase>> Function()? guestPurchasesHandler;
  Future<String?> Function()? loginUidHandler;
  Future<String> Function()? accountUuidHandler;
  Future<MembershipGuestIdentity> Function()? guestHandler;
  bool gemsBusy = false;
  int guestPrepares = 0;
  int guestDiscoveries = 0;
  final guestChecks = <String>[];
  Future<MembershipGuestPurchaseCheck> Function(String)? guestCheckHandler;
  int eligibilityQueries = 0;
  Future<List<MembershipProduct>> Function()? productsHandler;
  int refreshes = 0;
  Future<void> Function()? walletRefreshHandler;
  int recoverQueries = 0;
  int restoreQueries = 0;
  final claimRequests = <MembershipClaimRequest>[];
  Future<MembershipClaimResult> Function(MembershipClaimRequest)? claimHandler;
  int signedTransactionQueries = 0;
  Future<String> Function(MembershipClaimRequest)? signedTransactionHandler;
  Future<List<BillingPurchase>> Function()? storeQuery;
  List<BillingPurchase> recoverable = [];
  final reports = <MembershipPurchaseRequest>[];
  Future<MembershipPurchaseReport> Function(MembershipPurchaseRequest)?
  reportHandler;
  MembershipProduct product({bool yearly = false}) =>
      membershipProduct(provider: provider, yearly: yearly);
  BillingPurchase purchase({
    bool yearly = false,
    BillingPurchaseStatus status = BillingPurchaseStatus.purchased,
    String token = 'test-token',
    String transaction = '100',
    String? uuid,
    String purchaseTime = '',
  }) => BillingPurchase(
    provider: provider == MembershipProvider.google
        ? BillingProvider.googlePlay
        : BillingProvider.appStore,
    productId: product(yearly: yearly).storeProductId,
    purchaseToken: token,
    transactionId: transaction,
    originalTransactionId: 'original-test',
    originalJson: '',
    signedTransaction: provider == MembershipProvider.apple
        ? 'test.header.signature'
        : '',
    purchaseTime: purchaseTime,
    status: status,
    obfuscatedAccountId:
        uuid ?? (uid == null ? guest.accountUuid : accountUuid),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _RecordingAnalyticsClient enableFirebaseAnalytics() {
    final client = _RecordingAnalyticsClient();
    FirebaseAnalyticsMonitoring.resetForTesting();
    FirebaseAnalyticsMonitoring.setClientForTesting(client);
    FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
      _MemoryAnalyticsOnceEventStore(),
    );
    FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
    FirebaseAnalyticsMonitoring.setReadinessForTesting(Future.value());
    FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
      () async => 'test-device-id',
    );
    addTearDown(FirebaseAnalyticsMonitoring.resetForTesting);
    return client;
  }

  for (final provider in MembershipProvider.values) {
    test(
      '$provider Firebase purchase records completed once and deduplicates callbacks',
      () async {
        final client = enableFirebaseAnalytics();
        final h = Harness(provider: provider);
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        await h.service.recover();
        await h.service.interceptPurchase(h.purchase());
        await _settleAnalytics();
        expect(client.events.map((e) => e.name), [
          'purchase',
          'purchase_first',
          'subscription_first',
        ]);
        expect(h.reports, hasLength(1));
        expect(h.service.state.value, MembershipCheckoutState.completed);
      },
    );

    test(
      '$provider Firebase accepted does not become success after restart',
      () async {
        final client = enableFirebaseAnalytics();
        final h = Harness(provider: provider);
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.accepted,
        );
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(
          h.purchase(status: BillingPurchaseStatus.pending),
        );
        await _settleAnalytics();
        expect(client.events, isEmpty);
        final restarted = Harness(provider: provider, storage: h.store);
        await restarted.service.recover();
        await _settleAnalytics();
        expect(client.events, isEmpty);
        expect(restarted.reports, isEmpty);
        await restarted.service.interceptPurchase(h.purchase());
        await _settleAnalytics();
        expect(client.events, isEmpty);
      },
    );
  }

  for (final outcome in ['rejected', 'offline', 'foreign_account']) {
    test('subscription Firebase purchase excludes $outcome', () async {
      final client = enableFirebaseAnalytics();
      final h = Harness();
      if (outcome == 'rejected') {
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.rejected,
        );
      }
      if (outcome == 'offline') {
        h.reportHandler = (_) async => throw StateError('offline');
      }
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(uuid: outcome == 'foreign_account' ? 'other-account' : null),
      );
      await _settleAnalytics();
      expect(client.events, isEmpty);
    });
  }
  for (final provider in MembershipProvider.values) {
    test(
      '$provider debug order ID follows the latest checkout and clears on session change',
      () async {
        final h = Harness(provider: provider);
        final firstId = provider == MembershipProvider.google
            ? 'GPA.1111-2222-3333-44444'
            : '9900123456789';
        final nextId = provider == MembershipProvider.google
            ? 'GPA.5555-6666-7777-88888'
            : '9900987654321';
        try {
          expect(h.service.debugStoreOrderId.value, isNull);
          await h.service.purchase(
            h.product(),
            attemptId: 'local-first-attempt',
          );
          expect(h.service.debugStoreOrderId.value, isNull);
          await h.service.interceptPurchase(h.purchase(transaction: firstId));
          expect(h.service.debugStoreOrderId.value, firstId);
          expect(h.store.records, isEmpty);
          await h.service.purchase(
            h.product(yearly: true),
            attemptId: 'local-next-attempt',
          );
          expect(h.service.debugStoreOrderId.value, isNull);
          // A late callback from the previous receipt must not replace this order.
          await h.service.interceptPurchase(h.purchase(transaction: firstId));
          expect(h.service.debugStoreOrderId.value, isNull);
          await h.service.interceptPurchase(
            h.purchase(
              yearly: true,
              token: 'next-purchase-token',
              transaction: nextId,
            ),
          );
          expect(h.service.debugStoreOrderId.value, nextId);
          h.uid = 'another-user';
          h.service.resetForSession();
          await h.service.recover();
          expect(h.service.debugStoreOrderId.value, isNull);
        } finally {
          h.service.dispose();
        }
      },
    );
  }

  test(
    'subscription purchases record independent first analytics events',
    () async {
      final analytics = _RecordingAnalyticsClient();
      FirebaseAnalyticsMonitoring.resetForTesting();
      FirebaseAnalyticsMonitoring.setClientForTesting(analytics);
      FirebaseAnalyticsMonitoring.setOnceEventStoreForTesting(
        _MemoryAnalyticsOnceEventStore(),
      );
      FirebaseAnalyticsMonitoring.setEnabledForTesting(true);
      FirebaseAnalyticsMonitoring.setReadinessForTesting(Future<void>.value());
      FirebaseAnalyticsMonitoring.setDeviceIdReaderForTesting(
        () async => 'test-device-id',
      );
      addTearDown(FirebaseAnalyticsMonitoring.resetForTesting);

      final google = Harness();
      await google.service.purchase(google.product());
      await google.service.interceptPurchase(google.purchase());

      final apple = Harness(provider: MembershipProvider.apple);
      await apple.service.purchase(apple.product(yearly: true));
      await apple.service.interceptPurchase(
        apple.purchase(yearly: true, token: '', transaction: 'apple-2'),
      );

      final restored = Harness();
      await restored.service.purchase(restored.product());
      await restored.service.interceptPurchase(
        restored.purchase(status: BillingPurchaseStatus.restored),
      );

      final canceled = Harness();
      await canceled.service.purchase(canceled.product());
      await canceled.service.interceptPurchase(
        canceled.purchase(status: BillingPurchaseStatus.canceled),
      );

      final unowned = Harness();
      await unowned.service.interceptPurchase(
        unowned.purchase(token: 'unowned-token', transaction: 'unowned-order'),
      );
      await _settleAnalytics();

      expect(analytics.events.map((event) => event.name), <String>[
        'purchase',
        'purchase_first',
        'subscription_first',
        'purchase',
      ]);
      expect(analytics.events.first.parameters, <String, Object>{
        'provider': 'google',
        'product_id': google.product().storeProductId,
        'device_id': 'test-device-id',
      });
      expect(analytics.events.last.parameters, <String, Object>{
        'provider': 'apple',
        'product_id': apple.product(yearly: true).storeProductId,
        'device_id': 'test-device-id',
      });
    },
  );

  test('successful logged-in report leaves no durable order history', () async {
    final h = Harness();
    await h.service.purchase(h.product(yearly: true));
    await h.service.interceptPurchase(h.purchase(yearly: true));
    expect(h.store.records, isEmpty);
    final restarted = Harness(storage: h.store, restoreEnabled: true);
    restarted.recoverable = [h.purchase(yearly: true)];
    await restarted.service.restorePurchases(
      products: [h.product(), h.product(yearly: true)],
    );
    expect(restarted.reports, isEmpty);
    expect(restarted.store.confirmed, isEmpty);
    expect(restarted.store.restores, isEmpty);
  });
  test('completed report does not depend on legacy queue cleanup', () async {
    final h = Harness(provider: MembershipProvider.apple);
    h.store.failComplete = true;
    await h.service.purchase(h.product());
    await h.service.interceptPurchase(h.purchase());
    expect(h.service.state.value, MembershipCheckoutState.completed);
    expect(h.store.records, isEmpty);
    h.store.failComplete = false;
    await h.service.recover();
    expect(h.reports, hasLength(1));
    expect(h.store.records, isEmpty);
  });
  for (final provider in MembershipProvider.values) {
    test(
      '$provider accepted ends report without persistence or later retry',
      () async {
        final h = Harness(provider: provider);
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.accepted,
        );
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        expect(h.store.records, isEmpty);
        expect(h.store.confirmed, isEmpty);
        expect(h.refreshes, 0);
        h.reportHandler = null;
        await h.service.recover();
        expect(h.reports, hasLength(1));
        expect(h.service.state.value, MembershipCheckoutState.accepted);
        expect(h.store.records, isEmpty);
        expect(h.refreshes, 0);
      },
    );
  }
  test(
    'stream errors release the lock and a late callback can still report',
    () async {
      final h = Harness();
      await h.service.purchase(h.product());
      h.service.handleStreamError();
      expect(h.service.isBusy, isFalse);
      await h.service.recover();
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
    },
  );
  test(
    'keeps selected yearly plan in memory, then reports and deduplicates',
    () async {
      final h = Harness();
      h.platform.onLaunch = () async {
        expect(h.store.records, isEmpty);
        expect(h.platform.product!.isYearly, isTrue);
      };
      await h.service.purchase(h.product(yearly: true));
      expect(h.platform.launches, 1);
      expect(h.platform.uuid, accountUuid);
      expect(h.reports, isEmpty);
      final event = h.purchase(yearly: true);
      expect(await h.service.interceptPurchase(event), isTrue);
      await h.service.interceptPurchase(event);
      expect(h.reports, hasLength(1));
      expect(h.reports.single.product.basePlanId, 'test-annual');
      expect(h.refreshes, 1);
      expect(h.service.isBusy, isFalse);
    },
  );
  test(
    'parallel taps only launch once and Gems purchase blocks VIP launch',
    () async {
      final h = Harness();
      final gate = Completer<void>();
      h.platform.onPrepare = () => gate.future;
      final first = h.service.purchase(h.product());
      await h.service.purchase(h.product(yearly: true));
      gate.complete();
      await first;
      expect(h.platform.launches, 1);
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.canceled),
      );
      h.gemsBusy = true;
      await h.service.purchase(h.product());
      expect(h.platform.launches, 1);
    },
  );
  test(
    'guest proof is cached after payment and guest report does not refresh account wallet',
    () async {
      final h = Harness()..uid = null;
      h.platform.onLaunch = () async {
        expect(h.store.records, isEmpty);
        expect(
          h.store.claims.values.single.guest.accountUuid,
          guest.accountUuid,
        );
        expect(h.store.claims.values.single.requiresLogin, isFalse);
        expect(h.store.claims.values.single.autoClaimAllowed, isFalse);
      };
      await h.service.purchase(h.product());
      expect(h.guestPrepares, 1);
      expect(h.platform.uuid, guest.accountUuid);
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports.single.guest?.accountUuid, guest.accountUuid);
      expect(h.refreshes, 0);
      expect(h.store.records, isEmpty);
      expect(
        h.store.confirmed.values.single.guest?.accountUuid,
        guest.accountUuid,
      );
    },
  );
  test(
    'guest identity persistence failure blocks launch without saving speculative orders',
    () async {
      final h = Harness()..uid = null;
      h.store.fail = true;
      await h.service.purchase(h.product());
      expect(h.platform.launches, 0);
      expect(h.store.records, isEmpty);
    },
  );
  test(
    'launch rejection and cancellation allow another attempt without reporting',
    () async {
      final h = Harness();
      h.platform.launchResult = false;
      await h.service.purchase(h.product());
      expect(h.service.isBusy, isFalse);
      h.platform.launchResult = true;
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.canceled),
      );
      await h.service.purchase(h.product());
      expect(h.platform.launches, 3);
      expect(h.reports, isEmpty);
    },
  );
  test(
    'Google cancellation without product id releases the active VIP purchase',
    () async {
      final h = Harness();
      await h.service.purchase(h.product());
      const canceled = BillingPurchase(
        provider: BillingProvider.googlePlay,
        productId: '',
        purchaseToken: '',
        transactionId: '',
        originalTransactionId: '',
        originalJson: '',
        purchaseTime: '',
        status: BillingPurchaseStatus.canceled,
      );
      expect(await h.service.interceptPurchase(canceled), isTrue);
      expect(h.service.isBusy, isFalse);
      expect(h.service.state.value, MembershipCheckoutState.canceled);
      expect(h.reports, isEmpty);
      expect(await h.service.interceptPurchase(canceled), isFalse);
    },
  );
  test('report failure is not saved or retried after restart', () async {
    final h = Harness();
    h.reportHandler = (_) async => throw StateError('offline');
    await h.service.purchase(h.product());
    await h.service.interceptPurchase(h.purchase());
    expect(h.service.state.value, MembershipCheckoutState.deferred);
    final restarted = Harness(storage: h.store);
    await restarted.service.recover();
    expect(restarted.reports, isEmpty);
    expect(h.store.records, isEmpty);
    expect(h.reports.single.toJson(), isNot(contains('request_id')));
  });
  test(
    'cleanup storage failure does not prevent report or cause a duplicate report',
    () async {
      final h = Harness();
      await h.service.purchase(h.product());
      h.store.fail = true;
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
      h.store.fail = false;
      await h.service.recover();
      expect(h.reports, hasLength(1));
    },
  );
  for (final provider in MembershipProvider.values) {
    for (final legacyFinished in [false, true]) {
      test(
        '$provider completed report survives restart with legacy finished=$legacyFinished',
        () async {
          final h = Harness(provider: provider);
          h.store.failComplete = true;
          await h.service.purchase(h.product());
          await h.service.interceptPurchase(h.purchase());
          expect(h.reports, hasLength(1));
          h.store.records['legacy-completed'] = MembershipPurchaseRecord(
            requestId: 'legacy-completed',
            product: h.product(),
            accountUuid: accountUuid,
            ownerUid: h.uid,
            purchaseToken: 'test-token',
            transactionId: '100',
            state: 'purchased',
            reportStatus: 'completed',
            finished: legacyFinished,
          );
          h.service.dispose();
          h.store.failComplete = false;
          final restarted = Harness(provider: provider, storage: h.store);
          await restarted.service.start();
          expect(restarted.reports, isEmpty);
          expect(restarted.platform.launches, 0);
          expect(restarted.store.records, isEmpty);
          expect(restarted.store.confirmed, isEmpty);
          expect(restarted.refreshes, 0);
        },
      );
    }
  }
  test(
    'accepted and rejected both end reporting without a durable queue',
    () async {
      for (final status in [
        MembershipReportStatus.accepted,
        MembershipReportStatus.rejected,
      ]) {
        final h = Harness();
        h.reportHandler = (_) async => MembershipPurchaseReport(status: status);
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        await h.service.recover();
        expect(h.reports, hasLength(1));
        expect(h.store.records.length, 0);
        expect(h.refreshes, 0);
      }
    },
  );
  test(
    'pending Apple payment is not completed or reported without a transaction',
    () async {
      final h = Harness(provider: MembershipProvider.apple);
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(
          status: BillingPurchaseStatus.pending,
          transaction: '',
          token: '',
        ),
      );
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
      expect(h.store.records, isEmpty);
      expect(h.service.state.value, MembershipCheckoutState.completed);
    },
  );
  test(
    'session changes during preparation cannot launch for the new user',
    () async {
      final h = Harness();
      h.platform.onPrepare = () async {
        h.uid = 'another-user';
      };
      await h.service.purchase(h.product());
      expect(h.platform.launches, 0);
    },
  );
  test(
    'account changes never trigger reports without another store callback',
    () async {
      final h = Harness();
      await h.service.purchase(h.product());
      h.uid = 'another-user';
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, isEmpty);
      h.uid = 'user-test';
      await h.service.recover();
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
    },
  );
  test(
    'unknown subscription never becomes a Gems purchase or guessed base plan',
    () async {
      final h = Harness();
      expect(await h.service.interceptPurchase(h.purchase()), isTrue);
      expect(h.reports, isEmpty);
      final gem = BillingPurchase(
        provider: BillingProvider.googlePlay,
        productId: 'gem-test',
        purchaseToken: 'gem-token',
        transactionId: '',
        originalTransactionId: '',
        originalJson: '',
        purchaseTime: '',
        status: BillingPurchaseStatus.purchased,
      );
      expect(await h.service.interceptPurchase(gem), isFalse);
    },
  );
  test(
    'new Google renewal using same token reports once per transaction',
    () async {
      final h = Harness();
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase(transaction: 'order-1'));
      await h.service.interceptPurchase(h.purchase(transaction: 'order-2'));
      expect(h.reports, hasLength(2));
      expect(h.reports.map((r) => r.transactionId), ['order-1', 'order-2']);
      expect(h.reports.last.toJson(), h.reports.first.toJson());
      await h.service.interceptPurchase(h.purchase(transaction: 'order-1'));
      await h.service.interceptPurchase(h.purchase(transaction: 'order-2'));
      expect(h.reports, hasLength(2));
      expect(h.store.records, isEmpty);
      expect(h.store.confirmed, isEmpty);
    },
  );
  test(
    'callback and foreground retry cannot double-report a receipt',
    () async {
      final h = Harness();
      final gate = Completer<MembershipPurchaseReport>();
      h.reportHandler = (_) => gate.future;
      await h.service.purchase(h.product());
      final callback = h.service.interceptPurchase(h.purchase());
      await pumpEventQueue();
      final recovery = h.service.recover();
      gate.complete(completed);
      await Future.wait([callback, recovery]);
      expect(h.reports, hasLength(1));
    },
  );
}

Future<void> _settleAnalytics() async {
  for (var index = 0; index < 8; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _RecordingAnalyticsClient implements AppAnalyticsClient {
  final List<_AnalyticsEvent> events = <_AnalyticsEvent>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_AnalyticsEvent(name, parameters ?? const <String, Object>{}));
  }
}

class _MemoryAnalyticsOnceEventStore
    implements FirebaseAnalyticsOnceEventStore {
  final Set<String> sentEvents = <String>{};

  @override
  Future<void> markSent(String eventName) async {
    sentEvents.add(eventName);
  }

  @override
  Future<bool> wasSent(String eventName) async {
    return sentEvents.contains(eventName);
  }
}

class _AnalyticsEvent {
  const _AnalyticsEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object> parameters;
}
