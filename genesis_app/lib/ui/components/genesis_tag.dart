import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';

enum GenesisTagTone { neutral, accent, danger }

enum GenesisTagSize { compact, regular }

/// A non-interactive metadata label. Use [GenesisFilterChip] for selection.
class GenesisTag extends StatelessWidget {
  const GenesisTag({
    super.key,
    required this.label,
    this.tone = GenesisTagTone.neutral,
    this.size = GenesisTagSize.regular,
    this.leading,
  });

  final String label;
  final GenesisTagTone tone;
  final GenesisTagSize size;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final compact = size == GenesisTagSize.compact;
    final (background, foreground) = switch (tone) {
      GenesisTagTone.neutral => (
        colors.foregroundStrong.withValues(alpha: 0.13),
        colors.textPrimary,
      ),
      GenesisTagTone.accent => (
        colors.danger.withValues(alpha: 0.18),
        colors.accentText,
      ),
      GenesisTagTone.danger => (colors.danger, colors.onDanger),
    };

    return Container(
      height: compact
          ? GenesisControlMetrics.tagCompactHeight
          : GenesisControlMetrics.tagRegularHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? GenesisSpacing.md : GenesisSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.all(
          compact ? GenesisRadii.tag : GenesisRadii.compactControl,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[
            ExcludeSemantics(child: leading!),
            SizedBox(width: compact ? GenesisSpacing.xs : GenesisSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact
                          ? GenesisTypography.caption
                          : GenesisTypography.tabLabel)
                      .copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
