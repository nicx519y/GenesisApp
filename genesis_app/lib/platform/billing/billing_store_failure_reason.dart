import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_models.dart';

typedef BillingSdkFailureReason =
    String? Function(String code, Object? error, String stage);

/// Formats only explicit, structured store diagnostics.
///
/// Human-readable messages and arbitrary exception details intentionally never
/// cross this analytics boundary because they can be localized or contain
/// sensitive data.
String? billingStoreFailureReason(
  BillingProvider provider, {
  Object? error,
  String? code,
  String? source,
  Object? details,
  required String stage,
  String? status,
  BillingSdkFailureReason? sdkFailureReason,
}) {
  if (error is IAPError) {
    code = error.code;
    source = error.source;
    details = error.details;
  } else if (error is PlatformException) {
    code = error.code;
    details = error.details;
  } else if (error is BillingPlatformException) {
    code = error.code;
    details = error.details;
  }
  final values = details is Map ? details : const {};
  String? field(Object? value) {
    if (value is! String && value is! num) return null;
    final text = '$value'.trim();
    return RegExp(r'^[A-Za-z0-9_.-]{1,128}$').hasMatch(text) ? text : null;
  }

  if (provider == BillingProvider.googlePlay) {
    final response = field(values['responseCode']);
    if (response != null && response != 'ok' && response != '0') {
      final sub = field(values['subResponseCode']);
      return 'google[response_code=$response${sub == null ? '' : ';sub_response_code=$sub'}]';
    }
  } else {
    final nativeCode = field(values['nativeCode']);
    if (nativeCode != null) {
      final domain = field(values['domain']);
      return 'apple[${domain == null ? '' : 'domain=$domain;'}code=$nativeCode]';
    }
  }
  final sdkCode = field(code);
  if (sdkCode != null) {
    final mapped = sdkFailureReason?.call(sdkCode, error, stage);
    if (mapped != null) return mapped;
    final sdkSource = field(source);
    return 'sdk[${sdkSource == null ? '' : 'source=$sdkSource;'}code=$sdkCode]';
  }
  if (status != null) return 'store_failure[stage=$stage;status=$status]';
  return null;
}
