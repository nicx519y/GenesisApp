import 'dart:convert';

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

  test('billing analytics uses an allowlist for sensitive properties', () {
    final result = sanitizeBillingAnalyticsProperties(<String, Object?>{
      'action': 'purchase_launch_start',
      'attempt_id': 'attempt-1',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
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
      'action': 'purchase_launch_start',
      'attempt_id': 'attempt-1',
      'product_id': 'gem_pack_500',
      'offer_token_present': true,
      'billing_account_id_present': true,
    });
  });

  test(
    'billing analytics adds a safe Collect projection with identity headers',
    () async {
      final sink = _CapturingTelemetrySink();
      GenesisTelemetry.setSinkForTesting(sink);

      const GenesisBillingAnalytics().track(
        'report_result',
        properties: <String, Object?>{
          'attempt_id': 'attempt-1',
          'product_id': 'gem_pack_500',
          'result': 'completed',
          'retry_count': 1,
          'uid': 'u_1',
          'device_id': 'device-1',
          'purchase_token': 'must-not-send',
        },
      );
      await Future<void>.delayed(Duration.zero);

      final event = sink.events.single;
      expect(event.name, 'pay_event');
      expect(event.category, 'billing.purchase');
      expect(event.includeCollectIdentityHeaders, isTrue);
      expect(event.collectPayload, {
        'action_type': 'pay_event',
        'action': 'report_result',
        'object1': 'gem_pack_500',
        'object2': 'attempt-1',
        'object3': '{"result":"completed","retry_count":1}',
      });
      final details = jsonDecode('${event.collectPayload!['object3']}');
      expect(details, {'result': 'completed', 'retry_count': 1});
      expect('${event.collectPayload}', isNot(contains('must-not-send')));
      expect('${event.collectPayload}', isNot(contains('device-1')));
      expect('${event.collectPayload}', isNot(contains('u_1')));
    },
  );
}
