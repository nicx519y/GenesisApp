import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/config/genesis_image_config.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../ui/tokens/genesis_palette.dart';
import '../legacy_world_map/legacy_world_map_gesture.dart';
import '../world_map_location_marker.dart';
import '../world_map_contract.dart';
import '../world_point.dart';
import 'tilemap_fog.dart';
import 'tilemap_message_bubble.dart';
import 'tilemap_model.dart';

export 'tilemap_fog.dart';

part 'tilemap_renderer_projection.dart';
part 'tilemap_renderer_image_loading.dart';
part 'tilemap_renderer_index.dart';
part 'tilemap_renderer_widget.dart';
part 'tilemap_renderer_labels.dart';
part 'tilemap_renderer_canvas_layer.dart';
part 'tilemap_renderer_image_flow.dart';
part 'tilemap_renderer_fog_bitmap_cache.dart';
part 'tilemap_renderer_fog_shadow.dart';

const double tilemapBaseTileExtent = 16;
const double tilemapPlaceholderScale = 10;
const double tilemapMinScale = 5;
const double tilemapMaxScale = 30;
const double tilemapInitialScaleMin = tilemapMinScale;
const double tilemapInitialScaleMax = tilemapMaxScale;
const double tilemapDefaultInitialScale = 12;
const double tilemapDragBoundaryPaddingTilesMin = 0;
const double tilemapDragBoundaryPaddingTilesMax = 20;
const double tilemapDefaultDragBoundaryPaddingTiles = 2;
const double tilemapZoomControlScaleFactor = 1.25;
const bool tilemapDefaultBlendFogWithShadowTiles = true;
const bool tilemapDefaultCacheFogTileBitmaps = true;
const bool tilemapDefaultShowShadowZeroBorders = false;
const bool tilemapDefaultShowLocationImageFlow = true;
const double tilemapDefaultLocationImageFlowAngleDegrees = 267.88;
const double tilemapDefaultLocationImageFlowOpacity = 0.49;
const double tilemapDefaultLocationImageFlowDurationSeconds = 7.50;
const TilemapLocationImageFlowBlendMode
tilemapDefaultLocationImageFlowBlendMode =
    TilemapLocationImageFlowBlendMode.plus;
const double tilemapLocationImageFlowDurationSecondsMin = 0.5;
const double tilemapLocationImageFlowDurationSecondsMax = 10;
const double tilemapLocationImageFlowActiveFraction = 2 / 3;
const double tilemapLocationImageFlowBandWidthFraction = 0.18;

@immutable
class TilemapLocationImageFlowGradientPoint {
  const TilemapLocationImageFlowGradientPoint({
    required this.position,
    required this.color,
  });

  final double position;
  final Color color;

  TilemapLocationImageFlowGradientPoint copyWith({
    double? position,
    Color? color,
  }) {
    return TilemapLocationImageFlowGradientPoint(
      position: position ?? this.position,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TilemapLocationImageFlowGradientPoint &&
        other.position == position &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(position, color);
}

enum TilemapLocationImageFlowBlendMode { normal, screen, overlay, plus }

const List<TilemapLocationImageFlowGradientPoint>
tilemapDefaultLocationImageFlowGradientPoints = [
  TilemapLocationImageFlowGradientPoint(position: 0, color: Color(0x00624700)),
  TilemapLocationImageFlowGradientPoint(
    position: 0.24,
    color: Color(0x556AFFA6),
  ),
  TilemapLocationImageFlowGradientPoint(
    position: 0.51,
    color: Color(0xD9B9B088),
  ),
  TilemapLocationImageFlowGradientPoint(
    position: 0.76,
    color: Color(0x55FFD86A),
  ),
  TilemapLocationImageFlowGradientPoint(position: 1, color: Color(0x00926C00)),
];

typedef TilemapTileActionHandler = Future<void> Function(TilemapCell tile);
typedef TilemapLocationNameResolver = String? Function(TilemapCell tile);
typedef TilemapLocationAvatarsResolver =
    List<UserAvatar> Function(TilemapCell tile);
typedef TilemapRecentChatResolver = bool Function(TilemapCell tile);
typedef TilemapEventResolver = bool Function(TilemapCell tile);

enum TilemapVisualMode { light, dark }

const TilemapVisualMode tilemapDefaultVisualMode = TilemapVisualMode.dark;

@immutable
class TilemapCanvasRenderStats {
  const TilemapCanvasRenderStats({
    required this.tileCount,
    required this.imageCount,
    required this.drawCallCount,
    required this.renderObjectCount,
  });

  final int tileCount;
  final int imageCount;

  /// Number of `drawRawAtlas` submissions in the Canvas tile layer.
  final int drawCallCount;

  /// The single Canvas tile-layer render object; effect children are excluded.
  final int renderObjectCount;

  @override
  bool operator ==(Object other) {
    return other is TilemapCanvasRenderStats &&
        other.tileCount == tileCount &&
        other.imageCount == imageCount &&
        other.drawCallCount == drawCallCount &&
        other.renderObjectCount == renderObjectCount;
  }

  @override
  int get hashCode =>
      Object.hash(tileCount, imageCount, drawCallCount, renderObjectCount);
}

@visibleForTesting
ValueChanged<TilemapCanvasRenderStats>? debugTilemapCanvasRenderStatsChanged;

@immutable
class TilemapVisualStyle {
  const TilemapVisualStyle({
    required this.backgroundColor,
    required this.gridLineColor,
  });

  final Color backgroundColor;
  final Color gridLineColor;
}

const TilemapVisualStyle tilemapLightVisualStyle = TilemapVisualStyle(
  backgroundColor: Color(0xFFFAFAF8),
  gridLineColor: Color(0xFFD7D6D2),
);
const TilemapVisualStyle tilemapDarkVisualStyle = TilemapVisualStyle(
  backgroundColor: GenesisPalette.redesignBackground,
  gridLineColor: Color(0xFF2E2D26),
);

TilemapVisualStyle tilemapVisualStyleFor(TilemapVisualMode mode) {
  return switch (mode) {
    TilemapVisualMode.light => tilemapLightVisualStyle,
    TilemapVisualMode.dark => tilemapDarkVisualStyle,
  };
}

const Color tilemapShadowZeroBorderColor = Color(0xFFFFFF00);
const double tilemapShadowZeroBorderWidth = 2;
