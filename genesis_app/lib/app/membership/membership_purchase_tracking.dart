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

  void _checkoutFailure(String id, String reason) {
    final tracking = _attemptTracking[id];
    if (tracking != null) analytics.failed(tracking, reason, once: true);
  }

  String _preparationFailure(Object error, String stage) {
    // Request/storage stages must not be mislabeled as a store failure just
    // because a local plugin happens to throw a PlatformException.
    if (stage == 'prepare_guest') {
      return subscriptionRequestFailure('guest_prepare_failed', error);
    }
    if (stage == 'load_local_orders' || stage == 'persist_guest_identity') {
      return 'local_storage_failed';
    }
    if (stage == 'load_account_uuid') return 'uuid_unavailable';
    if (stage == 'read_catalog') return 'catalog_unavailable';
    if (error is MembershipPurchaseBlocked) {
      return error.reason == 'downgrade_not_allowed'
          ? error.reason
          : 'catalog_unavailable';
    }
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

  MembershipPurchaseRecord _trackReportResult(
    MembershipPurchaseRecord record,
    MembershipPurchaseReport report,
  ) {
    var tracking = _trackingFor(record);
    switch (report.status) {
      case MembershipReportStatus.completed:
        tracking = analytics.success(
          tracking,
          provider.name,
          record.transactionId,
        );
      case MembershipReportStatus.accepted:
        tracking = analytics.pending(tracking, 'report_accepted');
      case MembershipReportStatus.rejected:
        analytics.failed(tracking, 'report_rejected');
    }
    _attemptTracking[record.requestId] = tracking;
    return record.copyWith(tracking: tracking);
  }

  Future<MembershipPurchaseReport> _sendTrackedReport(
    MembershipPurchaseRecord record,
    MembershipPurchaseRequest request,
  ) async {
    try {
      return await reportPurchase(request);
    } catch (error) {
      final tracking = _trackingFor(record);
      if (subscriptionRequestTimedOut(error)) {
        analytics.timeout(tracking, 'report');
      } else {
        analytics.failed(
          tracking,
          subscriptionRequestFailure('report_failed', error),
        );
      }
      rethrow;
    }
  }

  Future<MembershipClaimResult> _sendTrackedClaim(
    MembershipGuestClaimRecord record,
    MembershipClaimRequest request,
  ) async {
    final tracking = _trackingForClaim(record);
    try {
      final result = await claimGuest!(request);
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
