import '../../support/membership_fixtures.dart' as fixtures;
import 'dart:convert';
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
    id: 'checkout_page_click',
    source: SubscriptionSource.meMembership,
  );
  test(
    'skipped success deduplicates reasons without consuming normal success',
    () {
      analytics.successSkipped(
        tracking,
        'account_uuid_missing',
        transactionIdentity: 'tx',
      );
      analytics.successSkipped(
        tracking,
        'account_uuid_missing',
        transactionIdentity: 'tx',
      );
      expect(events.single.object3, 'account_uuid_missing');
      final done = analytics.success(tracking, 'apple', 'tx');
      analytics.success(done, 'apple', 'tx');
      analytics.success(done, 'apple', 'tx');
      expect(
        events.where((e) => e.action == 'subscription_success'),
        hasLength(1),
      );
      expect(
        events
            .where((e) => e.action == 'subscription_success_skipped')
            .map((e) => e.object3),
        ['account_uuid_missing', 'duplicate_transaction'],
      );
      analytics.success(done.copyWith(), 'apple', 'other-tx');
      expect(events.last.object3, 'duplicate_tracking');
    },
  );
  test(
    'Android subscription carries base plan through all event types and persistence',
    () {
      final clicked = analytics.click(
        'page',
        SubscriptionSurface.page,
        SubscriptionSource.meMembership,
        isYearly: false,
        storeProductId: 'premium',
        basePlanId: 'premium-monthly',
      );
      final restored = SubscriptionTracking.fromJson(clicked.toJson())!;
      analytics.pending(restored, 'store_callback_pending');
      analytics.failed(restored, 'canceled');
      analytics.timeout(restored, 'prepare');
      analytics.success(restored, 'google', 'tx');
      analytics.successSkipped(restored, 'duplicate_transaction');
      analytics.claim(restored, 'completed');
      expect(events, hasLength(7));
      expect(events.map((e) => e.object2), everyElement('premium-monthly'));
      expect(restored.storeProductId, 'premium');
    },
  );
  test(
    'Gems origins form validated non-nested subscription sources and survive persistence',
    () {
      for (final source in [
        BillingPurchaseSource.meGems,
        BillingPurchaseSource.tickNoBalance,
        BillingPurchaseSource.msgLowBalance,
        BillingPurchaseSource.msgNoBalance,
      ]) {
        final sub = SubscriptionSource.fromGemsEntry(source);
        expect(sub.value, 'from_buy_gems_tab[${source.value}]');
        final tracking = SubscriptionTracking(id: source.value, source: sub);
        final restored = SubscriptionTracking.fromJson(tracking.toJson())!;
        analytics.pending(restored, 'store_callback_pending');
        analytics.success(restored, 'google', source.value);
        expect(events.last.object1, sub.value);
      }
      expect(
        SubscriptionSource.parse('from_buy_gems_tab[from_unknown]'),
        SubscriptionSource.unknown,
      );
      expect(
        SubscriptionSource.parse('from_buy_gems_tab[from_home_membership]'),
        SubscriptionSource.unknown,
      );
      expect(
        SubscriptionSource.parse(
          'from_buy_gems_tab[from_subscription_tab[from_home_membership]]',
        ),
        SubscriptionSource.unknown,
      );
    },
  );
  setUp(() {
    events = [];
    analytics = SubscriptionAnalytics(sink: events.add);
  });

  test('unknown and recovery sources never reach the subscription sink', () {
    for (final sourceTracking in [
      const SubscriptionTracking(id: 'unknown'),
      SubscriptionTracking.recovery('apple:transaction'),
      SubscriptionTracking.fromJson({'id': 'legacy', 'source': 'removed'})!,
    ]) {
      analytics.pageShow(
        sourceTracking.id,
        SubscriptionSurface.page,
        sourceTracking.source,
        MembershipType.premium,
      );
      analytics.click(
        sourceTracking.id,
        SubscriptionSurface.page,
        sourceTracking.source,
        isYearly: false,
      );
      analytics.failed(sourceTracking, 'canceled');
      analytics.timeout(sourceTracking, 'prepare');
      analytics.pending(sourceTracking, 'store_callback_pending');
      analytics.success(sourceTracking, 'apple', sourceTracking.id);
      analytics.claim(sourceTracking, 'completed');
    }
    expect(events, isEmpty);
  });

  test(
    'store product follows click and results while object3 stays unchanged',
    () {
      final t = analytics.click(
        'sku-page',
        SubscriptionSurface.page,
        SubscriptionSource.meMembership,
        isYearly: false,
        storeProductId: 'premium_monthly',
      );
      final restored = SubscriptionTracking.fromJson(t.toJson())!;
      analytics.pending(restored, 'store_callback_pending');
      analytics.timeout(restored, 'prepare');
      analytics.failed(restored, 'canceled');
      analytics.success(restored, 'apple', 'transaction-1');
      analytics.claim(restored, 'completed');
      expect(events.map((e) => e.object2), everyElement('premium_monthly'));
      expect(events.map((e) => e.object3), [
        'monthly',
        'store_callback_pending',
        'prepare_failed[reason=timeout]',
        'unknown_failed[reason=canceled]',
        'transaction-1',
        'completed',
      ]);
    },
  );

  test('timeout deduplicates separately and preserves later store results', () {
    const t = SubscriptionTracking(
      id: 'timeout-result',
      source: SubscriptionSource.meMembership,
      storeProductId: 'sku',
    );
    analytics.timeout(t, 'store_callback');
    analytics.timeout(t, 'store_callback');
    analytics.failed(
      t,
      'canceled',
      once: true,
      diagnostics: {'stage': 'callback'},
    );
    analytics.success(t, 'apple', 'late-transaction');
    expect(events.map((e) => e.action), [
      'subscription_failed',
      'subscription_failed',
      'subscription_success',
    ]);
    expect(events.first.object3, 'callback_failed[reason=timeout]');
    expect(events[1].object3, 'callback_failed[reason=canceled]');
    expect(events.last.object3, 'late-transaction');
  });

  for (final provider in MembershipProvider.values) {
    for (final phase in ['callback', 'stream', 'prepare', 'busy']) {
      test(
        '$provider $phase failure retains attempt, tracking and store identifiers',
        () async {
          final h = support.Harness(provider: provider, analytics: analytics);
          addTearDown(h.service.dispose);
          final product = fixtures.membershipProduct(
            provider: provider,
            offerId: provider == MembershipProvider.google ? 'test-offer' : '',
          );
          h.productsHandler = () async => [product];
          if (phase == 'busy') h.gemsBusy = true;
          const runtimeId = 'runtime-attempt-distinct-from-tracking';
          if (phase == 'prepare') h.accountUuidHandler = () async => '';
          await h.service.purchase(
            product,
            attemptId: runtimeId,
            tracking: tracking,
          );
          if (phase == 'callback') {
            await h.service.interceptPurchase(
              h.purchase(status: BillingPurchaseStatus.canceled),
            );
          } else if (phase == 'stream') {
            h.service.handleStreamError(
              StateError('listener error'),
              StackTrace.fromString('billing.dart:42'),
            );
          }
          final event = events.singleWhere(
            (e) => e.action == 'subscription_failed',
          );
          final d = jsonDecode(event.extData) as Map;
          expect(d['attempt_id'], runtimeId);
          expect(d['tracking_id'], tracking.id);
          expect(
            d['provider'],
            provider == MembershipProvider.google ? 'google' : 'apple',
          );
          expect(d['plan_code'], h.product().planCode);
          expect(d['store_product_id'], h.product().storeProductId);
          expect(d.containsKey('product_id'), false);
          if (product.basePlanId.isNotEmpty) {
            expect(d['base_plan_id'], product.basePlanId);
          } else {
            expect(d.containsKey('base_plan_id'), false);
          }
          if (product.offerId.isNotEmpty) {
            expect(d['offer_id'], product.offerId);
          } else {
            expect(d.containsKey('offer_id'), false);
          }
          if (phase == 'callback') {
            expect(event.object3, 'callback_failed[reason=canceled]');
            expect(d['purchase_status'], 'canceled');
            expect(d['event_status'], 'canceled');
            expect(d['callback_product_id'], h.product().storeProductId);
          } else if (phase == 'stream') {
            expect(d['event_status'], 'error');
            expect(d.containsKey('purchase_status'), false);
            expect(d['payment_outcome'], 'unknown');
          }
        },
      );
    }
  }

  test(
    'edit quota sheet and purchase use a distinct source with existing surface',
    () {
      analytics.pageShow(
        'edit-page',
        SubscriptionSurface.sheet,
        SubscriptionSource.chatEditSaveQuota,
        MembershipType.deluxe,
      );
      final click = analytics.click(
        'edit-page',
        SubscriptionSurface.sheet,
        SubscriptionSource.chatEditSaveQuota,
        isYearly: true,
      );
      analytics.failed(click, 'query_failed');
      expect(
        events.every((e) => e.object1 == 'from_chat_edit_save_quota'),
        isTrue,
      );
      expect(events.first.object2, 'Deluxe');
      expect(events.first.object3, 'subscription_sheet');
      expect(
        SubscriptionSource.parse('from_chat_edit_save_quota'),
        SubscriptionSource.chatEditSaveQuota,
      );
    },
  );

  test(
    'purchase events omit object2 and clicks keep private operation IDs',
    () {
      analytics.pageShow(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
        MembershipType.premium,
      );
      analytics.pageShow(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.dailyCheckIn,
        MembershipType.deluxe,
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
      expect(first.id, isNotEmpty);
      expect(first.id, isNot(second.id));
      expect(events.first.action, 'subscription_page_show');
      expect(events.first.object1, 'from_daily_check_in');
      expect(events.first.object2, 'Premium');
      expect(events.skip(1).every((event) => event.object2.isEmpty), isTrue);
      expect(events.first.object3, 'subscription_sheet');
      expect(events[1].action, 'subscription_purchase_click');
      expect(events[1].object1, 'from_daily_check_in');
      expect(events[1].object3, 'yearly');
      expect(events[2].action, 'subscription_purchase_click');
      expect(events[2].object1, 'from_daily_check_in');
      expect(events[2].object3, 'monthly');
      expect(events.length, 3);
    },
  );

  test('every purchase result keeps the original source in object1', () {
    const purchase = SubscriptionTracking(
      id: 'checkout_result',
      source: SubscriptionSource.chatFeatureQuota,
    );
    analytics.pending(purchase, 'store_callback_pending');
    analytics.timeout(purchase, 'report');
    analytics.failed(purchase, 'report_rejected');
    analytics.success(purchase, 'google', 'GPA.result');
    analytics.claim(purchase, 'completed');

    expect(events.map((event) => event.action), [
      'subscription_pending',
      'subscription_failed',
      'subscription_failed',
      'subscription_success',
      'subscription_claim_result',
    ]);
    expect(
      events.every((event) => event.object1 == 'from_chat_feature_quota'),
      isTrue,
    );
    expect(events.map((event) => event.object3), [
      'store_callback_pending',
      'report_failed[reason=timeout]',
      'unknown_failed[reason=unknown_error]',
      'GPA.result',
      'completed',
    ]);

    final recovered = SubscriptionTracking.recovery('missing-click');
    analytics.failed(recovered, 'report_rejected');
    expect(events, hasLength(5));
  });

  for (final stage in ['precheck', 'query', 'launch']) {
    test('purchase $stage failure emits one staged result', () async {
      final h = support.Harness(analytics: analytics);
      if (stage == 'precheck') h.gemsBusy = true;
      if (stage == 'query') {
        h.platform.onPrepare = () async => throw const BillingPlatformException(
          'membership_product_not_found',
        );
      }
      if (stage == 'launch') h.platform.launchResult = false;
      final tracking = SubscriptionTracking(
        id: 'failed-$stage',
        source: SubscriptionSource.meMembership,
      );

      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      await pumpEventQueue();

      final failed = events.where(
        (event) => event.action == 'subscription_failed',
      );
      expect(failed, hasLength(1));
      expect(failed.single.object1, 'from_me_membership');
      expect(
        failed.single.object2,
        h.product().provider == MembershipProvider.google
            ? h.product().basePlanId
            : h.product().storeProductId,
      );
      expect(failed.single.object3, startsWith('${stage}_failed['));
      expect(h.reports, isEmpty);
    });
  }

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
    'report technical failure emits store success and report failure without retry',
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
      expect(events.map((e) => e.action), [
        'subscription_success',
        'subscription_failed',
        'subscription_success_skipped',
      ]);
      expect(events.first.object3, 'GPA.actual');
      expect(events[1].object3, 'report_failed[reason=network_error]');
      expect(events.last.object3, 'duplicate_transaction');
      expect(
        events.every(
          (e) =>
              e.object2 ==
              (h.product().provider == MembershipProvider.google
                  ? h.product().basePlanId
                  : h.product().storeProductId),
        ),
        isTrue,
      );
      expect(events.last.object1, 'from_me_membership');
      expect(
        h.reports.every((r) => !r.toJson().containsKey('request_id')),
        isTrue,
      );
    },
  );

  test(
    'pending and purchased report once without retry after restart',
    () async {
      final h = support.Harness(analytics: analytics);
      h.reportHandler = (_) async => const MembershipPurchaseReport(
        status: MembershipReportStatus.completed,
      );
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
      expect(events.map((e) => e.object3), ['store_callback_pending', '100']);
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
        'subscription_success',
      ]);
      expect(
        events.last.object2,
        h.product().provider == MembershipProvider.google
            ? h.product().basePlanId
            : h.product().storeProductId,
      );
      expect(events.last.object1, 'from_me_membership');
    },
  );

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
      expect(
        events.last.object2,
        h.product().provider == MembershipProvider.google
            ? h.product().basePlanId
            : h.product().storeProductId,
      );
      expect(events.last.object1, 'from_me_membership');
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
        events
            .where((e) => e.action == 'subscription_claim_result')
            .every((e) => e.object1 == 'from_me_membership'),
        isTrue,
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
      expect(events.single.object3, 'callback_failed[reason=store_error]');
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
      expect(events.single.action, 'subscription_failed');
      expect(events.single.object3, 'prepare_failed[reason=timeout]');
    },
  );

  test(
    'stream diagnostic does not suppress the later explicit store failure',
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
      expect(events, hasLength(1));
      expect(events.single.action, 'subscription_failed');
      expect(
        events.single.object3,
        'stream_failed[reason=unknown_stream_error]',
      );
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.error),
      );
      expect(events, hasLength(2));
      expect(events.last.object3, 'callback_failed[reason=store_error]');
      await h.service.interceptPurchase(
        h.purchase(status: BillingPurchaseStatus.error),
      );
      expect(events, hasLength(2));
    },
  );

  test(
    'a purchased callback after stream failure still reports success',
    () async {
      final h = support.Harness(analytics: analytics);
      await h.service.purchase(
        h.product(),
        attemptId: tracking.id,
        tracking: tracking,
      );
      h.service.handleStreamError();
      expect(events.single.action, 'subscription_failed');
      expect(
        events.single.object3,
        'stream_failed[reason=unknown_stream_error]',
      );

      await h.service.interceptPurchase(h.purchase());

      expect(events.map((event) => event.action), [
        'subscription_failed',
        'subscription_success',
      ]);
      expect(h.reports, hasLength(1));
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
      expect(events, hasLength(1));
      expect(events.single.action, 'subscription_failed');
      expect(
        events.single.object3,
        startsWith(stage == 'catalog' ? 'query_failed[' : 'prepare_failed['),
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
    expect(events, hasLength(1));
    expect(events.single.action, 'subscription_failed');
    expect(events.single.object3, startsWith('query_failed['));
  });

  test(
    'storage failure before checkout is tracked without blocking billing',
    () async {
      final h = support.Harness(analytics: analytics)..uid = null;
      h.store.failClaim = true;
      await h.service.purchase(h.product(), tracking: tracking);
      expect(h.platform.launches, 0);
      expect(events, hasLength(1));
      expect(
        events.single.object3,
        'prepare_failed[reason=local_storage_failed]',
      );
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
      expect(
        events.where((e) => e.action == 'subscription_success'),
        hasLength(1),
      );
      expect(state.successEventId, isNotNull);
      final restarted = SubscriptionAnalytics(sink: events.add);
      restarted.success(
        SubscriptionTracking.fromJson(state.toJson())!,
        'google',
        'GPA.later',
      );
      expect(
        events.where((e) => e.action == 'subscription_success'),
        hasLength(1),
      );
    },
  );
}
