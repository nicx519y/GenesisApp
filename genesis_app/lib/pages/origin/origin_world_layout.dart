import 'package:flutter/material.dart';

const Color originWorldDetailSheetBackgroundColor = Color(0xFFEDEDED);
const double originWorldMapPanelTopGap = 50;
const double originWorldMapHeightFraction = 0.65;

double originWorldMapHeightFor({
  required double viewportHeight,
  required double bottomSafeArea,
}) {
  final maxMapHeight =
      (viewportHeight - originWorldMapPanelTopGap - bottomSafeArea)
          .clamp(0.0, viewportHeight)
          .toDouble();
  return (viewportHeight * originWorldMapHeightFraction - bottomSafeArea)
      .clamp(0.0, maxMapHeight)
      .toDouble();
}
