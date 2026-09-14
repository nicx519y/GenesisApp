import 'package:flutter/material.dart';

import '../tokens/genesis_colors.dart';

/// Shared dark information card. Callers provide content and inner spacing.
class GenesisInfoCard extends StatelessWidget {
  const GenesisInfoCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.selected = false,
    this.onTap,
  });

  static const double radius = 8;
  static const borderRadius = BorderRadius.all(Radius.circular(radius));

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: selected
          ? GenesisColors.redPrimary.withValues(alpha: 0.12)
          : GenesisColors.darkCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: selected
              ? GenesisColors.redPrimary
              : GenesisColors.darkCardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      // Static cards may contain slider handles extending beyond their bounds.
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: content,
            ),
    );
  }
}
