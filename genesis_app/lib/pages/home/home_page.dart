import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/auth/login_guard.dart';
import '../../components/discuss/origin_discuss_preview_list.dart';
import '../../components/genesis_logo.dart';
import '../../components/home/popular_origin_list.dart';
import '../../components/home/world_item_card.dart';
import '../../components/origin/origin_item_card.dart';
import '../../components/page_header.dart';
import '../../components/search_bar.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/secend_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialTabIndex, this.activationListenable});

  static const List<String> tabs = ['My Worlds', 'Popular'];
  static const int myWorldsTabIndex = 0;
  static const int popularTabIndex = 1;

  final int? initialTabIndex;
  final ValueListenable<int>? activationListenable;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<int> _initialTabIndexFuture;

  @override
  void initState() {
    super.initState();
    _initialTabIndexFuture = _initialTabIndex();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _initialTabIndexFuture = _initialTabIndex();
    }
  }

  Future<int> _initialTabIndex() async {
    final requestedIndex = widget.initialTabIndex;
    if (requestedIndex != null) {
      return requestedIndex.clamp(0, HomePage.tabs.length - 1);
    }
    return await _hasLocalLoginSession()
        ? HomePage.myWorldsTabIndex
        : HomePage.popularTabIndex;
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _initialTabIndexFuture,
      builder: (context, snapshot) {
        final initialIndex = snapshot.data;
        if (initialIndex == null) {
          return const Column(
            children: [
              _HomeHeader(),
              SizedBox(height: 4),
              Expanded(child: GenesisListLoadingSkeleton.popularOriginList()),
            ],
          );
        }

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
                  activationListenable: widget.activationListenable,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTabs extends StatefulWidget {
  const _HomeTabs();

  @override
  State<_HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<_HomeTabs> {
  static const _myWorldsIndex = 0;
  static const _popularIndex = 1;

  bool _handlingLogin = false;

  Future<void> _handleTap(int index) async {
    if (index != _myWorldsIndex || _handlingLogin) return;
    final controller = DefaultTabController.of(context);
    final cameFromPopular =
        controller.index == _popularIndex ||
        controller.previousIndex == _popularIndex;
    if (!cameFromPopular) return;

    controller.animateTo(_popularIndex, duration: Duration.zero);

    _handlingLogin = true;
    try {
      final loggedIn = await ensureGenesisLogin(context);
      if (!mounted || !loggedIn) return;
      controller.animateTo(_myWorldsIndex);
    } finally {
      _handlingLogin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecendTabs(
      labels: HomePage.tabs,
      verticalPadding: 0,
      onTap: _handleTap,
    );
  }
}

class _HomeTabView extends StatefulWidget {
  const _HomeTabView({this.activationListenable});

  final ValueListenable<int>? activationListenable;

  @override
  State<_HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<_HomeTabView> {
  static const _myWorldsIndex = HomePage.myWorldsTabIndex;
  static const _popularIndex = HomePage.popularTabIndex;

  bool? _loggedIn;
  bool _handlingLogin = false;
  double _dragDistance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoginState();
  }

  Future<void> _syncLoginState() async {
    final loggedIn = await hasGenesisLoginSession(context);
    if (!mounted || _loggedIn == loggedIn) return;
    setState(() {
      _loggedIn = loggedIn;
    });
  }

  Future<void> _handleMyWorldsSwipe() async {
    if (_handlingLogin) return;
    final controller = DefaultTabController.of(context);
    if (controller.index != _popularIndex) return;
    if (await hasGenesisLoginSession(context)) return;
    if (!mounted) return;

    _handlingLogin = true;
    controller.animateTo(_popularIndex, duration: Duration.zero);
    try {
      final loggedIn = await ensureGenesisLogin(context);
      if (!mounted) return;
      if (loggedIn) {
        setState(() {
          _loggedIn = true;
        });
        controller.animateTo(_myWorldsIndex);
      } else {
        controller.animateTo(_popularIndex, duration: Duration.zero);
      }
    } finally {
      _handlingLogin = false;
      _dragDistance = 0;
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragDistance = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx;
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 0 || _dragDistance > 24) {
      _handleMyWorldsSwipe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedOut = _loggedIn == false;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: signedOut ? _handleHorizontalDragStart : null,
      onHorizontalDragUpdate: signedOut ? _handleHorizontalDragUpdate : null,
      onHorizontalDragEnd: signedOut ? _handleHorizontalDragEnd : null,
      child: TabBarView(
        physics: signedOut ? const NeverScrollableScrollPhysics() : null,
        children: [
          _MyWorldFeed(
            index: 0,
            activationListenable: widget.activationListenable,
          ),
          _PopularOriginFeed(
            index: 1,
            activationListenable: widget.activationListenable,
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
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
  const _MyWorldFeed({required this.index, this.activationListenable});

  final int index;
  final ValueListenable<int>? activationListenable;

  @override
  State<_MyWorldFeed> createState() => _MyWorldFeedState();
}

class _MyWorldFeedState extends State<_MyWorldFeed>
    with AutomaticKeepAliveClientMixin<_MyWorldFeed> {
  static const _pageSize = 20;
  static const _loadMoreThreshold = 700.0;

  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<WorldListItem> _items = <WorldListItem>[];
  var _nextPage = 1;
  var _total = 0;
  var _hasMore = true;
  var _hasRequested = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.activationListenable?.addListener(_handlePageActivated);
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
    _requestIfCurrentTab();
  }

  @override
  void didUpdateWidget(covariant _MyWorldFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handlePageActivated);
      widget.activationListenable?.addListener(_handlePageActivated);
    }
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
    widget.activationListenable?.removeListener(_handlePageActivated);
    _tabController?.removeListener(_handleTabChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _resetListState() {
    _items.clear();
    _nextPage = 1;
    _total = 0;
    _hasMore = true;
    _hasRequested = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _error = null;
  }

  void _handleTabChange() {
    _requestIfCurrentTab();
  }

  void _handlePageActivated() {
    final controller = _tabController;
    if (controller == null || controller.index != widget.index) return;
    if (!_hasRequested) {
      _requestIfCurrentTab();
      return;
    }
    unawaited(_refreshItems());
  }

  void _requestIfCurrentTab() {
    final controller = _tabController;
    if (controller == null ||
        controller.index != widget.index ||
        _hasRequested) {
      return;
    }
    _hasRequested = true;
    _refreshItems();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    _loadNextPage();
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
    final list = data['list'];
    final items = list is List
        ? list
              .whereType<Map>()
              .map((raw) => WorldListItem.fromJson(asJsonMap(raw)))
              .toList(growable: false)
        : const <WorldListItem>[];
    return _WorldListPage(items: items, total: asInt(data['total']));
  }

  Future<void> _refreshItems() async {
    if (_isInitialLoading || _isRefreshing) return;
    if (!await _hasLocalLoginSession()) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _nextPage = 1;
        _total = 0;
        _hasMore = false;
        _error = null;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
      });
      return;
    }

    setState(() {
      _error = null;
      _isInitialLoading = _items.isEmpty;
      _isRefreshing = true;
    });

    try {
      final page = await _fetchPage(1);
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
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
    if (!_hasRequested || _isInitialLoading) {
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

    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: _items.isEmpty
          ? ListView(
              key: const PageStorageKey<String>('home-feed-my-world'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  child: const Center(child: Text('No data')),
                ),
              ],
            )
          : ListView.separated(
              key: const PageStorageKey<String>('home-feed-my-world'),
              controller: _scrollController,
              primary: false,
              cacheExtent: 900,
              padding: const EdgeInsets.only(top: 4),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _items.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(
                height: 25,
                thickness: 1,
                color: Color(0xFFEFEFEF),
              ),
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
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.world, arguments: {'wid': vm.wid}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WorldItemCard(item: vm, showPreviewImages: false),
                  ),
                );
              },
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
  const _PopularOriginFeed({required this.index, this.activationListenable});

  final int index;
  final ValueListenable<int>? activationListenable;

  @override
  State<_PopularOriginFeed> createState() => _PopularOriginFeedState();
}

class _PopularOriginFeedState extends State<_PopularOriginFeed>
    with AutomaticKeepAliveClientMixin<_PopularOriginFeed> {
  static const _pageSize = 20;
  static const _loadMoreThreshold = 700.0;

  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<OriginListItem> _items = <OriginListItem>[];
  final Map<String, List<OriginDiscussPreviewItem>> _discussPreviews =
      <String, List<OriginDiscussPreviewItem>>{};
  var _nextPage = 1;
  var _total = 0;
  var _hasMore = true;
  var _hasRequested = false;
  var _scrollListenerAttached = false;
  var _isInitialLoading = false;
  var _isLoadingMore = false;
  var _isRefreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.activationListenable?.addListener(_handlePageActivated);
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
    _requestIfCurrentTab();
  }

  @override
  void didUpdateWidget(covariant _PopularOriginFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationListenable != widget.activationListenable) {
      oldWidget.activationListenable?.removeListener(_handlePageActivated);
      widget.activationListenable?.addListener(_handlePageActivated);
    }
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
    widget.activationListenable?.removeListener(_handlePageActivated);
    _tabController?.removeListener(_handleTabChange);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _resetListState() {
    _items.clear();
    _discussPreviews.clear();
    _nextPage = 1;
    _total = 0;
    _hasMore = true;
    _hasRequested = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _error = null;
  }

  void _handleTabChange() {
    _requestIfCurrentTab();
  }

  void _handlePageActivated() {
    final controller = _tabController;
    if (controller == null || controller.index != widget.index) return;
    if (!_hasRequested) {
      _requestIfCurrentTab();
      return;
    }
    unawaited(_refreshItems());
  }

  void _requestIfCurrentTab() {
    final controller = _tabController;
    if (controller == null ||
        controller.index != widget.index ||
        _hasRequested) {
      return;
    }
    _hasRequested = true;
    _refreshItems();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    _loadNextPage();
  }

  Future<_OriginListPage> _fetchPage(int page) async {
    final data = await AppServicesScope.of(
      context,
    ).api.v1.origin.list(scene: 'popular', pn: page, rn: _pageSize);
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
    if (mounted) {
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

  Future<void> _refreshItems() async {
    if (_isInitialLoading || _isRefreshing) return;
    setState(() {
      _error = null;
      _isInitialLoading = _items.isEmpty;
      _isRefreshing = true;
    });

    try {
      final page = await _fetchPage(1);
      if (!mounted) return;
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
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
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
    if (!_hasRequested || _isInitialLoading) {
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
