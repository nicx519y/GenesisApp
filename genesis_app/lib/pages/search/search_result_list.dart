part of 'search_page.dart';

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
            GenesisButton(
              label: 'Retry',
              onPressed: widget.onRetry,
              size: GenesisButtonSize.compact,
              fullWidth: false,
            ),
          ],
        ),
      );
    }

    final rows = _displayRows(widget.tab, state.items);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No results.',
          style: TextStyle(
            fontSize: 14,
            color: context.genesisColors.textTertiary,
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
