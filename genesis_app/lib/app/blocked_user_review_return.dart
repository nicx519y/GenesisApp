class BlockedUserReviewReturn {
  const BlockedUserReviewReturn._();

  static bool _pendingHomeRefresh = false;

  static void markPendingHomeRefresh() {
    _pendingHomeRefresh = true;
  }

  static bool get hasPendingHomeRefresh => _pendingHomeRefresh;

  static bool consumePendingHomeRefresh() {
    final pending = _pendingHomeRefresh;
    _pendingHomeRefresh = false;
    return pending;
  }

  static void resetForTesting() {
    _pendingHomeRefresh = false;
  }
}
