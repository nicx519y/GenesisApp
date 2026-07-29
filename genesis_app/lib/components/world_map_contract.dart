import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'world_point.dart';

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

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
  });

  final String characterId;
  final String content;
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
