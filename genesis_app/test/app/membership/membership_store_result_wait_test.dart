import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';

import 'membership_purchase_service_test.dart';

void main() {
  for (final isGuest in [true, false]) {
    for (final status in MembershipReportStatus.values) {
      testWidgets(
        'Apple direct UUID mismatch reaches server: guest=$isGuest result=$status',
        (tester) async {
          final h = Harness(provider: MembershipProvider.apple);
          if (isGuest) h.uid = null;
          final response = Completer<MembershipPurchaseReport>();
          h.reportHandler = (_) => response.future;
          final events = <MembershipCheckoutEvent>[];
          h.service.checkoutEvents.listen(events.add);
          await h.service.purchase(h.product(), attemptId: 'current');
          final storeResult = h.purchase(
            uuid: '00000000-0000-4000-8000-000000000002',
            transaction: 'direct-store-transaction',
            checkoutAttemptId: 'current',
          );
          final callback = h.service.interceptPurchase(storeResult);
          await tester.pump();
          expect(h.reports, hasLength(1));
          expect(h.reports.single.transactionId, 'direct-store-transaction');
          expect(h.reports.single.guest, isGuest ? guest : null);
          if (isGuest) {
            expect(
              h.reports.single.signedTransaction,
              storeResult.signedTransaction,
            );
          }
          expect(h.service.state.value, MembershipCheckoutState.reporting);
          await tester.pump(const Duration(seconds: 11));
          expect(h.service.state.value, MembershipCheckoutState.reporting);
          response.complete(MembershipPurchaseReport(status: status));
          await callback;
          await tester.pump();
          expect(events.last.attemptId, 'current');
          expect(events.last.state, switch (status) {
            MembershipReportStatus.completed =>
              MembershipCheckoutState.completed,
            MembershipReportStatus.accepted => MembershipCheckoutState.accepted,
            MembershipReportStatus.rejected => MembershipCheckoutState.rejected,
          });
          expect(h.platform.launches, 1);
          expect(h.reports, hasLength(1));
          expect(
            events.any(
              (event) =>
                  event.state == MembershipCheckoutState.deferred ||
                  event.state == MembershipCheckoutState.failed,
            ),
            isFalse,
          );
        },
      );
    }
  }

  for (final status in MembershipReportStatus.values) {
    for (final sameIdentity in [true, false]) {
      testWidgets(
        'Apple direct existing $status result ends only its checkout; same identity=$sameIdentity',
        (tester) async {
          final h = Harness(provider: MembershipProvider.apple)..uid = null;
          h.reportHandler = (_) async =>
              MembershipPurchaseReport(status: status);
          await h.service.purchase(h.product(), attemptId: 'original');
          await h.service.interceptPurchase(h.purchase());
          final currentGuest = MembershipGuestIdentity(
            accountUuid: sameIdentity
                ? guest.accountUuid
                : '00000000-0000-4000-8000-000000000002',
          );
          h.guestHandler = () async => currentGuest;
          final events = <MembershipCheckoutEvent>[];
          h.service.checkoutEvents.listen(events.add);
          await h.service.purchase(h.product(), attemptId: 'current');
          // A background redelivery of exactly the same transaction must not
          // close the user's still-open system payment flow.
          await h.service.interceptPurchase(h.purchase());
          await tester.pump();
          expect(h.service.isBusy, isTrue);
          expect(events.last.state, MembershipCheckoutState.store);
          await h.service.interceptPurchase(
            h.purchase(checkoutAttemptId: 'current'),
          );
          await tester.pump();
          expect(h.service.isBusy, isFalse);
          expect(events.last.attemptId, 'current');
          expect(events.last.state, switch (status) {
            MembershipReportStatus.completed =>
              MembershipCheckoutState.alreadyProcessed,
            MembershipReportStatus.accepted => MembershipCheckoutState.accepted,
            MembershipReportStatus.rejected => MembershipCheckoutState.rejected,
          });
          expect(h.reports, hasLength(1));
          expect(h.claimRequests, isEmpty);
          expect(h.platform.launches, 2);
          if (!sameIdentity) {
            expect(
              h.store.claims.containsKey(currentGuest.accountUuid),
              isFalse,
            );
          }
          await tester.pump(const Duration(seconds: 11));
          expect(
            events.any((e) => e.state == MembershipCheckoutState.deferred),
            isFalse,
          );
        },
      );
    }
  }

  testWidgets(
    'Apple existing result before launch returns does not arm a timer',
    (tester) async {
      final h = Harness(provider: MembershipProvider.apple);
      h.reportHandler = (_) async =>
          MembershipPurchaseReport(status: MembershipReportStatus.rejected);
      await h.service.purchase(h.product(), attemptId: 'original');
      await h.service.interceptPurchase(h.purchase());
      final result = Completer<void>();
      h.platform.onLaunch = () async {
        expectSync(h.platform.handoff!(), isTrue);
        await result.future;
      };
      final purchase = h.service.purchase(h.product(), attemptId: 'current');
      await tester.pump();
      await h.service.interceptPurchase(
        h.purchase(checkoutAttemptId: 'current'),
      );
      await tester.pump();
      expect(h.service.state.value, MembershipCheckoutState.rejected);
      expect(h.service.isBusy, isFalse);
      result.complete();
      await purchase;
      await tester.pump(const Duration(seconds: 11));
      expect(h.service.state.value, MembershipCheckoutState.rejected);
      expect(h.reports, hasLength(1));
    },
  );

  testWidgets('late Apple direct result cannot resolve a newer checkout', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple);
    await h.service.purchase(h.product(), attemptId: 'old');
    await tester.pump(const Duration(seconds: 10));
    await h.service.purchase(h.product(), attemptId: 'current');
    final events = <MembershipCheckoutEvent>[];
    h.service.checkoutEvents.listen(events.add);
    await h.service.interceptPurchase(h.purchase(checkoutAttemptId: 'old'));
    await tester.pump();
    expect(h.service.isBusy, isTrue);
    expect(events.where((event) => event.attemptId == 'current'), isEmpty);
    // The late purchase is still processed for its original attempt.
    expect(h.reports, hasLength(1));
    await h.service.interceptPurchase(
      h.purchase(transaction: 'new', checkoutAttemptId: 'current'),
    );
    expect(h.service.state.value, MembershipCheckoutState.completed);
    expect(h.reports, hasLength(2));
  });

  testWidgets('Apple returned result without a matching callback ends waiting', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple)..uid = null;
    final events = <MembershipCheckoutEvent>[];
    h.service.checkoutEvents.listen(events.add);
    await h.service.purchase(h.product(), attemptId: 'current');
    await tester.pump(const Duration(seconds: 9));
    expect(h.service.isBusy, isTrue);
    // A callback for another product does not resolve this purchase.
    await h.service.interceptPurchase(
      h.purchase(yearly: true, transaction: 'other-product-transaction'),
    );
    expect(h.reports, isEmpty);
    expect(h.service.isBusy, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(h.service.isBusy, isFalse);
    expect(events.last.state, MembershipCheckoutState.deferred);
    expect(events.last.attemptId, 'current');
    expect(events.last.debugInfo, contains('store_callback_missing'));
    expect(
      events.any((e) => e.state == MembershipCheckoutState.failed),
      isFalse,
    );
    expect(h.store.records, isEmpty);
    expect(h.store.claims.values.single.autoClaimAllowed, isFalse);
    expect(h.platform.launches, 1);
    // A valid late callback still uses the original guest identity and attempt.
    await h.service.interceptPurchase(h.purchase());
    expect(h.reports, hasLength(1));
    expect(h.reports.single.guest, guest);
    expect(h.store.confirmed.keys.single, 'current');
    expect(h.service.state.value, MembershipCheckoutState.completed);
    h.service.dispose();
  });

  testWidgets('Apple callback wait begins only after the store flow returns', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple);
    final result = Completer<void>();
    h.platform.onLaunch = () async {
      expectSync(h.platform.handoff!(), isTrue);
      await result.future;
    };
    final purchase = h.service.purchase(h.product());
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(h.service.isBusy, isTrue);
    expect(h.service.state.value, MembershipCheckoutState.store);
    result.complete();
    await tester.pump();
    await purchase;
    await tester.pump(const Duration(seconds: 9));
    expect(h.service.isBusy, isTrue);
    await h.service.interceptPurchase(h.purchase());
    await tester.pump(const Duration(seconds: 1));
    expect(h.service.state.value, MembershipCheckoutState.completed);
    expect(h.reports, hasLength(1));
    h.service.dispose();
  });

  testWidgets('matched Apple callback stops the wait while report is pending', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple);
    final response = Completer<MembershipPurchaseReport>();
    h.reportHandler = (_) => response.future;
    await h.service.purchase(h.product());
    await tester.pump(const Duration(seconds: 9));
    final callback = h.service.interceptPurchase(h.purchase());
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(h.service.state.value, MembershipCheckoutState.reporting);
    expect(h.reports, hasLength(1));
    response.complete(completed);
    await callback;
    expect(h.service.state.value, MembershipCheckoutState.completed);
    h.service.dispose();
  });

  testWidgets('callback before Apple return cannot arm a stale result timer', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple);
    final result = Completer<void>();
    h.platform.onLaunch = () async {
      expectSync(h.platform.handoff!(), isTrue);
      await result.future;
    };
    final purchase = h.service.purchase(h.product());
    await tester.pump();
    await h.service.interceptPurchase(h.purchase());
    result.complete();
    await tester.pump();
    await purchase;
    await tester.pump(const Duration(minutes: 1));
    expect(h.service.state.value, MembershipCheckoutState.completed);
    expect(h.reports, hasLength(1));
    h.service.dispose();
  });

  testWidgets('completed order result timer cannot close a newer Apple flow', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple);
    await h.service.purchase(h.product(), attemptId: 'old');
    await tester.pump(const Duration(seconds: 9));
    await h.service.interceptPurchase(h.purchase());
    final result = Completer<void>();
    h.platform.onLaunch = () async {
      expectSync(h.platform.handoff!(), isTrue);
      await result.future;
    };
    final purchase = h.service.purchase(
      h.product(yearly: true),
      attemptId: 'new',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(h.service.isBusy, isTrue);
    expect(h.service.state.value, MembershipCheckoutState.store);
    await h.service.interceptPurchase(h.purchase(yearly: true));
    result.complete();
    await tester.pump();
    await purchase;
    expect(h.reports, hasLength(2));
    h.service.dispose();
  });

  testWidgets('Google launch return does not start an Apple result deadline', (
    tester,
  ) async {
    final h = Harness();
    await h.service.purchase(h.product());
    await tester.pump(const Duration(minutes: 5));
    expect(h.service.isBusy, isTrue);
    expect(h.service.state.value, MembershipCheckoutState.store);
    await h.service.interceptPurchase(h.purchase());
    expect(h.service.state.value, MembershipCheckoutState.completed);
    h.service.dispose();
  });
}
