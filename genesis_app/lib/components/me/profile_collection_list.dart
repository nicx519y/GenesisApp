import 'package:flutter/material.dart';

import '../../ui/genesis_ui.dart';

class ProfileCollectionList extends StatelessWidget {
  const ProfileCollectionList({
    super.key,
    required this.items,
    required this.emptyText,
    this.isLoading = false,
    this.loadingKey,
  });

  final List<GenesisProfileCollectionItemData> items;
  final String emptyText;
  final bool isLoading;
  final Key? loadingKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      return Center(
        child: SizedBox(
          key: loadingKey,
          width: 24,
          height: 24,
          child: const CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A8A8A),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemBuilder: (context, index) =>
          GenesisProfileCollectionListItem(item: items[index]),
    );
  }
}
