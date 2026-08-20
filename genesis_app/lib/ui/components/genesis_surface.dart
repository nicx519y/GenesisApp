import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../theme/genesis_ui_theme.dart';
import '../tokens/genesis_radii.dart';

enum GenesisSurfaceVariant {
  background,
  surface,
  raised,
  subtle,
  input,
  grouped,
  card,
}

class GenesisSurface extends StatelessWidget {
  const GenesisSurface({
    super.key,
    required this.child,
    this.variant = GenesisSurfaceVariant.surface,
    this.padding,
    this.borderRadius,
    this.border,
    this.clipBehavior = Clip.none,
    this.color,
  });

  final Widget child;
  final GenesisSurfaceVariant variant;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Clip clipBehavior;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final uiTheme = GenesisUiTheme.of(context);
    final effectiveColor =
        color ??
        switch (variant) {
          GenesisSurfaceVariant.background => colors.background,
          GenesisSurfaceVariant.surface => colors.surface,
          GenesisSurfaceVariant.raised => colors.raisedSurface,
          GenesisSurfaceVariant.subtle => colors.subtleSurface,
          GenesisSurfaceVariant.input => colors.inputSurface,
          GenesisSurfaceVariant.grouped => colors.surfaceGrouped,
          GenesisSurfaceVariant.card => colors.raisedSurface,
        };
    final effectiveRadius =
        borderRadius ??
        switch (variant) {
          GenesisSurfaceVariant.input => GenesisRadii.input,
          GenesisSurfaceVariant.card => GenesisRadii.card,
          GenesisSurfaceVariant.raised ||
          GenesisSurfaceVariant.grouped => uiTheme.panelBorderRadius,
          GenesisSurfaceVariant.background ||
          GenesisSurfaceVariant.surface ||
          GenesisSurfaceVariant.subtle => BorderRadius.zero,
        };

    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveRadius,
        border: border,
      ),
      child: child,
    );
  }
}
