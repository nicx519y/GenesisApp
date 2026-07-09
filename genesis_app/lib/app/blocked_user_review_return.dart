class BlockedUserReviewReturn {
  const BlockedUserReviewReturn._();

  static bool _pendingHomePopularRefresh = false;

  static void markPendingHomePopularRefresh() {
    _pendingHomePopularRefresh = true;
  }

  static bool get hasPendingHomePopularRefresh => _pendingHomePopularRefresh;

  static bool consumePendingHomePopularRefresh() {
    final pending = _pendingHomePopularRefresh;
    _pendingHomePopularRefresh = false;
    return pending;
  }

  static void resetForTesting() {
    _pendingHomePopularRefresh = false;
  }
}
