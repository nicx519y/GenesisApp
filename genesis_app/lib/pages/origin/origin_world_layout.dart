import 'package:flutter/material.dart';

import '../../ui/components/genesis_search_field.dart';
import '../../ui/tokens/genesis_radii.dart';

const Color originWorldDetailSheetBackgroundColor = Color(0xFFEDEDED);
const double originWorldMapPanelTopGap = 50;
const double originWorldMapHeightFraction = 0.65;
const double originWorldCollapsedSheetHeightFraction =
    1 - originWorldMapHeightFraction;
const double originWorldCollapsedSheetContentMaxHeight = 270;
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
  final collapsedSheetHeight = originWorldCollapsedSheetHeightFor(
    viewportHeight: viewportHeight,
    bottomSafeArea: bottomSafeArea,
  );
  final maxMapHeight =
      (viewportHeight - originWorldMapPanelTopGap - bottomSafeArea)
          .clamp(0.0, viewportHeight)
          .toDouble();
  return (viewportHeight - collapsedSheetHeight)
      .clamp(0.0, maxMapHeight)
      .toDouble();
}

double originWorldCollapsedSheetHeightFor({
  required double viewportHeight,
  required double bottomSafeArea,
}) {
  final resolvedViewportHeight = viewportHeight.clamp(0.0, double.infinity);
  final resolvedBottomSafeArea = bottomSafeArea.clamp(
    0.0,
    resolvedViewportHeight,
  );
  final contentHeight =
      (resolvedViewportHeight * originWorldCollapsedSheetHeightFraction)
          .clamp(0.0, originWorldCollapsedSheetContentMaxHeight)
          .toDouble();
  return (contentHeight + resolvedBottomSafeArea)
      .clamp(0.0, resolvedViewportHeight)
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
