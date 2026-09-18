import 'membership_access_store.dart';
import 'membership_store_failure.dart';
import '../../network/models/membership_product.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';

class MembershipPurchaseBlocked implements Exception {
  const MembershipPurchaseBlocked(this.reason);
  final String reason;
}

/// The active wallet membership matches the currently selected plan.
bool membershipHasSelectedPlan(
  MembershipProduct product,
  MembershipAccessState access,
) => access.isVip == true && access.membership?.planCode == product.planCode;

/// A selected plan that is active and set to renew is already subscribed.
///
/// The subscription page uses this same condition for its `Subscribed` label
/// and its local purchase interception, so iOS and Android behave identically.
bool membershipIsSubscribedToSelectedPlan(
  MembershipProduct product,
  MembershipAccessState access,
) =>
    membershipHasSelectedPlan(product, access) &&
    access.membership?.autoRenew == true;

/// Wallet membership is authoritative; only an active yearly plan blocks monthly.
bool membershipIsDowngrade(
  MembershipProduct product,
  MembershipAccessState access,
) =>
    !product.isYearly &&
    access.isVip == true &&
    access.membership?.planCode == 'pro_yearly';

String membershipPurchaseFailureMessage(
  String reason, {
  MembershipProduct? product,
  String? debugInfo,
}) {
  final message = switch (reason) {
    'downgrade_not_allowed' =>
      'An active yearly Premium subscription cannot be changed to a monthly plan.',
    'already_subscribed' =>
      product == null
          ? 'You already have an active Premium subscription.'
          : 'You’re already subscribed to Premium ${product.label}.',
    'purchase_processing' =>
      'Your previous Premium purchase is still being confirmed.',
    'cross_platform_upgrade_not_allowed' =>
      'Please use the original store to upgrade your Premium subscription.',
    'subscription_requires_action' =>
      'Please resolve your current subscription in the store before purchasing.',
    'sale_disabled' => 'Premium purchase is currently unavailable.',
    'device_id_required' || 'eligibility_unavailable' =>
      'Unable to verify purchase eligibility. Please try again.',
    'account_mismatch' => membershipAccountIdentifiersMismatchMessage,
    'invalid_purchase' => 'The store could not verify this Premium purchase.',
    'product_mismatch' =>
      'The Premium purchase does not match the selected plan.',
    'purchase_canceled' => 'This Premium purchase was canceled.',
    'purchase_revoked' => 'This Premium purchase was revoked.',
    _ => 'Purchase failed.',
  };
  return purchaseToastMessage(
    message,
    debugInfo:
        debugInfo ?? purchaseDebugInfo('vip.eligibility', reason: reason),
  );
}
