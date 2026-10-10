part of 'membership_purchase_service.dart';

extension _MembershipPurchaseTracking on MembershipPurchaseService {
  SubscriptionTracking _trackingFor(MembershipPurchaseRecord record) =>
      _attemptTracking[record.requestId] ??=
          record.tracking ??
          SubscriptionTracking.recovery(
            '${provider.name}:attempt:${record.requestId}',
          );

  SubscriptionTracking _trackingForClaim(MembershipGuestClaimRecord claim) {
    final purchase = _claimPurchase(claim);
    return purchase != null
        ? _trackingFor(purchase)
        : claim.tracking ??
              SubscriptionTracking.recovery(
                '${provider.name}:claim:${claim.guest.accountUuid}',
              );
  }

  void _checkoutFailure(
    String id,
    String reason, {
    bool fromStoreCallback = false,
    bool fromStoreStream = false,
  }) {
    if (!fromStoreCallback && !fromStoreStream) return;
    final tracking = _attemptTracking[id];
    if (tracking != null) analytics.failed(tracking, reason, once: true);
  }

  void _trackPreparationFailure(String id, String stage, String reason) {
    final tracking = _attemptTracking[id];
    if (tracking == null) return;
    final action = switch (stage) {
      'query_store_product' => 'query_failed',
      'launch_store' => 'launch_failed',
      _ => 'precheck_failed',
    };
    analytics.failed(tracking, '$action[$reason]', once: true);
  }

  String _preparationFailure(Object error, String stage) {
    // Request/storage stages must not be mislabeled as a store failure just
    // because a local plugin happens to throw a PlatformException.
    if (error is MembershipPurchaseBlocked) {
      return error.reason == 'downgrade_not_allowed'
          ? error.reason
          : 'catalog_unavailable';
    }
    if (stage == 'prepare_guest') {
      return subscriptionRequestFailure('guest_prepare_failed', error);
    }
    if (stage == 'load_local_orders' ||
        stage == 'prepare_order' ||
        stage == 'persist_guest_identity') {
      return 'local_storage_failed';
    }
    if (stage == 'start_store_listener') return 'service_unavailable';
    if (stage == 'read_session') return 'session_unavailable';
    if (stage == 'check_membership') {
      return subscriptionRequestFailure('membership_check_failed', error);
    }
    if (stage == 'load_account_uuid') return 'uuid_unavailable';
    if (stage == 'read_catalog') return 'catalog_unavailable';
    if (stage == 'prepare_store_checkout') return 'preparation_failed';
    if (error is StateError &&
        error.message == 'membership_provider_mismatch') {
      return 'provider_mismatch';
    }
    return subscriptionStoreFailureReason(
          provider,
          error: error,
          stage: stage == 'query_store_product' ? 'query' : 'launch',
        ) ??
        'unknown_error';
  }

  MembershipPurchaseRecord _trackPending(
    MembershipPurchaseRecord record,
    String reason,
  ) {
    final tracking = analytics.pending(_trackingFor(record), reason);
    _attemptTracking[record.requestId] = tracking;
    return record.copyWith(tracking: tracking);
  }

  Future<MembershipPurchaseReport> _sendTrackedReport(
    MembershipPurchaseRecord record,
    MembershipPurchaseRequest request,
  ) async {
    return reportPurchase(request);
  }

  Future<MembershipClaimResult> _sendTrackedClaim(
    MembershipGuestClaimRecord record,
    MembershipClaimRequest request,
  ) async {
    final tracking = _trackingForClaim(record);
    try {
      debugPrint(
        '[Membership][guest_claim] request; provider=${provider.name}',
      );
      final result = await claimGuest!(request);
      debugPrint(
        '[Membership][guest_claim] response; status=${result.status.name}',
      );
      analytics.claim(tracking, result.status.name);
      return result;
    } catch (error) {
      analytics.claim(
        tracking,
        subscriptionRequestTimedOut(error)
            ? 'timeout'
            : subscriptionRequestFailure('error', error),
      );
      rethrow;
    }
  }
}
