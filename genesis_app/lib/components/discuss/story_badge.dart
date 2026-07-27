import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../../ui/theme/genesis_color_token.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

class DiscussStoryBadge extends StatelessWidget {
  const DiscussStoryBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = GenesisSemanticColors.of(context);
    final background = colors.color(GenesisColorToken.warningContainer);
    final foreground = colors.color(GenesisColorToken.warning);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MyFlutterApp.pregress, size: 9, color: foreground),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
