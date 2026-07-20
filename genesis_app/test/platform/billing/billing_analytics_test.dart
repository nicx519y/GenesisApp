import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/platform/billing/billing_analytics.dart';

class _CapturingTelemetrySink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

void main() {
  tearDown(GenesisTelemetry.resetForTesting);

  test('billing analytics sanitizes sensitive properties', () {
    final result = sanitizeBillingAnalyticsProperties(<String, Object?>{
      'action': 'product_click',
      'attempt_id': 'attempt-1',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
      'source': 'buy_gems_sheet',
      'purchase_token': 'purchase-token-1',
      'offerToken': 'offer-token-1',
      'billing_account_id': 'account-1',
      'uid': 'u_1',
      'device_id': 'device-1',
      'transaction_id': 'GPA.1',
      'original_json': '{"purchaseToken":"purchase-token-1"}',
      'payload': <String, Object?>{'secret': 'value'},
      'unknown_field': 'value',
    });

    expect(result, <String, Object?>{
      'action': 'product_click',
      'attempt_id': 'attempt-1',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
      'source': 'buy_gems_sheet',
      'transaction_id': 'GPA.1',
    });
  });

  test(
    'product click collect projection keeps source as object3 text',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'product_click',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'source': 'buy_gems_sheet',
          'provider': 'google',
          'can_purchase': true,
        },
      );
      await Future<void>.delayed(Duration.zero);

      final event = sink.events.single;
      expect(event.collectPayload, {
        'action_type': 'pay_event',
        'action': 'product_click',
        'object1': 'gem_pack_500',
        'object2': 'attempt-1',
        'object3': 'buy_gems_sheet',
      });
    },
  );

  test('success collect projection sends transaction id as object3', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_success',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
        'store_product_id': 'worldo_gem_pack_500',
        'transaction_id': 'GPA.1',
      },
    );
    await Future<void>.delayed(Duration.zero);

    final event = sink.events.single;
    expect(event.collectPayload, {
      'action_type': 'pay_event',
      'action': 'purchase_success',
      'object1': 'gem_pack_500',
      'object2': 'attempt-1',
      'object3': 'GPA.1',
    });
  });

  test('failed collect projection keeps reason as object3 text', () async {
    final sink = _CapturingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);

    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: <String, Object?>{
        'attempt_id': 'attempt-1',
        'product_id': 'gem_pack_500',
        'reason': 'query_failed',
        'error_code': 'offer_not_available',
      },
    );
    await Future<void>.delayed(Duration.zero);

    final event = sink.events.single;
    expect(event.collectPayload, {
      'action_type': 'pay_event',
      'action': 'purchase_failed',
      'object1': 'gem_pack_500',
      'object2': 'attempt-1',
      'object3': 'query_failed',
    });
  });
}
