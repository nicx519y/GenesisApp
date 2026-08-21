import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_control_icons.dart';

/// Compact text-and-chevron action for a leading-title app bar.
///
/// Its visible content follows the Worldo navigation specification while the
/// hit target remains at least 44 logical pixels high.
class GenesisAppBarActionLink extends StatelessWidget {
  const GenesisAppBarActionLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.genesisColors.textQuaternary;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: GenesisControlMetrics.minimumTapTarget,
        minHeight: GenesisControlMetrics.minimumTapTarget,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GenesisTypography.navigationAction.copyWith(
                  color: effectiveColor,
                ),
              ),
            ),
            const SizedBox(width: GenesisControlMetrics.appBarActionGap),
            GenesisChevronRightIcon(color: effectiveColor),
          ],
        ),
      ),
    );

    final action = Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip ?? label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onPressed, child: content),
      ),
    );

    if (tooltip == null) return action;
    return Tooltip(message: tooltip!, child: action);
  }
}
