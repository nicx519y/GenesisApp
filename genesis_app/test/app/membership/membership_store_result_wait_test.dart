import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import 'membership_purchase_service_test.dart';

void main() {
  for (final isGuest in [false, true]) {
    for (final selectedYearly in [false, true]) {
      for (final status in MembershipReportStatus.values) {
        testWidgets(
          'Apple reports its returned product without waiting: guest=$isGuest selectedYearly=$selectedYearly result=$status',
          (tester) async {
            final h = Harness(provider: MembershipProvider.apple);
            if (isGuest) h.uid = null;
            addTearDown(h.service.dispose);
            final response = Completer<MembershipPurchaseReport>();
            h.reportHandler = (_) => response.future;
            final events = <MembershipCheckoutEvent>[];
            h.service.checkoutEvents.listen(events.add);
            await h.service.purchase(
              h.product(yearly: selectedYearly),
              attemptId: 'current',
            );
            final returned = h.purchase(yearly: !selectedYearly);
            final callback = h.service.interceptPurchase(returned);
            await tester.pump();
            expect(h.reports.single.product.storeProductId, returned.productId);
            expect(h.reports.single.transactionId, returned.transactionId);
            expect(
              h.reports.single.toJson()['store_product_id'],
              returned.productId,
            );
            expect(events.last.state, MembershipCheckoutState.reporting);
            if (isGuest) {
              expect(
                h.reports.single.signedTransaction,
                returned.signedTransaction,
              );
              final stored = h.store.confirmed['current']!;
              expect(stored.product.storeProductId, returned.productId);
              expect(stored.priceAmountMicros, isNull);
              expect(stored.priceCurrencyCode, isEmpty);
            }
            response.complete(MembershipPurchaseReport(status: status));
            await callback;
            await tester.pump();
            expect(events.last.attemptId, 'current');
            expect(events.last.state.name, status.name);
            expect(h.service.isBusy, isFalse);
            await tester.pump(const Duration(seconds: 11));
            expect(
              events.any((e) => e.state == MembershipCheckoutState.deferred),
              isFalse,
            );
            await h.service.interceptPurchase(returned);
            expect(h.reports, hasLength(1));
          },
        );
      }
    }
  }

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
        'Apple reports the current callback regardless of previous $status; same identity=$sameIdentity',
        (tester) async {
          final h = Harness(provider: MembershipProvider.apple)..uid = null;
          h.reportHandler = (_) async =>
              MembershipPurchaseReport(status: status);
          await h.service.purchase(h.product(), attemptId: 'original');
          await h.service.interceptPurchase(h.purchase());
          final nextStatus = switch (status) {
            MembershipReportStatus.completed => MembershipReportStatus.rejected,
            MembershipReportStatus.accepted => MembershipReportStatus.completed,
            MembershipReportStatus.rejected => MembershipReportStatus.accepted,
          };
          final response = Completer<MembershipPurchaseReport>();
          h.reportHandler = (_) => response.future;
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
          await h.service.interceptPurchase(h.purchase(directResult: false));
          await tester.pump();
          expect(h.service.isBusy, isTrue);
          expect(events.last.state, MembershipCheckoutState.store);
          expect(h.reports, hasLength(1));
          final storeResult = h.purchase(checkoutAttemptId: 'current');
          final callback = h.service.interceptPurchase(storeResult);
          await tester.pump();
          expect(h.reports, hasLength(2));
          expect(h.reports.last.transactionId, storeResult.transactionId);
          expect(
            h.reports.last.signedTransaction,
            storeResult.signedTransaction,
          );
          expect(h.reports.last.guest, currentGuest);
          expect(events.last.state, MembershipCheckoutState.reporting);
          await tester.pump(const Duration(seconds: 11));
          expect(events.last.state, MembershipCheckoutState.reporting);
          response.complete(MembershipPurchaseReport(status: nextStatus));
          await callback;
          await tester.pump();
          expect(h.service.isBusy, isFalse);
          expect(events.last.attemptId, 'current');
          expect(events.last.state, switch (nextStatus) {
            MembershipReportStatus.completed =>
              MembershipCheckoutState.completed,
            MembershipReportStatus.accepted => MembershipCheckoutState.accepted,
            MembershipReportStatus.rejected => MembershipCheckoutState.rejected,
          });
          await h.service.interceptPurchase(storeResult);
          await h.service.interceptPurchase(h.purchase(directResult: false));
          await h.service.recover();
          expect(h.reports, hasLength(2));
          expect(h.claimRequests, isEmpty);
          expect(h.platform.launches, 2);
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
      h.reportHandler = (_) async =>
          MembershipPurchaseReport(status: MembershipReportStatus.completed);
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
      expect(h.service.state.value, MembershipCheckoutState.completed);
      expect(h.service.isBusy, isFalse);
      result.complete();
      await purchase;
      await tester.pump(const Duration(seconds: 11));
      expect(h.service.state.value, MembershipCheckoutState.completed);
      expect(h.reports, hasLength(2));
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

  testWidgets(
    'Apple background transaction cannot take over an open checkout',
    (tester) async {
      final h = Harness(provider: MembershipProvider.apple);
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product(), attemptId: 'current');
      await h.service.interceptPurchase(
        h.purchase(transaction: 'background', directResult: false),
      );
      expect(h.reports, isEmpty);
      expect(h.service.isBusy, isTrue);
      await h.service.interceptPurchase(
        h.purchase(transaction: 'direct', checkoutAttemptId: 'current'),
      );
      expect(h.reports.single.transactionId, 'direct');
      // Attempt identity alone deduplicates a repeated result. It does not need
      // to compare the returned transaction ID with a stored receipt.
      await h.service.interceptPurchase(
        h.purchase(transaction: 'another', checkoutAttemptId: 'current'),
      );
      expect(h.reports, hasLength(1));
    },
  );

  testWidgets(
    'Apple pending checkout reports its later successful store update',
    (tester) async {
      final h = Harness(provider: MembershipProvider.apple);
      addTearDown(h.service.dispose);
      await h.service.purchase(h.product(), attemptId: 'current');
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.pending, transaction: ''),
      );
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(
        h.purchase(transaction: 'approved', directResult: false),
      );
      expect(h.reports.single.transactionId, 'approved');
      expect(h.service.state.value, MembershipCheckoutState.completed);
      await h.service.interceptPurchase(
        h.purchase(transaction: 'approved', directResult: false),
      );
      expect(h.reports, hasLength(1));
    },
  );

  testWidgets(
    'Apple claim proof from a previous run never blocks a new report',
    (tester) async {
      final original = Harness(provider: MembershipProvider.apple)..uid = null;
      await original.service.purchase(
        original.product(),
        attemptId: 'original',
      );
      await original.service.interceptPurchase(original.purchase());
      original.service.dispose();
      final h = Harness(
        provider: MembershipProvider.apple,
        storage: original.store,
      )..uid = null;
      addTearDown(h.service.dispose);
      await h.service.start();
      expect(h.reports, isEmpty);
      await h.service.purchase(h.product(), attemptId: 'current');
      final callback = h.purchase();
      await h.service.interceptPurchase(callback);
      expect(h.reports.single.transactionId, callback.transactionId);
      expect(h.reports.single.signedTransaction, callback.signedTransaction);
      expect(h.service.state.value, MembershipCheckoutState.completed);
    },
  );

  testWidgets('Apple returned result without a matching callback ends waiting', (
    tester,
  ) async {
    final h = Harness(provider: MembershipProvider.apple)..uid = null;
    final events = <MembershipCheckoutEvent>[];
    h.service.checkoutEvents.listen(events.add);
    await h.service.purchase(h.product(), attemptId: 'current');
    await tester.pump(const Duration(seconds: 9));
    expect(h.service.isBusy, isTrue);
    // An unrelated background callback must not resolve this purchase.
    await h.service.interceptPurchase(
      h.purchase(
        yearly: true,
        transaction: 'other-product-transaction',
        directResult: false,
      ),
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
