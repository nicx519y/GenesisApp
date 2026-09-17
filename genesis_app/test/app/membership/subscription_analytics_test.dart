import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/app/membership/subscription_failure_reason.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/platform/billing/billing_models.dart';
import 'package:genesis_flutter_android/platform/billing/membership_pending_store.dart';
import 'package:genesis_flutter_android/platform/billing/membership_guest_claim_record.dart';

import 'membership_purchase_service_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<SubscriptionAnalyticsEvent> events;
  late SubscriptionAnalytics analytics;
  const tracking = SubscriptionTracking(
    id: 'track_id_page_click',
    source: SubscriptionSource.meMembership,
  );
  setUp(() {
    events = [];
    analytics = SubscriptionAnalytics(sink: events.add);
  });

  test(
    'only seven events and exact document projection; page and click IDs',
    () {
      analytics.pageShow(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
      );
      analytics.pageShow(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
      );
      final first = analytics.click(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
        isYearly: true,
      );
      final second = analytics.click(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
        isYearly: false,
      );
      expect(first.id, startsWith('track_id_page_'));
      expect(first.id, isNot(second.id));
      expect(events.first.action, 'subscription_page_show');
      expect(events.first.object1, 'subscription_sheet');
      expect(events.first.object2, 'track_id_page');
      expect(events.first.object3, 'from_daily_check_in');
      expect(events[1].action, 'subscription_purchase_click');
      expect(events[1].object1, 'yearly');
      expect(events[1].object3, 'subscription_sheet');
      expect(events[2].action, 'subscription_purchase_click');
      expect(events[2].object1, 'monthly');
      expect(events[2].object3, 'subscription_sheet');
      expect(events.length, 3);
    },
  );

  test(
    'native errors keep primary and optional subcode, never inspect messages',
    () {
      for (final code in [1, 5, -3, 'userCanceled', 'serviceTimeout']) {
        final reason = subscriptionStoreFailureReason(
          MembershipProvider.google,
          error: PlatformException(
            code: 'wrapper',
            message: 'secret-token',
            details: {
              'responseCode': code,
              'subResponseCode': 2,
              'debugMessage': 'secret',
            },
          ),
          stage: 'launch',
        );
        expect(reason, 'google[response_code=$code;sub_response_code=2]');
      }
      expect(
        subscriptionStoreFailureReason(
          MembershipProvider.google,
          details: {'responseCode': 7},
          stage: 'query',
        ),
        'google[response_code=7]',
      );
      expect(
        subscriptionStoreFailureReason(
          MembershipProvider.apple,
          details: {
            'domain': 'SKErrorDomain',
            'nativeCode': 2,
            'storeKitCode': 'normalized',
          },
          stage: 'callback',
        ),
        'apple[domain=SKErrorDomain;code=2]',
      );
      expect(
        subscriptionStoreFailureReason(
          MembershipProvider.apple,
          details: {'nativeCode': -1001},
          stage: 'launch',
        ),
        'apple[code=-1001]',
      );
      expect(
        subscriptionStoreFailureReason(
          MembershipProvider.google,
          source: 'google_play',
          code: 'billing_error',
          stage: 'callback',
        ),
        'sdk[source=google_play;code=billing_error]',
      );
      expect(
        subscriptionStoreFailureReason(
          MembershipProvider.apple,
          stage: 'callback',
          status: 'canceled',
        ),
        'store_failure[stage=callback;status=canceled]',
      );
    },
  );

  test(
    'report technical failure emits one correlated failure without retry',
    () async {
      final h = support.Harness(analytics: analytics);
      var requests = 0;
      h.reportHandler = (_) async {
        requests++;
        if (requests == 1) {
          throw ApiException(
            message: 'connection lost',
            kind: ApiExceptionKind.transport,
            transportErrorKind: TransportErrorKind.connection,
          );
        }
        if (requests == 2) throw TimeoutException('timeout');
        return support.completed;
      };
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await h.service.interceptPurchase(h.purchase(transaction: 'GPA.actual'));
      await h.service.recover();
      await h.service.recover();
      await h.service.interceptPurchase(h.purchase(transaction: 'GPA.actual'));
      expect(requests, 1);
      expect(events.map((e) => e.action), ['subscription_failed']);
      expect(events.single.object3, startsWith('report_failed'));
      expect(events.every((e) => e.object2 == tracking.id), isTrue);
      expect(events.last.object1, isEmpty);
      expect(
        h.reports.every((r) => !r.toJson().containsKey('request_id')),
        isTrue,
      );
    },
  );

  test('pending and accepted dedupe without reporting after restart', () async {
    final h = support.Harness(analytics: analytics);
    h.reportHandler = (_) async =>
        const MembershipPurchaseReport(status: MembershipReportStatus.accepted);
    await h.service.purchase(
      h.product(),
      attemptId: tracking.id,
      tracking: tracking,
    );
    await h.service.interceptPurchase(
      h.purchase(status: BillingPurchaseStatus.pending),
    );
    await h.service.interceptPurchase(
      h.purchase(status: BillingPurchaseStatus.pending),
    );
    expect(h.reports, isEmpty);
    await h.service.interceptPurchase(h.purchase());
    expect(events.map((e) => e.object3), [
      'store_callback_pending',
      'report_accepted',
    ]);
    expect(h.reports, hasLength(1));
    expect(h.store.records, isEmpty);
    h.service.dispose();
    final restarted = support.Harness(
      storage: h.store,
      analytics: SubscriptionAnalytics(sink: events.add),
    );
    await restarted.service.recover();
    await restarted.service.recover();
    expect(events.map((e) => e.action), [
      'subscription_pending',
      'subscription_pending',
    ]);
    expect(events.last.object2, tracking.id);
    expect(events.last.object1, isEmpty);
  });

  test(
    'success precedes wallet/cache cleanup; cleanup failure is not failed',
    () async {
      final h = support.Harness(
        provider: MembershipProvider.apple,
        analytics: analytics,
      );
      h.store.failComplete = true;
      h.walletRefreshHandler = () async {
        expect(events.single.action, 'subscription_success');
        throw StateError('wallet unavailable');
      };
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await h.service.interceptPurchase(
        h.purchase(transaction: 'apple-this-transaction'),
      );
      await h.service.recover();
      expect(events, hasLength(1));
      expect(events.single.object3, 'apple-this-transaction');
      expect(h.store.records, isEmpty);
      expect(h.service.state.value, MembershipCheckoutState.completed);
    },
  );

  test(
    'guest login and claim reuse original tracking, each actual retry counted',
    () async {
      final h = support.Harness(analytics: analytics, claimEnabled: true)
        ..uid = null;
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await h.service.interceptPurchase(h.purchase());
      expect(events.single.action, 'subscription_success');
      final savedClaim = MembershipGuestClaimRecord.fromJson(
        h.store.claims.values.single.toJson(),
      );
      expect(savedClaim.tracking?.id, tracking.id);
      h.service.dispose();
      final restarted = support.Harness(
        storage: h.store,
        analytics: SubscriptionAnalytics(sink: events.add),
        claimEnabled: true,
      );
      await restarted.service.recover();
      expect(events.map((e) => e.action), [
        'subscription_success',
        'subscription_claim_result',
      ]);
      expect(events.last.object2, tracking.id);
      expect(events.last.object3, 'completed');
    },
  );

  testWidgets(
    'claim retry emits one result per HTTP request, no extra success',
    (tester) async {
      final h = support.Harness(
        analytics: analytics,
        claimEnabled: true,
        retryDelay: const Duration(seconds: 1),
      )..uid = null;
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await h.service.interceptPurchase(h.purchase());
      h.uid = 'first-login';
      h.claimHandler = (_) async =>
          throw ApiException(message: 'private', code: 1500);
      await h.service.recover();
      await tester.pump(const Duration(seconds: 1));
      await h.service.recover();
      expect(h.claimRequests, hasLength(2));
      expect(
        events
            .where((e) => e.action == 'subscription_claim_result')
            .map((e) => e.object3),
        ['error[1500]', 'error[1500]'],
      );
      expect(
        events.where((e) => e.action == 'subscription_success'),
        hasLength(1),
      );
      h.service.dispose();
    },
  );

  test(
    'store callback plus launch error records only the native callback failure',
    () async {
      final h = support.Harness(analytics: analytics);
      final error = PlatformException(
        code: 'wrapper',
        details: {'responseCode': 5, 'subResponseCode': 2},
      );
      h.platform.onLaunch = () async {
        final purchase = h.purchase(status: BillingPurchaseStatus.error);
        await h.service.interceptPurchase(
          BillingPurchase(
            provider: purchase.provider,
            productId: purchase.productId,
            purchaseToken: '',
            transactionId: '',
            originalTransactionId: '',
            originalJson: '',
            purchaseTime: '',
            status: BillingPurchaseStatus.error,
            errorCode: 'wrapper',
            errorDetails: error.details,
          ),
        );
        throw error;
      };
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      expect(events, hasLength(1));
      expect(
        events.single.object3,
        'google[response_code=5;sub_response_code=2]',
      );
    },
  );

  testWidgets(
    'prepare timer expires once, late error is ignored, no fake store timeout',
    (tester) async {
      final h = support.Harness(
        analytics: analytics,
        attemptTimeout: const Duration(seconds: 1),
      );
      final blocked = Completer<void>();
      h.platform.onPrepare = () => blocked.future;
      final purchase = h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await purchase;
      blocked.completeError(StateError('late error'));
      await tester.pump();
      expect(events.single.action, 'subscription_timeout');
      expect(events.single.object3, 'prepare');
    },
  );

  test(
    'purchase stream preserves the native failure and deduplicates its callback',
    () async {
      final h = support.Harness(analytics: analytics);
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      h.service.handleStreamError(
        PlatformException(code: 'wrapper', details: {'responseCode': -1}),
      );
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.error),
      );
      expect(events, hasLength(1));
      expect(events.single.object3, 'google[response_code=-1]');
    },
  );

  for (final stage in ['uuid', 'guest', 'catalog']) {
    test('$stage preparation keeps its client or API cause', () async {
      final h = support.Harness(analytics: analytics);
      if (stage == 'uuid') h.accountUuidHandler = () async => '';
      if (stage == 'guest') {
        h.uid = null;
        h.guestHandler = () async =>
            throw ApiException(message: 'private', code: 1404);
      }
      if (stage == 'catalog') h.productsHandler = () async => [];
      await h.service.purchase(h.product(), tracking: tracking);
      expect(h.platform.launches, 0);
      expect(
        events.single.object3,
        {
          'uuid': 'uuid_unavailable',
          'guest': 'guest_prepare_failed[1404]',
          'catalog': 'catalog_unavailable',
        }[stage],
      );
    });
  }

  test('native timeout error is failed, not client timeout', () async {
    final h = support.Harness(analytics: analytics);
    h.platform.onPrepare = () async => throw PlatformException(
      code: 'serviceTimeout',
      details: {'responseCode': -3},
    );
    await h.service.purchase(h.product(), tracking: tracking);
    expect(events.single.action, 'subscription_failed');
    expect(events.single.object3, 'google[response_code=-3]');
  });

  test(
    'storage failure before checkout prevents launch but analytics cannot',
    () async {
      final h = support.Harness(analytics: analytics)..uid = null;
      h.store.failClaim = true;
      await h.service.purchase(h.product(), tracking: tracking);
      expect(h.platform.launches, 0);
      expect(events.single.object3, 'local_storage_failed');
      final failingAnalytics = SubscriptionAnalytics(
        sink: (_) => throw StateError('telemetry broken'),
      );
      final other = support.Harness(analytics: failingAnalytics);
      await other.service.purchase(other.product(), tracking: tracking);
      await other.service.interceptPurchase(other.purchase());
      expect(other.reports, hasLength(1));
      expect(other.refreshes, 1);
    },
  );

  test('legacy queue cleanup fabricates no report or analytics', () async {
    final h = support.Harness(analytics: analytics);
    h.store.records['legacy'] = MembershipPurchaseRecord(
      requestId: 'legacy',
      product: h.product(),
      accountUuid: support.accountUuid,
      ownerUid: h.uid,
      purchaseToken: 'sensitive-token',
      transactionId: 'GPA.real',
      state: 'purchased',
    );
    await h.service.recover();
    expect(events, isEmpty);
    expect(h.reports, isEmpty);
    expect(h.store.records, isEmpty);
  });

  test(
    'no-order success merges later order identity without duplicate success',
    () {
      var state = analytics.success(tracking, 'google', '');
      expect(events.single.object3, '');
      state = analytics.success(state, 'google', 'GPA.later');
      analytics.success(
        const SubscriptionTracking(id: 'other'),
        'google',
        'GPA.later',
      );
      expect(events, hasLength(1));
      expect(state.successEventId, isNotNull);
      final restarted = SubscriptionAnalytics(sink: events.add);
      restarted.success(
        SubscriptionTracking.fromJson(state.toJson())!,
        'google',
        'GPA.later',
      );
      expect(events, hasLength(1));
    },
  );
}
