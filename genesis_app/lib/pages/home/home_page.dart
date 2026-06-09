import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/genesis_logo.dart';
import '../../components/home/popular_origin_list.dart';
import '../../components/home/world_item_card.dart';
import '../../components/origin/origin_item_card.dart';
import '../../components/search_bar.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/secend_tabs.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const List<String> tabs = ['My World', 'Popular'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          const _HomeHeader(),
          const SizedBox(height: 4),
          SecendTabs(labels: tabs),
          const SizedBox(height: 4),
          const Expanded(
            child: TabBarView(
              children: [_MyWorldFeed(index: 0), _PopularOriginFeed(index: 1)],
            ),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            const GenesisLogo(height: 26.2),
            const SizedBox(width: 12),
            Expanded(
              child: SearchBarPlaceholder(
                hintText: 'Search origins, worlds, users...',
                onTap: () {
                  Navigator.of(context).pushNamed(RouteNames.search);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyWorldFeed extends StatefulWidget {
  const _MyWorldFeed({required this.index});

  final int index;

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
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
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
      ownerUid: uid,
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
                    child: WorldItemCard(
                      item: vm,
                      thumbnailBorderRadius: 0,
                      showPreviewImages: false,
                    ),
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
  const _PopularOriginFeed({required this.index});

  final int index;

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
    if (oldWidget.index != widget.index) {
      _resetListState();
      _requestIfCurrentTab();
    }
  }

  @override
  void dispose() {
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
    ).api.v1.origin.list(pn: page, rn: _pageSize);
    final list = data['list'];
    final items = list is List
        ? list
              .whereType<Map>()
              .map((raw) => OriginListItem.fromJson(asJsonMap(raw)))
              .toList(growable: false)
        : const <OriginListItem>[];
    return _OriginListPage(items: items, total: asInt(data['total']));
  }

  Future<void> _refreshItems() async {
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
              thumbnailBorderRadius: 0,
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
  const _OriginListPage({required this.items, required this.total});

  final List<OriginListItem> items;
  final int total;
}
