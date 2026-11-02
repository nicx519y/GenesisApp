import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'billing_models.dart';
import '../../network/api_exception.dart';

bool? _paymentForeground() {
  try {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null ? null : state == AppLifecycleState.resumed;
  } catch (_) {
    return null;
  }
}

/// Only allowlisted diagnostic scalars cross the Collect boundary. Receipts,
/// tokens, account identifiers, full requests and arbitrary maps are excluded.
Map<String, Object?> paymentFailureDiagnostics({
  required String provider,
  required String stage,
  Object? error,
  String? message,
  StackTrace? stackTrace,
  String? code,
  String? source,
  Object? details,
  String? status,
  Map<String, Object?> context = const {},
}) {
  try {
    if (error is ApiException) message = error.message;
    if (error is FormatException) message = error.message;
    if (error is StateError) message = error.message.toString();
    if (error is ArgumentError) message = error.message?.toString();
    if (error is Error) {
      message ??= error.toString();
      stackTrace ??= error.stackTrace;
    }

    if (error is IAPError) {
      code = error.code;
      source = error.source;
      details = error.details;
      message = error.message;
    }
    if (error is PlatformException) {
      code = error.code;
      details = error.details;
      message = error.message;
    }
    if (error is BillingPlatformException) {
      code = error.code;
      details = error.details;
      message = error.message;
    }
    final native = details is Map ? details : const {};
    return {
      'schema_version': 2,
      'provider': provider,
      'stage': stage,
      if (_paymentForeground() case final bool foreground)
        'foreground': foreground,
      'error_layer': error is ApiException
          ? 'http'
          : native['responseCode'] != null || native['nativeCode'] != null
          ? 'store_native'
          : error is IAPError ||
                error is PlatformException ||
                error is BillingPlatformException
          ? 'sdk'
          : error is Error || error is FormatException
          ? 'client'
          : 'unknown',
      if (error != null) 'error_type': error.runtimeType.toString(),
      if (code != null) 'error_code': code,
      if (source != null) 'error_source': source,
      if (status != null) 'purchase_status': status,
      if (native['responseCode'] != null)
        'response_code': native['responseCode'],
      if (native['subResponseCode'] != null)
        'sub_response_code': native['subResponseCode'],
      if (native['debugMessage'] != null)
        'debug_message': native['debugMessage'],
      if (message != null) 'message': message,
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
      if (error is ApiException) ...{
        'api_path': error.uri?.path,
        'http_status': error.statusCode,
        'business_code': error.code,
        'client_failure_code': error.clientFailureCode?.value,
        'transport_error_kind': error.transportErrorKind?.name,
        'request_id':
            error.responseHeaders?['x-request-id'] ??
            error.responseHeaders?['request-id'],
        'error_layer': 'http',
      },
      if (native['nativeCode'] != null) 'native_code': native['nativeCode'],
      if (native['domain'] != null) 'domain': native['domain'],
      ...context,
    };
  } catch (_) {
    return {
      'schema_version': 2,
      'provider': provider,
      'stage': stage,
      'diagnostic_capture_failed': true,
    };
  }
}

const _diagnosticKeys = {
  'schema_version',
  'timeout_type',
  'step',
  'original_reason',
  'purchase_kind',
  'payment_outcome',
  'error_layer',
  'stack_trace',
  'api_path',
  'http_status',
  'business_code',
  'request_id',
  'client_failure_code',
  'transport_error_kind',
  'diagnostic_capture_failed',
  'stage_duration_ms',
  'total_duration_ms',
  'foreground',
  'store_handoff_started',
  'store_callback_received',
  'success_callback_received',
  'cache_hit',
  'force_refresh',
  'expected_price_amount_micros',
  'actual_price_amount_micros',
  'expected_catalog_price_amount',
  'actual_catalog_price_amount',
  'expected_currency',
  'actual_currency',
  'base_plan_id',
  'expected_store_product_id',
  'diagnostics_truncated',
  'truncated_fields',
  'provider',
  'stage',
  'error_type',
  'error_code',
  'error_source',
  'purchase_status',
  'response_code',
  'sub_response_code',
  'debug_message',
  'message',
  'native_code',
  'domain',
  'attempt_id',
  'tracking_id',
  'product_id',
  'store_product_id',
  'callback_product_id',
  'association',
  'source',
  'reason',
  'failure_reason',
  'duration_ms',
  'offer_id',
  'purchase_option_id',
  'offer_token_present',
  'billing_account_id_present',
  'purchase_token_present',
  'can_purchase',
  'price_amount_micros',
  'price_currency_code',
  'operation',
  'status',
  'result',
  'retry_count',
};
String _safeDiagnosticText(String input) {
  var value = input.replaceAll(
    RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
    'Bearer [redacted]',
  );
  value = value.replaceAllMapped(
    RegExp(
      r'''(purchaseToken|purchase_token|signedTransaction|signed_transaction|authorization|accountId|account_id|obfuscatedAccountId|receipt|token)["']?\s*[=:]\s*(?:"[^"]*"|'[^']*')''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}=[redacted]',
  );
  value = value.replaceAllMapped(
    RegExp(
      r'(purchaseToken|purchase_token|signedTransaction|signed_transaction|authorization|accountId|account_id|obfuscatedAccountId|receipt|token)["\x27]?\s*[=:]\s*["\x27]?[^\s,;\}\]"\x27]+',
      caseSensitive: false,
    ),
    (m) => '${m[1]}=[redacted]',
  );
  value = value.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    '[email]',
  );
  value = value.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    '[signed-data]',
  );
  value = value.replaceAll(RegExp(r'/Users/[^/\s]+/'), '/Users/[user]/');
  // Preserve paths and code locations; strip query strings from URLs.
  value = value.replaceAllMapped(RegExp(r'https?://[^\s<>]+'), (m) {
    final uri = Uri.tryParse(m[0]!);
    return uri == null ? '[url]' : '${uri.scheme}://${uri.host}${uri.path}';
  });
  return value;
}

String encodePaymentFailureDiagnostics(Map<String, Object?> values) {
  try {
    final output = <String, Object?>{'schema_version': 2};
    final truncated = <String>{};
    for (final entry in values.entries) {
      if (!_diagnosticKeys.contains(entry.key)) continue;
      final value = entry.key == 'provider'
          ? switch (entry.value) {
              'googlePlay' => 'google',
              'appStore' => 'apple',
              _ => entry.value,
            }
          : entry.value;
      if (value is String && value.trim().isNotEmpty) {
        final safe = _safeDiagnosticText(value);
        final limit = entry.key == 'stack_trace' ? 1400 : 700;
        output[entry.key] = safe.length > limit
            ? safe.substring(0, limit)
            : safe;
        if (safe.length > limit) truncated.add(entry.key);
      } else if (value is bool ||
          value is int ||
          (value is double && value.isFinite)) {
        output[entry.key] = value;
      }
    }
    void markTruncation() {
      if (truncated.isNotEmpty) {
        output['diagnostics_truncated'] = true;
        output['truncated_fields'] = truncated.join(',');
      }
    }

    markTruncation();
    var encoded = jsonEncode(output);
    // Keep classifier, association, source codes and useful message fragments.
    const essential = {
      'schema_version',
      'stage',
      'step',
      'reason',
      'provider',
      'purchase_kind',
      'attempt_id',
      'tracking_id',
      'product_id',
      'store_product_id',
      'error_code',
      'response_code',
      'sub_response_code',
      'native_code',
      'domain',
      'payment_outcome',
      'diagnostics_truncated',
      'truncated_fields',
    };
    for (final key in [
      'original_reason',
      'stack_trace',
      'debug_message',
      'message',
    ]) {
      if (encoded.length <= 3900) break;
      final value = output[key];
      if (value is String && value.length > 160) {
        output[key] = value.substring(0, 160);
        truncated.add(key);
        markTruncation();
        encoded = jsonEncode(output);
      }
    }
    for (final key in output.keys.toList().reversed) {
      if (encoded.length <= 3900) break;
      if (essential.contains(key)) continue;
      output.remove(key);
      truncated.add(key);
      markTruncation();
      encoded = jsonEncode(output);
    }
    if (encoded.length > 3900) {
      for (final key in output.keys.toList()) {
        if (encoded.length <= 3900) break;
        final value = output[key];
        if (value is String && value.length > 100) {
          output[key] = value.substring(0, 100);
          truncated.add(key);
          markTruncation();
          encoded = jsonEncode(output);
        }
      }
    }
    return encoded.length <= 3900
        ? encoded
        : '{"schema_version":2,"diagnostic_capture_failed":true}';
  } catch (_) {
    return '{"schema_version":2,"diagnostic_capture_failed":true}';
  }
}
