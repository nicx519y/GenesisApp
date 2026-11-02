import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';

void main() {
  test(
    'subscription failure carries correlation and native error diagnostic',
    () async {
      final events = <SubscriptionAnalyticsEvent>[];
      final analytics = SubscriptionAnalytics(sink: events.add);
      analytics.failed(
        const SubscriptionTracking(id: 'track-1'),
        'google[response_code=developerError]',
        diagnostics: {
          'stage': 'callback',
          'debug_message': 'Wrong purchase parameters',
          'response_code': 'developerError',
          'product_id': 'premium_monthly',
          'purchase_token': 'secret',
        },
      );
      await Future<void>.delayed(Duration.zero);
      final event = events.single;
      final d = jsonDecode(event.extData) as Map;
      expect(d['tracking_id'], 'track-1');
      expect(d['stage'], 'callback');
      expect(d['debug_message'], 'Wrong purchase parameters');
      expect(d['product_id'], 'premium_monthly');
      expect(d.containsKey('purchase_token'), isFalse);
    },
  );

  tearDown(GenesisTelemetry.resetForTesting);
  test('subscription failure is queued as monitor', () async {
    final store = MemoryCollectEventStore();
    final uploader = CollectTelemetryUploader(store: store)
      ..configure(enabled: true);
    GenesisTelemetry.setCollectUploaderForTesting(uploader);
    SubscriptionAnalytics().failed(
      const SubscriptionTracking(
        id: 'failed-checkout',
        source: SubscriptionSource.meMembership,
      ),
      'launch_failed[NOT_FOUND]',
    );
    await GenesisTelemetry.waitForCollectWritesForTesting();
    final event = (await store.claimPending(limit: 20))!.events.single;
    expect(event.actionType, 'monitor');
    expect(event.action, 'subscription_failed');
    expect(event.object1, 'from_me_membership');
    expect(event.object3, 'launch_failed[reason=store_launch_error]');
    expect(
      (jsonDecode(event.extData) as Map)['original_reason'],
      'launch_failed[NOT_FOUND]',
    );
  });

  test(
    'queued click captures guest UID, claim captures login UID without extra fields',
    () async {
      final store = MemoryCollectEventStore();
      final uploader = CollectTelemetryUploader(store: store)
        ..configure(enabled: true);
      uploader.setContext(
        const CollectUploadContext(platform: 'android', userId: ''),
      );
      GenesisTelemetry.setCollectUploaderForTesting(uploader);
      final analytics = SubscriptionAnalytics();
      final tracking = analytics.click(
        'page',
        SubscriptionSurface.sheet,
        SubscriptionSource.meMembership,
        isYearly: false,
      );
      GenesisTelemetry.setUserId('login-owner');
      analytics.claim(tracking, 'completed');
      await GenesisTelemetry.waitForCollectWritesForTesting();
      final guest = (await store.claimPending(limit: 20))!.events.single;
      final loggedIn = (await store.claimPending(limit: 20))!.events.single;
      expect(guest.userId, '');
      expect(loggedIn.userId, 'login-owner');
      expect(guest.object2, loggedIn.object2);
      expect(guest.object1, 'from_me_membership');
      expect(guest.object3, 'monthly');
      expect(guest.extData, '');
      expect(guest.actionType, 'pay_event');
      expect(loggedIn.action, 'subscription_claim_result');
      expect(loggedIn.object1, 'from_me_membership');
    },
  );

  test(
    'stable success event ID survives new analytics instance and queue replay',
    () async {
      final store = MemoryCollectEventStore();
      final uploader = CollectTelemetryUploader(store: store)
        ..configure(enabled: true);
      GenesisTelemetry.setCollectUploaderForTesting(uploader);
      const tracking = SubscriptionTracking(id: 'recovery_stable');
      SubscriptionAnalytics().success(tracking, 'google', 'GPA.same-order');
      SubscriptionAnalytics().success(tracking, 'google', 'GPA.same-order');
      await GenesisTelemetry.waitForCollectWritesForTesting();
      final batch = (await store.claimPending(limit: 20))!;
      expect(batch.events, hasLength(1));
      final event = batch.events.single;
      await store.recoverInFlight();
      expect(
        (await store.claimPending(limit: 20))!.events.single.eventId,
        event.eventId,
      );
      expect(event.object3, 'GPA.same-order');
    },
  );
}
