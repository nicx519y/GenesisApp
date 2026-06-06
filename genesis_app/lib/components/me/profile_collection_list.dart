import 'package:flutter/material.dart';

import '../../ui/genesis_ui.dart';

class ProfileCollectionList extends StatelessWidget {
  const ProfileCollectionList({
    super.key,
    required this.items,
    required this.emptyText,
    this.isLoading = false,
    this.loadingKey,
    this.onRefresh,
    this.refreshKey,
  });

  final List<GenesisProfileCollectionItemData> items;
  final String emptyText;
  final bool isLoading;
  final Key? loadingKey;
  final Future<void> Function()? onRefresh;
  final Key? refreshKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      final loading = SizedBox(
        key: loadingKey,
        width: 24,
        height: 24,
        child: const CircularProgressIndicator(strokeWidth: 2.4),
      );
      return _buildRefreshablePlaceholder(context, loading);
    }

    if (items.isEmpty) {
      final empty = Text(
        emptyText,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF8A8A8A),
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      );
      return _buildRefreshablePlaceholder(context, empty);
    }

    final list = ListView.separated(
      itemCount: items.length,
      physics: onRefresh == null
          ? const BouncingScrollPhysics()
          : const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, index) =>
          GenesisProfileCollectionListItem(item: items[index]),
    );
    return _wrapRefreshIndicator(list);
  }

  Widget _buildRefreshablePlaceholder(BuildContext context, Widget child) {
    if (onRefresh == null) return Center(child: child);

    return _wrapRefreshIndicator(
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }

  Widget _wrapRefreshIndicator(Widget child) {
    final refresh = onRefresh;
    if (refresh == null) return child;
    return RefreshIndicator(key: refreshKey, onRefresh: refresh, child: child);
  }
}
