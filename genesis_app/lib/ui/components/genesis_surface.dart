import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../theme/genesis_ui_theme.dart';

enum GenesisSurfaceVariant { card, raised, muted }

/// Reusable neutral surface whose color follows the active Genesis skin.
class GenesisSurface extends StatelessWidget {
  const GenesisSurface({
    super.key,
    required this.child,
    this.variant = GenesisSurfaceVariant.card,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.borderRadius,
    this.showBorder = false,
    this.borderColor,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final GenesisSurfaceVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final Color? borderColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final backgroundColor = switch (variant) {
      GenesisSurfaceVariant.card => colors.surface,
      GenesisSurfaceVariant.raised => colors.surfaceRaised,
      GenesisSurfaceVariant.muted => colors.surfaceMuted,
    };
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            borderRadius ?? GenesisUiTheme.of(context).panelBorderRadius,
        border: showBorder
            ? Border.all(color: borderColor ?? colors.border)
            : null,
      ),
      child: child,
    );
  }
}
