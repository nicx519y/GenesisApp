import 'package:flutter/material.dart';

import '../../ui/genesis_ui.dart';

class ProfileCollectionList extends StatelessWidget {
  const ProfileCollectionList({
    super.key,
    required this.items,
    required this.emptyText,
  });

  final List<GenesisProfileCollectionItemData> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
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
