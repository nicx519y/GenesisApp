import 'package:flutter/foundation.dart';
import 'payment_failure_classification.dart';
import '../../network/models/gem_product.dart';
import 'payment_failure_diagnostics.dart';
import '../../app/telemetry/genesis_telemetry.dart';

abstract interface class BillingAnalytics {
  void track(
    String action, {
    Map<String, Object?> properties = const <String, Object?>{},
  });
}

class GenesisBillingAnalytics implements BillingAnalytics {
  const GenesisBillingAnalytics();

  @override
  void track(
    String action, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    try {
      final data = sanitizeBillingAnalyticsProperties(<String, Object?>{
        'action': action,
        ...properties,
      });
      if (data['action'] == null || data['source'] == 'from_unknown') return;
      GenesisTelemetry.event(
        'pay_event',
        category: 'billing.purchase',
        bestEffort: true,
        data: data,
        collectPayload: _billingCollectPayload(
          data,
          failureDiagnostics: properties['failure_diagnostics'],
          attemptId: properties['attempt_id'],
        ),
        eventId: data['event_id'] as String?,
      );
    } catch (_) {
      // Analytics must never interrupt billing.
    }
  }
}

Map<String, Object?> _billingCollectPayload(
  Map<String, Object?> data, {
  Object? failureDiagnostics,
  Object? attemptId,
}) {
  final action = data['action'];
  if (action is! String || action.isEmpty) return const {};

  if (action == 'purchase_success_skipped') {
    return {
      'action_type': 'monitor',
      'action': action,
      'object1': data['source'] ?? '',
      'object2': data['store_product_id'] ?? '',
      'object3': data['reason'] ?? '',
    };
  }
  if (action == 'product_click') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      'object1': data['source'] ?? '',
      'object2': data['store_product_id'] ?? '',
    };
  }
  if (action == 'purchase_success') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      'object1': data['source'] ?? '',
      'object2': data['store_product_id'] ?? '',
      if (data['transaction_id'] != null) 'object3': data['transaction_id'],
    };
  }
  if (action == 'purchase_pending') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      'object1': data['source'] ?? '',
      'object2': data['store_product_id'] ?? '',
      'object3': 'store_callback_pending',
    };
  }
  if (action == 'purchase_failed') {
    final diagnostic = <String, Object?>{
      ...data,
      'attempt_id': attemptId,
      'stage': switch (data['reason']) {
        'purchase_callback_error' ||
        'canceled' ||
        'receipt_missing' => 'callback',
        'stream_failed' => 'stream',
        'precheck_failed' => 'precheck',
        'query_failed' => 'query',
        'launch_failed' => 'launch',
        _ => 'unknown',
      },
      if (failureDiagnostics is Map<String, Object?>) ...failureDiagnostics,
    };
    final original = _purchaseFailureReason(data) ?? 'unknown';
    final classification = classifyPaymentFailure(original, diagnostic);
    return <String, Object?>{
      'action_type': 'monitor',
      'action': action,
      'object1': data['source'] ?? '',
      'object2': data['store_product_id'] ?? '',
      'object3': classification.object3,
      'ext_data': encodePaymentFailureDiagnostics({
        ...diagnostic,
        'schema_version': 2,
        'purchase_kind': 'consumable',
        'stage': classification.stage,
        'step': classification.step,
        'reason': classification.reason,
        'original_reason': original,
        'payment_outcome': classification.reason == 'canceled'
            ? 'canceled'
            : classification.reason == 'timeout' ||
                  classification.stage == 'stream' ||
                  classification.reason.contains('receipt_missing') ||
                  classification.reason == 'signed_transaction_missing'
            ? 'unknown'
            : 'failed',
      }),
    };
  }

  return const {};
}

String? _purchaseFailureReason(Map<String, Object?> data) {
  final reason = data['reason'];
  if (reason is! String || reason.isEmpty) return null;
  final stagedFailure =
      reason == 'precheck_failed' ||
      reason == 'query_failed' ||
      reason == 'launch_failed';
  final formatted = data['failure_reason'];
  if (!stagedFailure && formatted is String && formatted.isNotEmpty) {
    return formatted;
  }
  final appendsErrorCode =
      stagedFailure ||
      reason == 'purchase_callback_error' ||
      reason == 'report_failed' ||
      reason == 'report_rejected';
  if (!appendsErrorCode) {
    return reason;
  }

  final errorCode = '${data['error_code'] ?? ''}'
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (reason == 'launch_failed' && errorCode.isEmpty) return reason;
  if ((reason == 'report_failed' || reason == 'report_rejected') &&
      errorCode.isEmpty) {
    return reason;
  }
  return '$reason[${errorCode.isEmpty ? 'unknown' : errorCode}]';
}

// Billing events intentionally sanitize properties. Purchase tokens, account
// identifiers, and raw store payloads cannot pass
// through this boundary even if a caller adds them by mistake.
const Set<String> _allowedBillingAnalyticsKeys = <String>{
  'action',
  'event_id',
  'source',
  'provider',
  'product_id',
  'store_product_id',
  'trigger',
  'result',
  'status',
  'reason',
  'timeout_type',
  'duration_ms',
  'error_code',
  'failure_reason',
  'can_purchase',
  'billing_type',
  'product_type',
  'base_gems_cent',
  'bonus_gems_cent',
  'price_amount',
  'price_currency_code',
  'activity_type',
  'purchase_option_id',
  'offer_id',
  'formatted_price',
  'price_amount_micros',
  'offer_token_present',
  'billing_account_id_present',
  'purchase_status',
  'purchase_token_present',
  'transaction_id',
  'transaction_id_present',
  'operation',
  'order_status',
  'retry_count',
  'report_type',
  'order_age_ms',
  'local_order_count',
  'retry_order_count',
  'skipped_order_count',
  'google_purchase_count',
  'past_purchase_query_succeeded',
  'granted_gems_cent',
};

Map<String, Object?> sanitizeBillingAnalyticsProperties(
  Map<String, Object?> properties,
) {
  final result = <String, Object?>{};
  for (final entry in properties.entries) {
    if (!_allowedBillingAnalyticsKeys.contains(entry.key)) continue;
    final value = entry.value;
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) result[entry.key] = normalized;
    } else if (value is num || value is bool) {
      result[entry.key] = value;
    }
  }
  return result;
}

/// Called only by an explicit click's confirmation path, never by preloading.
void reportGemConfirmationFailure({
  required GemProduct product,
  required String attemptId,
  required String source,
  required String reason,
  Object? error,
  StackTrace? stackTrace,
  int? durationMs,
  List<GemProduct>? currentProducts,
}) {
  try {
    GemProduct? actual;
    if (reason == 'catalog_unavailable' && currentProducts != null) {
      final matches = currentProducts
          .where((p) => p.productId == product.productId)
          .toList();
      if (matches.isEmpty) {
        reason = 'product_not_found';
      } else if (matches.length == 1) {
        actual = matches.single;
        if (!actual.canPurchase) {
          reason = 'product_not_purchasable';
        } else if (actual.appleProductId != product.appleProductId ||
            actual.googleProductId != product.googleProductId ||
            actual.billingType != product.billingType) {
          reason = 'product_config_invalid';
        } else if (actual.googleOfferId != product.googleOfferId ||
            actual.googlePurchaseOptionId != product.googlePurchaseOptionId) {
          reason = 'offer_mismatch';
        } else if (actual.storeFormattedPrice != null &&
            (actual.displaysStorePrice != product.displaysStorePrice ||
                (product.displaysStorePrice
                    ? actual.storeAmountMicros != product.storeAmountMicros ||
                          actual.storeCurrencyCode != product.storeCurrencyCode
                    : actual.priceAmount != product.priceAmount ||
                          actual.priceCurrencyCode !=
                              product.priceCurrencyCode))) {
          reason = 'price_changed';
        }
      }
    }
    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: {
        'product_id': product.productId,
        'store_product_id': defaultTargetPlatform == TargetPlatform.iOS
            ? product.appleProductId
            : product.googleProductId,
        'attempt_id': attemptId,
        'source': source,
        'reason': 'query_failed',
        'error_code': reason,
        'failure_diagnostics': paymentFailureDiagnostics(
          provider: defaultTargetPlatform == TargetPlatform.iOS
              ? 'apple'
              : defaultTargetPlatform == TargetPlatform.android
              ? 'google'
              : 'unknown',
          stage: 'query',
          error: error,
          stackTrace: stackTrace,
          context: {
            'step': 'confirm_product',
            'error_code': reason,
            'source': source,
            'total_duration_ms': durationMs,
            if (actual != null) ...{
              'expected_price_amount_micros': product.storeAmountMicros,
              'actual_price_amount_micros': actual.storeAmountMicros,
              'expected_catalog_price_amount': product.priceAmount,
              'actual_catalog_price_amount': actual.priceAmount,
              'expected_currency': product.displaysStorePrice
                  ? product.storeCurrencyCode
                  : product.priceCurrencyCode,
              'actual_currency': actual.displaysStorePrice
                  ? actual.storeCurrencyCode
                  : actual.priceCurrencyCode,
              'expected_store_product_id':
                  defaultTargetPlatform == TargetPlatform.iOS
                  ? product.appleProductId
                  : product.googleProductId,
              'can_purchase': actual.canPurchase,
            },
          },
        ),
      },
    );
  } catch (_) {
    /* Diagnostics cannot change a checkout result. */
  }
}

void reportGemConfirmationTimeout({
  required GemProduct product,
  required String attemptId,
  String source = '',
}) {
  try {
    const GenesisBillingAnalytics().track(
      'purchase_failed',
      properties: {
        'product_id': product.productId,
        'source': source,
        'store_product_id': defaultTargetPlatform == TargetPlatform.iOS
            ? product.appleProductId
            : product.googleProductId,
        'attempt_id': attemptId,
        'reason': 'timeout',
        'timeout_type': 'prepare',
        'failure_diagnostics': {'stage': 'query', 'step': 'confirm_product'},
      },
    );
  } catch (_) {
    /* Never affect the existing timeout handling. */
  }
}
