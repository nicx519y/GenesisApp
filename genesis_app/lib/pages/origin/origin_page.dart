import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/list_loading_skeleton.dart';
import '../../components/page_header.dart';
import '../../components/origin/origin_item_card.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/secend_tabs.dart';

class OriginPage extends StatefulWidget {
  const OriginPage({super.key});

  //兜底数据
  static const List<_OriginCategory> _fallbackCategories = [
    _OriginCategory(name: 'For you', scene: 'foryou'),
    _OriginCategory(name: 'adventure', scene: 'tag'),
    _OriginCategory(name: 'drama', scene: 'tag'),
    _OriginCategory(name: 'fantasy', scene: 'tag'),
    _OriginCategory(name: 'identity', scene: 'tag'),
  ];

  @override
  State<OriginPage> createState() => _OriginPageState();
}

class _OriginPageState extends State<OriginPage> {
  late Future<List<_OriginCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<_OriginCategory>> _loadCategories() async {
    try {
      final list = await AppServicesScope.read(context).api.v1.origin.homeNav();
      final categories = list
          .whereType<Map>()
          .map((item) => _OriginCategory.fromJson(asJsonMap(item)))
          .where((item) => item.name.isNotEmpty && item.scene.isNotEmpty)
          .toList(growable: false);
      return categories.isNotEmpty
          ? categories
          : OriginPage._fallbackCategories;
    } catch (_) {
      return OriginPage._fallbackCategories;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_OriginCategory>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final categories = snapshot.data;
        if (categories == null || categories.isEmpty) {
          return const Column(
            children: [
              PageHeader(pageName: 'Origin'),
              Expanded(child: GenesisListLoadingSkeleton.originGrid()),
            ],
          );
        }

        return DefaultTabController(
          length: categories.length,
          child: Column(
            children: [
              const PageHeader(pageName: 'Origin'),
              const SizedBox(height: 4),
              SecendTabs(
                labels: categories.map((item) => item.name).toList(),
                bottomPadding: 0,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final entry in categories.indexed)
                      _OriginFeed(index: entry.$1, category: entry.$2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OriginCategory {
  const _OriginCategory({required this.name, required this.scene});

  factory _OriginCategory.fromJson(Map<String, dynamic> json) {
    return _OriginCategory(
      name: asString(json['name']).trim(),
      scene: asString(json['scene']).trim(),
    );
  }

  final String name;
  final String scene;
}

class _OriginFeed extends StatefulWidget {
  const _OriginFeed({required this.index, required this.category});

  final int index;
  final _OriginCategory category;

  @override
  State<_OriginFeed> createState() => _OriginFeedState();
}

class _OriginFeedState extends State<_OriginFeed>
    with AutomaticKeepAliveClientMixin<_OriginFeed> {
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
    final scene = widget.category.scene;
    final data = await AppServicesScope.of(context).api.v1.origin.list(
      scene: scene,
      tag: scene == 'tag' ? widget.category.name : null,
      pn: page,
      rn: _pageSize,
    );
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
      return const GenesisListLoadingSkeleton.originGrid();
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
              key: PageStorageKey<String>(
                'origin-feed-${widget.category.name}-${widget.category.scene}',
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.45,
                  child: const Center(child: Text('No data')),
                ),
              ],
            )
          : MasonryGridView.builder(
              key: PageStorageKey<String>(
                'origin-feed-${widget.category.name}-${widget.category.scene}',
              ),
              controller: _scrollController,
              primary: false,
              cacheExtent: 900,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              gridDelegate:
                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
              mainAxisSpacing: 10,
              crossAxisSpacing: 11,
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
                final item = _items[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pushNamed(
                    RouteNames.originWorld,
                    arguments: {'originId': 0, 'oid': item.oid},
                  ),
                  child: OriginItemCard(item: item),
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
