import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_eligibility.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';

import '../../support/membership_fixtures.dart';
import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final provider in MembershipProvider.values) {
    for (final scenario in [
      'active yearly',
      'expired status',
      'expired time',
      'active monthly',
      'unknown',
    ]) {
      test('$provider monthly checkout checks wallet: $scenario', () async {
        final h = support.Harness(provider: provider);
        final now = DateTime.utc(2040);
        final wallet = GemWalletStore(
          readUid: () async => h.uid,
          loadWallet: () async {
            if (scenario == 'unknown') throw StateError('offline');
            return GemWallet(
              balanceCent: 98765,
              membership: GemWalletMembership(
                status: scenario == 'expired status' ? 2 : 1,
                planCode: scenario == 'active monthly'
                    ? 'pro_monthly'
                    : 'pro_yearly',
                expiresAt: scenario == 'expired time'
                    ? now
                    : now.add(const Duration(days: 1)),
                autoRenew: false,
                blueGemsCent: 12300,
              ),
            );
          },
        );
        final access = MembershipAccessStore(
          wallet: wallet,
          readLoginUid: () async => h.uid,
          serverNow: () => now,
        );
        h.access = await access.refresh();
        final events = <MembershipCheckoutEvent>[];
        final sub = h.service.checkoutEvents.listen(events.add);
        await h.service.purchase(h.product());
        await pumpEventQueue();
        final blocked = scenario == 'active yearly';
        expect(h.platform.launches, blocked ? 0 : 1);
        expect(h.platform.product == null, blocked);
        expect(h.guestPrepares, 0);
        expect(h.refreshes, 0);
        if (blocked) {
          expect(events.last.reason, 'downgrade_not_allowed');
          expect(
            membershipPurchaseFailureMessage(events.last.reason!),
            contains(
              'An active yearly Premium subscription cannot be changed to a monthly plan.',
            ),
          );
        }
        await sub.cancel();
        h.service.dispose();
        access.dispose();
        wallet.dispose();
      });
    }
    test(
      '$provider yearly purchase skips wallet eligibility entirely',
      () async {
        final h = support.Harness(provider: provider);
        addTearDown(h.service.dispose);
        h.membershipAccessHandler = () async =>
            throw StateError('must not query wallet');
        await h.service.purchase(h.product(yearly: true));
        expect(h.platform.launches, 1);
      },
    );
  }

  test(
    'another account annual wallet cannot block the current account',
    () async {
      final h = support.Harness();
      addTearDown(h.service.dispose);
      h.access = membershipAccessSnapshot(
        ownerUid: 'previous-user',
        planCode: 'pro_yearly',
      );
      await h.service.purchase(h.product());
      expect(h.platform.launches, 1);
    },
  );

  test(
    'a session switch while waiting for wallet cannot launch payment',
    () async {
      final h = support.Harness();
      addTearDown(h.service.dispose);
      final gate = Completer<MembershipAccessState>();
      h.membershipAccessHandler = () => gate.future;
      final purchase = h.service.purchase(h.product());
      await pumpEventQueue();
      h.uid = 'another-user';
      gate.complete(const MembershipAccessState());
      await purchase;
      expect(h.platform.launches, 0);
      expect(h.platform.product, isNull);
    },
  );

  test(
    'waiting for the platform blocks double taps without a wallet request',
    () async {
      final h = support.Harness();
      final handoff = Completer<void>();
      h.platform.onLaunch = () => handoff.future;
      final first = h.service.purchase(h.product());
      await pumpEventQueue();
      await h.service.purchase(h.product());
      expect(h.refreshes, 0);
      expect(h.platform.launches, 1);
      handoff.complete();
      await first;
      expect(h.platform.launches, 1);
    },
  );

  for (final provider in MembershipProvider.values) {
    for (final guest in [false, true]) {
      for (final yearly in [false, true]) {
        test(
          '$provider guest=$guest yearly=$yearly delegates payment without a wallet request',
          () async {
            final h = support.Harness(provider: provider);
            if (guest) h.uid = null;
            final events = <MembershipCheckoutEvent>[];
            final subscription = h.service.checkoutEvents.listen(events.add);
            await h.service.purchase(h.product(yearly: yearly));
            await pumpEventQueue();
            expect(h.eligibilityQueries, 2);
            expect(h.refreshes, 0);
            expect(h.platform.launches, 1);
            expect(h.platform.product?.isYearly, yearly);
            expect(h.guestPrepares, guest ? 1 : 0);
            expect(events.last.state, MembershipCheckoutState.store);
            expect(events.last.reason, isNull);
            expect(h.reports, isEmpty);
            await subscription.cancel();
            h.service.dispose();
          },
        );
      }
    }
  }

  for (final provider in MembershipProvider.values) {
    for (final guest in [false, true]) {
      test(
        '$provider guest=$guest ignores action during checkout and report',
        () async {
          for (final action in ['upgrade', 'none']) {
            final h = support.Harness(provider: provider);
            if (guest) h.uid = null;
            h.productsHandler = () async => [
              MembershipProduct.fromJson({
                ...h.product(yearly: true).toJson(),
                'purchase_action': action,
              }),
            ];
            await h.service.purchase(h.product(yearly: true));
            expect(h.eligibilityQueries, 2);
            expect(h.platform.product?.isYearly, isTrue);
            expect(h.platform.launches, 1);
            expect(h.guestPrepares, guest ? 1 : 0);
            expect(h.reports, isEmpty);

            await h.service.interceptPurchase(h.purchase(yearly: true));
            expect(h.reports, hasLength(1));
            expect(h.reports.single.product.isYearly, isTrue);
            expect(h.reports.single.guest != null, guest);
            expect(
              h.reports.single.toJson(),
              isNot(contains('purchase_action')),
            );
          }
        },
      );
    }
  }

  test(
    'unavailable or changed eligibility cannot launch using cached product data',
    () async {
      for (final failure in ['offline', 'missing', 'changed_offer']) {
        final h = support.Harness();
        h.productsHandler = () async {
          if (failure == 'offline') throw StateError('offline');
          return failure == 'missing'
              ? []
              : [membershipProduct(offerId: 'different-offer')];
        };
        final event = h.service.checkoutEvents.firstWhere(
          (e) => e.state == MembershipCheckoutState.failed,
        );
        await h.service.purchase(h.product());
        expect((await event).reason, 'eligibility_unavailable');
        expect(h.platform.product, isNull);
        expect(h.platform.launches, 0);
      }
    },
  );

  test(
    'session switch while checking eligibility cannot prepare a store purchase',
    () async {
      final h = support.Harness();
      final gate = Completer<List<MembershipProduct>>();
      h.productsHandler = () => gate.future;
      final task = h.service.purchase(h.product());
      await pumpEventQueue();
      h.uid = 'another-user';
      gate.complete([h.product()]);
      await task;
      expect(h.platform.product, isNull);
      expect(h.platform.launches, 0);
    },
  );

  for (final provider in MembershipProvider.values) {
    for (final outcome in ['offline', 'timeout', 'accepted']) {
      testWidgets(
        '$provider ends $outcome report without background retry or repurchase',
        (tester) async {
          final h = support.Harness(
            provider: provider,
            retryDelay: const Duration(seconds: 15),
          );
          h.reportHandler = (_) async {
            if (h.reports.length > 1) return support.completed;
            if (outcome == 'offline') throw StateError('offline');
            if (outcome == 'timeout') throw TimeoutException('report timeout');
            return const MembershipPurchaseReport(
              status: MembershipReportStatus.accepted,
            );
          };
          await h.service.purchase(h.product());
          expect(h.platform.launches, 1);
          expect(h.reports, isEmpty);
          await h.service.interceptPurchase(h.purchase());
          final requests = outcome == 'timeout' ? 2 : 1;
          expect(h.reports, hasLength(requests));
          expect(h.store.records, isEmpty);
          expect(h.service.isBusy, isFalse);

          await tester.pump(const Duration(seconds: 15));
          expect(h.reports, hasLength(requests));
          expect(h.reports.last.toJson(), h.reports.first.toJson());
          expect(h.platform.launches, 1);
          expect(h.store.records, isEmpty);
          expect(h.refreshes, outcome == 'timeout' ? 1 : 0);
          expect(
            h.service.state.value,
            outcome == 'timeout'
                ? MembershipCheckoutState.completed
                : outcome == 'accepted'
                ? MembershipCheckoutState.accepted
                : MembershipCheckoutState.deferred,
          );
          await h.service.recover();
          expect(h.reports, hasLength(requests));
        },
      );
    }
  }

  for (final status in ['accepted', 'offline', 'pending']) {
    test(
      '$status report is not recovered and does not block another plan',
      () async {
        final h = support.Harness();
        h.reportHandler = (_) async {
          if (status == 'offline') throw StateError('offline');
          return const MembershipPurchaseReport(
            status: MembershipReportStatus.accepted,
          );
        };
        await h.service.purchase(h.product(yearly: true));
        await h.service.interceptPurchase(
          h.purchase(
            yearly: true,
            status: status == 'pending'
                ? BillingPurchaseStatus.pending
                : BillingPurchaseStatus.purchased,
          ),
        );
        final restarted = support.Harness(storage: h.store);
        await restarted.service.purchase(restarted.product());
        expect(restarted.eligibilityQueries, 2);
        expect(restarted.platform.launches, 1);
        expect(h.store.records, isEmpty);
        expect(h.store.confirmed, isEmpty);
      },
    );
  }

  test(
    'confirmed historical order does not block an expired member allowed by server',
    () async {
      final h = support.Harness();
      await h.service.purchase(h.product(yearly: true));
      await h.service.interceptPurchase(h.purchase(yearly: true));
      expect(h.store.confirmed, isEmpty);
      // A later server response allows new purchase after the old plan expired.
      await h.service.purchase(h.product());
      expect(h.platform.launches, 2);
      expect(h.eligibilityQueries, 4);
    },
  );

  test(
    'accepted pending payment never becomes completed through recovery',
    () async {
      final h = support.Harness(provider: MembershipProvider.apple);
      h.reportHandler = (_) async => const MembershipPurchaseReport(
        status: MembershipReportStatus.accepted,
      );
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.pending),
      );
      expect(h.store.records, isEmpty);
      expect(h.service.catalogRevision.value, 1);
      h.reportHandler = null;
      await h.service.recover();
      expect(h.reports.last.toJson(), h.reports.first.toJson());
      expect(h.service.state.value, MembershipCheckoutState.accepted);
      expect(h.store.records, isEmpty);
      expect(h.store.confirmed, isEmpty);
      expect(h.service.catalogRevision.value, 1);
      expect(h.reports, hasLength(1));
    },
  );

  test(
    'status-only rejected pending payment is terminal without granting entitlement',
    () async {
      final h = support.Harness(provider: MembershipProvider.apple);
      h.reportHandler = (_) async => const MembershipPurchaseReport(
        status: MembershipReportStatus.rejected,
      );
      final rejected = h.service.checkoutEvents.firstWhere(
        (e) => e.state == MembershipCheckoutState.rejected,
      );
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.pending),
      );
      expect((await rejected).reason, isNull);
      await h.service.recover();
      expect(h.reports, hasLength(1));
      expect(h.store.records, isEmpty);
      expect(h.store.confirmed, isEmpty);
      expect(h.refreshes, 0);
      expect(h.service.catalogRevision.value, 1);
    },
  );

  test(
    'status-only rejection cleans retry work without granting entitlement',
    () async {
      final h = support.Harness(provider: MembershipProvider.apple);
      h.reportHandler = (_) async => const MembershipPurchaseReport(
        status: MembershipReportStatus.rejected,
      );
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      await h.service.recover();
      expect(h.reports, hasLength(1));
      expect(h.store.records, isEmpty);
      expect(h.store.completedRecords, isEmpty);
      expect(h.refreshes, 0);
      expect(h.service.state.value, MembershipCheckoutState.rejected);
      expect(h.service.isBusy, isFalse);
      await h.service.interceptPurchase(h.purchase());
      await h.service.recover();
      expect(h.reports, hasLength(1));
    },
  );
}
