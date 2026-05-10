import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/search_bar.dart';
import '../../network/genesis_api.dart';
import '../../network/models/origin.dart';
import '../../components/origin/fixed_width_underline_indicator.dart';
import '../../routers/app_router.dart';

enum _SearchTab { all, origin, world, user }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 450);
  static const int _minSearchLength = 2;

  final GenesisApi _api = GenesisApi();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  int _requestToken = 0;

  bool _hasSearched = false;
  bool _isLoading = false;
  Object? _error;
  SearchResultBundle? _result;
  _SearchTab _selectedTab = _SearchTab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
        _hasSearched = false;
        _isLoading = false;
        _error = null;
        _result = null;
        _selectedTab = _SearchTab.all;
      });
      return;
    }

    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _error = null;
      _result = null;
      _selectedTab = _SearchTab.all;
    });

    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(_search(query, token));
    });
  }

  Future<void> _search(String query, int token) async {
    try {
      final result = await _api.search(query: query, limit: 20);
      if (!mounted || token != _requestToken) return;

      setState(() {
        _isLoading = false;
        _error = null;
        _result = result;
        _selectedTab = _defaultTabFor(result);
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _isLoading = false;
        _error = e;
        _result = null;
      });
    }
  }

  _SearchTab _defaultTabFor(SearchResultBundle result) {
    if (result.origins.isNotEmpty) return _SearchTab.origin;
    if (result.worlds.isNotEmpty) return _SearchTab.world;
    if (result.users.isNotEmpty) return _SearchTab.user;
    return _SearchTab.all;
  }

  List<Widget> _buildAllItems(SearchResultBundle result) {
    final children = <Widget>[];
    if (result.origins.isNotEmpty) {
      children.add(const _SectionTitle('Origin'));
      children.addAll(
        result.origins.map((item) {
          final title = item.name.trim().isEmpty ? item.oid : item.name.trim();
          return _SearchListTile(
            title: '#$title',
            subtitle: item.description,
            onTap: () {
              Navigator.of(context).pushNamed(
                RouteNames.originWorld,
                arguments: {'originId': item.id, 'oid': item.oid},
              );
            },
          );
        }),
      );
    }
    if (result.worlds.isNotEmpty) {
      children.add(const _SectionTitle('World'));
      children.addAll(
        result.worlds.map((item) {
          final title = item.name.trim().isEmpty ? item.wid : item.name.trim();
          return _SearchListTile(
            title: title,
            subtitle: item.updatedAtText,
            onTap: () {
              Navigator.of(
                context,
              ).pushNamed(RouteNames.world, arguments: item.wid);
            },
          );
        }),
      );
    }
    if (result.users.isNotEmpty) {
      children.add(const _SectionTitle('User'));
      children.addAll(
        result.users.map((item) {
          final title = item.displayName.trim().isEmpty
              ? item.uid
              : item.displayName.trim();
          return _SearchListTile(
            title: title,
            subtitle: item.userCode,
            onTap: () {},
          );
        }),
      );
    }
    return children;
  }

  List<Widget> _buildTabItems(SearchResultBundle result) {
    switch (_selectedTab) {
      case _SearchTab.origin:
        return result.origins
            .map((item) {
              final title = item.name.trim().isEmpty
                  ? item.oid
                  : item.name.trim();
              return _SearchListTile(
                title: '#$title',
                subtitle: item.description,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteNames.originWorld,
                    arguments: {'originId': item.id, 'oid': item.oid},
                  );
                },
              );
            })
            .toList(growable: false);
      case _SearchTab.world:
        return result.worlds
            .map((item) {
              final title = item.name.trim().isEmpty
                  ? item.wid
                  : item.name.trim();
              return _SearchListTile(
                title: title,
                subtitle: item.updatedAtText,
                onTap: () {
                  Navigator.of(
                    context,
                  ).pushNamed(RouteNames.world, arguments: item.wid);
                },
              );
            })
            .toList(growable: false);
      case _SearchTab.user:
        return result.users
            .map((item) {
              final title = item.displayName.trim().isEmpty
                  ? item.uid
                  : item.displayName.trim();
              return _SearchListTile(
                title: title,
                subtitle: item.userCode,
                onTap: () {},
              );
            })
            .toList(growable: false);
      case _SearchTab.all:
        return _buildAllItems(result);
    }
  }

  bool get _showTabs => _hasSearched;

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
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
            const SizedBox(height: 10),
            if (_showTabs)
              _SearchTabs(
                selected: _selectedTab,
                onChanged: (tab) => setState(() => _selectedTab = tab),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomInset + 56),
        child: const Column(
          children: [
            Spacer(),
            Text(
              'No search history yet.\nType at least 2 characters to search.',
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Search failed'),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final q = _controller.text.trim();
                if (q.length < _minSearchLength) return;
                _onQueryChanged(q);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final items = _buildTabItems(result);
    if (items.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _SearchTabs extends StatelessWidget {
  const _SearchTabs({required this.selected, required this.onChanged});

  final _SearchTab selected;
  final ValueChanged<_SearchTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SearchTabChip(
            text: 'All',
            selected: selected == _SearchTab.all,
            onTap: () => onChanged(_SearchTab.all),
          ),
          const SizedBox(width: 22),
          _SearchTabChip(
            text: 'Origin',
            selected: selected == _SearchTab.origin,
            onTap: () => onChanged(_SearchTab.origin),
          ),
          const SizedBox(width: 22),
          _SearchTabChip(
            text: 'World',
            selected: selected == _SearchTab.world,
            onTap: () => onChanged(_SearchTab.world),
          ),
          const SizedBox(width: 22),
          _SearchTabChip(
            text: 'User',
            selected: selected == _SearchTab.user,
            onTap: () => onChanged(_SearchTab.user),
          ),
        ],
      ),
    );
  }
}

class _SearchTabChip extends StatelessWidget {
  const _SearchTabChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? const Color(0xFF111111)
                    : const Color(0xFF6E6E6E),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            height: 3,
            child: selected
                ? const DecoratedBox(
                    decoration: FixedWidthUnderlineIndicator(
                      color: Color(0xFFFF3B30),
                      width: 42,
                      height: 3,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF777777),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchListTile extends StatelessWidget {
  const _SearchListTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF707070),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFB2B2B2)),
          ],
        ),
      ),
    );
  }
}
