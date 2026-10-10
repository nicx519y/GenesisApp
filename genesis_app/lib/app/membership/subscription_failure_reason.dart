import 'dart:async';

import '../../network/api_exception.dart';
import '../../network/models/membership_product.dart';
import '../../platform/billing/billing_models.dart';
import '../../platform/billing/billing_store_failure_reason.dart';

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
  return billingStoreFailureReason(
    provider == MembershipProvider.google
        ? BillingProvider.googlePlay
        : BillingProvider.appStore,
    error: error,
    code: code,
    source: source,
    details: details,
    stage: stage,
    status: status,
    sdkFailureReason: (sdkCode, sdkError, _) {
      // These are our own prechecks, not codes supplied by a store SDK.
      switch (sdkCode) {
        case 'store_unavailable':
        case 'purchase_not_allowed':
          if (sdkError is BillingPlatformException) {
            return 'service_unavailable';
          }
        case 'membership_product_not_found':
        case 'invalid_membership_product':
          return 'catalog_unavailable';
        case 'membership_launch_rejected':
          return 'store_failure[stage=launch]';
      }
      return null;
    },
  );
}
