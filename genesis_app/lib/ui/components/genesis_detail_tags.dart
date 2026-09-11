import 'package:flutter/material.dart';

import '../tokens/genesis_colors.dart';
import '../tokens/genesis_typography.dart';

/// Compact detail tags, preserving complete chips within at most two rows.
class GenesisDetailTags extends StatelessWidget {
  const GenesisDetailTags({super.key, required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final labels = tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty);
    if (labels.isEmpty) return const SizedBox.shrink();
    // Measure the same resolved style that Text paints, including inherited
    // letter spacing and the accessibility bold-text setting.
    final textStyle = GenesisTypography.withFallback(
      DefaultTextStyle.of(context).style.merge(
        TextStyle(
          color: GenesisColors.darkTextSecondary,
          fontSize: 11,
          fontWeight: MediaQuery.boldTextOf(context)
              ? FontWeight.w700
              : FontWeight.w400,
          height: 1.2,
        ),
      ),
    ).copyWith(inherit: false);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0) return const SizedBox.shrink();
        final chips = <Widget>[];
        var row = 1;
        var usedWidth = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: textStyle),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            locale: locale,
            maxLines: 1,
          )..layout();
          final width = painter.width.ceilToDouble() + 12;
          painter.dispose();
          if (width > constraints.maxWidth) continue;
          final gap = usedWidth == 0 ? 0.0 : 6.0;
          if (usedWidth + gap + width > constraints.maxWidth) {
            if (row == 2) break;
            row += 1;
            usedWidth = width;
          } else {
            usedWidth += gap + width;
          }
          chips.add(
            Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: GenesisColors.darkFaintFill,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textScaler: textScaler,
                locale: locale,
                style: textStyle,
              ),
            ),
          );
        }
        if (chips.isEmpty) return const SizedBox.shrink();
        return Padding(
          // Match the adjacent metadata rows: 3px below the preceding row
          // plus 3px here gives a 6px gap before the first chip.
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(spacing: 6, runSpacing: 6, children: chips),
        );
      },
    );
  }
}
