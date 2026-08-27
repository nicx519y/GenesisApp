part of 'home_page.dart';

class _MyWorldFeed extends StatefulWidget {
  const _MyWorldFeed({
    required this.index,
    required this.initialRequestMetricWindow,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    this.activationListenable,
    this.isActiveListenable,
    this.isFirstPageViewReported,
    this.onFirstPageViewReady,
    this.initialPageData,
    this.initialPageRenderOperation,
    this.initialPageRequestAttempt = 0,
  });

  final int index;
  final Duration initialRequestMetricWindow;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool>? isActiveListenable;
  final bool Function(String action)? isFirstPageViewReported;
  final void Function(String action)? onFirstPageViewReady;
  final Map<String, dynamic>? initialPageData;
  final FirebasePerformanceOperation? initialPageRenderOperation;
  final int initialPageRequestAttempt;

  @override
  State<_MyWorldFeed> createState() => _MyWorldFeedState();
}

class _MyWorldFeedState extends State<_MyWorldFeed>
    with AutomaticKeepAliveClientMixin<_MyWorldFeed> {
  static const _pageViewAction = 'home_my_worlds';
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
  var _initialContentReady = false;
  var _firstPageViewReportedFallback = false;
  var _hasResolvedLocalSession = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  var _isSignedOut = false;
  String _activityTagUid = '';
  WorldActivityTagState? _activityTagState;
  Object? _error;
  FirebasePerformanceOperation? _activeFirstScreenRequestOperation;
  FirebasePerformanceOperation? _activeFirstScreenRenderOperation;
  var _firstScreenRequestAttempt = 0;
  var _firstScreenRenderCompleted = false;

  @override
  void initState() {
    super.initState();
    _firstScreenRequestAttempt = widget.initialPageRequestAttempt;
    _activeFirstScreenRenderOperation = widget.initialPageRenderOperation;
    _hydrateInitialPageDataIfAvailable();
    _scheduleInitialPageRenderCompletionIfNeeded();
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
    _tryRecordFirstPageView();
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
      _tryRecordFirstPageView();
    }
  }

  @override
  void dispose() {
    _startupInitialRetryTimer?.cancel();
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
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
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
    _activeFirstScreenRequestOperation = null;
    _activeFirstScreenRenderOperation = null;
    _firstScreenRequestAttempt = 0;
    _firstScreenRenderCompleted = false;
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
    _initialContentReady = false;
    _hasResolvedLocalSession = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _isSignedOut = false;
    _error = null;
  }

  void _scheduleInitialPageRenderCompletionIfNeeded() {
    final operation = _activeFirstScreenRenderOperation;
    if (operation == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_activeFirstScreenRenderOperation, operation) ||
          _tabController?.index != widget.index) {
        if (identical(_activeFirstScreenRenderOperation, operation)) {
          _activeFirstScreenRenderOperation = null;
        }
        unawaited(operation.cancel());
        return;
      }
      _activeFirstScreenRenderOperation = null;
      _firstScreenRenderCompleted = true;
      unawaited(operation.succeed());
    });
  }

  void _scheduleFirstScreenRenderCompletion(
    FirebasePerformanceOperation operation,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_activeFirstScreenRenderOperation, operation) ||
          _tabController?.index != widget.index) {
        if (identical(_activeFirstScreenRenderOperation, operation)) {
          _activeFirstScreenRenderOperation = null;
        }
        unawaited(operation.cancel());
        return;
      }
      _activeFirstScreenRenderOperation = null;
      _firstScreenRenderCompleted = true;
      unawaited(operation.succeed());
    });
  }

  void _hydrateInitialPageDataIfAvailable() {
    final data = widget.initialPageData;
    if (data == null) return;
    final page = _parseWorldListPage(data);
    _items
      ..clear()
      ..addAll(page.items);
    _total = page.total;
    _nextPage = 2;
    _hasMore = _items.length < _total && page.items.isNotEmpty;
    _hasRequested = true;
    _hasAttemptedCachePreload = true;
    _hasLoadedCachedPage = true;
    _initialContentReady = true;
    _hasResolvedLocalSession = true;
    _isSignedOut = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _cacheLoadFuture = Future<bool>.value(true);
    unawaited(_syncLastTickActivityTagFromItems(page.items));
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
    _tryRecordFirstPageView();
  }

  void _handleNetworkRequestsAllowed() {
    if (widget.networkRequestsAllowed.value) {
      _requestIfCurrentTab();
      _tryRecordFirstPageView();
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
      if (_hasReportedFirstPageView) {
        _recordPageView();
      } else {
        _tryRecordFirstPageView();
      }
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
    if (_hasReportedFirstPageView) _recordPageView();
    unawaited(_requestInitialItems());
  }

  bool get _hasReportedFirstPageView =>
      widget.isFirstPageViewReported?.call(_pageViewAction) ??
      _firstPageViewReportedFallback;

  bool get _isPageActive {
    final controller = _tabController;
    return (widget.isActiveListenable?.value ?? true) &&
        controller != null &&
        controller.index == widget.index;
  }

  void _recordPageView() {
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: _pageViewAction,
    );
  }

  void _tryRecordFirstPageView() {
    if (!_hasRequested ||
        !_initialContentReady ||
        !_isPageActive ||
        _hasReportedFirstPageView) {
      return;
    }
    final callback = widget.onFirstPageViewReady;
    if (callback != null) {
      callback(_pageViewAction);
      return;
    }
    _firstPageViewReportedFallback = true;
    _recordPageView();
  }

  void _markInitialContentReady() {
    _initialContentReady = true;
    _tryRecordFirstPageView();
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
    _markInitialContentReady();
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
    return _parseHomeWorldListPage(
      data,
      locallyDeletedWorldIds: _locallyDeletedWorldIds,
    );
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

    FirebasePerformanceOperation? requestOperation;
    final shouldTrackFirstScreen = !_firstScreenRenderCompleted;
    if (shouldTrackFirstScreen) {
      final attempt = ++_firstScreenRequestAttempt;
      requestOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.myWorlds,
        phase: FirebasePerformancePhase.request,
        attempt: attempt,
      );
      if (!mounted) {
        unawaited(requestOperation.cancel());
        return;
      }
      _activeFirstScreenRequestOperation = requestOperation;
    }

    try {
      final page = await _fetchPage(1);
      if (!mounted) {
        unawaited(requestOperation?.cancel());
        return;
      }
      if (identical(_activeFirstScreenRequestOperation, requestOperation)) {
        _activeFirstScreenRequestOperation = null;
      }
      unawaited(requestOperation?.succeed());
      unawaited(_syncLastTickActivityTagFromItems(page.items));
      _startupInitialRetryTimer?.cancel();
      _startupInitialRetryTimer = null;
      final shouldReplaceItems = !_worldPageMatchesCurrent(page);
      FirebasePerformanceOperation? renderOperation;
      if (shouldTrackFirstScreen &&
          _tabController?.index == widget.index &&
          !_firstScreenRenderCompleted) {
        renderOperation = await FirebasePerformanceOperation.start(
          surface: FirebasePerformanceSurface.myWorlds,
          phase: FirebasePerformancePhase.render,
          attempt: requestOperation?.attempt ?? _firstScreenRequestAttempt,
          timeout: FirebasePerformanceOperation.renderTimeout,
        );
        if (!mounted || _tabController?.index != widget.index) {
          unawaited(renderOperation.cancel());
          renderOperation = null;
        } else {
          _activeFirstScreenRenderOperation = renderOperation;
        }
      }
      if (!mounted) return;
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
      _markInitialContentReady();
      if (renderOperation != null) {
        _scheduleFirstScreenRenderCompletion(renderOperation);
      }
    } catch (error) {
      if (identical(_activeFirstScreenRequestOperation, requestOperation)) {
        _activeFirstScreenRequestOperation = null;
      }
      unawaited(
        requestOperation?.fail(errorType: firebasePerformanceErrorType(error)),
      );
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
      item.lastProgressSubTickNo,
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
      arguments: {
        'wid': item.wid,
        'initialName': item.name,
        'initiallyLaunched': true,
      },
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
                      : 30,
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
