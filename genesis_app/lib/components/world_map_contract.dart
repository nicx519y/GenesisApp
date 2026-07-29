import 'dart:async';

import 'package:flutter/material.dart';

import 'world_point.dart';

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

const double worldMapMessageBubbleMaxWidth = 220;
const double worldMapMessageBubbleHorizontalPadding = 12;
const double worldMapMessageBubblePointerWidth = 12;
const TextStyle worldMapMessageBubbleTextStyle = TextStyle(
  color: Color(0xFF1F1F1F),
  fontSize: 11,
  height: 1.25,
  fontWeight: FontWeight.w400,
);

double resolveWorldMapMessageBubbleWidth(
  BuildContext context,
  String text, {
  bool preservePageWidth = false,
}) {
  if (preservePageWidth) return worldMapMessageBubbleMaxWidth;
  final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final painter = TextPainter(
    text: TextSpan(text: normalized, style: worldMapMessageBubbleTextStyle),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  const horizontalInsets = worldMapMessageBubbleHorizontalPadding * 2;
  const minimumWidth = worldMapMessageBubblePointerWidth * 3;
  return (painter.width + horizontalInsets)
      .clamp(minimumWidth, worldMapMessageBubbleMaxWidth)
      .toDouble();
}

@immutable
class WorldMapHorizontalPanState {
  const WorldMapHorizontalPanState({
    required this.canScrollLeft,
    required this.canScrollRight,
  });

  final bool canScrollLeft;
  final bool canScrollRight;
}

@immutable
class WorldMapMessageBubble {
  const WorldMapMessageBubble({
    required this.characterId,
    required this.content,
    this.preservePageWidth = false,
  });

  final String characterId;
  final String content;
  final bool preservePageWidth;
}

@immutable
class WorldMapCommonConfig {
  const WorldMapCommonConfig({
    this.locationNodes = const <WorldMapLocationNode>[],
    this.drillExitTop = 68,
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onDrillIntoLocation,
    this.onMapTap,
    this.onPointTap,
  });

  final List<WorldMapLocationNode> locationNodes;
  final double drillExitTop;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onDrillIntoLocation;
  final VoidCallback? onMapTap;
  final WorldPointTapCallback? onPointTap;
}
