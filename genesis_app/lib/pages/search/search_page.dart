import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/origin/stat_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/components/genesis_page_header.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_search_field.dart';
import '../../ui/components/genesis_tab_bar.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/stat_count_formatter.dart';
import '../world/world_page_result.dart';
import 'search_history_store.dart';

part 'search_history_panel.dart';
part 'search_result_list.dart';
part 'search_result_tiles.dart';
part 'search_result_models.dart';

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
                        child: GenesisSearchField(
                          variant: GenesisSearchFieldVariant.compact,
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
              GenesisTabBar(
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

  Future<void> _openResult(_SearchResultItem item) async {
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
        final result = await Navigator.of(context).pushNamed<WorldPageResult>(
          RouteNames.world,
          arguments: {'wid': item.entityId},
        );
        if (!mounted || result == null) return;
        _removeDeletedWorld(result.deletedWorldId);
      case _SearchTab.user:
        Navigator.of(
          context,
        ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.entityId});
      case _SearchTab.all:
        break;
    }
  }

  void _removeDeletedWorld(String rawWorldId) {
    final worldId = rawWorldId.trim();
    if (worldId.isEmpty) return;
    setState(() {
      for (final state in _results.values) {
        final previousLength = state.items.length;
        state.items.removeWhere(
          (item) =>
              item.tab == _SearchTab.world && item.entityId.trim() == worldId,
        );
        final removedCount = previousLength - state.items.length;
        if (removedCount == 0) continue;

        state.total = state.total > removedCount
            ? state.total - removedCount
            : 0;
        final worldTotal = state.sectionTotals[_SearchTab.world];
        if (worldTotal != null) {
          state.sectionTotals[_SearchTab.world] = worldTotal > removedCount
              ? worldTotal - removedCount
              : 0;
        }
        state.hasMore =
            state.tab != _SearchTab.all && state.items.length < state.total;
      }
    });
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
