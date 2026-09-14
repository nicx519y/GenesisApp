import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_guest_purchase_check.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/membership_guest_claim_record.dart';
import 'package:genesis_flutter_android/platform/billing/membership_store_purchase.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy prepare-only UUIDs never trigger check', () async {
    final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
    for (var i = 0; i < 6; i++) {
      final uuid = '${i}b74ec68-7abc-4cce-a223-e997e31dc811';
      h.store.claims[uuid] = MembershipGuestClaimRecord(
        guest: MembershipGuestIdentity(accountUuid: uuid),
        autoClaimAllowed: false,
      );
    }
    await h.service.checkGuestPurchasesOnHome();
    expect(h.guestChecks, isEmpty);
    expect(h.guestDiscoveries, 1);
    expect(h.service.guestLoginRequestId.value, isNull);
  });

  for (final provider in MembershipProvider.values) {
    test(
      '$provider paid cache takes precedence over other store UUIDs',
      () async {
        final h = support.Harness(
          provider: provider,
          guestRecoveryEnabled: true,
        )..uid = null;
        h.store.claims[support.guest.accountUuid] =
            const MembershipGuestClaimRecord(
              guest: support.guest,
              purchaseConfirmed: true,
              purchasedAt: 2000,
            );
        h.store.claims[support.accountUuid] = const MembershipGuestClaimRecord(
          guest: MembershipGuestIdentity(accountUuid: support.accountUuid),
          purchaseConfirmed: true,
          purchasedAt: 1000,
        );
        h.guestPurchases = [
          MembershipStorePurchase(
            purchase: h.purchase(uuid: support.accountUuid),
          ),
        ];
        await h.service.checkGuestPurchasesOnHome();
        expect(h.guestDiscoveries, 0);
        expect(h.guestChecks, [support.guest.accountUuid]);
        expect(h.store.claims[support.accountUuid]!.autoClaimAllowed, isFalse);
        expect(h.store.claims, hasLength(2));
      },
    );

    test(
      '$provider uncached recovery selects only latest active paid order',
      () async {
        final h = support.Harness(
          provider: provider,
          guestRecoveryEnabled: true,
          claimEnabled: true,
        )..uid = null;
        final latest = h.purchase(
          yearly: true,
          token: 'latest',
          transaction: '200',
          purchaseTime: '2000',
        );
        h.guestPurchases = [
          MembershipStorePurchase(
            purchase: h.purchase(
              uuid: support.accountUuid,
              purchaseTime: '1000',
            ),
          ),
          MembershipStorePurchase(purchase: latest),
          MembershipStorePurchase(purchase: latest),
          MembershipStorePurchase(
            purchase: h.purchase(
              token: 'pending',
              transaction: '300',
              purchaseTime: '3000',
              status: BillingPurchaseStatus.pending,
            ),
          ),
          MembershipStorePurchase(
            purchase: h.purchase(
              token: 'expired',
              transaction: '400',
              purchaseTime: '4000',
            ),
            expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ];
        await h.service.checkGuestPurchasesOnHome();
        expect(h.guestChecks, [support.guest.accountUuid]);
        expect(h.store.claims, hasLength(1));
        expect(h.store.claims.values.single.purchasedAt, 2000);
        h.uid = 'first-login';
        await h.service.recover();
        final claim = h.claimRequests.single;
        expect(
          provider == MembershipProvider.google
              ? claim.purchaseToken
              : claim.transactionId,
          provider == MembershipProvider.google ? 'latest' : '200',
        );
        expect(h.reports, isEmpty);
      },
    );

    for (final launchRejected in [false, true]) {
      test(
        '$provider definite cancellation/rejection=$launchRejected removes only temporary identity',
        () async {
          final h = support.Harness(
            provider: provider,
            guestRecoveryEnabled: true,
          )..uid = null;
          h.platform.launchResult = !launchRejected;
          await h.service.purchase(h.product());
          if (!launchRejected) {
            expect(h.store.claims.values.single.hasPurchase, isFalse);
            await h.service.interceptPurchase(
              h.purchase(
                status: BillingPurchaseStatus.canceled,
                token: '',
                transaction: '',
              ),
            );
          }
          expect(h.store.claims, isEmpty);
          expect(h.store.confirmed, isEmpty);
          expect(h.reports, isEmpty);
          h.service.dispose();
          final restarted = support.Harness(
            provider: provider,
            storage: h.store,
            guestRecoveryEnabled: true,
          )..uid = null;
          await restarted.service.checkGuestPurchasesOnHome();
          expect(restarted.guestChecks, isEmpty);
        },
      );
    }

    test(
      '$provider canceling a later checkout keeps the prior paid identity',
      () async {
        final first = support.Harness(provider: provider)..uid = null;
        await first.service.purchase(first.product());
        await first.service.interceptPurchase(
          first.purchase(purchaseTime: '1000'),
        );
        final previous = first.store.claims.values.single;
        first.service.dispose();
        final h = support.Harness(provider: provider, storage: first.store)
          ..uid = null;
        await h.service.purchase(h.product(yearly: true));
        expect(h.platform.launches, 1);
        await h.service.interceptPurchase(
          h.purchase(
            yearly: true,
            token: '',
            transaction: '',
            status: BillingPurchaseStatus.canceled,
          ),
        );
        expect(
          h.store.claims.values.single.purchaseRequestId,
          previous.purchaseRequestId,
        );
        expect(h.store.claims.values.single.purchaseConfirmed, isTrue);
        expect(h.store.confirmed.values.single.purchaseToken, 'test-token');
        expect(h.reports, isEmpty);
      },
    );
  }

  testWidgets(
    'check=false is final for the current snapshot, including duplicate callbacks and resumes',
    (tester) async {
      final h = support.Harness(
        guestRecoveryEnabled: true,
        retryDelay: const Duration(seconds: 1),
      )..uid = null;
      h.guestPurchases = [MembershipStorePurchase(purchase: h.purchase())];
      h.guestCheckHandler = (_) async =>
          const MembershipGuestPurchaseCheck(hasUnboundOrder: false);
      await h.service.checkGuestPurchasesOnHome();
      for (var i = 0; i < 5; i++) {
        h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await h.service.interceptPurchase(h.purchase());
        await h.service.checkGuestPurchasesOnHome();
        await tester.pump(const Duration(seconds: 1));
      }
      expect(h.guestDiscoveries, 1);
      expect(h.guestChecks, [support.guest.accountUuid]);
      expect(h.service.guestLoginRequestId.value, isNull);
      h.service.dispose();
    },
  );

  test(
    'old history callbacks do not recheck the selected latest order',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      final old = h.purchase(uuid: support.accountUuid, purchaseTime: '1000');
      h.guestPurchases = [
        MembershipStorePurchase(purchase: old),
        MembershipStorePurchase(
          purchase: h.purchase(
            token: 'latest',
            transaction: '200',
            purchaseTime: '2000',
          ),
        ),
      ];
      h.guestCheckHandler = (_) async =>
          const MembershipGuestPurchaseCheck(hasUnboundOrder: false);
      await h.service.checkGuestPurchasesOnHome();
      await h.service.interceptPurchase(old);
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestDiscoveries, 1);
      expect(h.guestChecks, [support.guest.accountUuid]);
    },
  );

  testWidgets('resumes cannot restart or bypass failed-check backoff', (
    tester,
  ) async {
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
    for (final seconds in [1, 2, 4]) {
      final count = h.guestChecks.length;
      h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, hasLength(count));
      await tester.pump(Duration(seconds: seconds));
      expect(h.guestChecks, hasLength(count + 1));
    }
    h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await h.service.checkGuestPurchasesOnHome();
    await tester.pump(const Duration(seconds: 60));
    expect(h.guestChecks, hasLength(4));
    expect(h.guestDiscoveries, 0);
    expect(h.store.claims, hasLength(1));
    h.service.dispose();
  });

  test(
    'unknown store errors preserve identity without triggering check',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      h.platform.onLaunch = () async => throw StateError('connection lost');
      await h.service.purchase(h.product());
      expect(h.store.claims.values.single.hasPurchase, isFalse);
      await h.service.checkGuestPurchasesOnHome();
      expect(h.guestChecks, isEmpty);
      expect(h.store.claims, hasLength(1));
    },
  );

  test(
    'pending payment preserves temporary identity until a paid callback',
    () async {
      final h = support.Harness(guestRecoveryEnabled: true)..uid = null;
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(
          status: BillingPurchaseStatus.pending,
          token: '',
          transaction: '',
        ),
      );
      expect(h.store.claims.values.single.hasPurchase, isFalse);
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(h.purchase());
      expect(h.store.claims.values.single.hasPurchase, isTrue);
      expect(h.reports, hasLength(1));
    },
  );

  testWidgets('failed temporary identity cleanup is retried safely', (
    tester,
  ) async {
    final h = support.Harness(retryDelay: const Duration(seconds: 1))
      ..uid = null;
    await h.service.purchase(h.product());
    h.store.failClaimCleanup = true;
    await h.service.interceptPurchase(
      h.purchase(
        status: BillingPurchaseStatus.canceled,
        token: '',
        transaction: '',
      ),
    );
    expect(h.store.claims, hasLength(1));
    h.store.failClaimCleanup = false;
    await tester.pump(const Duration(seconds: 1));
    expect(h.store.claims, isEmpty);
    expect(h.reports, isEmpty);
    h.service.dispose();
  });
}
