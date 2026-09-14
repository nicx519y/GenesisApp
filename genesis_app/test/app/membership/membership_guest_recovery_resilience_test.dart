import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_guest_purchase_check.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/membership_guest_claim_record.dart';
import 'package:genesis_flutter_android/platform/billing/membership_store_purchase.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'identity is durable before store launch and is not proof of payment',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      h.platform.onLaunch = () async {
        final saved = h.store.claims.values.single;
        expect(saved.guest.accountUuid, support.guest.accountUuid);
        expect(saved.requiresLogin, isFalse);
        expect(saved.autoClaimAllowed, isFalse);
        expect(saved.recoveredProof, isNull);
        expect(h.store.records, isEmpty);
        expect(h.store.confirmed, isEmpty);
      };
      await h.service.purchase(h.product());
      expect(h.platform.launches, 1);
      expect(h.service.guestLoginRequestId.value, isNull);
      h.service.dispose();
      final restarted = support.Harness(
        storage: h.store,
        guestRecoveryEnabled: true,
      )..uid = null;
      restarted.guestCheckHandler = (_) async =>
          const MembershipGuestPurchaseCheck(hasUnboundOrder: false);
      await restarted.service.checkGuestPurchasesOnHome();
      expect(restarted.guestChecks, isEmpty);
      expect(restarted.guestDiscoveries, 1);
      expect(restarted.service.guestLoginRequestId.value, isNull);
    },
  );

  test('identity storage failure prevents opening payment', () async {
    final h = support.Harness()..uid = null;
    h.store.failClaim = true;
    await h.service.purchase(h.product());
    expect(h.platform.launches, 0);
    expect(h.reports, isEmpty);
  });

  test(
    'unpaid cached identity is ignored in favor of a paid store order',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      h.store.claims[support.accountUuid] = const MembershipGuestClaimRecord(
        guest: MembershipGuestIdentity(accountUuid: support.accountUuid),
        autoClaimAllowed: false,
      );
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      h.guestCheckHandler = (uuid) async => MembershipGuestPurchaseCheck(
        hasUnboundOrder: uuid == support.guest.accountUuid,
      );
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.service.guestLoginRequestId.value, support.guest.accountUuid);
      expect(
        h
            .store
            .claims[support.guest.accountUuid]!
            .recoveredProof!
            .purchaseToken,
        'test-token',
      );
    },
  );

  test('paid cache is checked without querying an unavailable store', () async {
    final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
    h.store.claims[support.guest.accountUuid] =
        const MembershipGuestClaimRecord(
          guest: support.guest,
          purchaseConfirmed: true,
          autoClaimAllowed: false,
        );
    h.guestPurchasesHandler = () async => throw StateError('store unavailable');
    await h.service.checkGuestPurchasesOnHome();
    expect(h.guestChecks, [support.guest.accountUuid]);
    expect(h.service.guestLoginRequestId.value, support.guest.accountUuid);
  });

  testWidgets('missing UUID retries then recovers without another Home entry', (
    tester,
  ) async {
    final h = support.Harness(
      guestRecoveryEnabled: true,
      retryDelay: const Duration(seconds: 1),
    )..uid = null;
    h.guestPurchases = [
      MembershipStorePurchase(purchase: h.purchase(uuid: '')),
    ];
    await h.service.checkGuestPurchasesOnHome();
    expect(h.guestChecks, isEmpty);
    h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
    await tester.pump(const Duration(seconds: 1));
    expect(h.guestDiscoveries, 2);
    expect(h.guestChecks, [support.guest.accountUuid]);
    expect(h.service.guestLoginRequestId.value, isNotNull);
    h.service.dispose();
  });

  testWidgets('unresolved discovery stops after three retries', (tester) async {
    final h = support.Harness(
      guestRecoveryEnabled: true,
      retryDelay: const Duration(seconds: 1),
    )..uid = null;
    h.guestPurchases = [
      MembershipStorePurchase(purchase: h.purchase(uuid: '')),
    ];
    await h.service.checkGuestPurchasesOnHome();
    for (final seconds in [1, 2, 4, 60]) {
      await tester.pump(Duration(seconds: seconds));
    }
    expect(h.guestDiscoveries, 4);
    expect(h.guestChecks, isEmpty);
    expect(h.service.guestLoginRequestId.value, isNull);
    h.service.dispose();
  });

  testWidgets('check failure retries using the same UUID', (tester) async {
    final h = support.Harness(
      guestRecoveryEnabled: true,
      retryDelay: const Duration(seconds: 1),
    )..uid = null;
    h.store.claims[support.guest.accountUuid] =
        const MembershipGuestClaimRecord(
          guest: support.guest,
          purchaseConfirmed: true,
        );
    h.guestCheckHandler = (_) async => throw StateError('offline');
    await h.service.checkGuestPurchasesOnHome();
    expect(h.service.guestLoginRequestId.value, isNull);
    h.guestCheckHandler = (_) async =>
        const MembershipGuestPurchaseCheck(hasUnboundOrder: true);
    await tester.pump(const Duration(seconds: 1));
    expect(h.guestChecks, [
      support.guest.accountUuid,
      support.guest.accountUuid,
    ]);
    expect(h.service.guestLoginRequestId.value, isNotNull);
    h.service.dispose();
  });

  testWidgets('paid cache bypasses a hung store query', (tester) async {
    final h = support.Harness(
      guestRecoveryEnabled: true,
      guestRecoveryTimeout: const Duration(seconds: 1),
    )..uid = null;
    h.store.claims[support.guest.accountUuid] =
        const MembershipGuestClaimRecord(
          guest: support.guest,
          purchaseConfirmed: true,
        );
    final pending = Completer<List<MembershipStorePurchase>>();
    h.guestPurchasesHandler = () => pending.future;
    final check = h.service.checkGuestPurchasesOnHome();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await check;
    expect(h.guestChecks, [support.guest.accountUuid]);
    expect(h.guestDiscoveries, 0);
    expect(h.service.guestLoginRequestId.value, isNotNull);
    pending.complete([]);
    h.service.dispose();
  });

  test(
    'returning to foreground preserves a recent successful discovery',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      await h.service.checkGuestPurchasesOnHome();
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestDiscoveries, 1);
      expect(h.guestChecks, isEmpty);
      expect(h.service.guestLoginRequestId.value, isNull);
    },
  );

  test(
    'late store callback rechecks even without a local checkout record',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      await h.service.checkGuestPurchasesOnHome();
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      await h.service.interceptPurchase(h.purchase());
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.service.guestLoginRequestId.value, isNotNull);
      expect(h.reports, isEmpty);
      expect(h.store.records, isEmpty);
    },
  );

  test(
    'identity saved before process death gains proof then claims after login',
    () async {
      final first = support.Harness()..uid = null;
      await first.service.purchase(first.product());
      first.service.dispose();
      final h = support.Harness(
        storage: first.store,
        guestRecoveryEnabled: true,
        claimEnabled: true,
      )..uid = null;
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      await h.service.checkGuestPurchasesOnHome();
      expect(h.store.claims.values.single.recoveredProof, isNotNull);
      expect(h.service.guestLoginRequestId.value, isNotNull);
      h.uid = 'first-login';
      await h.service.recover();
      expect(h.claimRequests.single.purchaseToken, 'test-token');
      expect(h.store.claims, isEmpty);
      expect(h.store.confirmed, isEmpty);
      expect(h.reports, isEmpty);
      await h.service.recover();
      expect(h.claimRequests, hasLength(1));
    },
  );

  test('store proof recovery can continue after forced login', () async {
    final h = support.Harness(guestRecoveryEnabled: true, claimEnabled: true)
      ..uid = null;
    h.store.claims[support.guest.accountUuid] =
        const MembershipGuestClaimRecord(
          guest: support.guest,
          purchaseConfirmed: true,
          autoClaimAllowed: false,
        );
    h.guestPurchasesHandler = () async => throw StateError('store offline');
    await h.service.checkGuestPurchasesOnHome();
    expect(h.service.guestLoginRequestId.value, isNotNull);
    h.uid = 'first-login';
    h.guestPurchasesHandler = null;
    h.guestPurchases = [
      MembershipStorePurchase(
        purchase: h.purchase(uuid: support.guest.accountUuid),
      ),
    ];
    await h.service.recover();
    expect(h.claimRequests.single.guest.accountUuid, support.guest.accountUuid);
    expect(h.store.claims, isEmpty);
  });
  test(
    'late payment invalidates an in-flight empty discovery result',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      final firstResult = Completer<List<MembershipStorePurchase>>();
      h.guestPurchasesHandler = () => h.guestDiscoveries == 1
          ? firstResult.future
          : Future.value([MembershipStorePurchase(purchase: h.purchase())]);
      final firstCheck = h.service.checkGuestPurchasesOnHome();
      await pumpEventQueue();
      await h.service.interceptPurchase(h.purchase());
      firstResult.complete([]);
      await firstCheck;
      await pumpEventQueue();
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestDiscoveries, 2);
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.service.guestLoginRequestId.value, isNotNull);
    },
  );

  test(
    'missing Google account metadata uses only the exact cached token',
    () async {
      final first = support.Harness()..uid = null;
      await first.service.purchase(first.product());
      await first.service.interceptPurchase(first.purchase());
      first.service.dispose();
      final h = support.Harness(
        storage: first.store,
        guestRecoveryEnabled: true,
      )..uid = null;
      h.guestPurchases = [
        MembershipStorePurchase(purchase: h.purchase(uuid: '')),
      ];
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.service.guestLoginRequestId.value, isNotNull);
      expect(h.reports, isEmpty);
    },
  );

  test(
    'old bound UUID cache is removed during recovery without another claim',
    () async {
      final h = support.Harness(claimEnabled: true);
      h.store.claims[support.guest.accountUuid] =
          const MembershipGuestClaimRecord(
            guest: support.guest,
            ownerUid: 'user-test',
            status: 'completed',
            autoClaimAllowed: false,
          );
      await h.service.recover();
      expect(h.store.claims, isEmpty);
      expect(h.claimRequests, isEmpty);
    },
  );

  test(
    'claim cleanup removes terminal report residue after report cleanup failed',
    () async {
      final h = support.Harness(claimEnabled: true)..uid = null;
      await h.service.purchase(h.product());
      h.store.failComplete = true;
      await h.service.interceptPurchase(h.purchase());
      expect(h.store.records.values.single.reportStatus, 'completed');
      h.uid = 'first-login';
      await h.service.recover();
      expect(h.claimRequests, hasLength(1));
      expect(h.store.records, isEmpty);
      expect(h.store.confirmed, isEmpty);
      expect(h.store.claims, isEmpty);
      h.service.dispose();
      final restarted = support.Harness(storage: h.store, claimEnabled: true)
        ..uid = 'first-login';
      await restarted.service.recover();
      expect(restarted.claimRequests, isEmpty);
      expect(restarted.reports, isEmpty);
    },
  );
}
