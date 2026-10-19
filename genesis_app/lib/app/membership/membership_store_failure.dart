import '../../l10n/genesis_l10n.dart';
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
                GenesisL10n.current.premiumGooglePlayFailedComplete
          : membershipAppleErrorMessages[code] ??
                GenesisL10n.current.premiumAppStoreFailedComplete);
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
    final debugMessage =
        values['debugMessage'] ?? (details is String ? details : message);
    if (normalized == 'developer_error' &&
        debugMessage is String &&
        debugMessage.trim() == membershipAccountIdentifiersMismatchMessage) {
      normalized = 'account_identifiers_mismatch';
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

String get membershipAccountIdentifiersMismatchMessage =>
    GenesisL10n.current.premiumAccountMismatch;

Map<String, String> get membershipGoogleErrorMessages => <String, String>{
  'service_timeout':
      GenesisL10n.current.premiumGooglePlayTookTooLong,
  'feature_not_supported':
      GenesisL10n.current.premiumSubscriptionsNotSupported,
  'service_disconnected':
      GenesisL10n.current.premiumConnectionGooglePlayLost,
  'user_canceled': GenesisL10n.current.premiumPurchaseCanceled,
  'service_unavailable':
      GenesisL10n.current.premiumGooglePlayTemporarily,
  'billing_unavailable':
      GenesisL10n.current.premiumGooglePlayBilling,
  'item_unavailable':
      GenesisL10n.current.premiumSubscriptionUnavailable,
  'developer_error': GenesisL10n.current.premiumPurchaseCanceled,
  'account_identifiers_mismatch': membershipAccountIdentifiersMismatchMessage,
  'error': GenesisL10n.current.premiumGooglePlayFailedComplete,
  'item_already_owned':
      GenesisL10n.current.premiumAlreadyOwnSubscription,
  'item_not_owned':
      GenesisL10n.current.premiumGooglePlayFailedFind,
  'network_error': GenesisL10n.current.premiumFailedConnectGooglePlay,
  'insufficient_funds':
      GenesisL10n.current.premiumInsufficientFunds,
  'user_ineligible':
      GenesisL10n.current.premiumGoogleAccountIneligible,
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

Map<String, String> get membershipAppleErrorMessages => <String, String>{
  'unknown': GenesisL10n.current.premiumAppStoreFailedComplete,
  'user_cancelled': GenesisL10n.current.premiumPurchaseCanceled,
  'network_error': GenesisL10n.current.premiumFailedConnectAppStore,
  'network_timeout': GenesisL10n.current.premiumAppStoreTookTooLong,
  'system_error':
      GenesisL10n.current.premiumAppStoreEncounteredSystem,
  'not_available_in_storefront':
      GenesisL10n.current.premiumRegionUnavailable,
  'not_entitled': GenesisL10n.current.premiumAppCannotMakeStoreRequest,
  'unsupported': GenesisL10n.current.premiumPurchaseNotSupported,
  'invalid_presentation_context':
      GenesisL10n.current.premiumAppStorePurchaseWindow,
  'invalid_quantity':
      GenesisL10n.current.premiumAppStoreFailedAccept,
  'product_unavailable':
      GenesisL10n.current.premiumAppStoreUnavailable,
  'purchase_not_allowed':
      GenesisL10n.current.premiumPurchasesNotAllowedDevice,
  'ineligible_for_offer':
      GenesisL10n.current.premiumAppleAccountNotEligible,
  'invalid_offer_identifier':
      GenesisL10n.current.premiumSubscriptionOffer,
  'invalid_offer_price':
      GenesisL10n.current.premiumAppStoreFailedAcceptOffer,
  'invalid_offer_signature':
      GenesisL10n.current.premiumAppStoreFailedVerify,
  'missing_offer_parameters':
      GenesisL10n.current.premiumSubscriptionOfferFailed,
  'payment_method_binding_configuration_required':
      GenesisL10n.current.premiumAddPaymentMethodApple,
  'client_invalid':
      GenesisL10n.current.premiumAppCannotMakePurchases,
  'payment_cancelled':
      GenesisL10n.current.premiumPurchaseCanceled,
  'payment_invalid':
      GenesisL10n.current.premiumAppStoreRequestRejected,
  'payment_not_allowed':
      GenesisL10n.current.premiumPurchasesNotAllowedDevice,
  'store_product_not_available':
      GenesisL10n.current.premiumRegionUnavailable,
  'cloud_service_permission_denied':
      GenesisL10n.current.premiumAppleCloudServiceAccess,
  'cloud_service_network_connection_failed':
      GenesisL10n.current.premiumFailedConnectApple,
  'cloud_service_revoked':
      GenesisL10n.current.premiumAccess2AppleCloudService,
  'privacy_acknowledgement_required':
      GenesisL10n.current.premiumAcceptLatestApplePrivacy,
  'unauthorized_request_data':
      GenesisL10n.current.premiumAppCannotMakeStoreRequest,
  'invalid_signature':
      GenesisL10n.current.premiumAppStoreFailedVerify,
  'missing_offer_params':
      GenesisL10n.current.premiumSubscriptionOfferFailed,
  'overlay_cancelled':
      GenesisL10n.current.premiumPurchaseCanceled,
  'overlay_invalid_configuration':
      GenesisL10n.current.premiumAppStoreWindowFailed,
  'overlay_timeout':
      GenesisL10n.current.premiumAppStoreWindowTookTooLong,
  'unsupported_platform':
      GenesisL10n.current.premiumPurchaseNotSupported,
  'overlay_presented_in_background_scene':
      GenesisL10n.current.premiumReturnAppTryPurchase,
};

Map<String, String> get membershipLocalStoreMessages => <String, String>{
  'store_unavailable':
      GenesisL10n.current.premiumGooglePlayUnavailable,
  'membership_product_not_found':
      GenesisL10n.current.premiumIs4Subscription,
  'invalid_membership_product':
      GenesisL10n.current.premiumSubscriptionFailed,
  'membership_launch_rejected':
      GenesisL10n.current.premiumStoreFailedOpenPurchase,
  'membership_upgrade_purchase_missing':
      GenesisL10n.current.premiumOriginalSubscriptionMissing,
  'membership_upgrade_account_mismatch':
      GenesisL10n.current.premiumSubscriptionUsesDifferent,
  'membership_upgrade_not_ready':
      GenesisL10n.current.premiumGooglePlayCannotChange,
  'storekit_duplicate_product_object':
      GenesisL10n.current.premiumPlanChangePending,
  'storekit2_failed_to_fetch_product':
      GenesisL10n.current.premiumAppStoreUnavailable,
  'storekit2_products_error':
      GenesisL10n.current.premiumFailedLoadPlansAppStore,
  'purchase_preparation_expired': GenesisL10n
      .current
      .premiumPurchasePreparation,
  'storekit2_unknown_purchase_result':
      GenesisL10n.current.premiumAppStoreReturnedUnknown,
};
