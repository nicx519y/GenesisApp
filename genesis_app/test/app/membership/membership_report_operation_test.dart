import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in MembershipProvider.values) {
    for (final status in [
      BillingPurchaseStatus.pending,
      BillingPurchaseStatus.restored,
      BillingPurchaseStatus.canceled,
      BillingPurchaseStatus.error,
    ]) {
      for (final guest in [false, true]) {
        test(
          '$provider $status guest=$guest never reports even with a receipt',
          () async {
            final h = support.Harness(provider: provider);
            if (guest) h.uid = null;
            const attemptId = 'checkout';
            await h.service.purchase(h.product(), attemptId: attemptId);
            await h.service.interceptPurchase(
              h.purchase(status: status, checkoutAttemptId: attemptId),
            );
            await h.service.interceptPurchase(h.purchase(status: status));
            await h.service.recover();
            expect(h.reports, isEmpty);
            expect(h.refreshes, 0);
            h.service.dispose();
          },
        );
      }
    }
    test('$provider pending then restored reports only on purchased', () async {
      final h = support.Harness(provider: provider);
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.pending),
      );
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.restored),
      );
      expect(h.reports, isEmpty);
      await h.service.interceptPurchase(h.purchase());
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
      expect(h.service.state.value, MembershipCheckoutState.completed);
      h.service.dispose();
    });
    for (final status in MembershipReportStatus.values) {
      test(
        '$provider $status ends report including duplicate callback and restart',
        () async {
          final events = <SubscriptionAnalyticsEvent>[];
          final h = support.Harness(
            provider: provider,
            analytics: SubscriptionAnalytics(sink: events.add),
          );
          final reply = Completer<MembershipPurchaseReport>();
          h.reportHandler = (_) => reply.future;
          await h.service.purchase(h.product());
          expect(h.platform.launches, 1);
          expect(h.reports, isEmpty);
          final callback = h.service.interceptPurchase(h.purchase());
          while (h.reports.isEmpty) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(h.service.state.value, MembershipCheckoutState.reporting);
          expect(events, isEmpty);
          reply.complete(MembershipPurchaseReport(status: status));
          await callback;
          expect(h.service.state.value.name, status.name);
          await h.service.interceptPurchase(h.purchase());
          h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await h.service.recover();
          expect(h.reports, hasLength(1));
          expect(h.store.records, isEmpty);
          expect(events.map((e) => e.action), [
            switch (status) {
              MembershipReportStatus.completed => 'subscription_success',
              MembershipReportStatus.accepted => 'subscription_pending',
              MembershipReportStatus.rejected => 'subscription_failed',
            },
          ]);
          h.service.dispose();
          final restarted = support.Harness(
            provider: provider,
            storage: h.store,
          );
          await restarted.service.start();
          await restarted.service.interceptPurchase(h.purchase());
          expect(restarted.reports, isEmpty);
        },
      );
    }

    final errors = <String, Object>{
      'timeout': TimeoutException('timeout'),
      'connection': ApiException(
        message: 'offline',
        kind: ApiExceptionKind.transport,
        transportErrorKind: TransportErrorKind.connection,
      ),
      'http503': ApiException(
        message: 'unavailable',
        kind: ApiExceptionKind.httpStatus,
        statusCode: 503,
      ),
      'business': ApiException(
        message: 'business',
        kind: ApiExceptionKind.business,
        code: 1403,
        retryable: true,
      ),
      'unknown status': const FormatException('unrecognized status'),
      'cancelled': ApiException(
        message: 'cancelled',
        kind: ApiExceptionKind.cancelled,
      ),
      'certificate': ApiException(
        message: 'certificate',
        kind: ApiExceptionKind.transport,
        transportErrorKind: TransportErrorKind.badCertificate,
      ),
    };
    for (final entry in errors.entries) {
      test(
        '$provider ${entry.key} fails after one request without any retry',
        () async {
          final events = <SubscriptionAnalyticsEvent>[];
          final h = support.Harness(
            provider: provider,
            analytics: SubscriptionAnalytics(sink: events.add),
          );
          h.reportHandler = (_) async => throw entry.value;
          await h.service.purchase(h.product());
          await h.service.interceptPurchase(h.purchase());
          expect(h.reports, hasLength(1));
          expect(h.service.state.value, MembershipCheckoutState.failed);
          expect(events, hasLength(1));
          expect(
            events.single.action,
            entry.key == 'timeout'
                ? 'subscription_timeout'
                : 'subscription_failed',
          );
          await h.service.interceptPurchase(h.purchase());
          h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await h.service.recover();
          expect(h.reports, hasLength(1));
          expect(h.store.records, isEmpty);
          h.service.dispose();
          final restarted = support.Harness(
            provider: provider,
            storage: h.store,
          );
          await restarted.service.start();
          await restarted.service.interceptPurchase(h.purchase());
          expect(restarted.reports, isEmpty);
        },
      );
    }
    test(
      '$provider never retries even if a second request would succeed',
      () async {
        final events = <SubscriptionAnalyticsEvent>[];
        final h = support.Harness(
          provider: provider,
          analytics: SubscriptionAnalytics(sink: events.add),
        );
        h.reportHandler = (_) async {
          if (h.reports.length == 1) throw TimeoutException('timeout');
          return support.completed;
        };
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        await h.service.interceptPurchase(h.purchase());
        h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await h.service.recover();
        expect(h.reports, hasLength(1));
        expect(events.single.action, 'subscription_timeout');
        expect(h.service.state.value, MembershipCheckoutState.failed);
        h.service.dispose();
      },
    );
    test('$provider session change does not retry report', () async {
      final h = support.Harness(provider: provider);
      h.reportHandler = (_) async {
        h.uid = 'other-user';
        h.service.resetForSession();
        throw TimeoutException('timeout');
      };
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(1));
    });
    test(
      '$provider guest failed report is not retried after restart',
      () async {
        final h = support.Harness(provider: provider)..uid = null;
        h.reportHandler = (_) async => throw TimeoutException('report timeout');
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        await h.service.interceptPurchase(h.purchase());
        await h.service.recover();
        expect(h.reports, hasLength(1));
        expect(h.service.state.value, MembershipCheckoutState.failed);
        h.service.dispose();
        final restarted = support.Harness(provider: provider, storage: h.store)
          ..uid = null;
        await restarted.service.start();
        await restarted.service.interceptPurchase(restarted.purchase());
        restarted.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await restarted.service.recover();
        expect(restarted.reports, isEmpty);
        restarted.service.dispose();
      },
    );
  }

  test(
    'Apple returning an already failed transaction does not retry report',
    () async {
      final h = support.Harness(provider: MembershipProvider.apple);
      h.reportHandler = (_) async => throw TimeoutException('report timeout');
      await h.service.purchase(h.product(), attemptId: 'first');
      await h.service.interceptPurchase(h.purchase(checkoutAttemptId: 'first'));
      await h.service.purchase(h.product(), attemptId: 'second');
      expect(h.platform.launches, 2);
      await h.service.interceptPurchase(
        h.purchase(checkoutAttemptId: 'second'),
      );
      expect(h.reports, hasLength(1));
      expect(h.service.state.value, MembershipCheckoutState.failed);
      expect(h.service.isBusy, isFalse);
      h.service.dispose();
    },
  );
}
