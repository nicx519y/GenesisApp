import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/payment_failure_classification.dart';
import 'package:genesis_flutter_android/platform/billing/payment_failure_diagnostics.dart';
import 'package:genesis_flutter_android/network/api_exception.dart';

void main() {
  test('quoted sensitive assignments with spaces are fully removed', () {
    final text = encodePaymentFailureDiagnostics({
      'message':
          'token="secret with spaces"; receipt=\'other secret\'; attempt-1',
    });
    expect(text, isNot(contains('secret')));
    expect(text, contains('attempt-1'));
  });

  for (final row in <(String, Map<String, Object?>, String)>[
    (
      'precheck_failed[purchase_in_progress]',
      {},
      'precheck_failed[reason=purchase_in_progress]',
    ),
    (
      'precheck_failed[uuid_unavailable]',
      {},
      'prepare_failed[reason=uuid_unavailable]',
    ),
    (
      'precheck_failed[service_unavailable]',
      {'stage': 'start_store_listener'},
      'prepare_failed[reason=listener_start_failed]',
    ),
    (
      'query_failed[product_not_found]',
      {},
      'query_failed[reason=product_not_found]',
    ),
    (
      'query_failed[billingUnavailable]',
      {},
      'query_failed[reason=store_query_error]',
    ),
    (
      'precheck_failed[store_price_changed]',
      {},
      'query_failed[reason=price_changed]',
    ),
    (
      'query_failed',
      {
        'stage': 'query',
        'error_code': 'store_query_error',
        'step': 'confirm_product',
      },
      'query_failed[reason=store_query_error]',
    ),
    (
      'launch_failed[sdk[code=product_details_changed]]',
      {'stage': 'launch_store', 'error_code': 'product_details_changed'},
      'launch_failed[reason=product_details_changed]',
    ),
    (
      'launch_failed[launch_rejected]',
      {},
      'launch_failed[reason=launch_rejected]',
    ),
    (
      'google[response_code=userCanceled]',
      {'stage': 'callback', 'response_code': 'userCanceled'},
      'callback_failed[reason=canceled]',
    ),
    (
      'apple[code=1]',
      {'stage': 'callback', 'purchase_status': 'error'},
      'callback_failed[reason=store_error]',
    ),
    (
      'store_failure[stage=callback;status=canceled]',
      {},
      'callback_failed[reason=canceled]',
    ),
    ('receipt_missing', {}, 'callback_failed[reason=receipt_missing]'),
    (
      'store_failure[stage=stream;status=error]',
      {'stage': 'stream'},
      'stream_failed[reason=unknown_stream_error]',
    ),
    (
      'stream_failed',
      {'stage': 'stream', 'error_type': 'FormatException'},
      'stream_failed[reason=result_conversion_error]',
    ),
  ]) {
    test('classifies ${row.$1} with ${row.$2}', () {
      expect(classifyPaymentFailure(row.$1, row.$2).object3, row.$3);
    });
  }
  test(
    'debug text cannot fabricate cancellation or classify a provider failure',
    () {
      final c = classifyPaymentFailure('stream_failed', {
        'stage': 'stream',
        'debug_message': 'userCanceled developerError',
      });
      expect(c.reason, 'unknown_stream_error');
    },
  );
  test(
    'HTTP diagnostics preserve codes and path without credentials or body',
    () {
      final d = paymentFailureDiagnostics(
        provider: 'apple',
        stage: 'prepare',
        error: ApiException(
          message: 'request failed',
          code: 1404,
          statusCode: 403,
          uri: Uri.parse('https://api.example.test/user/info?token=secret'),
          responseHeaders: {'x-request-id': 'trace-1'},
          responseBody: 'private body',
        ),
        stackTrace: StackTrace.fromString(
          '#0 method (/Users/person/project/billing.dart:42:5)',
        ),
      );
      final text = encodePaymentFailureDiagnostics(d);
      final decoded = jsonDecode(text) as Map;
      expect(decoded['api_path'], '/user/info');
      expect(decoded['business_code'], 1404);
      expect(decoded['request_id'], 'trace-1');
      expect(decoded['stack_trace'], contains('billing.dart:42:5'));
      expect(text, isNot(contains('/Users/person/')));
      expect(text, isNot(contains('private body')));
      expect(text, isNot(contains('secret')));
    },
  );
  test(
    'long correlation IDs stay intact and diagnostic truncation is explicit',
    () {
      final id = List.filled(100, 'a').join();
      final text = encodePaymentFailureDiagnostics({
        'attempt_id': id,
        'stage': 'stream',
        'stack_trace': List.filled(200, 'frame.dart:3:5 ').join(),
      });
      final d = jsonDecode(text) as Map;
      expect(d['attempt_id'], id);
      expect(d['diagnostics_truncated'], true);
      expect(d['truncated_fields'], contains('stack_trace'));
      expect(text.length, lessThanOrEqualTo(3900));
    },
  );
  test(
    'callback messages preserve native codes and remove sensitive assignments',
    () {
      final text = encodePaymentFailureDiagnostics(
        paymentFailureDiagnostics(
          provider: 'googlePlay',
          stage: 'callback',
          error: PlatformException(
            code: 'purchase_error',
            message: 'failed; token=secret',
            details: {
              'responseCode': 'developerError',
              'subResponseCode': 0,
              'debugMessage': 'Invalid product',
            },
          ),
        ),
      );
      final d = jsonDecode(text) as Map;
      expect(d['provider'], 'google');
      expect(d['response_code'], 'developerError');
      expect(d['message'], contains('[redacted]'));
      expect(text, isNot(contains('secret')));
    },
  );
}
