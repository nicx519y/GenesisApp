import 'package:flutter/material.dart';

const Color originWorldDetailSheetBackgroundColor = Color(0xFFEDEDED);
const double originWorldMapPanelTopGap = 50;
const double originWorldMapCollapsedHeightOffset = 60;
const double originWorldMapDefaultExposedChildSize = 0.31;

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
