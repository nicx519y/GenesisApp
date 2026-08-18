import 'package:flutter/material.dart';

class GenesisUnreadBadge extends StatelessWidget {
  const GenesisUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : count.toString();
    final textOffset = switch (Theme.of(context).platform) {
      TargetPlatform.android => const Offset(0, 0.5),
      TargetPlatform.iOS => const Offset(0, -0.5),
      _ => Offset.zero,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2442),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Center(
        child: Transform.translate(
          offset: textOffset,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
