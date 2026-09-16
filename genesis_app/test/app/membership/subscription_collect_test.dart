import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/membership/subscription_analytics.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';

void main() {
  tearDown(GenesisTelemetry.resetForTesting);
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
      );
      GenesisTelemetry.setUserId('login-owner');
      analytics.claim(tracking, 'completed');
      await GenesisTelemetry.waitForCollectWritesForTesting();
      final guest = (await store.claimPending(limit: 20))!.events.single;
      final loggedIn = (await store.claimPending(limit: 20))!.events.single;
      expect(guest.userId, '');
      expect(loggedIn.userId, 'login-owner');
      expect(guest.object2, loggedIn.object2);
      expect(guest.object1, '');
      expect(guest.extData, '');
      expect(guest.actionType, 'pay_event');
      expect(loggedIn.action, 'subscription_claim_result');
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
