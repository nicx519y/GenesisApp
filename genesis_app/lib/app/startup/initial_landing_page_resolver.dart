import '../../pages/home/home_feed_cache_store.dart';
import '../../pages/origin/origin_feed_cache_store.dart';
import '../../platform/session/user_session_store.dart';
import 'app_startup_coordinator.dart';

typedef StartupSessionLoader = Future<CompleteUserSession?> Function();
typedef StartupCacheLoader =
    Future<Map<String, dynamic>?> Function(String ownerUid);

class InitialLandingPageDecision {
  const InitialLandingPageDecision({
    required this.index,
    required this.page,
    required this.reason,
  });

  final int index;
  final String page;
  final String reason;
}

Future<InitialLandingPageDecision> resolveInitialLandingPage({
  required StartupSessionLoader loadSession,
  StartupCacheLoader loadHomeCache = _loadHomeCache,
  StartupCacheLoader loadWorldoCache = _loadWorldoCache,
  Duration timeout = const Duration(seconds: 2),
}) async {
  CompleteUserSession? session;
  try {
    session = await loadSession().timeout(timeout);
  } catch (_) {
    return const InitialLandingPageDecision(
      index: 1,
      page: 'worldo',
      reason: 'session_error',
    );
  }

  if (session == null) {
    final worldoCache = await _loadCache(
      () => loadWorldoCache(OriginFeedCacheStore.anonymousOwnerUid),
      timeout,
    );
    return InitialLandingPageDecision(
      index: 1,
      page: 'worldo',
      reason: AppStartupCoordinator.resolveLaunchPageReason(
        hasSession: false,
        sessionReadFailed: false,
        hasHomeCache: false,
        hasWorldoCache: worldoCache != null,
      ),
    );
  }

  final ownerUid = session.uid;
  final homeCacheFuture = _loadCache(() => loadHomeCache(ownerUid), timeout);
  final worldoCacheFuture = _loadCache(
    () => loadWorldoCache(ownerUid),
    timeout,
  );
  final homeCache = await homeCacheFuture;
  if (_hasMyWorldsContent(homeCache)) {
    return const InitialLandingPageDecision(
      index: 0,
      page: 'home',
      reason: 'session_home_cache_hit',
    );
  }

  final worldoCache = await worldoCacheFuture;
  return InitialLandingPageDecision(
    index: 1,
    page: 'worldo',
    reason: AppStartupCoordinator.resolveLaunchPageReason(
      hasSession: true,
      sessionReadFailed: false,
      hasHomeCache: false,
      hasWorldoCache: worldoCache != null,
    ),
  );
}

Future<Map<String, dynamic>?> _loadCache(
  Future<Map<String, dynamic>?> Function() load,
  Duration timeout,
) async {
  try {
    return await load().timeout(timeout);
  } catch (_) {
    return null;
  }
}

bool _hasMyWorldsContent(Map<String, dynamic>? cached) {
  if (cached == null) return false;
  final list = cached['list'];
  if (list is List && list.isNotEmpty) return true;
  final total = cached['total'];
  if (total is num) return total > 0;
  return (int.tryParse(total?.toString() ?? '') ?? 0) > 0;
}

Future<Map<String, dynamic>?> _loadHomeCache(String ownerUid) {
  return HomeFeedCacheStore(
    ownerUid: ownerUid,
  ).load(HomeFeedCacheKind.myWorlds);
}

Future<Map<String, dynamic>?> _loadWorldoCache(String ownerUid) {
  return OriginFeedCacheStore(ownerUid: ownerUid).loadForYouFirstPage();
}
