import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';

class GenesisUnreadBadge extends StatelessWidget {
  const GenesisUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: context.genesisColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.genesisColors.onDanger,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
