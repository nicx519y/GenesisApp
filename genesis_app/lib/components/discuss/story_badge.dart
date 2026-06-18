import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';

class DiscussStoryBadge extends StatelessWidget {
  const DiscussStoryBadge({super.key, required this.count});

  final int count;

  static const Color _chipBackground = Color(0xFFFEF3C7);
  static const Color _chipForeground = Color(0xFF92400E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(MyFlutterApp.pregress, size: 9, color: _chipForeground),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              color: _chipForeground,
            ),
          ),
        ],
      ),
    );
  }
}
