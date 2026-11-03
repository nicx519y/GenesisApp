/// Telemetry-only classification. Never used to decide checkout behavior.
class PaymentFailureClassification {
  const PaymentFailureClassification(this.stage, this.reason, this.step);
  final String stage;
  final String reason;
  final String step;
  String get object3 => '${stage}_failed[reason=$reason]';
}

PaymentFailureClassification classifyPaymentFailure(
  String original,
  Map<String, Object?> diagnostic,
) {
  String text(String key) => diagnostic[key]?.toString() ?? '';
  var step = text('step');
  final suppliedStage = text('stage');
  if (suppliedStage == 'report') {
    final match = RegExp(
      r'^report_(?:rejected|failed)\[([^\]]+)\]$',
    ).firstMatch(original);
    final reason = match?.group(1)?.split('[').first ?? 'unknown';
    return PaymentFailureClassification(
      'report',
      reason,
      step.isEmpty ? 'purchase_report' : step,
    );
  }
  if (step.isEmpty) step = suppliedStage;
  var raw = original;
  for (final prefix in [
    'precheck_failed',
    'prepare_failed',
    'query_failed',
    'launch_failed',
    'callback_failed',
    'stream_failed',
  ]) {
    if (raw.startsWith('$prefix[') && raw.endsWith(']')) {
      raw = raw.substring(prefix.length + 1, raw.length - 1);
      if (raw.startsWith('reason=')) raw = raw.substring(7);
      break;
    }
  }
  if (raw == 'precheck_failed') raw = text('error_code');
  var stage = switch (suppliedStage) {
    'read_session' || 'check_membership' => 'precheck',
    'prepare_guest' ||
    'load_account_uuid' ||
    'load_local_orders' ||
    'prepare_order' ||
    'persist_guest_identity' ||
    'start_store_listener' ||
    'prepare_store_checkout' => 'prepare',
    'query_store_product' || 'read_catalog' || 'confirm_product' => 'query',
    'launch_store' => 'launch',
    'precheck' ||
    'prepare' ||
    'query' ||
    'launch' ||
    'callback' ||
    'stream' => suppliedStage,
    _ => '',
  };
  if (stage.isEmpty) {
    for (final candidate in [
      'precheck',
      'prepare',
      'query',
      'launch',
      'callback',
      'stream',
    ]) {
      if (original.startsWith('${candidate}_failed')) stage = candidate;
    }
  }
  if (original.startsWith('store_failure[stage=stream')) stage = 'stream';
  if (original.startsWith('store_failure[stage=callback')) stage = 'callback';
  final reasonRoot = raw.split('[').first;
  if ({
    'uuid_unavailable',
    'guest_prepare_failed',
    'local_storage_failed',
    'service_unavailable',
    'gp_unavailable',
  }.contains(reasonRoot)) {
    stage = 'prepare';
  }
  if (raw == 'receipt_missing' || raw == 'signed_transaction_missing') {
    stage = 'callback';
  }
  if (raw == 'store_price_changed') stage = 'query';
  if (stage.isEmpty) stage = 'unknown';
  final code = text('error_code');
  final specific =
      raw.startsWith('sdk[') || raw == 'query_failed' || raw == 'launch_failed'
      ? code
      : reasonRoot;
  var reason = switch (specific) {
    'gp_unavailable' => 'service_unavailable',
    'store_product_id_missing' ||
    'unsupported_product_type' ||
    'invalid_membership_product' => 'product_config_invalid',
    'membership_product_not_found' => 'product_not_found',
    'invalid_app_store_product' ||
    'invalid_google_product' => 'invalid_native_product',
    'store_price_changed' => 'price_changed',
    'purchase_rejected' || 'membership_launch_rejected' => 'launch_rejected',
    'service_unavailable' when step == 'start_store_listener' =>
      'listener_start_failed',
    'purchase_in_progress' ||
    'session_unavailable' ||
    'membership_check_failed' ||
    'downgrade_not_allowed' ||
    'provider_mismatch' ||
    'uuid_unavailable' ||
    'guest_prepare_failed' ||
    'local_storage_failed' ||
    'service_unavailable' ||
    'listener_start_failed' ||
    'catalog_unavailable' ||
    'product_not_found' ||
    'product_not_purchasable' ||
    'product_config_invalid' ||
    'price_changed' ||
    'offer_mismatch' ||
    'product_details_changed' ||
    'launch_rejected' ||
    'invalid_native_product' ||
    'receipt_missing' ||
    'signed_transaction_missing' ||
    'store_query_error' ||
    'store_launch_error' ||
    'store_error' ||
    'result_conversion_error' ||
    'upstream_stream_error' ||
    'unknown_stream_error' ||
    'canceled' => specific,
    _ => switch (stage) {
      'query' => 'store_query_error',
      'launch' => 'store_launch_error',
      'callback' => 'store_error',
      'stream' => 'unknown_stream_error',
      'prepare' => 'unknown_prepare_error',
      'precheck' => 'unknown_precheck_error',
      _ => 'unknown_error',
    },
  };
  if (stage == 'callback' &&
      (text('purchase_status') == 'canceled' ||
          raw == 'canceled' ||
          original.contains('status=canceled') ||
          text('response_code') == 'userCanceled')) {
    reason = 'canceled';
  }
  if (stage == 'stream' &&
      {
        'TypeError',
        '_TypeError',
        'FormatException',
      }.contains(text('error_type'))) {
    reason = 'result_conversion_error';
  }
  if (step.isEmpty) step = stage;
  return PaymentFailureClassification(stage, reason, step);
}
