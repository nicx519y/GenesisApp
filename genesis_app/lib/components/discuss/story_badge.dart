import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

class DiscussStoryBadge extends StatelessWidget {
  const DiscussStoryBadge({
    super.key,
    required this.count,
    this.compactRed = false,
  });

  final int count;
  final bool compactRed;

  static const Color _chipBackground = Color(0xFFFEF3C7);
  static const Color _chipForeground = Color(0xFF92400E);

  @override
  Widget build(BuildContext context) {
    final background = compactRed
        ? context.genesisColors.danger.withValues(alpha: 0.18)
        : _chipBackground;
    final foreground = compactRed
        ? context.genesisColors.accentText
        : _chipForeground;
    return Container(
      padding: compactRed
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : const EdgeInsetsDirectional.fromSTEB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MyFlutterApp.pregress,
            size: compactRed ? 10 : 9,
            color: foreground,
          ),
          SizedBox(width: compactRed ? 4 : 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: compactRed ? 9.5 : 11,
              height: 1,
              fontWeight: compactRed ? FontWeight.w800 : FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
