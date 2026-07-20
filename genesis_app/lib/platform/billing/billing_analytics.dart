import 'dart:convert';

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
    final data = sanitizeBillingAnalyticsProperties(<String, Object?>{
      'action': action,
      ...properties,
    });
    if (data['action'] == null) return;
    try {
      GenesisTelemetry.event(
        'pay_event',
        category: 'billing.purchase',
        data: data,
        collectPayload: _billingCollectPayload(data),
      );
    } catch (_) {
      // Analytics must never interrupt billing.
    }
  }
}

Map<String, Object?> _billingCollectPayload(Map<String, Object?> data) {
  final action = data['action'];
  if (action is! String || action.isEmpty) return const {};

  final productId = data['product_id'] ?? data['store_product_id'];
  if (action == 'product_click') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      if (productId != null) 'object1': productId,
      if (data['attempt_id'] != null) 'object2': data['attempt_id'],
      if (data['source'] != null) 'object3': data['source'],
    };
  }
  if (action == 'success') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      if (productId != null) 'object1': productId,
      if (data['attempt_id'] != null) 'object2': data['attempt_id'],
    };
  }
  if (action == 'failed') {
    return <String, Object?>{
      'action_type': 'pay_event',
      'action': action,
      if (productId != null) 'object1': productId,
      if (data['attempt_id'] != null) 'object2': data['attempt_id'],
      if (data['reason'] != null) 'object3': data['reason'],
    };
  }

  final details = Map<String, Object?>.of(data)
    ..remove('action')
    ..remove('product_id')
    ..remove('attempt_id');

  return <String, Object?>{
    'action_type': 'pay_event',
    'action': action,
    if (productId != null) 'object1': productId,
    if (data['attempt_id'] != null) 'object2': data['attempt_id'],
    if (details.isNotEmpty) 'object3': jsonEncode(details),
  };
}

// Billing events intentionally use an allowlist. Purchase tokens, account
// identifiers, transaction identifiers, and raw store payloads cannot pass
// through this boundary even if a caller adds them by mistake.
const Set<String> _allowedBillingAnalyticsKeys = <String>{
  'action',
  'attempt_id',
  'source',
  'provider',
  'product_id',
  'store_product_id',
  'trigger',
  'result',
  'status',
  'reason',
  'duration_ms',
  'error_code',
  'can_purchase',
  'billing_type',
  'product_type',
  'base_gems',
  'bonus_gems',
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
  'granted_gems',
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
