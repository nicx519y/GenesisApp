import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final identity in ['matching', 'different', 'missing']) {
    test(
      'Apple $identity identity controls success but never prevents report',
      () async {
        final events = <SubscriptionAnalyticsEvent>[];
        final h = support.Harness(
          provider: MembershipProvider.apple,
          analytics: SubscriptionAnalytics(sink: events.add),
        );
        addTearDown(h.service.dispose);
        h.reportHandler = (_) async => const MembershipPurchaseReport(
          status: MembershipReportStatus.rejected,
          reason: 'account_mismatch',
        );
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(
          h.purchase(
            omitUuid: identity == 'missing',
            uuid: identity == 'different'
                ? '11111111-1111-4111-8111-111111111111'
                : null,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(h.reports, hasLength(1));
        expect(
          events.where((e) => e.action == 'subscription_success').length,
          identity == 'matching' ? 1 : 0,
        );
        expect(
          events.where((e) => e.action == 'subscription_failed').single.object3,
          'report_failed[reason=account_mismatch]',
        );
      },
    );
  }
  test('report timeout emits a report failure once', () async {
    final events = <SubscriptionAnalyticsEvent>[];
    final h = support.Harness(
      provider: MembershipProvider.apple,
      analytics: SubscriptionAnalytics(sink: events.add),
    );
    addTearDown(h.service.dispose);
    h.reportHandler = (_) async => throw TimeoutException('test');
    await h.service.purchase(h.product());
    final purchase = h.purchase();
    await h.service.interceptPurchase(purchase);
    await h.service.interceptPurchase(purchase);
    await Future<void>.delayed(Duration.zero);
    expect(
      events.where((e) => e.action == 'subscription_failed').single.object3,
      'report_failed[reason=timeout]',
    );
    expect(h.reports, hasLength(1));
  });
}
