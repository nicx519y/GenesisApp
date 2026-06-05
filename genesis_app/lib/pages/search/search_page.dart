import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/origin/stat_item.dart';
import '../../components/search_bar.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/secend_tabs.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import 'search_history_store.dart';

const String _connectIconAsset = 'assets/custom-icons/png/connect.png';

enum _SearchTab {
  all('', 'All', 'Results'),
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

  final SearchHistoryStore _historyStore = const SearchHistoryStore();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final TabController _tabController;
  late final Map<_SearchTab, _SearchTabResults> _results;

  Timer? _debounceTimer;
  int _requestToken = 0;
  String _activeQuery = '';
  bool _hasInput = false;
  List<String> _searchHistory = <String>[];

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
    unawaited(_loadSearchHistory());
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

  Future<void> _loadSearchHistory() async {
    final history = await _historyStore.load();
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _recordActiveSearchQuery() async {
    final query = _activeQuery.trim();
    if (query.isEmpty) return;
    final history = await _historyStore.add(query);
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
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
    final contractResult = _parseSearchEnvelope(data, tab, pageNumber);
    if (contractResult != null) return contractResult;

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

  _SearchPageResult? _parseSearchEnvelope(
    Map<String, dynamic> data,
    _SearchTab tab,
    int pageNumber,
  ) {
    final sectionKeys = tab == _SearchTab.all
        ? const {
            _SearchTab.origin: 'origins',
            _SearchTab.world: 'worlds',
            _SearchTab.user: 'users',
          }
        : {tab: _searchSectionKey(tab)};
    final items = <_SearchResultItem>[];
    var total = 0;
    var hasMore = false;
    var matchedSection = false;

    for (final entry in sectionKeys.entries) {
      final section = data[entry.value];
      if (section is! Map) continue;
      matchedSection = true;
      final sectionMap = asJsonMap(section);
      final list = sectionMap['list'] is List
          ? asJsonList(sectionMap['list'])
          : const <Object?>[];
      final sectionTotal = asInt(sectionMap['total'], fallback: list.length);
      final sectionPage = asInt(sectionMap['pn'], fallback: pageNumber);
      final sectionPageSize = asInt(sectionMap['rn'], fallback: _pageSize);
      total += sectionTotal;
      hasMore =
          hasMore ||
          (list.isNotEmpty && sectionPage * sectionPageSize < sectionTotal);

      for (final rawItem in list) {
        items.add(
          _SearchResultItem.fromContractJson(
            asJsonMap(rawItem),
            fallbackTab: entry.key,
          ),
        );
      }
    }

    if (!matchedSection) return null;
    return _SearchPageResult(items: items, total: total, hasMore: hasMore);
  }

  String _searchSectionKey(_SearchTab tab) {
    return switch (tab) {
      _SearchTab.origin => 'origins',
      _SearchTab.world => 'worlds',
      _SearchTab.user => 'users',
      _SearchTab.all => '',
    };
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
                          fontSize: 16,
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
      return _SearchHistoryPanel(
        queries: _searchHistory,
        onSelect: _searchFromHistory,
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

  void _searchFromHistory(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
    _focusNode.requestFocus();
  }

  void _openResult(_SearchResultItem item) {
    unawaited(_recordActiveSearchQuery());
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

class _SearchHistoryPanel extends StatelessWidget {
  const _SearchHistoryPanel({required this.queries, required this.onSelect});

  final List<String> queries;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (queries.isEmpty) return const SizedBox.shrink();

    final visibleQueries = queries.take(20);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTagWidth = constraints.maxWidth - 32;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search histroy',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: [
                    for (final query in visibleQueries)
                      _SearchHistoryTag(
                        query: query,
                        maxWidth: maxTagWidth,
                        onTap: () => onSelect(query),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchHistoryTag extends StatelessWidget {
  const _SearchHistoryTag({
    required this.query,
    required this.maxWidth,
    required this.onTap,
  });

  final String query;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 30,
              child: Center(
                widthFactor: 1,
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

// The following classes are adapted from WorldDetailsPanel and WorldDetailsShell to be used in the search page result details.
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
          fontSize: 16,
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
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF486284),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (isUser)
                    CopyableIdLabel(label: 'UID', value: item.displaySubtitle)
                  else
                    Text(
                      item.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.33,
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
    final size = item.tab == _SearchTab.user ? 48.0 : 62.0;
    if (item.tab == _SearchTab.user) {
      return GenesisAvatar(
        url: item.coverImage,
        name: item.title,
        size: size,
        borderRadius: 5,
      );
    }
    return GenesisListImage(
      imageUrl: item.coverImage,
      width: size,
      height: size,
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
            _StatData(icon: MyFlutterApp.save, value: item.copyCount),
            _StatData(iconAsset: _connectIconAsset, value: item.connectCount),
            _StatData(
              iconAsset: aiCharacterIconAsset,
              preserveIconAssetColor: true,
              value: item.playerCount,
            ),
          ]
        : [
            _StatData(icon: MyFlutterApp.pregress, value: item.tickCount),
            _StatData(iconAsset: _connectIconAsset, value: item.connectCount),
            _StatData(
              iconAsset: aiCharacterIconAsset,
              preserveIconAssetColor: true,
              value: item.playerCount,
            ),
            _StatData(icon: MyFlutterApp.user, value: item.memberCount),
          ];

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stat in stats)
          StatItem(
            icon: stat.icon,
            iconAsset: stat.iconAsset,
            preserveIconAssetColor: stat.preserveIconAssetColor,
            iconSize: 11,
            iconColor: Colors.black,
            gap: 4,
            text: formatStatCount(stat.value),
            textStyle: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

class _StatData {
  const _StatData({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
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

  factory _SearchResultItem.fromContractJson(
    Map<String, dynamic> json, {
    required _SearchTab fallbackTab,
  }) {
    final user = json['user'] is Map ? asJsonMap(json['user']) : null;
    if (fallbackTab == _SearchTab.user || user != null) {
      final raw = user ?? json;
      final uid = asString(raw['uid']);
      final title = formatUidForDisplay(
        asString(raw['name']),
        fallback: formatUidForDisplay(uid),
      );
      return _SearchResultItem(
        tab: _SearchTab.user,
        entityId: uid,
        shortCode: uid,
        title: title,
        subtitle: asString(raw['bio']),
        coverImage: asString(raw['avatar']),
        copyCount: 0,
        connectCount: 0,
        tickCount: 0,
        playerCount: 0,
        memberCount: 0,
      );
    }

    final info = json['info'] is Map
        ? asJsonMap(json['info'])
        : const <String, dynamic>{};
    final stats = json['stats'] is Map
        ? asJsonMap(json['stats'])
        : const <String, dynamic>{};
    if (fallbackTab == _SearchTab.world || info.containsKey('world_id')) {
      final worldId = asString(info['world_id']);
      return _SearchResultItem(
        tab: _SearchTab.world,
        entityId: worldId,
        shortCode: worldId,
        title: asString(info['world_name'], fallback: worldId),
        subtitle: asString(info['brief']),
        coverImage: asString(info['cover']),
        copyCount: 0,
        connectCount: asInt(stats['connect_cnt']),
        tickCount: asInt(stats['tick_cnt']),
        playerCount: asInt(stats['player_cnt']),
        memberCount: asInt(stats['location_cnt']),
      );
    }

    final originId = asString(info['origin_id']);
    return _SearchResultItem(
      tab: _SearchTab.origin,
      entityId: originId,
      shortCode: originId,
      title: asString(info['origin_name'], fallback: originId),
      subtitle: asString(info['brief']),
      coverImage: asString(info['cover']),
      copyCount: asInt(stats['copy_cnt']),
      connectCount: asInt(stats['connect_cnt']),
      tickCount: asInt(stats['tick_cnt']),
      playerCount: asInt(stats['character_cnt']),
      memberCount: asInt(stats['location_cnt']),
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
    if (tab == _SearchTab.origin && trimmed.isNotEmpty) {
      return originDisplayName(trimmed);
    }
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
