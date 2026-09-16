import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../network/api_exception.dart';
import '../../network/models/membership_product.dart';
import '../../platform/billing/billing_models.dart';

bool subscriptionRequestTimedOut(Object error) =>
    error is TimeoutException ||
    error is ApiException &&
        (error.kind == ApiExceptionKind.timeout ||
            error.transportErrorKind == TransportErrorKind.timeout);

String subscriptionRequestFailure(String reason, Object error) {
  final code = error is ApiException
      ? error.code ?? error.clientFailureCode?.value ?? error.statusCode
      : null;
  return code == null ? reason : '$reason[$code]';
}

/// Only explicit structured codes cross this boundary. Never parse messages,
/// normalize native codes for UI, or serialize arbitrary exception details.
String? subscriptionStoreFailureReason(
  MembershipProvider provider, {
  Object? error,
  String? code,
  String? source,
  Object? details,
  required String stage,
  String? status,
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

  if (provider == MembershipProvider.google) {
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
    // These are our own prechecks, not codes supplied by a store SDK.
    switch (sdkCode) {
      case 'store_unavailable':
      case 'purchase_not_allowed':
        if (error is BillingPlatformException) return 'service_unavailable';
      case 'membership_product_not_found':
      case 'invalid_membership_product':
        return 'catalog_unavailable';
      case 'membership_launch_rejected':
        return 'store_failure[stage=launch]';
    }
    final sdkSource = field(source);
    return 'sdk[${sdkSource == null ? '' : 'source=$sdkSource;'}code=$sdkCode]';
  }
  if (status != null) return 'store_failure[stage=$stage;status=$status]';
  return null;
}
