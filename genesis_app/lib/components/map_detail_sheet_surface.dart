import 'package:flutter/material.dart';

import '../ui/components/genesis_safe_area.dart';
import '../ui/components/genesis_search_field.dart';
import '../ui/theme/genesis_semantic_colors.dart';

const double mapDetailSheetTopOverlayOffset = 8;
const double mapDetailSheetExpandedTopGap = 20;

double mapDetailSheetExpandedTop(BuildContext context) {
  return GenesisSafeAreaInsets.top(context) +
      mapDetailSheetTopOverlayOffset +
      genesisSearchFieldHeight +
      mapDetailSheetExpandedTopGap;
}

const BorderRadius mapDetailSheetBorderRadius = BorderRadius.vertical(
  top: Radius.circular(24),
);

BoxDecoration mapDetailSheetDecoration(BuildContext context) {
  final colors = context.genesisColors;
  return BoxDecoration(
    color: colors.pageBackground,
    borderRadius: mapDetailSheetBorderRadius,
    boxShadow: [
      BoxShadow(
        color: colors.scrim.withValues(alpha: 0.6),
        blurRadius: 44,
        offset: const Offset(0, -14),
      ),
    ],
  );
}

BoxDecoration mapDetailSheetOutlineDecoration(BuildContext context) {
  return BoxDecoration(
    borderRadius: mapDetailSheetBorderRadius,
    border: Border.all(color: context.genesisColors.borderSubtle),
  );
}

class MapDetailSheetSurface extends StatelessWidget {
  const MapDetailSheetSurface({
    super.key,
    required this.child,
    this.surfaceKey,
  });

  final Widget child;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: surfaceKey,
      decoration: mapDetailSheetDecoration(context),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: mapDetailSheetOutlineDecoration(context),
        child: ClipRRect(
          borderRadius: mapDetailSheetBorderRadius,
          child: child,
        ),
      ),
    );
  }
}
