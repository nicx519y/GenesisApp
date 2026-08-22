import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../world_map_avatar_logic.dart';
import '../world_map_contract.dart';
import '../world_map_location_marker.dart';
import '../world_point.dart';
import 'legacy_world_map_bubble.dart';

@visibleForTesting
Color worldMapAvatarBorderColorForTesting({
  required bool isPlayerControlledRole,
}) {
  return legacyWorldMapAvatarBorderColor(
    isPlayerControlledRole: isPlayerControlledRole,
  );
}

Color legacyWorldMapAvatarBorderColor({required bool isPlayerControlledRole}) {
  return isPlayerControlledRole
      ? worldMapLocationMarkerEventColor
      : const Color(0xFF151517);
}

@visibleForTesting
Offset? worldMapInitialZoomFocusForTesting(List<WorldPoint> points) {
  return legacyWorldMapInitialZoomFocus(points);
}

Offset? legacyWorldMapInitialZoomFocus(List<WorldPoint> points) {
  WorldPoint? target;
  for (final point in points) {
    final users = worldMapVisibleAvatarsForPoint(point);
    if (users.isEmpty) continue;
    final current = target;
    if (current == null ||
        users.length > worldMapVisibleAvatarsForPoint(current).length) {
      target = point;
    }
  }
  return target?.position;
}

class _WorldPointMarkerGeometry {
  const _WorldPointMarkerGeometry({
    required this.metrics,
    required this.markerWidth,
    required this.markerHeight,
    required this.pointCenterY,
  });

  final WorldMapLocationMarkerMetrics metrics;
  final double markerWidth;
  final double markerHeight;
  final double pointCenterY;
}

const double _worldPointAvatarSize = 42;
const double _worldPointAvatarSpacing = 4;
const double _worldPointAvatarTopGap = 10;
// Keep a small, intentional tolerance around the visible controls, without
// making the empty space between a location's label, pin and avatars tappable.
const double _worldPointTapTargetPadding = 6;

_WorldPointMarkerGeometry _geometryForPoint(
  BuildContext context,
  WorldPoint point,
  double width, {
  required bool showRecentChatIcon,
  required bool showEventIcon,
}) {
  final users = worldMapVisibleAvatarsForPoint(point);
  final metrics = resolveWorldMapLocationMarkerMetrics(
    context,
    name: point.name,
    avatarCount: users.length,
  );
  final markerWidth = math.min(
    width,
    metrics.pillWidth + _worldPointTapTargetPadding * 2,
  );
  final markerHeight = metrics.totalHeight + _worldPointTapTargetPadding * 2;
  final pointCenterY = metrics.anchorCenterY + _worldPointTapTargetPadding;
  return _WorldPointMarkerGeometry(
    metrics: metrics,
    markerWidth: markerWidth,
    markerHeight: markerHeight,
    pointCenterY: pointCenterY,
  );
}

double _worldPointAvatarRingRadius(int count) {
  if (count < 4) return 0;
  final minimumChord = count > 5
      ? _worldPointAvatarSize * 0.88
      : _worldPointAvatarSize + _worldPointAvatarSpacing;
  final radius = minimumChord / (2 * math.sin(math.pi / count));
  return math.max(_worldPointAvatarSize * 0.88, radius);
}

double _worldPointAvatarLeft(int index, int count, double markerWidth) {
  if (count < 4) {
    final rowWidth =
        count * _worldPointAvatarSize + (count - 1) * _worldPointAvatarSpacing;
    return markerWidth / 2 -
        rowWidth / 2 +
        index * (_worldPointAvatarSize + _worldPointAvatarSpacing);
  }
  if (count == 4) {
    final gridWidth = _worldPointAvatarSize * 2 + _worldPointAvatarSpacing;
    final column = index % 2;
    return markerWidth / 2 -
        gridWidth / 2 +
        column * (_worldPointAvatarSize + _worldPointAvatarSpacing);
  }

  final radius = _worldPointAvatarRingRadius(count);
  final ringCenterX = markerWidth / 2;
  final angle = -math.pi / 2 + math.pi * 2 * index / count;
  return ringCenterX + math.cos(angle) * radius - _worldPointAvatarSize / 2;
}

double _worldPointAvatarTop(int index, int count, double pointCenterY) {
  if (count < 4) return pointCenterY + _worldPointAvatarTopGap;
  if (count == 4) {
    final row = index ~/ 2;
    return pointCenterY +
        _worldPointAvatarTopGap +
        row * (_worldPointAvatarSize + _worldPointAvatarSpacing);
  }

  final radius = _worldPointAvatarRingRadius(count);
  final ringCenterY =
      pointCenterY +
      radius +
      _worldPointAvatarTopGap +
      _worldPointAvatarSize / 2;
  final angle = -math.pi / 2 + math.pi * 2 * index / count;
  return ringCenterY + math.sin(angle) * radius - _worldPointAvatarSize / 2;
}

Offset _transformedWorldPointAnchor(Matrix4? transform, double x, double y) {
  if (transform == null) return Offset(x, y);
  final values = transform.storage;
  return Offset(
    values[0] * x + values[4] * y + values[12],
    values[1] * x + values[5] * y + values[13],
  );
}

class LegacyWorldMapPointPositioned extends StatelessWidget {
  const LegacyWorldMapPointPositioned({
    super.key,
    required this.point,
    required this.showRecentChatIcon,
    required this.showEventIcon,
    required this.width,
    required this.height,
    this.transform,
    required this.enableAvatarScaleReboundHint,
    required this.onPointerDown,
    required this.onTap,
  });

  final WorldPoint point;
  final bool showRecentChatIcon;
  final bool showEventIcon;
  final double width;
  final double height;
  final Matrix4? transform;
  final bool enableAvatarScaleReboundHint;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final users = worldMapVisibleAvatarsForPoint(point);
    final geometry = _geometryForPoint(
      context,
      point,
      width,
      showRecentChatIcon: showRecentChatIcon,
      showEventIcon: showEventIcon,
    );
    final markerWidth = geometry.markerWidth;
    final markerHeight = geometry.markerHeight;
    final pointCenterY = geometry.pointCenterY;

    final baseX = (point.position.dx * width).clamp(0, width).toDouble();
    final baseY = (point.position.dy * height).clamp(0, height).toDouble();
    final transformedAnchor = _transformedAnchor(baseX, baseY);
    final x = transformedAnchor.dx;
    final y = transformedAnchor.dy;

    final shouldClamp = transform == null;
    final maxLeft = (width - markerWidth) > 0 ? (width - markerWidth) : 0.0;
    final maxTop = (height - markerHeight) > 0 ? (height - markerHeight) : 0.0;

    final rawLeft = x - markerWidth / 2;
    final rawTop = y - pointCenterY;
    final left = shouldClamp ? rawLeft.clamp(0.0, maxLeft).toDouble() : rawLeft;
    final top = shouldClamp ? rawTop.clamp(0.0, maxTop).toDouble() : rawTop;

    return Positioned(
      left: left,
      top: top,
      width: markerWidth,
      height: markerHeight,
      child: _WorldPointMarker(
        point: point,
        showRecentChatIcon: showRecentChatIcon,
        showEventIcon: showEventIcon,
        users: users,
        metrics: geometry.metrics,
        markerWidth: markerWidth,
        markerHeight: markerHeight,
        enableAvatarScaleReboundHint: enableAvatarScaleReboundHint,
        onPointerDown: onPointerDown,
        onTap: onTap,
      ),
    );
  }

  Offset _transformedAnchor(double x, double y) {
    return _transformedWorldPointAnchor(transform, x, y);
  }
}

class LegacyWorldMapPointMessageBubblePositioned extends StatelessWidget {
  const LegacyWorldMapPointMessageBubblePositioned({
    super.key,
    required this.point,
    required this.width,
    required this.height,
    required this.onPointerDown,
    required this.onTap,
    this.transform,
    required this.messageBubble,
  });

  final WorldPoint point;
  final double width;
  final double height;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;
  final Matrix4? transform;
  final WorldMapMessageBubble? messageBubble;

  @override
  Widget build(BuildContext context) {
    final bubble = messageBubble;
    if (bubble == null) return const SizedBox.shrink();

    final users = worldMapVisibleAvatarsForPoint(point);
    final bubbleIndex = users.indexWhere(
      (avatar) => avatar.id.trim() == bubble.characterId.trim(),
    );
    if (bubbleIndex < 0) return const SizedBox.shrink();

    final geometry = _geometryForPoint(
      context,
      point,
      width,
      showRecentChatIcon: false,
      showEventIcon: false,
    );
    final markerWidth = geometry.markerWidth;
    final markerHeight = geometry.markerHeight;
    final pointCenterY = geometry.pointCenterY;

    final baseX = (point.position.dx * width).clamp(0, width).toDouble();
    final baseY = (point.position.dy * height).clamp(0, height).toDouble();
    final transformedAnchor = _transformedWorldPointAnchor(
      transform,
      baseX,
      baseY,
    );
    final x = transformedAnchor.dx;
    final y = transformedAnchor.dy;

    final shouldClamp = transform == null;
    final maxLeft = (width - markerWidth) > 0 ? (width - markerWidth) : 0.0;
    final maxTop = (height - markerHeight) > 0 ? (height - markerHeight) : 0.0;
    final rawLeft = x - markerWidth / 2;
    final rawTop = y - pointCenterY;
    final left = shouldClamp ? rawLeft.clamp(0.0, maxLeft).toDouble() : rawLeft;
    final top = shouldClamp ? rawTop.clamp(0.0, maxTop).toDouble() : rawTop;

    return LegacyWorldMapPositionedMessageBubble(
      text: bubble.content,
      preservePageWidth: bubble.preservePageWidth,
      markerLeft: left,
      markerTop: top,
      avatarLeft: _worldPointAvatarLeft(bubbleIndex, users.length, markerWidth),
      avatarTop: _worldPointAvatarTop(bubbleIndex, users.length, pointCenterY),
      markerWidth: markerWidth,
      onPointerDown: onPointerDown,
      onTap: onTap,
    );
  }
}

class _WorldPointMarker extends StatelessWidget {
  const _WorldPointMarker({
    required this.point,
    required this.showRecentChatIcon,
    required this.showEventIcon,
    required this.users,
    required this.metrics,
    required this.markerWidth,
    required this.markerHeight,
    required this.enableAvatarScaleReboundHint,
    required this.onPointerDown,
    this.onTap,
  });

  final WorldPoint point;
  final bool showRecentChatIcon;
  final bool showEventIcon;
  final List<UserAvatar> users;
  final WorldMapLocationMarkerMetrics metrics;
  final double markerWidth;
  final double markerHeight;
  final bool enableAvatarScaleReboundHint;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: markerWidth,
      height: markerHeight,
      child: Padding(
        padding: const EdgeInsets.all(_worldPointTapTargetPadding),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: onPointerDown,
          child: WorldMapLocationMarker(
            key: ValueKey<String>('world-map-location-marker-${point.id}'),
            name: point.name,
            avatars: users,
            eventCount: showEventIcon ? 1 : 0,
            highlighted: showRecentChatIcon,
            metrics: metrics,
            enableAvatarScaleReboundHint: enableAvatarScaleReboundHint,
            onLabelTap: onTap,
            onAvatarTap: onTap,
          ),
        ),
      ),
    );
  }
}
