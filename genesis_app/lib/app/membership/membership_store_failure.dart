import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../network/models/membership_product.dart';
import '../../platform/billing/billing_models.dart';

/// A store failure belongs to the current checkout, never to a persisted order.
class MembershipStoreFailure {
  const MembershipStoreFailure(this.provider, this.code);
  final MembershipProvider provider;
  final String code;

  bool get canceled => const {
    'user_canceled',
    'user_cancelled',
    'payment_cancelled',
    'overlay_cancelled',
  }.contains(code);

  String get message =>
      membershipLocalStoreMessages[code] ??
      (provider == MembershipProvider.google
          ? membershipGoogleErrorMessages[code] ??
                'Google Play could not complete this VIP purchase. Please try again.'
          : membershipAppleErrorMessages[code] ??
                'The App Store could not complete this VIP purchase. Please try again.');
}

MembershipStoreFailure? membershipStoreFailure(
  MembershipProvider provider,
  Object error,
) => switch (error) {
  PlatformException() => membershipStoreError(
    provider,
    code: error.code,
    message: error.message,
    details: error.details,
  ),
  IAPError() => membershipStoreError(
    provider,
    code: error.code,
    message: error.message,
    details: error.details,
  ),
  BillingPlatformException() => membershipStoreError(
    provider,
    code: error.code,
    message: error.message,
    details: error.details,
  ),
  _ => null,
};

MembershipStoreFailure membershipStoreError(
  MembershipProvider provider, {
  String? code,
  String? message,
  Object? details,
}) {
  if (kDebugMode) {
    debugPrint(
      '[Membership][store_error] provider=${provider.name}; code=$code; message=$message; details=$details',
    );
  }
  final values = details is Map ? details : const {};
  var normalized = _normalize(code ?? 'unknown');
  if (provider == MembershipProvider.google) {
    final raw =
        values['responseCode'] ??
        ((message ?? '').startsWith('BillingResponse.')
            ? message!.substring('BillingResponse.'.length)
            : code);
    normalized =
        membershipGoogleResponseCodes[int.tryParse('$raw')] ??
        _normalize('$raw');
    // Cancellation is intentional and should not be replaced by a stale subcode.
    if (normalized != 'user_canceled' && normalized != 'ok') {
      normalized = switch (int.tryParse('${values['subResponseCode']}')) {
        1 => 'insufficient_funds',
        2 => 'user_ineligible',
        _ => normalized,
      };
    }
  } else {
    final typed = values['storeKitCode'];
    if (typed is String) normalized = _normalize(typed);
    // Specific StoreKit cases win; a system/unknown wrapper may contain SKError
    // or URLError, whose numeric code is meaningful only within its own domain.
    if (typed == null ||
        const {
          'system_error',
          'unknown',
          'network_error',
        }.contains(normalized)) {
      for (final (domain, nativeCode) in [
        (values['domain'], values['nativeCode']),
        (values['underlyingDomain'], values['underlyingCode']),
      ]) {
        final number = int.tryParse('$nativeCode');
        if (domain == 'SKErrorDomain') {
          normalized = membershipAppleNativeCodes[number] ?? 'unknown';
          if (normalized != 'unknown') break;
        } else if (domain == 'NSURLErrorDomain') {
          normalized = number == -1001 ? 'network_timeout' : 'network_error';
          break;
        }
      }
    }
  }
  return MembershipStoreFailure(provider, normalized);
}

String _normalize(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase();

const membershipGoogleResponseCodes = <int, String>{
  -3: 'service_timeout',
  -2: 'feature_not_supported',
  -1: 'service_disconnected',
  0: 'ok',
  1: 'user_canceled',
  2: 'service_unavailable',
  3: 'billing_unavailable',
  4: 'item_unavailable',
  5: 'developer_error',
  6: 'error',
  7: 'item_already_owned',
  8: 'item_not_owned',
  12: 'network_error',
};

const membershipGoogleErrorMessages = <String, String>{
  'service_timeout': 'Google Play took too long to respond. Please try again.',
  'feature_not_supported':
      'Subscriptions are not supported by Google Play on this device.',
  'service_disconnected':
      'The connection to Google Play was lost. Please try again.',
  'user_canceled': 'VIP purchase cancelled.',
  'service_unavailable':
      'Google Play is temporarily unavailable. Please try again later.',
  'billing_unavailable':
      'Google Play billing is unavailable. Please check your Play account and payment settings.',
  'item_unavailable': 'This VIP plan is currently unavailable on Google Play.',
  'developer_error':
      'Google Play could not start this subscription purchase. Please contact support if this continues.',
  'error':
      'Google Play could not complete this VIP purchase. Please try again.',
  'item_already_owned':
      'You already own this subscription on Google Play. Please check Manage subscriptions.',
  'item_not_owned':
      'Google Play could not find the subscription to change. Please check Manage subscriptions.',
  'network_error':
      'Could not connect to Google Play. Please check your internet connection and try again.',
  'insufficient_funds':
      'Your payment method has insufficient funds. Please update it in Google Play and try again.',
  'user_ineligible':
      'Your Google Play account is not eligible for this subscription offer.',
};

const membershipAppleNativeCodes = <int, String>{
  0: 'unknown',
  1: 'client_invalid',
  2: 'payment_cancelled',
  3: 'payment_invalid',
  4: 'payment_not_allowed',
  5: 'store_product_not_available',
  6: 'cloud_service_permission_denied',
  7: 'cloud_service_network_connection_failed',
  8: 'cloud_service_revoked',
  9: 'privacy_acknowledgement_required',
  10: 'unauthorized_request_data',
  11: 'invalid_offer_identifier',
  12: 'invalid_signature',
  13: 'missing_offer_params',
  14: 'invalid_offer_price',
  15: 'overlay_cancelled',
  16: 'overlay_invalid_configuration',
  17: 'overlay_timeout',
  18: 'ineligible_for_offer',
  19: 'unsupported_platform',
  20: 'overlay_presented_in_background_scene',
  21: 'payment_method_binding_configuration_required',
};

const membershipAppleErrorMessages = <String, String>{
  'unknown':
      'The App Store could not complete this VIP purchase. Please try again.',
  'user_cancelled': 'VIP purchase cancelled.',
  'network_error':
      'Could not connect to the App Store. Please check your internet connection and try again.',
  'network_timeout':
      'The App Store took too long to respond. Please try again.',
  'system_error':
      'The App Store encountered a system error. Please try again later.',
  'not_available_in_storefront':
      'This VIP plan is not available in your App Store region.',
  'not_entitled':
      'This app cannot make this App Store request. Please contact support.',
  'unsupported':
      'This purchase is not supported on this device or system version.',
  'invalid_presentation_context':
      'The App Store purchase window could not open. Please return to the app and try again.',
  'invalid_quantity':
      'The App Store could not accept this purchase quantity. Please contact support.',
  'product_unavailable':
      'This VIP plan is currently unavailable on the App Store.',
  'purchase_not_allowed':
      'Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions.',
  'ineligible_for_offer':
      'Your Apple Account is not eligible for this subscription offer.',
  'invalid_offer_identifier':
      'This subscription offer is unavailable. Please refresh the page and try again.',
  'invalid_offer_price':
      'The App Store could not accept this offer price. Please refresh the page and try again.',
  'invalid_offer_signature':
      'The App Store could not verify this subscription offer. Please contact support.',
  'missing_offer_parameters':
      'This subscription offer could not be prepared. Please refresh the page and try again.',
  'payment_method_binding_configuration_required':
      'Please add a payment method to your Apple Account, then try again.',
  'client_invalid':
      'This app cannot make purchases on the App Store. Please contact support.',
  'payment_cancelled': 'VIP purchase cancelled.',
  'payment_invalid':
      'The App Store could not accept this purchase request. Please try again or contact support.',
  'payment_not_allowed':
      'Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions.',
  'store_product_not_available':
      'This VIP plan is not available in your App Store region.',
  'cloud_service_permission_denied':
      'Apple cloud service access was denied. Please check your Apple Account permissions.',
  'cloud_service_network_connection_failed':
      'Could not connect to Apple services. Please check your internet connection and try again.',
  'cloud_service_revoked':
      'Apple cloud service access was revoked. Please check your Apple Account settings.',
  'privacy_acknowledgement_required':
      'Please accept the latest Apple privacy terms in your Apple Account, then try again.',
  'unauthorized_request_data':
      'This app cannot make this App Store request. Please contact support.',
  'invalid_signature':
      'The App Store could not verify this subscription offer. Please contact support.',
  'missing_offer_params':
      'This subscription offer could not be prepared. Please refresh the page and try again.',
  'overlay_cancelled': 'VIP purchase cancelled.',
  'overlay_invalid_configuration':
      'The App Store window could not be configured. Please contact support.',
  'overlay_timeout':
      'The App Store window took too long to open. Please try again.',
  'unsupported_platform':
      'This purchase is not supported on this device or system version.',
  'overlay_presented_in_background_scene':
      'Please return to the app and try your purchase again.',
};

const membershipLocalStoreMessages = <String, String>{
  'store_unavailable':
      'Google Play is unavailable. Please check that it is installed and you are signed in.',
  'membership_product_not_found':
      'This VIP plan is currently unavailable in the store. Please refresh the page and try again.',
  'invalid_membership_product':
      'This VIP plan could not be prepared. Please refresh the page and try again.',
  'membership_launch_rejected':
      'The store could not open this VIP purchase. Please try again.',
  'membership_upgrade_purchase_missing':
      'The original subscription was not found in Google Play. Please check Manage subscriptions.',
  'membership_upgrade_account_mismatch':
      'This subscription uses a different purchase identity. Please refresh the page or contact support.',
  'membership_upgrade_not_ready':
      'Google Play cannot change this subscription yet. Please check Manage subscriptions.',
  'storekit_duplicate_product_object':
      'An App Store purchase for this plan is still being processed. Please wait for it to finish.',
  'storekit2_failed_to_fetch_product':
      'This VIP plan is currently unavailable on the App Store.',
  'storekit2_products_error':
      'Could not load VIP plans from the App Store. Please try again.',
  'purchase_preparation_expired':
      'Purchase preparation expired. Please try again.',
  'storekit2_unknown_purchase_result':
      'The App Store returned an unknown purchase result. Please check your subscription before trying again.',
};
