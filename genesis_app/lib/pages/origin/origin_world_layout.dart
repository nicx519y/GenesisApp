import 'package:flutter/material.dart';

import '../../ui/components/genesis_search_field.dart';
import '../../ui/tokens/genesis_radii.dart';

const Color originWorldDetailSheetBackgroundColor = Color(0xFFEDEDED);
const double originWorldMapPanelTopGap = 50;
const double originWorldMapHeightFraction = 0.65;
const double originWorldMapSheetUnderlap = GenesisRadii.sheetTopRadiusValue;
const double originWorldDetailExpandedTopOverlayOffset = 8;
const double originWorldDetailExpandedTopOverlayGap = 20;

double originWorldDetailExpandedSheetTopFor({required double topSafeArea}) {
  return topSafeArea +
      originWorldDetailExpandedTopOverlayOffset +
      genesisSearchFieldHeight +
      originWorldDetailExpandedTopOverlayGap;
}

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

double originWorldRenderedMapHeightFor({
  required double viewportHeight,
  required double bottomSafeArea,
}) {
  final sheetTop = originWorldMapHeightFor(
    viewportHeight: viewportHeight,
    bottomSafeArea: bottomSafeArea,
  );
  return (sheetTop + originWorldMapSheetUnderlap)
      .clamp(0.0, viewportHeight)
      .toDouble();
}
