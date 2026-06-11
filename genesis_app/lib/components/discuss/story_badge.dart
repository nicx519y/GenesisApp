import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';

class DiscussStoryBadge extends StatelessWidget {
  const DiscussStoryBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6CF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(MyFlutterApp.pregress, size: 14, color: Color(0xFFF42C47)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF42C47),
            ),
          ),
        ],
      ),
    );
  }
}
