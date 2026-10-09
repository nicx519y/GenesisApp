import '../../l10n/genesis_l10n.dart';
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
      GenesisL10n
          .current
          .premiumActiveYearlySubscription,
    'already_subscribed' =>
      product == null
          ? GenesisL10n
                .current
                .premiumAlreadyHaveActive
          : GenesisL10n.current
                .premiumReAlreadySubscribedLabel(
                  label: (product.label).toString(),
                ),
    'purchase_processing' =>
      GenesisL10n
          .current
          .premiumPreviousPurchasePending,
    'cross_platform_upgrade_not_allowed' =>
      GenesisL10n
          .current
          .premiumUseOriginalStoreUpgrade,
    'subscription_requires_action' =>
      GenesisL10n
          .current
          .premiumResolveCurrent,
    'sale_disabled' =>
      GenesisL10n
          .current
          .premiumPurchaseUnavailable,
    'device_id_required' || 'eligibility_unavailable' =>
      GenesisL10n
          .current
          .premiumUnableVerifyPurchase,
    'account_mismatch' => membershipAccountIdentifiersMismatchMessage,
    'invalid_purchase' =>
      GenesisL10n
          .current
          .premiumStoreFailedVerifyPurchase,
    'product_mismatch' =>
      GenesisL10n
          .current
          .premiumPurchaseDoesNotMatch,
    'purchase_canceled' =>
      GenesisL10n
          .current
          .premiumMessagePurchaseCanceled,
    'purchase_revoked' =>
      GenesisL10n
          .current
          .premiumPurchaseRevoked,
    _ => GenesisL10n.current.mePurchaseFailed,
  };
  return purchaseToastMessage(
    message,
    debugInfo:
        debugInfo ?? purchaseDebugInfo('vip.eligibility', reason: reason),
  );
}
