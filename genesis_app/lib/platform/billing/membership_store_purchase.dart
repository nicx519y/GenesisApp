import 'billing_models.dart';

/// A subscription candidate returned by the store's read-only query.
/// Pending payments and missing identity/receipt fields remain visible so the
/// recovery service can retry them instead of treating them as no subscription.
class MembershipStorePurchase {
  const MembershipStorePurchase({required this.purchase, this.expiresAt});

  final BillingPurchase purchase;
  // Google queryPurchases(SUBS) filters inactive subscriptions but provides no
  // expiry/base plan. Apple supplies the verified transaction's expiration.
  final DateTime? expiresAt;

  bool isCurrent(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);
}
