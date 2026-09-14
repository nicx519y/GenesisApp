import '../../network/models/membership_purchase.dart';
import 'membership_guest_claim_proof.dart';

/// Separately persists the guest's claim and the first login chosen to own it.
class MembershipGuestClaimRecord {
  const MembershipGuestClaimRecord({
    required this.guest,
    this.ownerUid,
    this.status,
    this.loginRequired = false,
    this.purchaseRequestId,
    this.purchaseConfirmed = false,
    this.autoClaimAllowed = true,
    this.recoveredProof,
    this.purchasedAt,
  });

  final MembershipGuestIdentity guest;
  final String? ownerUid;
  final String? status;
  final bool loginRequired;
  final String? purchaseRequestId;
  final bool purchaseConfirmed;
  // Startup may discover several independent subscriptions. Only the selected
  // current subscription may be claimed; claiming a lower plan could replace it.
  final bool autoClaimAllowed;
  final MembershipGuestClaimProof? recoveredProof;
  final int? purchasedAt;

  /// A prepare identity alone must never be checked or offered for claiming.
  bool get hasPurchase =>
      purchaseConfirmed ||
      loginRequired ||
      purchaseRequestId != null ||
      recoveredProof != null;

  bool get requiresLogin =>
      status != 'completed' && (purchaseConfirmed || loginRequired);

  bool get needsRetry => status == null || status == 'accepted';

  MembershipGuestClaimRecord copyWith({
    String? ownerUid,
    String? status,
    bool? loginRequired,
    String? purchaseRequestId,
    bool? purchaseConfirmed,
    bool? autoClaimAllowed,
    MembershipGuestClaimProof? recoveredProof,
    int? purchasedAt,
  }) => MembershipGuestClaimRecord(
    guest: guest,
    ownerUid: ownerUid ?? this.ownerUid,
    status: status ?? this.status,
    loginRequired: loginRequired ?? this.loginRequired,
    purchaseRequestId: purchaseRequestId ?? this.purchaseRequestId,
    purchaseConfirmed: purchaseConfirmed ?? this.purchaseConfirmed,
    autoClaimAllowed: autoClaimAllowed ?? this.autoClaimAllowed,
    recoveredProof: recoveredProof ?? this.recoveredProof,
    purchasedAt: purchasedAt ?? this.purchasedAt,
  );

  Map<String, Object?> toJson() => {
    'guest': guest.toJson(),
    'owner_uid': ownerUid,
    'status': status,
    'login_required': loginRequired,
    'purchase_request_id': purchaseRequestId,
    'purchase_confirmed': purchaseConfirmed,
    'auto_claim_allowed': autoClaimAllowed,
    if (recoveredProof != null) 'recovered_proof': recoveredProof!.toJson(),
    if (purchasedAt != null) 'purchased_at': purchasedAt,
  };

  factory MembershipGuestClaimRecord.fromJson(Map<String, dynamic> json) =>
      MembershipGuestClaimRecord(
        guest: MembershipGuestIdentity.fromJson(
          Map<String, dynamic>.from(json['guest'] as Map),
        ),
        ownerUid: json['owner_uid'] as String?,
        status: json['status'] as String?,
        loginRequired: json['login_required'] as bool? ?? false,
        purchaseRequestId: json['purchase_request_id'] as String?,
        purchaseConfirmed: json['purchase_confirmed'] as bool? ?? false,
        autoClaimAllowed: json['auto_claim_allowed'] as bool? ?? true,
        purchasedAt: (json['purchased_at'] as num?)?.toInt(),
        recoveredProof: json['recovered_proof'] == null
            ? null
            : MembershipGuestClaimProof.fromJson(
                Map<String, dynamic>.from(json['recovered_proof'] as Map),
              ),
      );
}
