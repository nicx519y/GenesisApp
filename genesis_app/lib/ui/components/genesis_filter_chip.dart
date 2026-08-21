import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';

/// A single-select filter control using the Worldo surface-inversion rule.
class GenesisFilterChip extends StatelessWidget {
  const GenesisFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.leading,
    this.visualHeight = GenesisControlMetrics.filterChipVisualHeight,
    this.minimumTapTarget = GenesisControlMetrics.minimumTapTarget,
    this.horizontalPadding = GenesisSpacing.xl,
    this.fullWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? leading;
  final double visualHeight;
  final double minimumTapTarget;
  final double horizontalPadding;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    assert(visualHeight > 0);
    assert(minimumTapTarget >= visualHeight);
    final colors = context.genesisColors;
    final enabled = onPressed != null;
    final background = !enabled
        ? colors.disabledSurface
        : selected
        ? colors.foregroundStrong
        : colors.controlBackground;
    final foreground = !enabled
        ? colors.textDisabled
        : selected
        ? colors.background
        : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: SizedBox(
        height: minimumTapTarget,
        child: Center(
          child: Material(
            color: background,
            borderRadius: const BorderRadius.all(GenesisRadii.compactControl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: fullWidth ? double.infinity : null,
                height: visualHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        ExcludeSemantics(child: leading!),
                        const SizedBox(width: GenesisSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GenesisTypography.tabLabel.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
