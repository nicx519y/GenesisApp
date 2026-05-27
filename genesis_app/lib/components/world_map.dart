import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/components/genesis_character_avatar.dart';
import 'world_location_list.dart';
import 'world_point.dart';

export 'world_location_list.dart';
export 'world_point.dart';

class WorldMapLocationNode {
  const WorldMapLocationNode({
    required this.id,
    required this.point,
    this.mapImageUrl = '',
    this.children = const <WorldMapLocationNode>[],
  });

  final String id;
  final WorldPoint point;
  final String mapImageUrl;
  final List<WorldMapLocationNode> children;
}

class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    required this.points,
    this.listPoints,
    this.locationNodes = const <WorldMapLocationNode>[],
    this.mapImageUrl = '',
    this.preloadMapImageUrls = const <String>[],
    this.dimmed = false,
    this.showPointsList = false,
    this.overlayTop = 0,
    this.drillExitTop = 68,
    this.onDrillIntoLocation,
    this.onPointTap,
  });

  final List<WorldPoint> points;
  final List<WorldPoint>? listPoints;
  final List<WorldMapLocationNode> locationNodes;
  final String mapImageUrl;
  final List<String> preloadMapImageUrls;
  final bool dimmed;
  final bool showPointsList;
  final double overlayTop;
  final double drillExitTop;
  final VoidCallback? onDrillIntoLocation;
  final ValueChanged<WorldPoint>? onPointTap;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  final List<_WorldMapLocationTrailEntry> _locationTrail =
      <_WorldMapLocationTrailEntry>[];
  _MapTransitionSpec _mapTransition = const _MapTransitionSpec(
    origin: Alignment.center,
    direction: _MapTransitionDirection.drillIn,
  );

  bool get _hasDrillTree => widget.locationNodes.isNotEmpty;

  @override
  void didUpdateWidget(covariant WorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasDrillTree) {
      if (_locationTrail.isNotEmpty) _locationTrail.clear();
      return;
    }

    final currentId = _locationTrail.isEmpty ? '' : _locationTrail.last.id;
    if (currentId.isNotEmpty && _findNode(currentId) == null) {
      _locationTrail.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentNode = _currentNode;
    final visibleNodes = _hasDrillTree
        ? (currentNode == null ? widget.locationNodes : currentNode.children)
        : const <WorldMapLocationNode>[];
    final visiblePoints = _hasDrillTree
        ? visibleNodes.map((node) => node.point).toList(growable: false)
        : widget.points;
    final flattenedPoints = _hasDrillTree
        ? _flattenNodes(
            widget.locationNodes,
          ).map((node) => node.point).toList(growable: false)
        : widget.listPoints ?? widget.points;
    final currentMapImageUrl =
        currentNode?.mapImageUrl.trim().isNotEmpty == true
        ? currentNode!.mapImageUrl
        : widget.mapImageUrl;
    final preloadMapImageUrls = _hasDrillTree
        ? visibleNodes
              .map((node) => node.mapImageUrl.trim())
              .where((url) => url.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : widget.preloadMapImageUrls;
    final exitLocationLabel = currentNode?.point.name ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        const designWidth = 375.0;
        const designHeight = 670.0;
        final width = constraints.maxWidth;
        final height = width * designHeight / designWidth;
        final backgroundUrl = currentMapImageUrl.trim();
        final hasBackground = backgroundUrl.isNotEmpty;
        final mapKey = ValueKey<String>(
          _locationTrail.isEmpty ? '__world_root__' : _locationTrail.last.id,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: _WorldMapTransitionSurface(
                mapKey: mapKey,
                transition: _mapTransition,
                child: Stack(
                  children: [
                    if (hasBackground)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: height,
                        child: _MapBackgroundDeck(
                          currentUrl: backgroundUrl,
                          preloadUrls: preloadMapImageUrls,
                        ),
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
                        ignoring: widget.showPointsList,
                        child: Opacity(
                          opacity: widget.showPointsList ? 0.6 : 1,
                          child: Stack(
                            children: [
                              for (final p in visiblePoints)
                                _WorldPointPositioned(
                                  point: p,
                                  width: width,
                                  height: height,
                                  onTap: _pointTapHandler(p),
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
                          color: widget.dimmed
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showPointsList)
              Positioned.fill(
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.72)),
              ),
            if (widget.showPointsList)
              Positioned.fill(
                top: widget.overlayTop,
                child: Column(
                  children: [
                    Expanded(
                      child: WorldLocationList(
                        points: flattenedPoints,
                        onPointTap: _handlePointTap,
                      ),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            if (_locationTrail.isNotEmpty)
              Positioned(
                left: 12,
                top: widget.drillExitTop,
                child: _ExitLocationButton(
                  label: exitLocationLabel,
                  onPressed: _exitLocation,
                ),
              ),
          ],
        );
      },
    );
  }

  VoidCallback? _pointTapHandler(WorldPoint point) {
    if (_hasDrillTree && !_isLeafPoint(point)) {
      return () => _handlePointTap(point);
    }
    if (widget.onPointTap == null) return null;
    return () => _handlePointTap(point);
  }

  void _handlePointTap(WorldPoint point) {
    if (_hasDrillTree && !_isLeafPoint(point)) {
      final node = _findPointNode(point);
      if (node != null) {
        widget.onDrillIntoLocation?.call();
        final origin = _mapTransitionOrigin(point);
        final path = _nodePath(node.id);
        setState(() {
          _mapTransition = _MapTransitionSpec(
            origin: origin,
            direction: _MapTransitionDirection.drillIn,
          );
          _locationTrail
            ..clear()
            ..addAll(
              (path.isEmpty ? <String>[node.id] : path).map(
                (id) => _WorldMapLocationTrailEntry(
                  id: id,
                  origin: id == node.id ? origin : Alignment.center,
                ),
              ),
            );
        });
        return;
      }
    }

    widget.onPointTap?.call(point);
  }

  void _exitLocation() {
    if (_locationTrail.isEmpty) return;
    widget.onDrillIntoLocation?.call();
    final origin = _locationTrail.last.origin;
    setState(() {
      _mapTransition = _MapTransitionSpec(
        origin: origin,
        direction: _MapTransitionDirection.drillOut,
      );
      _locationTrail.removeLast();
    });
  }

  bool _isLeafPoint(WorldPoint point) {
    final node = _findPointNode(point);
    return node == null || node.children.isEmpty;
  }

  WorldMapLocationNode? get _currentNode {
    if (_locationTrail.isEmpty) return null;
    return _findNode(_locationTrail.last.id);
  }

  WorldMapLocationNode? _findPointNode(WorldPoint point) {
    final targetId = _pointLocationId(point);
    if (targetId.isEmpty) return null;
    return _findNode(targetId);
  }

  WorldMapLocationNode? _findNode(String nodeId) {
    final targetId = nodeId.trim();
    if (targetId.isEmpty) return null;

    WorldMapLocationNode? visit(WorldMapLocationNode node) {
      if (node.id == targetId) return node;
      for (final child in node.children) {
        final match = visit(child);
        if (match != null) return match;
      }
      return null;
    }

    for (final root in widget.locationNodes) {
      final match = visit(root);
      if (match != null) return match;
    }
    return null;
  }

  List<String> _nodePath(String nodeId) {
    final targetId = nodeId.trim();
    if (targetId.isEmpty) return const <String>[];

    List<String>? visit(WorldMapLocationNode node) {
      if (node.id == targetId) return <String>[node.id];
      for (final child in node.children) {
        final childPath = visit(child);
        if (childPath != null) return <String>[node.id, ...childPath];
      }
      return null;
    }

    for (final root in widget.locationNodes) {
      final path = visit(root);
      if (path != null) return path;
    }
    return const <String>[];
  }

  List<WorldMapLocationNode> _flattenNodes(List<WorldMapLocationNode> nodes) {
    return <WorldMapLocationNode>[
      for (final node in nodes) ...[node, ..._flattenNodes(node.children)],
    ];
  }
}

class _ExitLocationButton extends StatelessWidget {
  const _ExitLocationButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        height: 36,
        padding: EdgeInsets.only(left: 0, right: displayLabel.isEmpty ? 0 : 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.subdirectory_arrow_left,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
                if (displayLabel.isNotEmpty)
                  Flexible(
                    child: Text(
                      displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldMapTransitionSurface extends StatelessWidget {
  const _WorldMapTransitionSurface({
    required this.mapKey,
    required this.transition,
    required this.child,
  });

  final LocalKey mapKey;
  final _MapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(seconds: 1),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return _WorldMapZoomFadeTransition(
          animation: animation,
          incoming: child.key == mapKey,
          transition: transition,
          child: child,
        );
      },
      child: KeyedSubtree(key: mapKey, child: child),
    );
  }
}

class _WorldMapZoomFadeTransition extends StatelessWidget {
  const _WorldMapZoomFadeTransition({
    required this.animation,
    required this.incoming,
    required this.transition,
    required this.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final _MapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: incoming ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final scale = _transitionScale(t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: transition.origin,
            child: child,
          ),
        );
      },
    );
  }

  double _transitionScale(double t) {
    return switch (transition.direction) {
      _MapTransitionDirection.drillIn =>
        incoming ? _lerpDouble(0.56, 1, t) : _lerpDouble(1.68, 1, t),
      _MapTransitionDirection.drillOut =>
        incoming ? _lerpDouble(1.68, 1, t) : _lerpDouble(0.56, 1, t),
    };
  }
}

class _WorldMapLocationTrailEntry {
  const _WorldMapLocationTrailEntry({required this.id, required this.origin});

  final String id;
  final Alignment origin;
}

class _MapTransitionSpec {
  const _MapTransitionSpec({required this.origin, required this.direction});

  final Alignment origin;
  final _MapTransitionDirection direction;
}

enum _MapTransitionDirection { drillIn, drillOut }

String _pointLocationId(WorldPoint point) {
  final sceneId = point.sceneId.trim();
  if (sceneId.isNotEmpty) return sceneId;
  final pointId = point.pointId.trim();
  if (pointId.isNotEmpty) return pointId;
  return point.id.trim();
}

Alignment _mapTransitionOrigin(WorldPoint point) {
  final dx = point.position.dx.clamp(0.0, 1.0).toDouble();
  final dy = point.position.dy.clamp(0.0, 1.0).toDouble();
  return Alignment(dx * 2 - 1, dy * 2 - 1);
}

double _lerpDouble(double begin, double end, double t) {
  return begin + (end - begin) * t;
}

class _MapBackgroundDeck extends StatelessWidget {
  const _MapBackgroundDeck({
    required this.currentUrl,
    required this.preloadUrls,
  });

  final String currentUrl;
  final List<String> preloadUrls;

  @override
  Widget build(BuildContext context) {
    final urls = preloadUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && url != currentUrl)
        .toSet()
        .toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        _MapBackground(url: currentUrl),
        for (final url in urls)
          Offstage(offstage: true, child: _MapBackground(url: url)),
      ],
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
                  color: Color(0xFF008D68),
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
