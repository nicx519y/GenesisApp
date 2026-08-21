part of 'home_page.dart';

class _PopularOriginFeed extends StatefulWidget {
  const _PopularOriginFeed({
    required this.index,
    required this.initialRequestMetricWindow,
    required this.networkRequestsAllowed,
    required this.keepInitialNetworkFailureLoading,
    this.activationListenable,
    this.isActiveListenable,
    this.isFirstPageViewReported,
    this.onFirstPageViewReady,
  });

  final int index;
  final Duration initialRequestMetricWindow;
  final ValueListenable<bool> networkRequestsAllowed;
  final bool keepInitialNetworkFailureLoading;
  final ValueListenable<int>? activationListenable;
  final ValueListenable<bool>? isActiveListenable;
  final bool Function(String action)? isFirstPageViewReported;
  final void Function(String action)? onFirstPageViewReady;

  @override
  State<_PopularOriginFeed> createState() => _PopularOriginFeedState();
}

class _PopularOriginFeedState extends State<_PopularOriginFeed>
    with AutomaticKeepAliveClientMixin<_PopularOriginFeed> {
  static const _pageViewAction = 'home_popular';
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
  var _initialContentReady = false;
  var _firstPageViewReportedFallback = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  Object? _error;
  FirebasePerformanceOperation? _activeFirstScreenRequestOperation;
  FirebasePerformanceOperation? _activeFirstScreenRenderOperation;
  var _firstScreenRequestAttempt = 0;
  var _firstScreenRenderCompleted = false;

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
    _tryRecordFirstPageView();
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
      _tryRecordFirstPageView();
    }
  }

  @override
  void dispose() {
    _startupInitialRetryTimer?.cancel();
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
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
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
    _activeFirstScreenRequestOperation = null;
    _activeFirstScreenRenderOperation = null;
    _firstScreenRequestAttempt = 0;
    _firstScreenRenderCompleted = false;
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
    _initialContentReady = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _error = null;
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
    _markInitialContentReady();
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

    FirebasePerformanceOperation? requestOperation;
    final shouldTrackFirstScreen = !_firstScreenRenderCompleted;
    if (shouldTrackFirstScreen) {
      final attempt = ++_firstScreenRequestAttempt;
      requestOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.popular,
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
      _startupInitialRetryTimer?.cancel();
      _startupInitialRetryTimer = null;
      final shouldReplaceItems = !_originPageMatchesCurrent(page);
      FirebasePerformanceOperation? renderOperation;
      if (shouldTrackFirstScreen &&
          _tabController?.index == widget.index &&
          !_firstScreenRenderCompleted) {
        renderOperation = await FirebasePerformanceOperation.start(
          surface: FirebasePerformanceSurface.popular,
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
            GenesisButton(
              label: 'Retry',
              onPressed: _refreshItems,
              size: GenesisButtonSize.compact,
              fullWidth: false,
            ),
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
