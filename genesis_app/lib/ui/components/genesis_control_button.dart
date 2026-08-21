import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_radii.dart';

/// A small visual control with a full-size accessible tap target.
///
/// Use this for header and panel actions. Back and bottom-sheet close actions
/// keep their dedicated components because their drawings and surface rules
/// are more specific.
class GenesisControlButton extends StatelessWidget {
  const GenesisControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.dimension = GenesisControlMetrics.backButtonVisualSize,
    this.tapTargetSize = GenesisControlMetrics.minimumTapTarget,
    this.backgroundColor,
    this.side,
    this.borderRadius = GenesisRadii.button,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final double dimension;
  final double tapTargetSize;
  final Color? backgroundColor;
  final BorderSide? side;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    assert(dimension > 0);
    assert(tapTargetSize >= dimension);
    final colors = context.genesisColors;
    final hitScale = tapTargetSize / dimension;

    return Transform.scale(
      scale: hitScale,
      transformHitTests: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: Transform.scale(
          scale: 1 / hitScale,
          transformHitTests: false,
          child: Tooltip(
            message: tooltip,
            child: SizedBox.square(
              dimension: dimension,
              child: Material(
                color: backgroundColor ?? colors.controlMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: side ?? BorderSide.none,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: Opacity(
                      opacity: onPressed == null ? 0.45 : 1,
                      child: ExcludeSemantics(child: child),
                    ),
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
