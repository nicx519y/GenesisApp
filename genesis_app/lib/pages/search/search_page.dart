import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/search_bar.dart';
import '../../components/secend_tabs.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../utils/stat_count_formatter.dart';

enum _SearchTab {
  all('all', 'All', 'Results'),
  origin('origin', 'Origin', 'Origins'),
  world('world', 'World', 'Worlds'),
  user('user', 'User', 'Users');

  const _SearchTab(this.apiType, this.label, this.sectionTitle);

  final String apiType;
  final String label;
  final String sectionTitle;
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  static const Duration _debounceDuration = Duration(
    milliseconds: 600,
  ); // API rate limit is 1 request per second, so 600ms is a good balance between responsiveness and reducing unnecessary requests.
  static const int _pageSize = 20;
  static const int _minSearchLength = 1;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final TabController _tabController;
  late final Map<_SearchTab, _SearchTabResults> _results;

  Timer? _debounceTimer;
  int _requestToken = 0;
  String _activeQuery = '';
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _SearchTab.values.length,
      vsync: this,
    )..addListener(_handleTabChanged);
    _results = {
      for (final tab in _SearchTab.values) tab: _SearchTabResults(tab),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounceTimer?.cancel();
    _requestToken += 1;
    final token = _requestToken;
    final query = raw.trim();

    if (query.length < _minSearchLength) {
      setState(() {
        _activeQuery = '';
        _hasInput = false;
        _resetAllTabs();
      });
      return;
    }

    setState(() {
      _hasInput = true;
      _tabController.index = _SearchTab.all.index;
    });

    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _activeQuery = query;
        _markAllTabsStale();
      });
      unawaited(_refreshTab(_selectedTab, token: token));
    });
  }

  void _resetAllTabs() {
    for (final state in _results.values) {
      state.reset();
    }
  }

  void _markAllTabsStale() {
    for (final state in _results.values) {
      state.hasRequested = false;
      state.isInitialLoading = false;
      state.isLoadingMore = false;
      state.error = null;
      state.requestToken = 0;
    }
  }

  bool get _hasRenderedResults {
    return _results.values.any((state) => state.items.isNotEmpty);
  }

  _SearchTab get _selectedTab => _SearchTab.values[_tabController.index];

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = _selectedTab;
    final state = _results[tab]!;
    if (_activeQuery.isEmpty || state.hasRequested) return;
    unawaited(_refreshTab(tab, token: _requestToken));
  }

  Future<void> _refreshTab(_SearchTab tab, {required int token}) async {
    final query = _activeQuery;
    if (query.isEmpty) return;
    final state = _results[tab]!;
    setState(() {
      state
        ..hasRequested = true
        ..isInitialLoading = state.items.isEmpty
        ..isLoadingMore = false
        ..error = null
        ..requestToken = token;
    });

    try {
      final page = await _fetchPage(tab, query: query, pageNumber: 1);
      if (kDebugMode) {
        debugPrint(
          '[SearchPage] search query="$query" type=${tab.apiType} pn=1 '
          'items=${page.items.length} total=${page.total}',
        );
      }
      if (!_acceptsResult(token, query)) return;
      setState(() {
        state
          ..items.clear()
          ..items.addAll(page.items)
          ..total = page.total
          ..nextPage = 2
          ..hasMore = page.hasMore
          ..isInitialLoading = false
          ..error = null;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SearchPage] search failed query="$query" type=${tab.apiType}: '
          '$error',
        );
      }
      if (!_acceptsResult(token, query)) return;
      setState(() {
        state
          ..isInitialLoading = false
          ..error = state.items.isEmpty ? error : null;
      });
    }
  }

  Future<void> _loadNextPage(_SearchTab tab) async {
    final state = _results[tab]!;
    final query = _activeQuery;
    final token = _requestToken;
    if (query.isEmpty ||
        !state.hasMore ||
        state.isInitialLoading ||
        state.isLoadingMore) {
      return;
    }

    setState(() {
      state
        ..isLoadingMore = true
        ..error = null
        ..requestToken = token;
    });

    try {
      final page = await _fetchPage(
        tab,
        query: query,
        pageNumber: state.nextPage,
      );
      if (kDebugMode) {
        debugPrint(
          '[SearchPage] search load more query="$query" type=${tab.apiType} '
          'pn=${state.nextPage} items=${page.items.length} total=${page.total}',
        );
      }
      if (!_acceptsResult(token, query)) return;
      setState(() {
        state
          ..items.addAll(page.items)
          ..total = page.total
          ..nextPage += 1
          ..hasMore = page.hasMore
          ..isLoadingMore = false
          ..error = null;
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SearchPage] search load more failed query="$query" '
          'type=${tab.apiType}: $error',
        );
      }
      if (!_acceptsResult(token, query)) return;
      setState(() {
        state
          ..isLoadingMore = false
          ..error = error;
      });
    }
  }

  bool _acceptsResult(int token, String query) {
    return mounted && token == _requestToken && query == _activeQuery;
  }

  Future<_SearchPageResult> _fetchPage(
    _SearchTab tab, {
    required String query,
    required int pageNumber,
  }) async {
    final data = await AppServicesScope.of(context).api.v1.search.search(
      query: query,
      type: tab.apiType,
      pn: pageNumber,
      rn: _pageSize,
    );
    final groups = data['groups'] is List
        ? asJsonList(data['groups'])
        : const <Object?>[];
    final items = <_SearchResultItem>[];
    var total = 0;

    for (final rawGroup in groups) {
      final group = asJsonMap(rawGroup);
      final type = asString(group['type']);
      final searchTab = _tabFromApiType(type);
      if (searchTab == null) continue;
      if (tab != _SearchTab.all && tab != searchTab) continue;

      final list = group['list'] is List
          ? asJsonList(group['list'])
          : const <Object?>[];
      total += asInt(group['total'], fallback: list.length);
      for (final rawItem in list) {
        items.add(
          _SearchResultItem.fromJson(
            asJsonMap(rawItem),
            fallbackTab: searchTab,
          ),
        );
      }
    }

    return _SearchPageResult(
      items: items,
      total: total,
      hasMore: items.isNotEmpty && pageNumber * _pageSize < total,
    );
  }

  _SearchTab? _tabFromApiType(String type) {
    for (final tab in _SearchTab.values) {
      if (tab.apiType == type && tab != _SearchTab.all) return tab;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBarPlaceholder(
                      hintText: 'Search origins, worlds, users...',
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      onClear: () {
                        _controller.clear();
                        _onQueryChanged('');
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF222222),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (_hasInput)
              SecendTabs(
                controller: _tabController,
                labels: [for (final tab in _SearchTab.values) tab.label],
                horizontalPadding: 16,
                labelPadding: const EdgeInsets.symmetric(horizontal: 15),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasInput) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomInset + 56),
        child: const Column(
          children: [
            Spacer(),
            Text(
              'No search history yet.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8D8D8D),
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_activeQuery.isEmpty && !_hasRenderedResults) {
      return const SizedBox.shrink();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        for (final tab in _SearchTab.values)
          _SearchResultList(
            key: PageStorageKey<String>('search-results-${tab.apiType}'),
            tab: tab,
            state: _results[tab]!,
            onRetry: () => _refreshTab(tab, token: _requestToken),
            onLoadMore: () => _loadNextPage(tab),
            onOpen: _openResult,
          ),
      ],
    );
  }

  void _openResult(_SearchResultItem item) {
    switch (item.tab) {
      case _SearchTab.origin:
        Navigator.of(context).pushNamed(
          RouteNames.originWorld,
          arguments: {'originId': 0, 'oid': item.entityId},
        );
      case _SearchTab.world:
        Navigator.of(
          context,
        ).pushNamed(RouteNames.world, arguments: {'wid': item.entityId});
      case _SearchTab.user:
        Navigator.of(
          context,
        ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.entityId});
      case _SearchTab.all:
        break;
    }
  }
}

class _SearchResultList extends StatefulWidget {
  const _SearchResultList({
    super.key,
    required this.tab,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpen,
  });

  final _SearchTab tab;
  final _SearchTabResults state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<_SearchResultItem> onOpen;

  @override
  State<_SearchResultList> createState() => _SearchResultListState();
}

class _SearchResultListState extends State<_SearchResultList>
    with AutomaticKeepAliveClientMixin<_SearchResultList> {
  static const _loadMoreThreshold = 700.0;

  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }
    widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = widget.state;

    if (state.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Search failed'),
            const SizedBox(height: 10),
            FilledButton(onPressed: widget.onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final rows = _displayRows(widget.tab, state.items);
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No results.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8D8D8D),
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    final itemCount = rows.length + (state.isLoadingMore ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      primary: false,
      cacheExtent: 900,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= rows.length) {
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
        final row = rows[index];
        return switch (row) {
          _SearchSectionRow(:final title) => _SectionTitle(title),
          _SearchItemRow(:final item) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: _SearchResultTile(
              item: item,
              onTap: () => widget.onOpen(item),
            ),
          ),
        };
      },
    );
  }

  List<_SearchDisplayRow> _displayRows(
    _SearchTab tab,
    List<_SearchResultItem> items,
  ) {
    if (tab != _SearchTab.all) {
      return [
        _SearchSectionRow(tab.sectionTitle),
        ...items.map(_SearchItemRow.new),
      ];
    }

    final rows = <_SearchDisplayRow>[];
    for (final section in const [
      _SearchTab.origin,
      _SearchTab.world,
      _SearchTab.user,
    ]) {
      final sectionItems = items
          .where((item) => item.tab == section)
          .toList(growable: false);
      if (sectionItems.isEmpty) continue;
      rows.add(_SearchSectionRow(section.sectionTitle));
      rows.addAll(sectionItems.map(_SearchItemRow.new));
    }
    return rows;
  }
}

sealed class _SearchDisplayRow {
  const _SearchDisplayRow();
}

class _SearchSectionRow extends _SearchDisplayRow {
  const _SearchSectionRow(this.title);

  final String title;
}

class _SearchItemRow extends _SearchDisplayRow {
  const _SearchItemRow(this.item);

  final _SearchResultItem item;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final _SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = item.tab == _SearchTab.user;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultThumb(item: item),
          SizedBox(width: isUser ? 18 : 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: isUser ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF486284),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.displaySubtitle,
                    maxLines: isUser ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 12),
                    _ResultStats(item: item),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultThumb extends StatelessWidget {
  const _ResultThumb({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(
          item.tab == _SearchTab.user ? 32 : 0,
        ),
      ),
    );
    final size = item.tab == _SearchTab.user ? 70.0 : 62.0;
    final url = item.coverImage.trim();
    final image = url.isEmpty
        ? placeholder
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(item.tab == _SearchTab.user ? 35 : 0),
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}

class _ResultStats extends StatelessWidget {
  const _ResultStats({required this.item});

  final _SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final stats = item.tab == _SearchTab.origin
        ? [
            _StatData(Icons.view_list, item.copyCount),
            _StatData(Icons.hub_outlined, item.connectCount),
            _StatData(Icons.person, item.playerCount),
          ]
        : [
            _StatData(Icons.play_arrow, item.tickCount),
            _StatData(Icons.hub_outlined, item.connectCount),
            _StatData(Icons.person, item.playerCount),
            _StatData(Icons.person, item.memberCount),
          ];

    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        for (final stat in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stat.icon, size: 20, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                formatStatCount(stat.value),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatData {
  const _StatData(this.icon, this.value);

  final IconData icon;
  final int value;
}

class _SearchTabResults {
  _SearchTabResults(this.tab);

  final _SearchTab tab;
  final List<_SearchResultItem> items = <_SearchResultItem>[];
  int total = 0;
  int nextPage = 1;
  bool hasMore = true;
  bool hasRequested = false;
  bool isInitialLoading = false;
  bool isLoadingMore = false;
  int requestToken = 0;
  Object? error;

  void reset() {
    items.clear();
    total = 0;
    nextPage = 1;
    hasMore = true;
    hasRequested = false;
    isInitialLoading = false;
    isLoadingMore = false;
    requestToken = 0;
    error = null;
  }
}

class _SearchPageResult {
  const _SearchPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<_SearchResultItem> items;
  final int total;
  final bool hasMore;
}

class _SearchResultItem {
  const _SearchResultItem({
    required this.tab,
    required this.entityId,
    required this.shortCode,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.copyCount,
    required this.connectCount,
    required this.tickCount,
    required this.playerCount,
    required this.memberCount,
  });

  factory _SearchResultItem.fromJson(
    Map<String, dynamic> json, {
    required _SearchTab fallbackTab,
  }) {
    final type = asString(json['type']);
    final tab = switch (type) {
      'origin' => _SearchTab.origin,
      'world' => _SearchTab.world,
      'user' => _SearchTab.user,
      _ => fallbackTab,
    };
    final title = asString(json['title']);
    final shortCode = asString(json['short_code']);
    return _SearchResultItem(
      tab: tab,
      entityId: asString(json['entity_id'], fallback: shortCode),
      shortCode: shortCode,
      title: title,
      subtitle: asString(json['subtitle']),
      coverImage: asString(json['cover_image']),
      copyCount: asInt(json['copy_cnt']),
      connectCount: asInt(json['connect_cnt']),
      tickCount: asInt(json['tick_cnt']),
      playerCount: asInt(json['player_cnt']),
      memberCount: asInt(json['member_cnt'], fallback: asInt(json['user_cnt'])),
    );
  }

  final _SearchTab tab;
  final String entityId;
  final String shortCode;
  final String title;
  final String subtitle;
  final String coverImage;
  final int copyCount;
  final int connectCount;
  final int tickCount;
  final int playerCount;
  final int memberCount;

  String get displayTitle {
    final trimmed = title.trim();
    if (tab == _SearchTab.origin && trimmed.isNotEmpty) return '#$trimmed';
    if (trimmed.isNotEmpty) return trimmed;
    return shortCode.trim().isNotEmpty ? shortCode : entityId;
  }

  String get displaySubtitle {
    if (tab == _SearchTab.user) {
      return shortCode.trim().isNotEmpty ? shortCode : entityId;
    }
    return subtitle.trim().isNotEmpty ? subtitle : shortCode;
  }
}
