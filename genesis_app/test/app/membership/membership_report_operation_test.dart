import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in MembershipProvider.values) {
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
      final retryable = [
        'timeout',
        'connection',
        'http503',
      ].contains(entry.key);
      test(
        '$provider ${entry.key} has bounded immediate retries without recovery',
        () async {
          final events = <SubscriptionAnalyticsEvent>[];
          final h = support.Harness(
            provider: provider,
            analytics: SubscriptionAnalytics(sink: events.add),
          );
          h.reportHandler = (_) async => throw entry.value;
          await h.service.purchase(h.product());
          await h.service.interceptPurchase(h.purchase());
          final expected = retryable ? 3 : 1;
          expect(h.reports, hasLength(expected));
          expect(h.reports.every((r) => identical(r, h.reports.first)), isTrue);
          expect(events, hasLength(1));
          expect(
            events.single.action,
            entry.key == 'timeout'
                ? 'subscription_timeout'
                : 'subscription_failed',
          );
          await h.service.interceptPurchase(h.purchase());
          await h.service.recover();
          expect(h.reports, hasLength(expected));
          expect(h.store.records, isEmpty);
          h.service.dispose();
          final restarted = support.Harness(
            provider: provider,
            storage: h.store,
          );
          await restarted.service.start();
          expect(restarted.reports, isEmpty);
        },
      );
    }
    test('$provider successful technical retry reports only success', () async {
      final events = <SubscriptionAnalyticsEvent>[];
      final h = support.Harness(
        provider: provider,
        analytics: SubscriptionAnalytics(sink: events.add),
      );
      h.reportHandler = (_) async {
        if (h.reports.length < 3) throw TimeoutException('timeout');
        return support.completed;
      };
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      expect(h.reports, hasLength(3));
      expect(events.single.action, 'subscription_success');
      expect(h.service.state.value, MembershipCheckoutState.completed);
    });
    test('$provider session change stops technical retry', () async {
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
  }
}
