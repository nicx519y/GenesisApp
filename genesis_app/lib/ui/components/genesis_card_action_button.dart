import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

/// A compact muted action used inside image cards and immersive surfaces.
class GenesisCardActionButton extends StatelessWidget {
  const GenesisCardActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.surfaceKey,
    this.interactionKey,
    this.height = 34,
    this.borderRadius = 11,
  }) : icon = null,
       tooltip = null;

  const GenesisCardActionButton.icon({
    super.key,
    required IconData this.icon,
    required String this.tooltip,
    required this.onPressed,
    this.surfaceKey,
    this.interactionKey,
    this.height = 34,
    this.borderRadius = 11,
  }) : label = null;

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Key? surfaceKey;
  final Key? interactionKey;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final enabled = onPressed != null;
    final foreground = enabled ? colors.textPrimary : colors.textMuted;
    final iconData = icon;
    final content = iconData == null
        ? Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GenesisTypography.supporting.copyWith(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: foreground,
              decoration: TextDecoration.none,
            ),
          )
        : Icon(iconData, size: 15, color: foreground);

    Widget result = Semantics(
      button: true,
      enabled: enabled,
      label: label ?? tooltip,
      child: SizedBox(
        width: iconData == null ? null : height,
        height: height,
        child: Material(
          key: surfaceKey,
          color: colors.foregroundStrong.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: interactionKey,
            onTap: onPressed,
            child: Center(child: content),
          ),
        ),
      ),
    );
    if (tooltip case final tooltip?) {
      result = Tooltip(message: tooltip, child: result);
    }
    return result;
  }
}
