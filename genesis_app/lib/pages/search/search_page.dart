import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/origin/stat_item.dart';
import '../../components/page_header.dart';
import '../../components/search_bar.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/secend_tabs.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import 'search_history_store.dart';

enum _SearchTab {
  all('', 'All', 'Results'),
  origin('origin', 'Worldo', 'Worldos'),
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
  static const int _minSearchLength = 2;
  static const int _allTabSectionLimit = 3;

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
    final history = await (await _historyStore()).load();
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _recordActiveSearchQuery() async {
    final query = _activeQuery.trim();
    if (query.isEmpty) return;
    final history = await (await _historyStore()).add(query);
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<SearchHistoryStore> _historyStore() async {
    final uid =
        (await AppServicesScope.read(context).sessionStore.readUid())?.trim() ??
        '';
    return SearchHistoryStore(ownerUid: uid);
  }

  void _onQueryChanged(String raw) {
    _debounceTimer?.cancel();
    _requestToken += 1;
    final token = _requestToken;
    final query = raw.trim();

    if (_searchableCharacterCount(query) < _minSearchLength) {
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
          ..hasMore = tab != _SearchTab.all && page.hasMore
          ..isInitialLoading = false
          ..error = null;
        state.replaceSectionTotals(page.sectionTotals);
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
        tab == _SearchTab.all ||
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
        state.replaceSectionTotals(page.sectionTotals);
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
    final sectionTotals = <_SearchTab, int>{};
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
      final sectionTotal = asInt(group['total'], fallback: list.length);
      sectionTotals[searchTab] = sectionTotal;
      total += sectionTotal;
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
      sectionTotals: sectionTotals,
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
    final sectionTotals = <_SearchTab, int>{};
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
      sectionTotals[entry.key] = sectionTotal;
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
    return _SearchPageResult(
      items: items,
      total: total,
      sectionTotals: sectionTotals,
      hasMore: hasMore,
    );
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: kGenesisTopBarHeight,
                child: Transform.translate(
                  offset: const Offset(0, 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SearchBarPlaceholder(
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
                        child: const SizedBox(
                          height: 28,
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF222222),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (_hasInput)
              SecendTabs(
                controller: _tabController,
                labels: [for (final tab in _SearchTab.values) tab.label],
                horizontalPadding: 16,
                labelPadding: const EdgeInsets.symmetric(horizontal: 15),
                verticalPadding: 0,
              ),
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _dismissKeyboard(),
                child: _buildBody(),
              ),
            ),
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
            onOpenMore: _openTabFromAllResults,
            onDismissKeyboard: _dismissKeyboard,
          ),
      ],
    );
  }

  void _openTabFromAllResults(_SearchTab tab) {
    if (tab == _SearchTab.all) return;
    _tabController.index = tab.index;
    _handleTabChanged();
  }

  void _searchFromHistory(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
    _focusNode.requestFocus();
  }

  void _openResult(_SearchResultItem item) {
    if (item.deleted) return;
    _dismissKeyboard();
    unawaited(_recordActiveSearchQuery());
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'search_click',
      object1: _activeQuery,
      object2: item.entityId,
    );
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

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

int _searchableCharacterCount(String query) {
  var count = 0;
  for (final rune in query.runes) {
    if (_isAsciiLetter(rune) || _isCjkIdeograph(rune)) count += 1;
  }
  return count;
}

bool _isAsciiLetter(int rune) {
  return (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
}

bool _isCjkIdeograph(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF) ||
      (rune >= 0x2A700 && rune <= 0x2B73F) ||
      (rune >= 0x2B740 && rune <= 0x2B81F) ||
      (rune >= 0x2B820 && rune <= 0x2CEAF);
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
                    fontWeight: FontWeight.w600,
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
    required this.onOpenMore,
    required this.onDismissKeyboard,
  });

  final _SearchTab tab;
  final _SearchTabResults state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<_SearchResultItem> onOpen;
  final ValueChanged<_SearchTab> onOpenMore;
  final VoidCallback onDismissKeyboard;

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
    widget.onDismissKeyboard();
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
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
              onTap: item.deleted ? null : () => widget.onOpen(item),
            ),
          ),
          _SearchMoreRow(:final tab) => _SearchMoreButton(
            onTap: () => widget.onOpenMore(tab),
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
      if (items.isEmpty) return const [];
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
      rows.addAll(
        sectionItems
            .take(_SearchPageState._allTabSectionLimit)
            .map(_SearchItemRow.new),
      );
      final sectionTotal = widget.state.sectionTotalFor(section);
      if (sectionTotal > _SearchPageState._allTabSectionLimit ||
          sectionItems.length > _SearchPageState._allTabSectionLimit) {
        rows.add(_SearchMoreRow(section));
      }
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

class _SearchMoreRow extends _SearchDisplayRow {
  const _SearchMoreRow(this.tab);

  final _SearchTab tab;
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchMoreButton extends StatelessWidget {
  const _SearchMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              'More >',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final _SearchResultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = item.tab == _SearchTab.user;
    final titleStyle = isUser
        ? const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          )
        : const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultThumb(item: item),
          const SizedBox(width: 10),
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
                    style: titleStyle,
                  ),
                  const SizedBox(height: 5),
                  if (isUser)
                    Text(
                      'UID: ${formatCopyableIdValue(item.displaySubtitle)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CopyableIdLabel.textStyle,
                    )
                  else
                    Text(
                      item.displaySubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
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
    const size = 52.0;
    if (item.tab == _SearchTab.user) {
      return GenesisAvatar(
        url: item.coverImage,
        name: item.title,
        size: size,
        borderRadius: GenesisAvatarRadii.user,
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
            _StatData(iconAsset: copyStatIconAsset, value: item.copyCount),
            _StatData(
              iconAsset: connectStatIconAsset,
              value: item.connectCount,
            ),
            _StatData(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: item.characterCount,
            ),
          ]
        : [
            _StatData(iconAsset: tickStatIconAsset, value: item.tickCount),
            _StatData(
              iconAsset: connectStatIconAsset,
              value: item.connectCount,
            ),
            _StatData(
              iconAsset: characterStatIconAsset,
              preserveIconAssetColor: true,
              value: item.characterCount,
            ),
            _StatData(iconAsset: userStatIconAsset, value: item.playerCount),
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
  final Map<_SearchTab, int> sectionTotals = <_SearchTab, int>{};
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
    sectionTotals.clear();
    total = 0;
    nextPage = 1;
    hasMore = true;
    hasRequested = false;
    isInitialLoading = false;
    isLoadingMore = false;
    requestToken = 0;
    error = null;
  }

  int sectionTotalFor(_SearchTab section) {
    return sectionTotals[section] ??
        items.where((item) => item.tab == section).length;
  }

  void replaceSectionTotals(Map<_SearchTab, int> totals) {
    sectionTotals
      ..clear()
      ..addAll(totals);
  }
}

class _SearchPageResult {
  const _SearchPageResult({
    required this.items,
    required this.total,
    required this.sectionTotals,
    required this.hasMore,
  });

  final List<_SearchResultItem> items;
  final int total;
  final Map<_SearchTab, int> sectionTotals;
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
    required this.characterCount,
    required this.playerCount,
    required this.memberCount,
    this.deleted = false,
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
    final entityId = asString(json['entity_id'], fallback: shortCode);
    return _SearchResultItem(
      tab: tab,
      entityId: entityId,
      shortCode: shortCode,
      title: title,
      subtitle: switch (tab) {
        _SearchTab.origin => _originSearchSubtitle(json, fallbackId: entityId),
        _SearchTab.world => _worldSearchSubtitle(json, fallbackId: entityId),
        _ => asString(json['subtitle']),
      },
      coverImage: asImageUrl(json['cover_image']),
      copyCount: asInt(json['copy_cnt']),
      connectCount: asInt(json['connect_cnt']),
      tickCount: asInt(json['tick_cnt']),
      characterCount: asInt(json['character_cnt']),
      playerCount: asInt(json['player_cnt']),
      memberCount: asInt(json['member_cnt'], fallback: asInt(json['user_cnt'])),
      deleted: switch (tab) {
        _SearchTab.origin => entityDeleted(
          json['deleted'],
          fallback: json['origin_deleted'],
        ),
        _SearchTab.world => entityDeleted(
          json['world_deleted'],
          fallback: json['deleted'],
        ),
        _SearchTab.user => entityDeleted(json['deleted']),
        _SearchTab.all => entityDeleted(json['deleted']),
      },
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
        coverImage: asImageUrl(raw['avatar']),
        copyCount: 0,
        connectCount: 0,
        tickCount: 0,
        characterCount: 0,
        playerCount: 0,
        memberCount: 0,
        deleted: entityDeleted(raw['deleted']),
      );
    }

    final info = json['info'] is Map
        ? asJsonMap(json['info'])
        : const <String, dynamic>{};
    final stats = json['stats'] is Map
        ? asJsonMap(json['stats'])
        : const <String, dynamic>{};
    if (fallbackTab == _SearchTab.world ||
        info.containsKey('world_id') ||
        info.containsKey('wid')) {
      final worldId = asString(
        info['world_id'],
        fallback: asString(info['wid']),
      );
      return _SearchResultItem(
        tab: _SearchTab.world,
        entityId: worldId,
        shortCode: worldId,
        title: asString(
          info['world_name'],
          fallback: asString(info['name'], fallback: worldId),
        ),
        subtitle: _worldSearchSubtitle(info, fallbackId: worldId),
        coverImage: asImageUrl(info['cover']),
        copyCount: 0,
        connectCount: asInt(stats['connect_cnt']),
        tickCount: asInt(stats['tick_cnt']),
        characterCount: asInt(stats['character_cnt']),
        playerCount: asInt(stats['player_cnt']),
        memberCount: asInt(stats['location_cnt']),
        deleted: entityDeleted(
          json['world_deleted'],
          fallback: entityDeleted(
            info['world_deleted'],
            fallback: info['deleted'],
          ),
        ),
      );
    }

    final originId = asString(
      info['origin_id'],
      fallback: asString(info['oid']),
    );
    return _SearchResultItem(
      tab: _SearchTab.origin,
      entityId: originId,
      shortCode: originId,
      title: asString(
        info['origin_name'],
        fallback: asString(info['name'], fallback: originId),
      ),
      subtitle: _originSearchSubtitle(info, fallbackId: originId),
      coverImage: asImageUrl(info['cover']),
      copyCount: asInt(stats['copy_cnt']),
      connectCount: asInt(stats['connect_cnt']),
      tickCount: asInt(stats['tick_cnt']),
      characterCount: asInt(stats['character_cnt']),
      playerCount: 0,
      memberCount: asInt(stats['location_cnt']),
      deleted: entityDeleted(info['deleted'], fallback: info['origin_deleted']),
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
  final int characterCount;
  final int playerCount;
  final int memberCount;
  final bool deleted;

  String get displayTitle {
    final trimmed = title.trim();
    if (tab == _SearchTab.origin && trimmed.isNotEmpty) {
      return originDisplayName(trimmed);
    }
    if (trimmed.isNotEmpty) return trimmed;
    return shortCode.trim().isNotEmpty ? shortCode : entityId;
  }

  String get displaySubtitle {
    if (deleted &&
        (tab == _SearchTab.origin ||
            tab == _SearchTab.world ||
            tab == _SearchTab.user)) {
      return deletedEntityDisplayText;
    }
    if (tab == _SearchTab.user) {
      return shortCode.trim().isNotEmpty ? shortCode : entityId;
    }
    return subtitle.trim().isNotEmpty ? subtitle : shortCode;
  }
}

String _originSearchSubtitle(
  Map<dynamic, dynamic> raw, {
  required String fallbackId,
}) {
  final oid = _firstSearchString(raw, const ['oid', 'origin_id']);
  final displayOid = oid.trim().isEmpty ? _dashOrValue(fallbackId) : oid;
  final originator = _firstSearchString(raw, const [
    'owner_name',
    'created_user_name',
    'originator',
    'owner_uid',
    'created_uid',
  ]);
  final versionNum = _firstSearchInt(raw, const [
    'version_num',
    'origin_version',
    'origin_version_num',
    'latest_version',
    'latest_version_num',
    'latest_origin_version',
    'latest_origin_version_num',
    'latestVersion',
    'latestVersionNum',
    'latestOriginVersion',
    'latestOriginVersionNum',
    'version',
    'version_no',
    'versionNo',
  ]);
  final version = _originVersionLabel(raw, fallbackVersionNum: versionNum);
  final updated = formatGenesisTimestamp(
    _firstSearchValue(raw, const [
      'updated_at',
      'origin_version_time',
      'version_time',
      'latest_version_time',
      'latest_origin_version_time',
    ]),
  );
  return 'OID: $displayOid  Originator: '
      '${formatUidForDisplay(originator, fallback: '-')}\n'
      'Latest Version: $version · $updated';
}

String _originVersionLabel(
  Map<dynamic, dynamic> raw, {
  required int fallbackVersionNum,
}) {
  if (fallbackVersionNum > 0) return 'V$fallbackVersionNum';
  final directValue = _firstSearchVersionLabel(raw, const [
    'version_num',
    'origin_version',
    'origin_version_num',
    'latest_version',
    'latest_version_num',
    'latest_origin_version',
    'latest_origin_version_num',
    'latestVersion',
    'latestVersionNum',
    'latestOriginVersion',
    'latestOriginVersionNum',
    'version',
    'version_no',
    'versionNo',
  ]);
  if (directValue.isNotEmpty) return directValue;

  for (final key in const [
    'latest_version',
    'latestVersion',
    'latest_origin_version',
    'latestOriginVersion',
    'origin_version_info',
    'originVersionInfo',
    'version_info',
    'versionInfo',
  ]) {
    final value = raw[key];
    if (value is Map) {
      final nestedLabel = _firstSearchVersionLabel(value, const [
        'version_num',
        'versionNum',
        'origin_version',
        'originVersion',
        'origin_version_num',
        'originVersionNum',
        'latest_version',
        'latestVersion',
        'num',
        'version',
        'version_no',
        'versionNo',
        'label',
        'name',
      ]);
      if (nestedLabel.isNotEmpty) return nestedLabel;
    }
  }

  return '-';
}

String _firstSearchVersionLabel(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final label = _searchVersionLabelFromValue(raw[key]);
    if (label.isNotEmpty) return label;
  }
  return '';
}

String _searchVersionLabelFromValue(Object? raw) {
  if (raw is Map || raw is List) return '';
  final value = asString(raw).trim();
  if (_isBlankSearchValue(value) || value == '0') return '';
  final numeric = int.tryParse(value);
  if (numeric != null) return numeric <= 0 ? '' : 'V$numeric';
  final prefixedVersion = RegExp(r'^[vV]\s*(\d+)$').firstMatch(value);
  if (prefixedVersion != null) return 'V${prefixedVersion.group(1)}';
  return value;
}

String _worldSearchSubtitle(
  Map<dynamic, dynamic> raw, {
  required String fallbackId,
}) {
  final wid = _firstSearchString(raw, const ['wid', 'world_id']);
  final displayWid = wid.trim().isEmpty ? _dashOrValue(fallbackId) : wid;
  final owner = _firstSearchString(raw, const [
    'owner_name',
    'created_user_name',
    'owner_uid',
    'created_uid',
  ]);
  return 'WID: $displayWid  Owner: ${formatUidForDisplay(owner, fallback: '-')}';
}

String _firstSearchString(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = asString(raw[key]).trim();
    if (!_isBlankSearchValue(value)) return value;
  }
  return '';
}

int _firstSearchInt(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = asInt(raw[key], fallback: -1);
    if (value > 0) return value;
  }
  return 0;
}

Object? _firstSearchValue(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    final text = asString(value).trim();
    if (!_isBlankSearchValue(text)) return value;
  }
  return null;
}

String _dashOrValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

bool _isBlankSearchValue(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == '-' ||
      normalized == '--' ||
      normalized == 'null' ||
      normalized == 'none' ||
      normalized == 'n/a';
}
