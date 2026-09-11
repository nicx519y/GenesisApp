import '../../network/models/membership_product.dart';
import '../../platform/billing/purchase_toast_diagnostics.dart';

class MembershipPurchaseBlocked implements Exception {
  const MembershipPurchaseBlocked(this.reason);
  final String reason;
}

String? membershipPurchaseBlockReason(
  MembershipProduct product,
  MembershipVipStatus vipStatus,
) => switch (vipStatus) {
  MembershipVipStatus.yearly => 'already_subscribed',
  MembershipVipStatus.monthly when !product.isYearly => 'already_subscribed',
  _ => null,
};

String membershipPurchaseFailureMessage(String reason, {String? debugInfo}) {
  final message = switch (reason) {
    'already_subscribed' => 'You already have an active Premium subscription.',
    'downgrade_not_allowed' =>
      'An active yearly Premium subscription cannot be changed to a monthly plan.',
    'purchase_processing' =>
      'Your previous Premium purchase is still being confirmed.',
    'cross_platform_upgrade_not_allowed' =>
      'Please use the original store to upgrade your Premium subscription.',
    'subscription_requires_action' =>
      'Please resolve your current subscription in the store before purchasing.',
    'sale_disabled' => 'Premium purchase is currently unavailable.',
    'device_id_required' || 'eligibility_unavailable' =>
      'Unable to verify Premium purchase eligibility. Please try again.',
    'account_mismatch' =>
      'This Premium purchase belongs to a different account.',
    'invalid_purchase' => 'The store could not verify this Premium purchase.',
    'product_mismatch' =>
      'The Premium purchase does not match the selected plan.',
    'purchase_canceled' => 'This Premium purchase was canceled.',
    'purchase_revoked' => 'This Premium purchase was revoked.',
    _ => 'Premium purchase failed.',
  };
  return purchaseToastMessage(
    message,
    debugInfo:
        debugInfo ?? purchaseDebugInfo('vip.eligibility', reason: reason),
  );
}
