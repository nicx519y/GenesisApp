import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:genesis_flutter_android/platform/billing/payment_failure_diagnostics.dart';

void main() {
  test(
    'code-only SDK errors retain their layer without an exception object',
    () {
      final d = paymentFailureDiagnostics(
        provider: 'apple',
        stage: 'callback',
        code: 'purchase_error',
        source: 'app_store',
      );
      expect(d['error_layer'], 'sdk');
    },
  );
  test('stream status cannot fabricate a purchase callback status', () {
    final d = paymentFailureDiagnostics(
      provider: 'google',
      stage: 'stream',
      status: 'error',
    );
    expect(d['event_status'], 'error');
    expect(d.containsKey('purchase_status'), false);
  });

  test(
    'Google codes and diagnostic are structured and credentials are redacted',
    () {
      final diagnostic = paymentFailureDiagnostics(
        provider: 'googlePlay',
        stage: 'callback',
        error: PlatformException(
          code: 'purchase_error',
          details: {
            'responseCode': 'billingUnavailable',
            'subResponseCode': 0,
            'debugMessage':
                'Card rejected; purchaseToken=secret; user@example.test',
          },
        ),
      );
      final encoded = encodePaymentFailureDiagnostics({
        ...diagnostic,
        'purchase_token': 'never-copy',
        'signedTransaction': 'never-copy',
      });
      final data = jsonDecode(encoded) as Map;
      expect(data['response_code'], 'billingUnavailable');
      expect(data['sub_response_code'], 0);
      expect(data['stage'], 'callback');
      expect(encoded, isNot(contains('secret')));
      expect(encoded, isNot(contains('user@example.test')));
      expect(encoded, isNot(contains('never-copy')));
    },
  );
  test('bounded diagnostics always remain JSON and preserve correlation', () {
    final text = List.filled(9000, 'x ').join();
    final encoded = encodePaymentFailureDiagnostics({
      'tracking_id': 'track',
      'stage': 'launch',
      'debug_message': text,
      'message': text,
      'product_id': text,
      'reason': text,
      'source': text,
      'store_product_id': text,
      'provider': text,
    });
    expect(encoded.length, lessThanOrEqualTo(3900));
    expect((jsonDecode(encoded) as Map)['tracking_id'], 'track');
  });
}
