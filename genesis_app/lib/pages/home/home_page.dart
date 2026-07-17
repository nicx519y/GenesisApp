import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../app/bootstrap/app_bootstrap.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/startup/app_startup_coordinator.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/discuss/origin_discuss_preview_list.dart';
import '../../components/genesis_logo.dart';
import '../../components/home/popular_origin_list.dart';
import '../../components/home/world_item_card.dart';
import '../../components/origin/origin_item_card.dart';
import '../../components/page_header.dart';
import '../../components/search_bar.dart';
import '../../network/api_exception.dart';
import '../../network/json_utils.dart';
import '../../platform/privacy/app_tracking_transparency_service.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_deleted_list_item_transition.dart';
import '../../ui/components/secend_tabs.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import 'home_feed_cache_store.dart';
import '../world/world_deletion_events.dart';
import '../world/world_page_result.dart';

void _ignoreHomeFeedCacheWrite(Future<void> write) {
  unawaited(write.catchError((_) {}));
}

typedef TrackingAuthorizationRequester =
    Future<AppTrackingAuthorizationStatus> Function();
typedef TrackingAuthorizationStatusReader =
    Future<AppTrackingAuthorizationStatus> Function();
typedef StartupRuntimeInitializer =
    Future<void> Function(
      AppServices services,
      AppTrackingAuthorizationStatus trackingAuthorizationStatus,
    );

Future<void> _waitHomeInitialRequestMetricWindow(Duration delay) async {
  if (delay <= Duration.zero) return;
  await Future<void>.delayed(delay);
}

const Duration _homeInitialNetworkRetryDelay = Duration(seconds: 2);

bool _isNetworkLikeHomeError(Object error) {
  if (error is ApiException) {
    return error.kind == ApiExceptionKind.timeout ||
        error.kind == ApiExceptionKind.transport ||
        error.transportErrorKind == TransportErrorKind.timeout ||
        error.transportErrorKind == TransportErrorKind.connection;
  }
  if (error is TimeoutException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('timeout') ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('host lookup');
}

Future<void> _initializeDefaultStartupRuntime(
  AppServices services,
  AppTrackingAuthorizationStatus trackingAuthorizationStatus,
) async {
  await AppBootstrap.ensureFirebasePerformanceMonitoring();
  await AppStartupCoordinator.initializeTelemetry(
    services: services,
    trackingAuthorizationStatus: trackingAuthorizationStatus,
  );
  AppStartupCoordinator.startWarmUp(services);
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialTabIndex,
    this.activationListenable,
    this.startupPlatform,
    this.primeNetworkPermission = AppBootstrap.primeNetworkPermission,
    this.trackingAuthorizationStatus =
        AppTrackingTransparencyService.authorizationStatus,
    this.requestTrackingAuthorization =
        AppTrackingTransparencyService.requestAuthorization,
    this.initializeRuntime = _initializeDefaultStartupRuntime,
    this.initialRequestMetricWindow = const Duration(milliseconds: 200),
    this.networkPermissionDialogSettleTimeout = const Duration(seconds: 2),
    this.postSystemDialogResumeDelay = const Duration(milliseconds: 350),
  });

  static const List<String> tabs = ['My Worlds', 'Popular'];
  static const int myWorldsTabIndex = 0;
  static const int popularTabIndex = 1;

  final int? initialTabIndex;
  final ValueListenable<int>? activationListenable;
  final TargetPlatform? startupPlatform;
  final Future<bool> Function(AppServices services) primeNetworkPermission;
  final TrackingAuthorizationStatusReader trackingAuthorizationStatus;
  final TrackingAuthorizationRequester requestTrackingAuthorization;
  final StartupRuntimeInitializer initializeRuntime;
  final Duration initialRequestMetricWindow;
  final Duration networkPermissionDialogSettleTimeout;
  final Duration postSystemDialogResumeDelay;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static int? _lastResolvedInitialTabIndex;

  int? _initialTabIndex;
  Future<int>? _initialTabIndexFuture;
  late final ValueNotifier<bool> _homeNetworkRequestsAllowed;
  var _startupGateStarted = false;
  AppLifecycleState? _lifecycleState;
  Completer<void>? _resumedCompleter;
  Completer<void>? _inactiveCompleter;
  var _watchingNetworkPermissionDialog = false;

  @override
  void initState() {
    super.initState();
    _homeNetworkRequestsAllowed = ValueNotifier<bool>(!_requiresStartupGate);
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    _resolveInitialTabIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStartupGateIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumedCompleter?.complete();
    _inactiveCompleter?.complete();
    _homeNetworkRequestsAllowed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _resumedCompleter?.complete();
      _resumedCompleter = null;
    } else if (_watchingNetworkPermissionDialog) {
      _inactiveCompleter?.complete();
      _inactiveCompleter = null;
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _resolveInitialTabIndex();
    }
  }

  void _resolveInitialTabIndex() {
    final requestedIndex = widget.initialTabIndex;
    if (requestedIndex != null) {
      _initialTabIndex = requestedIndex.clamp(0, HomePage.tabs.length - 1);
      _initialTabIndexFuture = null;
      return;
    }
    final cachedIndex = _lastResolvedInitialTabIndex;
    if (cachedIndex != null) {
      _initialTabIndex = cachedIndex;
      _initialTabIndexFuture = null;
      unawaited(_refreshInitialTabIndexFromSession());
      return;
    }
    _initialTabIndex = null;
    _initialTabIndexFuture = _initialTabIndexFromSession();
  }

  bool get _requiresStartupGate {
    return (widget.startupPlatform ?? defaultTargetPlatform) ==
        TargetPlatform.iOS;
  }

  void _startStartupGateIfNeeded() {
    if (!mounted || _startupGateStarted) return;
    _startupGateStarted = true;
    if (!_requiresStartupGate) {
      _homeNetworkRequestsAllowed.value = true;
      return;
    }
    unawaited(_runIosStartupGate());
  }

  Future<void> _runIosStartupGate() async {
    final services = AppServicesScope.read(context);
    await _waitForAppResumed();
    if (!mounted) return;
    await _primeNetworkPermissionThenWaitForSystemDialog(services);
    if (!mounted) return;
    final trackingAuthorizationStatus = await _resolveTrackingAuthorization();
    if (!mounted) return;
    setState(() {
      _resolveInitialTabIndex();
    });
    await WidgetsBinding.instance.endOfFrame;
    await widget.initializeRuntime(services, trackingAuthorizationStatus);
    if (!mounted) return;
    AppStartupCoordinator.markPostLaunchWorkAllowed();
    services.startupNetworkGate.open();
    _homeNetworkRequestsAllowed.value = true;
  }

  Future<AppTrackingAuthorizationStatus> _resolveTrackingAuthorization() async {
    final currentStatus = await widget.trackingAuthorizationStatus();
    if (currentStatus != AppTrackingAuthorizationStatus.notDetermined &&
        currentStatus != AppTrackingAuthorizationStatus.unknown) {
      return currentStatus;
    }
    await _waitForAppResumed();
    final requestedStatus = await widget.requestTrackingAuthorization();
    await _waitForSystemDialogToClose();
    return requestedStatus;
  }

  Future<void> _primeNetworkPermissionThenWaitForSystemDialog(
    AppServices services,
  ) async {
    _watchingNetworkPermissionDialog = true;
    _inactiveCompleter ??= Completer<void>();
    try {
      unawaited(
        widget.primeNetworkPermission(services).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(
            '[Home][StartupGate] network permission prime failed: $error',
          );
          debugPrint('[Home][StartupGate] stacktrace:\n$stackTrace');
          return false;
        }),
      );
      await _waitForNetworkPermissionDialogToSettle();
    } finally {
      _watchingNetworkPermissionDialog = false;
    }
  }

  Future<void> _waitForNetworkPermissionDialogToSettle() async {
    final inactiveCompleter = _inactiveCompleter ?? Completer<void>();
    _inactiveCompleter = inactiveCompleter;
    final timeout = widget.networkPermissionDialogSettleTimeout;
    if (timeout <= Duration.zero) return;
    final inactiveObserved = await inactiveCompleter.future
        .then((_) => true)
        .timeout(timeout, onTimeout: () => false);
    if (!inactiveObserved) return;
    await _waitForAppResumed();
    await _waitAfterSystemDialogResume();
  }

  Future<void> _waitForSystemDialogToClose() async {
    await _waitAfterSystemDialogResume();
    if (_lifecycleState == AppLifecycleState.resumed ||
        _lifecycleState == null) {
      return;
    }
    final completer = _resumedCompleter ?? Completer<void>();
    _resumedCompleter = completer;
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _waitForAppResumed() async {
    if (_lifecycleState == AppLifecycleState.resumed ||
        _lifecycleState == null) {
      return;
    }
    final completer = _resumedCompleter ?? Completer<void>();
    _resumedCompleter = completer;
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> _waitAfterSystemDialogResume() async {
    final delay = widget.postSystemDialogResumeDelay;
    if (delay <= Duration.zero) return;
    await Future<void>.delayed(delay);
  }

  Future<int> _initialTabIndexFromSession() async {
    final index = await _hasLocalLoginSession()
        ? HomePage.myWorldsTabIndex
        : HomePage.popularTabIndex;
    _lastResolvedInitialTabIndex = index;
    return index;
  }

  Future<void> _refreshInitialTabIndexFromSession() async {
    final index = await _initialTabIndexFromSession();
    if (!mounted || _initialTabIndex == index) return;
    setState(() {
      _initialTabIndex = index;
    });
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return authToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final initialTabIndex = _initialTabIndex;
    if (initialTabIndex != null) {
      return _HomeTabScaffold(
        initialIndex: initialTabIndex,
        activationListenable: widget.activationListenable,
        networkRequestsAllowed: _homeNetworkRequestsAllowed,
        keepInitialNetworkFailureLoading: _requiresStartupGate,
        initialRequestMetricWindow: widget.initialRequestMetricWindow,
      );
    }

    return FutureBuilder<int>(
      future: _initialTabIndexFuture,
      builder: (context, snapshot) {
        final initialIndex = snapshot.data ?? HomePage.myWorldsTabIndex;

        return _HomeTabScaffold(
          initialIndex: initialIndex,
          activationListenable: widget.activationListenable,
          networkRequestsAllowed: _homeNetworkRequestsAllowed,
          keepInitialNetworkFailureLoading: _requiresStartupGate,
          initialRequestMetricWindow: widget.initialRequestMetricWindow,
        );
      },
    );
  }
}

class _HomeTabScaffold extends StatelessWidget {
  const _HomeTabScaffold({
    required this.initialIndex,
    required this.activationListenable,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    required this.initialRequestMetricWindow,
  });

  final int initialIndex;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final Duration initialRequestMetricWindow;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      key: ValueKey<int>(initialIndex),
      length: HomePage.tabs.length,
      initialIndex: initialIndex,
      child: Column(
        children: [
          const _HomeHeader(),
          const SizedBox(height: 4),
          const _HomeTabs(),
          Expanded(
            child: _HomeTabView(
              activationListenable: activationListenable,
              networkRequestsAllowed: networkRequestsAllowed,
              keepInitialNetworkFailureLoading:
                  keepInitialNetworkFailureLoading,
              initialRequestMetricWindow: initialRequestMetricWindow,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs();

  @override
  Widget build(BuildContext context) {
    return SecendTabs(
      labels: HomePage.tabs,
      verticalPadding: 0,
      tabAlignment: TabAlignment.center,
    );
  }
}

class _HomeTabView extends StatelessWidget {
  const _HomeTabView({
    this.activationListenable,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    required this.initialRequestMetricWindow,
  });

  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final Duration initialRequestMetricWindow;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _MyWorldFeed(
          index: 0,
          activationListenable: activationListenable,
          networkRequestsAllowed: networkRequestsAllowed,
          keepInitialNetworkFailureLoading: keepInitialNetworkFailureLoading,
          initialRequestMetricWindow: initialRequestMetricWindow,
        ),
        _PopularOriginFeed(
          index: 1,
          activationListenable: activationListenable,
          networkRequestsAllowed: networkRequestsAllowed,
          keepInitialNetworkFailureLoading: keepInitialNetworkFailureLoading,
          initialRequestMetricWindow: initialRequestMetricWindow,
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return GenesisTopSafeArea(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: kGenesisTopBarHeight,
          child: Transform.translate(
            offset: const Offset(0, 5),
            child: Row(
              children: [
                const GenesisLogo(height: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchBarPlaceholder(
                    hintText: 'Explore',
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.search);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyWorldFeed extends StatefulWidget {
  const _MyWorldFeed({
    required this.index,
    required this.initialRequestMetricWindow,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    this.activationListenable,
  });

  final int index;
  final Duration initialRequestMetricWindow;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final ValueListenable<int>? activationListenable;

  @override
  State<_MyWorldFeed> createState() => _MyWorldFeedState();
}

class _MyWorldFeedState extends State<_MyWorldFeed>
    with AutomaticKeepAliveClientMixin<_MyWorldFeed> {
  static const _pageSize = 10;
  static const _loadMoreThreshold = 700.0;

  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<WorldListItem> _items = <WorldListItem>[];
  final Set<String> _deletingWorldIds = <String>{};
  final Set<String> _collapsingWorldIds = <String>{};
  final Set<String> _locallyDeletedWorldIds = <String>{};
  final Map<String, double> _collapseBottomCompensation = <String, double>{};
  Timer? _startupInitialRetryTimer;
  Future<bool>? _cacheLoadFuture;
  var _nextPage = 1;
  var _total = 0;
  var _hasMore = true;
  var _hasRequested = false;
  var _hasAttemptedCachePreload = false;
  var _hasLoadedCachedPage = false;
  var _hasResolvedLocalSession = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  var _isSignedOut = false;
  String _activityTagUid = '';
  WorldActivityTagState? _activityTagState;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.activationListenable?.addListener(_handlePageActivated);
    widget.networkRequestsAllowed.addListener(_handleNetworkRequestsAllowed);
    worldActivityTagStore.listenable.addListener(_handleActivityTagsChanged);
    worldDeletionEvents.addListener(_handleExternalWorldDeleted);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (_tabController != nextController) {
      _tabController?.removeListener(_handleTabChange);
      _tabController = nextController..addListener(_handleTabChange);
    }
    if (!_scrollListenerAttached) {
      _scrollController.addListener(_handleScroll);
      _scrollListenerAttached = true;
    }
    _preloadCachedItemsIfNeeded();
    unawaited(_loadWorldActivityTags());
    _requestIfCurrentTab();
  }

  @override
  void didUpdateWidget(covariant _MyWorldFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handlePageActivated);
      widget.activationListenable?.addListener(_handlePageActivated);
    }
    if (oldWidget.networkRequestsAllowed != widget.networkRequestsAllowed) {
      oldWidget.networkRequestsAllowed.removeListener(
        _handleNetworkRequestsAllowed,
      );
      widget.networkRequestsAllowed.addListener(_handleNetworkRequestsAllowed);
    }
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
    _startupInitialRetryTimer?.cancel();
    worldActivityTagStore.listenable.removeListener(_handleActivityTagsChanged);
    worldDeletionEvents.removeListener(_handleExternalWorldDeleted);
    widget.activationListenable?.removeListener(_handlePageActivated);
    widget.networkRequestsAllowed.removeListener(_handleNetworkRequestsAllowed);
    _tabController?.removeListener(_handleTabChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadWorldActivityTags() async {
    final uid = await resolveRecentWorldChatUid(AppServicesScope.read(context));
    var state = await worldActivityTagStore.loadForUid(uid);
    if ((state?.lastMessageWorldId ?? '').trim().isEmpty) {
      final record = await recentWorldChatStore.loadForUid(uid);
      final worldId = record?.uid == uid ? record?.worldId.trim() ?? '' : '';
      if (worldId.isNotEmpty) {
        await worldActivityTagStore.markLastMessage(uid: uid, worldId: worldId);
        state = worldActivityTagStore.listenable.value;
      }
    }
    if (!mounted) return;
    if (_activityTagUid == uid &&
        _sameWorldActivityTagState(_activityTagState, state)) {
      return;
    }
    setState(() {
      _activityTagUid = uid;
      _activityTagState = state;
    });
  }

  void _handleActivityTagsChanged() {
    final state = worldActivityTagStore.listenable.value;
    if (state == null) return;
    if (_activityTagUid.isNotEmpty && state.uid != _activityTagUid) return;
    if (_sameWorldActivityTagState(_activityTagState, state)) return;
    setState(() {
      _activityTagUid = state.uid;
      _activityTagState = state;
    });
  }

  void _handleExternalWorldDeleted() {
    final event = worldDeletionEvents.value;
    if (event == null) return;
    _beginWorldDeletion(event.worldId);
  }

  bool _sameWorldActivityTagState(
    WorldActivityTagState? current,
    WorldActivityTagState? next,
  ) {
    if (identical(current, next)) return true;
    if (current == null || next == null) return current == next;
    return current.uid == next.uid &&
        current.lastMessageWorldId == next.lastMessageWorldId &&
        current.lastTickWorldId == next.lastTickWorldId &&
        current.lastLaunchWorldId == next.lastLaunchWorldId;
  }

  void _resetListState() {
    _startupInitialRetryTimer?.cancel();
    _startupInitialRetryTimer = null;
    _items.clear();
    _deletingWorldIds.clear();
    _collapsingWorldIds.clear();
    _locallyDeletedWorldIds.clear();
    _collapseBottomCompensation.clear();
    _nextPage = 1;
    _total = 0;
    _cacheLoadFuture = null;
    _hasMore = true;
    _hasRequested = false;
    _hasAttemptedCachePreload = false;
    _hasLoadedCachedPage = false;
    _hasResolvedLocalSession = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _isSignedOut = false;
    _error = null;
  }

  void _clearDeleteState() {
    _deletingWorldIds.clear();
    _collapsingWorldIds.clear();
    _locallyDeletedWorldIds.clear();
    _collapseBottomCompensation.clear();
  }

  void _pruneDeleteStateForCurrentItems() {
    final liveIds = _items.map((item) => item.wid.trim()).toSet();
    _deletingWorldIds.removeWhere((wid) => !liveIds.contains(wid));
    _collapsingWorldIds.removeWhere((wid) => !liveIds.contains(wid));
    _collapseBottomCompensation.removeWhere((wid, _) => !liveIds.contains(wid));
  }

  void _handleTabChange() {
    _requestIfCurrentTab();
  }

  void _handleNetworkRequestsAllowed() {
    if (widget.networkRequestsAllowed.value) {
      _requestIfCurrentTab();
    }
  }

  void _handlePageActivated() {
    final controller = _tabController;
    if (controller == null || controller.index != widget.index) return;
    if (!_hasRequested) {
      _requestIfCurrentTab();
      return;
    }
    if (widget.networkRequestsAllowed.value) {
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'home_my_worlds',
      );
      unawaited(_refreshItems());
    }
  }

  void _requestIfCurrentTab() {
    final controller = _tabController;
    if (controller == null ||
        controller.index != widget.index ||
        _hasRequested ||
        !widget.networkRequestsAllowed.value) {
      return;
    }
    _hasRequested = true;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'home_my_worlds',
    );
    unawaited(_requestInitialItems());
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    _loadNextPage();
  }

  void _preloadCachedItemsIfNeeded() {
    if (_hasAttemptedCachePreload) return;
    _hasAttemptedCachePreload = true;
    unawaited(_preloadCachedItemsForSignedInSession());
  }

  Future<void> _preloadCachedItemsForSignedInSession() async {
    final hasSession = await _hasLocalLoginSession();
    if (!mounted) return;
    if (!hasSession) {
      setState(() {
        _items.clear();
        _clearDeleteState();
        _nextPage = 1;
        _total = 0;
        _hasMore = false;
        _error = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
        _isSignedOut = true;
        _hasResolvedLocalSession = true;
      });
      return;
    }
    if (_isSignedOut || !_hasResolvedLocalSession) {
      setState(() {
        _isSignedOut = false;
        _hasResolvedLocalSession = true;
      });
    }
    await _loadCachedItemsOnce();
  }

  Future<void> _requestInitialItems() async {
    final hasSession = await _hasLocalLoginSession();
    if (!mounted) return;
    if (!hasSession) {
      setState(() {
        _items.clear();
        _clearDeleteState();
        _nextPage = 1;
        _total = 0;
        _hasMore = false;
        _error = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
        _isSignedOut = true;
        _hasResolvedLocalSession = true;
      });
      return;
    }
    if (mounted &&
        (_items.isEmpty || _isSignedOut || !_hasResolvedLocalSession)) {
      setState(() {
        _hasResolvedLocalSession = true;
        _isSignedOut = false;
        _isInitialLoading = _items.isEmpty;
      });
    }
    final didLoadCache = await _loadCachedItemsOnce();
    if (!mounted) return;
    if (!didLoadCache && _items.isEmpty) {
      setState(() {
        _isInitialLoading = true;
      });
    }
    await _waitHomeInitialRequestMetricWindow(
      widget.initialRequestMetricWindow,
    );
    if (!mounted) return;
    await _refreshItems(force: true);
  }

  Future<HomeFeedCacheStore?> _cacheStoreForActiveSession() async {
    final services = AppServicesScope.of(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return null;
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    if (authToken.isEmpty) return null;
    return HomeFeedCacheStore(ownerUid: uid);
  }

  Future<bool> _loadCachedItemsOnce() {
    return _cacheLoadFuture ??= _loadCachedItemsIfAvailable();
  }

  Future<bool> _loadCachedItemsIfAvailable() async {
    final cacheStore = await _cacheStoreForActiveSession();
    final data = await cacheStore?.load(HomeFeedCacheKind.myWorlds);
    if (!mounted) return false;
    if (data == null) {
      if (!_hasRequested) {
        setState(() {
          _isInitialLoading = false;
        });
      }
      return false;
    }

    final page = _parseWorldListPage(data);
    unawaited(_syncLastTickActivityTagFromItems(page.items));
    _startupInitialRetryTimer?.cancel();
    _startupInitialRetryTimer = null;
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _pruneDeleteStateForCurrentItems();
      _total = page.total;
      _nextPage = 2;
      _hasMore = _items.length < _total && page.items.isNotEmpty;
      _hasLoadedCachedPage = true;
      _error = null;
      _isInitialLoading = false;
      _isLoadingMore = false;
      _isRefreshing = false;
      _isSignedOut = false;
    });
    return true;
  }

  Future<_WorldListPage> _fetchPage(int page) async {
    final services = AppServicesScope.of(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty) {
      return const _WorldListPage(items: <WorldListItem>[], total: 0);
    }
    final data = await services.api.v1.world.list(
      scene: 'mine',
      pn: page,
      rn: _pageSize,
    );
    if (page == 1) {
      _ignoreHomeFeedCacheWrite(
        HomeFeedCacheStore(
          ownerUid: uid,
        ).save(HomeFeedCacheKind.myWorlds, data),
      );
    }
    return _parseWorldListPage(data);
  }

  _WorldListPage _parseWorldListPage(Map<String, dynamic> data) {
    final list = data['list'];
    final items = list is List
        ? list
              .whereType<Map>()
              .map((raw) => WorldListItem.fromJson(asJsonMap(raw)))
              .where(
                (item) => !_locallyDeletedWorldIds.contains(item.wid.trim()),
              )
              .toList(growable: false)
        : const <WorldListItem>[];
    return _WorldListPage(items: items, total: asInt(data['total']));
  }

  Future<void> _refreshItems({bool force = false}) async {
    if (!widget.networkRequestsAllowed.value) return;
    if ((!force && _isInitialLoading) || _isRefreshing) return;
    final hasSession = await _hasLocalLoginSession();
    if (!hasSession) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _clearDeleteState();
        _nextPage = 1;
        _total = 0;
        _hasMore = false;
        _error = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
        _isSignedOut = true;
        _hasResolvedLocalSession = true;
      });
      return;
    }

    setState(() {
      _error = null;
      _isSignedOut = false;
      _hasResolvedLocalSession = true;
      _isInitialLoading = _items.isEmpty && !_hasLoadedCachedPage;
      _isRefreshing = true;
    });

    try {
      final page = await _fetchPage(1);
      if (!mounted) return;
      unawaited(_syncLastTickActivityTagFromItems(page.items));
      _startupInitialRetryTimer?.cancel();
      _startupInitialRetryTimer = null;
      final shouldReplaceItems = !_worldPageMatchesCurrent(page);
      setState(() {
        if (shouldReplaceItems) {
          _items
            ..clear()
            ..addAll(page.items);
          _pruneDeleteStateForCurrentItems();
        }
        _total = page.total;
        _nextPage = 2;
        _hasMore = _items.length < _total && page.items.isNotEmpty;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_shouldKeepInitialNetworkFailureLoading(error)) {
        setState(() {
          _error = null;
          _isInitialLoading = true;
          _isRefreshing = false;
        });
        _scheduleStartupInitialRetry();
        return;
      }
      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  bool _worldPageMatchesCurrent(_WorldListPage page) {
    if (_total != page.total || _items.length != page.items.length) {
      return false;
    }
    for (var index = 0; index < _items.length; index += 1) {
      if (_worldItemSignature(_items[index]) !=
          _worldItemSignature(page.items[index])) {
        return false;
      }
    }
    return true;
  }

  String _worldItemSignature(WorldListItem item) {
    return <Object?>[
      item.oid,
      item.originVersionNum,
      item.originVersionCreateAt,
      item.wid,
      item.status,
      item.name,
      item.deleted,
      item.cover,
      item.displaySubtitle,
      item.createdUid,
      item.createdUserName,
      item.ownerUid,
      item.ownerName,
      item.createdAt,
      item.updatedAt,
      item.lastProgressAt,
      item.lastProgressSummary,
      item.lastProgressTickNo,
      item.lastProgressCurrentTime,
      item.previewImages.join('\n'),
      item.tags.join('\n'),
      item.tickCnt,
      item.connectCnt,
      item.aiCharacterCnt,
      item.playerCnt,
      item.locationCnt,
    ].join('\u001F');
  }

  bool _shouldKeepInitialNetworkFailureLoading(Object error) {
    return widget.keepInitialNetworkFailureLoading &&
        _items.isEmpty &&
        !_hasLoadedCachedPage &&
        !_isSignedOut &&
        _isNetworkLikeHomeError(error);
  }

  void _scheduleStartupInitialRetry() {
    if (_startupInitialRetryTimer?.isActive ?? false) return;
    _startupInitialRetryTimer = Timer(_homeInitialNetworkRetryDelay, () {
      _startupInitialRetryTimer = null;
      if (!mounted || !widget.networkRequestsAllowed.value) return;
      final controller = _tabController;
      if (controller == null || controller.index != widget.index) return;
      unawaited(_refreshItems(force: true));
    });
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return false;
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return authToken.isNotEmpty;
  }

  Future<void> _loadNextPage() async {
    if (!widget.networkRequestsAllowed.value ||
        !_hasMore ||
        _isInitialLoading ||
        _isLoadingMore ||
        _isRefreshing) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final page = await _fetchPage(_nextPage);
      if (!mounted) return;
      unawaited(_syncLastTickActivityTagFromItems([..._items, ...page.items]));
      setState(() {
        _items.addAll(page.items);
        _pruneDeleteStateForCurrentItems();
        _total = page.total;
        _nextPage += 1;
        _hasMore = _items.length < _total && page.items.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoadingMore = false;
      });
    }
  }

  double get _collapseCompensation {
    return _collapseBottomCompensation.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
  }

  void _setCollapseCompensation(String worldId, double value) {
    if (worldId.isEmpty) return;
    final normalized = value <= 0.5 ? 0.0 : value;
    final current = _collapseBottomCompensation[worldId] ?? 0;
    if ((current - normalized).abs() <= 0.5) return;
    if (!mounted) return;
    setState(() {
      if (normalized == 0) {
        _collapseBottomCompensation.remove(worldId);
      } else {
        _collapseBottomCompensation[worldId] = normalized;
      }
    });
  }

  void _handleWorldCollapseCompleted(String worldId) {
    if (worldId.isEmpty || !mounted) return;
    setState(() {
      _items.removeWhere((item) => item.wid.trim() == worldId);
      _deletingWorldIds.remove(worldId);
      _collapsingWorldIds.remove(worldId);
      _collapseBottomCompensation.remove(worldId);
      if (_total > 0) {
        _total -= 1;
      }
      _hasMore = _items.length < _total && _items.isNotEmpty;
    });
  }

  Future<void> _openWorld(WorldListItem item) async {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'home_my_worlds_click',
      object1: item.wid,
    );
    final result = await Navigator.of(context).pushNamed<WorldPageResult>(
      RouteNames.world,
      arguments: {'wid': item.wid},
    );
    if (!mounted || result == null) return;
    _beginWorldDeletion(result.deletedWorldId);
  }

  void _beginWorldDeletion(String rawWorldId) {
    final deletedWorldId = rawWorldId.trim();
    if (!mounted ||
        deletedWorldId.isEmpty ||
        _collapsingWorldIds.contains(deletedWorldId)) {
      return;
    }
    final hasVisibleItem = _items.any(
      (item) => item.wid.trim() == deletedWorldId,
    );
    setState(() {
      _locallyDeletedWorldIds.add(deletedWorldId);
      _deletingWorldIds.remove(deletedWorldId);
      if (hasVisibleItem) {
        _collapsingWorldIds.add(deletedWorldId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final waitingForStartupNetwork = !widget.networkRequestsAllowed.value;
    if (!waitingForStartupNetwork &&
        _hasResolvedLocalSession &&
        !_isSignedOut &&
        (_isInitialLoading ||
            (!_hasRequested && !_hasLoadedCachedPage && _items.isEmpty))) {
      return const GenesisListLoadingSkeleton.worldList();
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Load failed'),
            const SizedBox(height: 10),
            FilledButton(onPressed: _refreshItems, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty && !_hasResolvedLocalSession) {
      return ListView(
        key: const PageStorageKey<String>('home-feed-my-world-pending'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: MediaQuery.sizeOf(context).height * 0.62)],
      );
    }

    final emptyListView = ListView(
      key: const PageStorageKey<String>('home-feed-my-world'),
      physics: _isSignedOut
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: const _MyWorldsEmptyState(),
        ),
      ],
    );

    if (_items.isEmpty && _isSignedOut) {
      return emptyListView;
    }

    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: _items.isEmpty
          ? emptyListView
          : ListView.builder(
              key: const PageStorageKey<String>('home-feed-my-world'),
              controller: _scrollController,
              primary: false,
              scrollCacheExtent: const ScrollCacheExtent.pixels(900),
              padding: EdgeInsets.only(
                top: 10,
                bottom: 36 + _collapseCompensation,
              ),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _items.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final vm = _items[index];
                final worldId = vm.wid.trim();
                final isDeleting = _deletingWorldIds.contains(worldId);
                final isCollapsing = _collapsingWorldIds.contains(worldId);
                final canInteract = !vm.deleted && !isDeleting && !isCollapsing;
                final activityTagLabel = vm.deleted
                    ? ''
                    : _activityTagState?.labelForWorldId(worldId) ?? '';
                return _AnimatedHomeWorldListItem(
                  key: ValueKey<String>('home-my-world-$worldId'),
                  isCollapsing: isCollapsing,
                  bottomSpacing: index == _items.length - 1 && !_isLoadingMore
                      ? 0
                      : 41,
                  onCollapseCompensationChanged: (value) =>
                      _setCollapseCompensation(worldId, value),
                  onCollapsed: () => _handleWorldCollapseCompleted(worldId),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canInteract ? () => unawaited(_openWorld(vm)) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: WorldItemCard(
                        item: vm,
                        showPreviewImages: false,
                        recentActivityTagLabel: activityTagLabel,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _syncLastTickActivityTagFromItems(
    List<WorldListItem> items,
  ) async {
    final worldId = _lastTickWorldIdFromItems(items);
    if (worldId.isEmpty) return;
    final uid = _activityTagUid.isNotEmpty
        ? _activityTagUid
        : await resolveRecentWorldChatUid(AppServicesScope.read(context));
    await worldActivityTagStore.markLastTick(uid: uid, worldId: worldId);
  }

  String _lastTickWorldIdFromItems(List<WorldListItem> items) {
    WorldListItem? fallback;
    WorldListItem? latest;
    DateTime? latestTime;

    for (final item in items) {
      if (item.deleted) continue;
      if (item.lastProgressTickNo <= 1 && item.tickCnt <= 1) continue;
      fallback ??= item;
      final time = parseFlexibleTimestamp(item.lastProgressAt);
      if (time == null) continue;
      if (latestTime == null || time.isAfter(latestTime)) {
        latestTime = time;
        latest = item;
      }
    }

    return (latest ?? fallback)?.wid.trim() ?? '';
  }
}

class _AnimatedHomeWorldListItem extends StatefulWidget {
  const _AnimatedHomeWorldListItem({
    super.key,
    required this.child,
    required this.isCollapsing,
    required this.bottomSpacing,
    required this.onCollapseCompensationChanged,
    required this.onCollapsed,
  });

  final Widget child;
  final bool isCollapsing;
  final double bottomSpacing;
  final ValueChanged<double> onCollapseCompensationChanged;
  final VoidCallback onCollapsed;

  @override
  State<_AnimatedHomeWorldListItem> createState() =>
      _AnimatedHomeWorldListItemState();
}

class _AnimatedHomeWorldListItemState extends State<_AnimatedHomeWorldListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GlobalKey _contentKey = GlobalKey();
  double _contentExtent = 0;
  int _animationRevision = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: widget.isCollapsing ? 0 : 1,
    )..addListener(_notifyCompensationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContentExtent();
      _notifyCompensationChanged();
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedHomeWorldListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContentExtent();
      _notifyCompensationChanged();
    });
    if (oldWidget.isCollapsing == widget.isCollapsing) return;
    final revision = ++_animationRevision;
    if (widget.isCollapsing) {
      unawaited(_collapse(revision));
    } else {
      _controller.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyCompensationChanged);
    widget.onCollapseCompensationChanged(0);
    _controller.dispose();
    super.dispose();
  }

  void _measureContentExtent() {
    final renderObject = _contentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    _contentExtent = renderObject.size.height;
  }

  void _notifyCompensationChanged() {
    if (_contentExtent <= 0) return;
    final progress = 1 - _controller.value;
    widget.onCollapseCompensationChanged(
      _contentExtent *
          (1 -
              GenesisDeletedListItemTransition.heightFactorForProgress(
                progress,
              )),
    );
  }

  Future<void> _collapse(int revision) async {
    await _controller.animateTo(0, curve: Curves.linear);
    if (!mounted || revision != _animationRevision || !widget.isCollapsing) {
      return;
    }
    widget.onCollapsed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GenesisDeletedListItemTransition(
          progress: 1 - _controller.value,
          child: child!,
        );
      },
      child: RepaintBoundary(
        child: Column(
          key: _contentKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            if (widget.bottomSpacing > 0)
              const Padding(
                padding: EdgeInsets.only(top: 24, bottom: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEFEFEF),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyWorldsEmptyState extends StatelessWidget {
  const _MyWorldsEmptyState();

  static const launchImageAsset =
      'assets/images/my_worlds_empty_worldo_launch.jpg';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: const Alignment(0, -0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              launchImageAsset,
              key: ValueKey<String>(
                'home-my-worlds-empty-image:$launchImageAsset',
              ),
              width: MediaQuery.sizeOf(context).width.clamp(0, 360) * 0.82,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 22),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: 'Launch a '),
                  TextSpan(
                    text: '#Worldo',
                    style: TextStyle(color: Color(0xFF4B6192)),
                  ),
                  TextSpan(text: ' to generate your own World'),
                ],
              ),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: GenesisColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Worldo is the blueprint. Launch to create a live World you can enter and grow.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF666666),
                fontSize: 14,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldListPage {
  const _WorldListPage({required this.items, required this.total});

  final List<WorldListItem> items;
  final int total;
}

class _PopularOriginFeed extends StatefulWidget {
  const _PopularOriginFeed({
    required this.index,
    required this.initialRequestMetricWindow,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    this.activationListenable,
  });

  final int index;
  final Duration initialRequestMetricWindow;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final ValueListenable<int>? activationListenable;

  @override
  State<_PopularOriginFeed> createState() => _PopularOriginFeedState();
}

class _PopularOriginFeedState extends State<_PopularOriginFeed>
    with AutomaticKeepAliveClientMixin<_PopularOriginFeed> {
  static const _pageSize = 10;
  static const _loadMoreThreshold = 700.0;

  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<OriginListItem> _items = <OriginListItem>[];
  final Map<String, List<OriginDiscussPreviewItem>> _discussPreviews =
      <String, List<OriginDiscussPreviewItem>>{};
  Timer? _startupInitialRetryTimer;
  Future<bool>? _cacheLoadFuture;
  var _nextPage = 1;
  var _total = 0;
  var _hasMore = true;
  var _hasRequested = false;
  var _hasAttemptedCachePreload = false;
  var _hasLoadedCachedPage = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.activationListenable?.addListener(_handlePageActivated);
    widget.networkRequestsAllowed.addListener(_handleNetworkRequestsAllowed);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (_tabController != nextController) {
      _tabController?.removeListener(_handleTabChange);
      _tabController = nextController..addListener(_handleTabChange);
    }
    if (!_scrollListenerAttached) {
      _scrollController.addListener(_handleScroll);
      _scrollListenerAttached = true;
    }
    _preloadCachedItemsIfNeeded();
    _requestIfCurrentTab();
  }

  @override
  void didUpdateWidget(covariant _PopularOriginFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handlePageActivated);
      widget.activationListenable?.addListener(_handlePageActivated);
    }
    if (oldWidget.networkRequestsAllowed != widget.networkRequestsAllowed) {
      oldWidget.networkRequestsAllowed.removeListener(
        _handleNetworkRequestsAllowed,
      );
      widget.networkRequestsAllowed.addListener(_handleNetworkRequestsAllowed);
    }
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
    _startupInitialRetryTimer?.cancel();
    widget.activationListenable?.removeListener(_handlePageActivated);
    widget.networkRequestsAllowed.removeListener(_handleNetworkRequestsAllowed);
    _tabController?.removeListener(_handleTabChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _resetListState() {
    _startupInitialRetryTimer?.cancel();
    _startupInitialRetryTimer = null;
    _items.clear();
    _discussPreviews.clear();
    _nextPage = 1;
    _total = 0;
    _cacheLoadFuture = null;
    _hasMore = true;
    _hasRequested = false;
    _hasAttemptedCachePreload = false;
    _hasLoadedCachedPage = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _error = null;
  }

  void _handleTabChange() {
    _requestIfCurrentTab();
  }

  void _handleNetworkRequestsAllowed() {
    if (widget.networkRequestsAllowed.value) {
      _requestIfCurrentTab();
    }
  }

  void _handlePageActivated() {
    final controller = _tabController;
    if (controller == null || controller.index != widget.index) return;
    if (!_hasRequested) {
      _requestIfCurrentTab();
      return;
    }
    if (widget.networkRequestsAllowed.value) {
      GenesisTelemetry.collectLog(
        actionType: 'pageview',
        action: 'home_popular',
      );
      unawaited(_refreshItems());
    }
  }

  void _requestIfCurrentTab() {
    final controller = _tabController;
    if (controller == null ||
        controller.index != widget.index ||
        _hasRequested ||
        !widget.networkRequestsAllowed.value) {
      return;
    }
    _hasRequested = true;
    GenesisTelemetry.collectLog(actionType: 'pageview', action: 'home_popular');
    unawaited(_requestInitialItems());
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    _loadNextPage();
  }

  void _preloadCachedItemsIfNeeded() {
    if (_hasAttemptedCachePreload) return;
    _hasAttemptedCachePreload = true;
    unawaited(_loadCachedItemsOnce());
  }

  Future<void> _requestInitialItems() async {
    if (mounted && _items.isEmpty) {
      setState(() {
        _isInitialLoading = true;
      });
    }
    final didLoadCache = await _loadCachedItemsOnce();
    if (!mounted) return;
    if (!didLoadCache && _items.isEmpty) {
      setState(() {
        _isInitialLoading = true;
      });
    }
    await _waitHomeInitialRequestMetricWindow(
      widget.initialRequestMetricWindow,
    );
    if (!mounted) return;
    await _refreshItems(force: true);
  }

  Future<HomeFeedCacheStore> _cacheStoreForCurrentOwner() async {
    final services = AppServicesScope.of(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    return HomeFeedCacheStore(
      ownerUid: uid.isEmpty ? HomeFeedCacheStore.anonymousOwnerUid : uid,
    );
  }

  Future<bool> _loadCachedItemsOnce() {
    return _cacheLoadFuture ??= _loadCachedItemsIfAvailable();
  }

  Future<bool> _loadCachedItemsIfAvailable() async {
    final cacheStore = await _cacheStoreForCurrentOwner();
    final data = await cacheStore.load(HomeFeedCacheKind.popular);
    if (!mounted) return false;
    if (data == null) {
      if (!_hasRequested) {
        setState(() {
          _isInitialLoading = false;
        });
      }
      return false;
    }

    final page = await _parseOriginListPage(
      data,
      loadMissingDiscussPreviews: false,
    );
    if (!mounted) return false;
    _startupInitialRetryTimer?.cancel();
    _startupInitialRetryTimer = null;
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _discussPreviews
        ..clear()
        ..addAll(page.discussPreviews);
      _total = page.total;
      _nextPage = 2;
      _hasMore = _items.length < _total && page.items.isNotEmpty;
      _hasLoadedCachedPage = true;
      _error = null;
      _isInitialLoading = false;
      _isLoadingMore = false;
      _isRefreshing = false;
    });
    return true;
  }

  Future<_OriginListPage> _fetchPage(int page) async {
    final services = AppServicesScope.of(context);
    HomeFeedCacheStore? cacheStore;
    if (page == 1) {
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      cacheStore = HomeFeedCacheStore(
        ownerUid: uid.isEmpty ? HomeFeedCacheStore.anonymousOwnerUid : uid,
      );
    }
    final data = await services.api.v1.origin.list(
      scene: 'popular',
      pn: page,
      rn: _pageSize,
    );
    if (cacheStore != null) {
      _ignoreHomeFeedCacheWrite(
        cacheStore.save(HomeFeedCacheKind.popular, data),
      );
    }
    return _parseOriginListPage(data, loadMissingDiscussPreviews: true);
  }

  Future<_OriginListPage> _parseOriginListPage(
    Map<String, dynamic> data, {
    required bool loadMissingDiscussPreviews,
  }) async {
    final list = data['list'];
    final rawItems = list is List
        ? list.whereType<Map>().map((raw) => asJsonMap(raw)).toList()
        : const <Map<String, dynamic>>[];
    final items = <OriginListItem>[];
    final discussPreviews = <String, List<OriginDiscussPreviewItem>>{};
    for (final raw in rawItems) {
      final item = OriginListItem.fromJson(raw);
      items.add(item);
      if (raw['discusses'] is List) {
        discussPreviews[item.oid] = _discussPreviewsFromPopularField(
          raw['discusses'],
        );
      }
    }
    final total = asInt(data['total']);
    if (loadMissingDiscussPreviews && mounted) {
      final missingItems = items
          .where((item) => !discussPreviews.containsKey(item.oid))
          .toList(growable: false);
      discussPreviews.addAll(await _fetchDiscussPreviews(missingItems));
    }
    return _OriginListPage(
      items: items,
      total: total,
      discussPreviews: discussPreviews,
    );
  }

  List<OriginDiscussPreviewItem> _discussPreviewsFromPopularField(
    Object? rawDiscusses,
  ) {
    if (rawDiscusses is! List) return const <OriginDiscussPreviewItem>[];
    return rawDiscusses
        .whereType<Map>()
        .map((raw) => OriginDiscussPreviewItem.fromJson(asJsonMap(raw)))
        .where((item) => item.content.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
  }

  Future<Map<String, List<OriginDiscussPreviewItem>>> _fetchDiscussPreviews(
    List<OriginListItem> items,
  ) async {
    final oids = items
        .map((item) => item.oid.trim())
        .where((oid) => oid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (oids.isEmpty) {
      return const <String, List<OriginDiscussPreviewItem>>{};
    }

    final entries = await Future.wait(
      oids.map((oid) async {
        try {
          final previewItems = await loadOriginDiscussPreviewItems(
            context,
            oid,
          );
          return MapEntry(oid, previewItems);
        } catch (_) {
          return MapEntry(oid, const <OriginDiscussPreviewItem>[]);
        }
      }),
    );
    return Map<String, List<OriginDiscussPreviewItem>>.fromEntries(entries);
  }

  Future<void> _refreshItems({bool force = false}) async {
    if (!widget.networkRequestsAllowed.value) return;
    if ((!force && _isInitialLoading) || _isRefreshing) return;
    setState(() {
      _error = null;
      _isInitialLoading = _items.isEmpty && !_hasLoadedCachedPage;
      _isRefreshing = true;
    });

    try {
      final page = await _fetchPage(1);
      if (!mounted) return;
      _startupInitialRetryTimer?.cancel();
      _startupInitialRetryTimer = null;
      final shouldReplaceItems = !_originPageMatchesCurrent(page);
      setState(() {
        if (shouldReplaceItems) {
          _items
            ..clear()
            ..addAll(page.items);
          _discussPreviews
            ..clear()
            ..addAll(page.discussPreviews);
        }
        _total = page.total;
        _nextPage = 2;
        _hasMore = _items.length < _total && page.items.isNotEmpty;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_shouldKeepInitialNetworkFailureLoading(error)) {
        setState(() {
          _error = null;
          _isInitialLoading = true;
          _isRefreshing = false;
        });
        _scheduleStartupInitialRetry();
        return;
      }
      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  bool _originPageMatchesCurrent(_OriginListPage page) {
    if (_total != page.total || _items.length != page.items.length) {
      return false;
    }
    for (var index = 0; index < _items.length; index += 1) {
      final current = _items[index];
      final next = page.items[index];
      if (_originItemSignature(current) != _originItemSignature(next)) {
        return false;
      }
      if (_originDiscussSignature(_discussPreviews[current.oid]) !=
          _originDiscussSignature(page.discussPreviews[next.oid])) {
        return false;
      }
    }
    return true;
  }

  String _originItemSignature(OriginListItem item) {
    return <Object?>[
      item.oid,
      item.wid,
      item.status,
      item.versionNum,
      item.tickCount,
      item.name,
      item.deleted,
      item.cover,
      item.displaySubtitle,
      item.worldView,
      item.createdUid,
      item.createdUserName,
      item.ownerName,
      item.createdAt,
      item.updatedAt,
      item.tags.join('\n'),
      item.copyCnt,
      item.connectCnt,
      item.discussCnt,
      item.characterCnt,
      item.locationCnt,
    ].join('\u001F');
  }

  String _originDiscussSignature(List<OriginDiscussPreviewItem>? items) {
    return (items ?? const <OriginDiscussPreviewItem>[])
        .map(
          (item) => <Object?>[
            item.discussId,
            item.authorName,
            item.content,
            item.replyCount,
            item.createdAt,
          ].join('\u001E'),
        )
        .join('\u001F');
  }

  bool _shouldKeepInitialNetworkFailureLoading(Object error) {
    return widget.keepInitialNetworkFailureLoading &&
        _items.isEmpty &&
        !_hasLoadedCachedPage &&
        _isNetworkLikeHomeError(error);
  }

  void _scheduleStartupInitialRetry() {
    if (_startupInitialRetryTimer?.isActive ?? false) return;
    _startupInitialRetryTimer = Timer(_homeInitialNetworkRetryDelay, () {
      _startupInitialRetryTimer = null;
      if (!mounted || !widget.networkRequestsAllowed.value) return;
      final controller = _tabController;
      if (controller == null || controller.index != widget.index) return;
      unawaited(_refreshItems(force: true));
    });
  }

  Future<void> _loadNextPage() async {
    if (!widget.networkRequestsAllowed.value ||
        !_hasMore ||
        _isInitialLoading ||
        _isLoadingMore ||
        _isRefreshing) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final page = await _fetchPage(_nextPage);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _discussPreviews.addAll(page.discussPreviews);
        _total = page.total;
        _nextPage += 1;
        _hasMore = _items.length < _total && page.items.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final waitingForStartupNetwork = !widget.networkRequestsAllowed.value;
    if (_items.isEmpty &&
        (_isInitialLoading ||
            (!_hasRequested && !_hasLoadedCachedPage) ||
            (waitingForStartupNetwork && !_hasLoadedCachedPage))) {
      return const GenesisListLoadingSkeleton.popularOriginList();
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Load failed'),
            const SizedBox(height: 10),
            FilledButton(onPressed: _refreshItems, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: _items.isEmpty
          ? ListView(
              key: const PageStorageKey<String>('home-feed-popular'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  child: const Center(child: Text('No data')),
                ),
              ],
            )
          : PopularOriginList(
              storageKey: const PageStorageKey<String>('home-feed-popular'),
              items: _items,
              controller: _scrollController,
              isLoadingMore: _isLoadingMore,
              preloadedDiscussItems: _discussPreviews,
              onItemTap: (item) {
                if (item.deleted) return;
                GenesisTelemetry.collectLog(
                  actionType: 'event',
                  action: 'home_popular_click',
                  object1: item.oid,
                );
                Navigator.of(context).pushNamed(
                  RouteNames.originWorld,
                  arguments: {'originId': 0, 'oid': item.oid},
                );
              },
            ),
    );
  }
}

class _OriginListPage {
  const _OriginListPage({
    required this.items,
    required this.total,
    required this.discussPreviews,
  });

  final List<OriginListItem> items;
  final int total;
  final Map<String, List<OriginDiscussPreviewItem>> discussPreviews;
}
