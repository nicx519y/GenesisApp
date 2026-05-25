import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/components/genesis_character_avatar.dart';
import 'world_location_list.dart';
import 'world_point.dart';

export 'world_location_list.dart';
export 'world_point.dart';

class WorldMap extends StatelessWidget {
  const WorldMap({
    super.key,
    required this.points,
    this.mapImageUrl = '',
    this.dimmed = false,
    this.showPointsList = false,
    this.overlayTop = 0,
    this.onPointTap,
  });

  final List<WorldPoint> points;
  final String mapImageUrl;
  final bool dimmed;
  final bool showPointsList;
  final double overlayTop;
  final ValueChanged<WorldPoint>? onPointTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const designWidth = 375.0;
        const designHeight = 670.0;
        final width = constraints.maxWidth;
        final height = width * designHeight / designWidth;
        final backgroundUrl = mapImageUrl.trim();
        final hasBackground = backgroundUrl.isNotEmpty;
        return Stack(
          children: [
            if (hasBackground)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: _MapBackground(url: backgroundUrl),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: const ColoredBox(color: Color(0xFFF3F4F6)),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height,
              child: IgnorePointer(
                ignoring: showPointsList,
                child: Opacity(
                  opacity: showPointsList ? 0.6 : 1,
                  child: Stack(
                    children: [
                      for (final p in points)
                        _WorldPointPositioned(
                          point: p,
                          width: width,
                          height: height,
                          onTap: onPointTap == null
                              ? null
                              : () => onPointTap!(p),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  color: dimmed
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
              ),
            ),
            if (showPointsList)
              Positioned.fill(
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.72)),
              ),
            if (showPointsList)
              Positioned.fill(
                top: overlayTop,
                child: Column(
                  children: [
                    Expanded(
                      child: WorldLocationList(
                        points: points,
                        onPointTap: onPointTap,
                      ),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Color(0xFFF3F4F6)),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Color(0xFFF3F4F6)),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(color: Color(0xFFF3F4F6));
      },
    );
  }
}

class _WorldPointPositioned extends StatelessWidget {
  const _WorldPointPositioned({
    required this.point,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final WorldPoint point;
  final double width;
  final double height;
  final VoidCallback? onTap;

  static const double _labelHeight = 20;
  static const double _pointSize = 8;
  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _labelToPointSpacing = 6;
  static const double _avatarTopGap = 10;

  double _markerWidth() {
    final count = point.users.length;
    final avatarWidth = _avatarGroupWidth(count);
    final estimatedCharWidth = 10.0;
    final labelWidth = (point.name.runes.length * estimatedCharWidth + 12)
        .clamp(_labelHeight, width)
        .toDouble();
    return math.max(math.max(_pointSize, avatarWidth), labelWidth);
  }

  double _markerHeight() {
    final count = point.users.length;
    final pointCenterY = _labelHeight + _labelToPointSpacing + _pointSize / 2;
    if (count <= 0) return pointCenterY + _pointSize / 2;
    if (count < 4) return pointCenterY + _avatarTopGap + _avatarSize;
    if (count == 4) {
      return pointCenterY + _avatarTopGap + _avatarSize * 2 + _avatarSpacing;
    }

    final radius = _avatarRingRadius(count);
    return pointCenterY + radius * 2 + _avatarTopGap + _avatarSize;
  }

  double _avatarGroupWidth(int count) {
    if (count <= 0) return 0;
    if (count < 4) {
      return count * _avatarSize + (count - 1) * _avatarSpacing;
    }
    if (count == 4) return _avatarSize * 2 + _avatarSpacing;
    return _avatarRingRadius(count) * 2 + _avatarSize;
  }

  double _avatarRingRadius(int count) {
    if (count < 4) return 0;
    final minimumChord = count > 5
        ? _avatarSize * 0.88
        : _avatarSize + _avatarSpacing;
    final radius = minimumChord / (2 * math.sin(math.pi / count));
    return math.max(_avatarSize * 0.88, radius);
  }

  @override
  Widget build(BuildContext context) {
    final markerWidth = _markerWidth();
    final markerHeight = _markerHeight();
    final pointCenterY = _labelHeight + _labelToPointSpacing + _pointSize / 2;

    final x = (point.position.dx * width).clamp(0, width);
    final y = (point.position.dy * height).clamp(0, height);

    final maxLeft = (width - markerWidth) > 0 ? (width - markerWidth) : 0.0;
    final maxTop = (height - markerHeight) > 0 ? (height - markerHeight) : 0.0;

    final left = (x - markerWidth / 2).clamp(0.0, maxLeft).toDouble();
    final top = (y - pointCenterY).clamp(0.0, maxTop).toDouble();

    return Positioned(
      left: left,
      top: top,
      width: markerWidth,
      height: markerHeight,
      child: _WorldPointMarker(
        point: point,
        markerWidth: markerWidth,
        markerHeight: markerHeight,
        pointCenterY: pointCenterY,
        onTap: onTap,
      ),
    );
  }
}

class _WorldPointMarker extends StatelessWidget {
  const _WorldPointMarker({
    required this.point,
    required this.markerWidth,
    required this.markerHeight,
    required this.pointCenterY,
    this.onTap,
  });

  final WorldPoint point;
  final double markerWidth;
  final double markerHeight;
  final double pointCenterY;
  final VoidCallback? onTap;

  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _avatarTopGap = 10;
  static const double _pointSize = 8;

  double _ringRadius(int count) {
    if (count < 4) return 0;
    final minimumChord = count > 5
        ? _avatarSize * 0.88
        : _avatarSize + _avatarSpacing;
    final radius = minimumChord / (2 * math.sin(math.pi / count));
    return math.max(_avatarSize * 0.88, radius);
  }

  @override
  Widget build(BuildContext context) {
    final hasUsers = point.users.isNotEmpty;
    final avatars = point.users;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: markerWidth,
        height: markerHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: markerWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: _PointLabel(point: point, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: markerWidth / 2 - _pointSize / 2,
              top: pointCenterY - _pointSize / 2,
              width: _pointSize,
              height: _pointSize,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
            ),
            if (hasUsers)
              for (int i = 0; i < avatars.length; i++)
                _PositionedMapAvatar(
                  user: avatars[i],
                  left: _avatarLeft(i, avatars.length),
                  top: _avatarTop(i, avatars.length),
                ),
          ],
        ),
      ),
    );
  }

  double _avatarLeft(int index, int count) {
    if (count < 4) {
      final rowWidth = count * _avatarSize + (count - 1) * _avatarSpacing;
      return markerWidth / 2 -
          rowWidth / 2 +
          index * (_avatarSize + _avatarSpacing);
    }
    if (count == 4) {
      final gridWidth = _avatarSize * 2 + _avatarSpacing;
      final column = index % 2;
      return markerWidth / 2 -
          gridWidth / 2 +
          column * (_avatarSize + _avatarSpacing);
    }

    final radius = _ringRadius(count);
    final ringCenterX = markerWidth / 2;
    final angle = -math.pi / 2 + math.pi * 2 * index / count;
    return ringCenterX + math.cos(angle) * radius - _avatarSize / 2;
  }

  double _avatarTop(int index, int count) {
    if (count < 4) return pointCenterY + _avatarTopGap;
    if (count == 4) {
      final row = index ~/ 2;
      return pointCenterY +
          _avatarTopGap +
          row * (_avatarSize + _avatarSpacing);
    }

    final radius = _ringRadius(count);
    final ringCenterY = pointCenterY + radius + _avatarTopGap + _avatarSize / 2;
    final angle = -math.pi / 2 + math.pi * 2 * index / count;
    return ringCenterY + math.sin(angle) * radius - _avatarSize / 2;
  }
}

class _PointLabel extends StatelessWidget {
  const _PointLabel({required this.point, this.color});

  final WorldPoint point;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      point.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: FontWeight.w500,
        color: color ?? Colors.black,
      ),
    );
  }
}

class _PositionedMapAvatar extends StatelessWidget {
  const _PositionedMapAvatar({
    required this.user,
    required this.left,
    required this.top,
  });

  final UserAvatar user;
  final double left;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GenesisCharacterAvatar(
        url: user.avatarUrl,
        name: user.name ?? user.initials,
        showStar: user.showStar,
        size: 42,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
