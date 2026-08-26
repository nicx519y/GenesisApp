import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/firebase_performance_operation.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/origin/origin_item_card.dart';
import '../../components/page_header.dart';
import '../../components/search_bar.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/secend_tabs.dart';
import 'origin_feed_cache_store.dart';

class OriginPage extends StatefulWidget {
  const OriginPage({
    super.key,
    this.isInitialPage = false,
    this.onForYouFirstPageReady,
    this.activationListenable,
  });

  final bool isInitialPage;
  final VoidCallback? onForYouFirstPageReady;
  final ValueListenable<int>? activationListenable;

  @override
  State<OriginPage> createState() => _OriginPageState();
}

class _OriginPageState extends State<OriginPage> with WidgetsBindingObserver {
  static const _tabsHeight = 32.0;
  static const _scrollToTopDuration = Duration(milliseconds: 240);
  static const _forYouCategory = _OriginCategory(
    name: 'For you',
    scene: 'foryou',
  );

  final _hotTagsCache = const _OriginHotTagsCache();
  final Map<_OriginCategory, GlobalKey<_OriginFeedState>> _feedKeys = {};
  List<_OriginCategory> _categories = const [_forYouCategory];
  TabController? _categoryTabController;
  var _scrollToTopInProgress = false;
  var _hasSyncedHotTags = false;
  var _hotTagsSyncInFlight = false;
  var _retryHotTagsOnResume = false;
  AppLifecycleState? _lifecycleState;

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    widget.activationListenable?.addListener(_handleMainNavReselected);
    unawaited(_syncHotTags());
    unawaited(_hydrateCachedCategories());
  }

  @override
  void didUpdateWidget(covariant OriginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handleMainNavReselected);
      widget.activationListenable?.addListener(_handleMainNavReselected);
    }
  }

  @override
  void dispose() {
    widget.activationListenable?.removeListener(_handleMainNavReselected);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  GlobalKey<_OriginFeedState> _feedKeyFor(_OriginCategory category) {
    return _feedKeys.putIfAbsent(category, () => GlobalKey<_OriginFeedState>());
  }

  void _handleCategoryTap(BuildContext tabContext, int index) {
    final controller = DefaultTabController.of(tabContext);
    _categoryTabController = controller;
    if (controller.index != index || controller.indexIsChanging) return;
    unawaited(_scrollCategoryToTop(index));
  }

  void _handleMainNavReselected() {
    final controller = _categoryTabController;
    if (controller == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleMainNavReselected();
      });
      return;
    }
    if (controller.index != 0) {
      controller.animateTo(
        0,
        duration: _scrollToTopDuration,
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(_scrollCategoryToTop(0));
  }

  Future<void> _scrollCategoryToTop(int index) async {
    if (index < 0 || index >= _categories.length || _scrollToTopInProgress) {
      return;
    }
    _scrollToTopInProgress = true;
    try {
      final feedState = _feedKeyFor(_categories[index]).currentState;
      if (feedState != null) await feedState.scrollToTop();
    } finally {
      _scrollToTopInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed || _hasSyncedHotTags) return;
    if (_hotTagsSyncInFlight) {
      _retryHotTagsOnResume = true;
      return;
    }
    unawaited(_syncHotTags());
  }

  Future<void> _hydrateCachedCategories() async {
    final cachedTags = await _hotTagsCache.load();
    if (!mounted) return;
    if (_hasSyncedHotTags || cachedTags.isEmpty) return;
    setState(() {
      _categories = _categoriesFromTags(cachedTags);
    });
  }

  Future<void> _syncHotTags() async {
    if (_hasSyncedHotTags || _hotTagsSyncInFlight) return;
    _hotTagsSyncInFlight = true;
    try {
      final tags = await AppServicesScope.read(context).api.v1.origin.hotTags();
      final normalizedTags = _normalizeTags(tags);
      await _hotTagsCache.save(normalizedTags);
      if (!mounted) return;
      setState(() {
        _hasSyncedHotTags = true;
        _categories = _categoriesFromTags(normalizedTags);
      });
    } catch (_) {
      // Keep the already rendered For you tab or cached tabs on sync failure.
      // A later foreground transition retries this request after a system
      // network permission sheet or a temporary offline period.
    } finally {
      _hotTagsSyncInFlight = false;
      if (_retryHotTagsOnResume &&
          _lifecycleState == AppLifecycleState.resumed &&
          mounted) {
        _retryHotTagsOnResume = false;
        unawaited(_syncHotTags());
      }
    }
  }

  void _retryHotTagsIfNeeded() {
    if (_hasSyncedHotTags || _hotTagsSyncInFlight || !mounted) return;
    _retryHotTagsOnResume = false;
    unawaited(_syncHotTags());
  }

  static List<_OriginCategory> _categoriesFromTags(List<String> tags) {
    return [
      _forYouCategory,
      for (final tag in _normalizeTags(tags))
        _OriginCategory(name: tag, scene: 'tag'),
    ];
  }

  static List<String> _normalizeTags(List<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (key == _forYouCategory.name.toLowerCase()) continue;
      if (!seen.add(key)) continue;
      result.add(trimmed);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final labels = categories.map((item) => item.name).toList();
    return DefaultTabController(
      length: categories.length,
      child: Builder(
        builder: (tabContext) {
          _categoryTabController = DefaultTabController.of(tabContext);
          return Column(
            children: [
              GenesisTopSafeArea(
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: kGenesisTopBarHeight + 4,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: kGenesisTopBarHeight,
                        child: Transform.translate(
                          offset: const Offset(0, 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: SearchBarPlaceholder(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed(RouteNames.search);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: _tabsHeight,
                child: ColoredBox(
                  color: Colors.white,
                  child: SecendTabs(
                    labels: labels,
                    verticalPadding: 0,
                    onTap: (index) => _handleCategoryTap(tabContext, index),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final entry in categories.indexed)
                      _OriginFeed(
                        key: _feedKeyFor(entry.$2),
                        index: entry.$1,
                        category: entry.$2,
                        isInitialPage: widget.isInitialPage && entry.$1 == 0,
                        onFirstPageReady: entry.$1 == 0
                            ? widget.onForYouFirstPageReady
                            : null,
                        onInitialLoadCompleted: entry.$1 == 0
                            ? _retryHotTagsIfNeeded
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OriginHotTagsCache {
  const _OriginHotTagsCache();

  static const storageKey = 'origin_hot_tags_v1';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(storageKey) ?? const <String>[];
  }

  Future<void> save(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageKey, tags);
  }
}

class _OriginCategory {
  const _OriginCategory({required this.name, required this.scene});

  final String name;
  final String scene;

  @override
  bool operator ==(Object other) {
    return other is _OriginCategory &&
        other.name == name &&
        other.scene == scene;
  }

  @override
  int get hashCode => Object.hash(name, scene);
}

class _OriginFeed extends StatefulWidget {
  const _OriginFeed({
    super.key,
    required this.index,
    required this.category,
    this.isInitialPage = false,
    this.onFirstPageReady,
    this.onInitialLoadCompleted,
  });

  final int index;
  final _OriginCategory category;
  final bool isInitialPage;
  final VoidCallback? onFirstPageReady;
  final VoidCallback? onInitialLoadCompleted;

  @override
  State<_OriginFeed> createState() => _OriginFeedState();
}

class _OriginFeedState extends State<_OriginFeed>
    with AutomaticKeepAliveClientMixin<_OriginFeed>, WidgetsBindingObserver {
  static const _pageSize = 20;
  static const _loadMoreThreshold = 700.0;

  TabController? _tabController;
  final List<OriginListItem> _items = <OriginListItem>[];
  var _nextPage = 1;
  var _total = 0;
  var _hasMore = true;
  var _hasRequested = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  var _hasCompletedFirstPageNetworkRequest = false;
  Object? _error;
  ScrollPosition? _scrollPosition;
  var _initialLoadCompleted = false;
  var _initialLoadInFlight = false;
  var _permissionPromptMayBeOpen = false;
  var _retryInitialLoadWhenFinished = false;
  var _hasRetriedInitialStartup = false;
  FirebasePerformanceOperation? _activeFirstScreenRequestOperation;
  FirebasePerformanceOperation? _activeFirstScreenRenderOperation;
  var _firstScreenRequestAttempt = 0;
  var _firstScreenRenderCompleted = false;

  bool get _usesFirstPageCache => widget.category.scene == 'foryou';

  @override
  bool get wantKeepAlive => true;

  bool get _isPrimaryFeed =>
      widget.index == 0 && widget.category.scene == 'foryou';

  Future<void> scrollToTop() async {
    final position = _scrollPosition;
    if (position == null || !position.hasPixels) return;
    final minExtent = position.minScrollExtent;
    if (position.pixels <= minExtent) return;
    await position.animateTo(
      minExtent,
      duration: _OriginPageState._scrollToTopDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _trackForYouListLoad({required String type, required int page}) {
    if (!_isPrimaryFeed) return;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_list_load',
      object1: type,
      object2: page,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isPrimaryFeed || _initialLoadCompleted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // The iOS wireless-data permission sheet makes the app inactive. Keep
      // the first feed in its loading state until the sheet is dismissed.
      if (_initialLoadInFlight || _isInitialLoading) {
        _permissionPromptMayBeOpen = true;
      }
      return;
    }

    if (state != AppLifecycleState.resumed || !_hasRequested) return;

    // Any first-page failure can be caused by a transient network or system
    // permission transition. Retry once when the app is actually foregrounded.
    _permissionPromptMayBeOpen = false;
    if (_initialLoadInFlight) {
      _retryInitialLoadWhenFinished = true;
      return;
    }
    _hasRetriedInitialStartup = true;
    unawaited(_refreshItems());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (_tabController != nextController) {
      _tabController?.removeListener(_handleTabChange);
      _tabController = nextController..addListener(_handleTabChange);
    }
    _requestIfCurrentTab();
  }

  @override
  void didUpdateWidget(covariant _OriginFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _resetListState() {
    unawaited(_activeFirstScreenRequestOperation?.cancel());
    unawaited(_activeFirstScreenRenderOperation?.cancel());
    _activeFirstScreenRequestOperation = null;
    _activeFirstScreenRenderOperation = null;
    _firstScreenRequestAttempt = 0;
    _firstScreenRenderCompleted = false;
    _items.clear();
    _nextPage = 1;
    _total = 0;
    _hasMore = true;
    _hasRequested = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _hasCompletedFirstPageNetworkRequest = false;
    _error = null;
    _initialLoadCompleted = false;
    _initialLoadInFlight = false;
    _permissionPromptMayBeOpen = false;
    _retryInitialLoadWhenFinished = false;
    _hasRetriedInitialStartup = false;
  }

  void _scheduleFirstScreenRenderCompletion(
    FirebasePerformanceOperation operation,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_activeFirstScreenRenderOperation, operation) ||
          !_isPrimaryFeed ||
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
  }

  void _requestIfCurrentTab() {
    final controller = _tabController;
    if (controller == null ||
        controller.index != widget.index ||
        _hasRequested) {
      return;
    }
    _hasRequested = true;
    if (_usesFirstPageCache) unawaited(_hydrateCachedFirstPage());
    unawaited(_refreshItems());
  }

  bool _handleScroll(ScrollNotification notification) {
    final scrollableContext = notification.context;
    if (notification.depth == 0 && scrollableContext != null) {
      _scrollPosition = Scrollable.maybeOf(scrollableContext)?.position;
    }
    if (notification.depth != 0 ||
        notification.metrics.extentAfter > _loadMoreThreshold) {
      return false;
    }
    if (!_hasMore || _isInitialLoading || _isLoadingMore || _isRefreshing) {
      return false;
    }
    _trackForYouListLoad(type: 'load_more', page: _nextPage);
    unawaited(_loadNextPage());
    return false;
  }

  Future<void> _refreshFromPull() {
    _trackForYouListLoad(type: 'refresh', page: 1);
    return _refreshItems();
  }

  Future<_OriginListPage> _fetchPage(int page) async {
    final scene = widget.category.scene;
    final data = await AppServicesScope.of(context).api.v1.origin.list(
      scene: scene,
      tag: scene == 'tag' ? widget.category.name : null,
      pn: page,
      rn: _pageSize,
    );
    return _parseOriginListPage(data);
  }

  Future<OriginFeedCacheStore> _cacheStoreForCurrentOwner() async {
    final services = AppServicesScope.of(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    final ownerUid =
        uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty
        ? uid
        : OriginFeedCacheStore.anonymousOwnerUid;
    return OriginFeedCacheStore(ownerUid: ownerUid);
  }

  Future<void> _hydrateCachedFirstPage() async {
    Map<String, dynamic>? data;
    try {
      final cacheStore = await _cacheStoreForCurrentOwner();
      data = await cacheStore.loadForYouFirstPage();
    } catch (_) {
      return;
    }
    if (!mounted ||
        !_usesFirstPageCache ||
        _hasCompletedFirstPageNetworkRequest ||
        data == null) {
      return;
    }
    final page = _parseOriginListPage(data);
    if (!mounted || _hasCompletedFirstPageNetworkRequest) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _nextPage = 2;
      _hasMore = _items.length < _total && page.items.isNotEmpty;
      _isInitialLoading = false;
      _error = null;
    });
    widget.onFirstPageReady?.call();
  }

  Future<void> _saveFirstPageCache(Map<String, dynamic> data) async {
    try {
      final cacheStore = await _cacheStoreForCurrentOwner();
      await cacheStore.saveForYouFirstPage(data);
    } catch (_) {
      // Cache writes must not affect the visible network result.
    }
  }

  Future<void> _refreshItems() async {
    if (_initialLoadInFlight) return;
    _initialLoadInFlight = _isPrimaryFeed && !_initialLoadCompleted;
    setState(() {
      _error = null;
      _isInitialLoading = _items.isEmpty;
      _isRefreshing = true;
    });

    FirebasePerformanceOperation? requestOperation;
    final shouldTrackFirstScreen =
        _isPrimaryFeed && !_firstScreenRenderCompleted;
    if (shouldTrackFirstScreen) {
      final attempt = ++_firstScreenRequestAttempt;
      requestOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.worldo,
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
      _hasCompletedFirstPageNetworkRequest = true;
      if (_usesFirstPageCache) {
        unawaited(_saveFirstPageCache(page.rawData));
      }
      FirebasePerformanceOperation? renderOperation;
      if (shouldTrackFirstScreen &&
          _tabController?.index == widget.index &&
          !_firstScreenRenderCompleted) {
        renderOperation = await FirebasePerformanceOperation.start(
          surface: FirebasePerformanceSurface.worldo,
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
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _nextPage = 2;
        _hasMore = _items.length < _total && page.items.isNotEmpty;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
      widget.onFirstPageReady?.call();
      if (renderOperation != null) {
        _scheduleFirstScreenRenderCompletion(renderOperation);
      }
      _initialLoadInFlight = false;
      if (_isPrimaryFeed) {
        _initialLoadCompleted = true;
        widget.onInitialLoadCompleted?.call();
      }
    } catch (error) {
      if (identical(_activeFirstScreenRequestOperation, requestOperation)) {
        _activeFirstScreenRequestOperation = null;
      }
      unawaited(
        requestOperation?.fail(errorType: firebasePerformanceErrorType(error)),
      );
      if (!mounted) return;
      final shouldRetryAfterResume = _retryInitialLoadWhenFinished;
      _retryInitialLoadWhenFinished = false;
      _initialLoadInFlight = false;
      final keepInitialStartupSkeleton =
          _isPrimaryFeed &&
          widget.isInitialPage &&
          !_hasRetriedInitialStartup &&
          !_hasCompletedFirstPageNetworkRequest;
      if (_permissionPromptMayBeOpen || keepInitialStartupSkeleton) {
        setState(() {
          _error = null;
          _isInitialLoading = true;
          _isRefreshing = false;
        });
        return;
      }
      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
      if (shouldRetryAfterResume && mounted) {
        _hasRetriedInitialStartup = true;
        unawaited(_refreshItems());
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isInitialLoading || _isLoadingMore || _isRefreshing) {
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
    final scrollKey = PageStorageKey<String>(
      'origin-feed-${widget.category.name}-${widget.category.scene}',
    );
    const physics = BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );

    if (!_hasRequested ||
        _isInitialLoading ||
        (_permissionPromptMayBeOpen && !_initialLoadCompleted)) {
      return const GenesisListLoadingSkeleton.originGrid();
    }

    if (_error != null && _items.isEmpty) {
      return CustomScrollView(
        key: scrollKey,
        primary: true,
        physics: physics,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Load failed'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _refreshItems,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFromPull,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: _items.isEmpty
            ? CustomScrollView(
                key: scrollKey,
                primary: true,
                physics: physics,
                slivers: const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No data')),
                  ),
                ],
              )
            : CustomScrollView(
                key: scrollKey,
                primary: true,
                scrollCacheExtent: const ScrollCacheExtent.pixels(900),
                physics: physics,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childCount: _items.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final item = _items[index];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: item.deleted
                              ? null
                              : () {
                                  GenesisTelemetry.collectLog(
                                    actionType: 'event',
                                    action: 'worldo_list_click',
                                    object1: item.oid,
                                  );
                                  Navigator.of(context).pushNamed(
                                    RouteNames.originWorld,
                                    arguments: {
                                      'originId': 0,
                                      'oid': item.oid,
                                      'initialName': item.name,
                                    },
                                  );
                                },
                          child: OriginItemCard(item: item),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OriginListPage {
  const _OriginListPage({
    required this.items,
    required this.total,
    required this.rawData,
  });

  final List<OriginListItem> items;
  final int total;
  final Map<String, dynamic> rawData;
}

_OriginListPage _parseOriginListPage(Map<String, dynamic> data) {
  final list = data['list'];
  final items = list is List
      ? list
            .whereType<Map>()
            .map((raw) => OriginListItem.fromJson(asJsonMap(raw)))
            .toList(growable: false)
      : const <OriginListItem>[];
  return _OriginListPage(
    items: items,
    total: asInt(data['total']),
    rawData: data,
  );
}
