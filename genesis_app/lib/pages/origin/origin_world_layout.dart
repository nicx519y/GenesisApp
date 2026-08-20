const double originWorldMapPanelTopGap = 50;
const double originWorldMapCollapsedHeightOffset = 60;
const double originWorldMapSheetOverlap = originWorldMapCollapsedHeightOffset;
const double originWorldMapDefaultExposedChildSize = 0.315;
const double originWorldDetailBottomSafeAreaMinimum = 24;

double originWorldMapHeightFor({
  required double viewportHeight,
  required double bottomSafeArea,
}) {
  final maxMapHeight =
      (viewportHeight - originWorldMapPanelTopGap - bottomSafeArea)
          .clamp(0.0, viewportHeight)
          .toDouble();
  return (viewportHeight * (1 - originWorldMapDefaultExposedChildSize) +
          originWorldMapCollapsedHeightOffset -
          bottomSafeArea)
      .clamp(0.0, maxMapHeight)
      .toDouble();
}
