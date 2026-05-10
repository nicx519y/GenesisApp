import 'package:flutter/material.dart';

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
                child: Image.network(
                  backgroundUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Color(0xFFF3F4F6)),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ColoredBox(color: Color(0xFFF3F4F6));
                  },
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
                ignoring: showPointsList,
                child: Opacity(
                  opacity: showPointsList ? 0.25 : 1,
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
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: points.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = points[index];
                    return InkWell(
                      onTap: onPointTap == null ? null : () => onPointTap!(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(child: _PointLabel(point: p)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.place,
                                        size: 14,
                                        color: Colors.black,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (p.users.isNotEmpty)
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: [
                                        for (final u in p.users.take(2))
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Colors.black,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                u.name ?? u.initials,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    p.description.isEmpty
                                        ? 'Explore this location and its stories.'
                                        : p.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
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

  static const double _labelHeight = 36;
  static const double _ringSize = 24;
  static const double _avatarSize = 30;
  static const double _avatarSpacing = 6;
  static const double _labelToRingSpacing = 6;
  static const double _ringToAvatarsSpacing = 8;
  static const int _avatarsPerRow = 3;

  double _markerWidth() {
    final avatarWidth =
        _avatarSize * _avatarsPerRow + _avatarSpacing * (_avatarsPerRow - 1);
    final estimatedCharWidth = 10.0;
    final labelWidth = (point.name.runes.length * estimatedCharWidth + 20)
        .clamp(_labelHeight, width)
        .toDouble();
    return avatarWidth > labelWidth ? avatarWidth : labelWidth;
  }

  double _markerHeight() {
    final count = point.users.length;
    final base = _labelHeight + _labelToRingSpacing + _ringSize;
    if (count <= 0) return base;
    final rows = (count / _avatarsPerRow).ceil();
    final gaps = rows > 1 ? rows - 1 : 0;
    return base +
        _ringToAvatarsSpacing +
        rows * _avatarSize +
        gaps * _avatarSpacing;
  }

  @override
  Widget build(BuildContext context) {
    final markerWidth = _markerWidth();
    final markerHeight = _markerHeight();

    final x = (point.position.dx * width).clamp(0, width);
    final y = (point.position.dy * height).clamp(0, height);

    final maxLeft = (width - markerWidth) > 0 ? (width - markerWidth) : 0.0;
    final maxTop = (height - markerHeight) > 0 ? (height - markerHeight) : 0.0;

    final left = (x - markerWidth / 2).clamp(0.0, maxLeft).toDouble();
    final anchorOffset = _labelHeight + _labelToRingSpacing + _ringSize / 2;
    final top = (y - anchorOffset).clamp(0.0, maxTop).toDouble();

    return Positioned(
      left: left,
      top: top,
      width: markerWidth,
      height: markerHeight,
      child: _WorldPointMarker(
        point: point,
        markerWidth: markerWidth,
        onTap: onTap,
      ),
    );
  }
}

class WorldPoint {
  const WorldPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.users,
    this.sceneId = '',
    this.pointId = '',
    this.iconUrl = '',
    this.description = '',
  });

  final String id;
  final String name;
  final WorldPointType type;
  final Offset position;
  final List<UserAvatar> users;
  final String sceneId;
  final String pointId;
  final String iconUrl;
  final String description;
}

class UserAvatar {
  const UserAvatar(this.initials, {this.name, this.avatarUrl = ''});
  final String initials;
  final String? name;
  final String avatarUrl;
}

enum WorldPointType { castle, shop, portal, tavern, camp }

extension on WorldPointType {
  Color get color {
    switch (this) {
      case WorldPointType.castle:
        return const Color(0xFF111827);
      case WorldPointType.shop:
        return const Color(0xFF7C3AED);
      case WorldPointType.portal:
        return const Color(0xFF9333EA);
      case WorldPointType.tavern:
        return const Color(0xFF0F766E);
      case WorldPointType.camp:
        return const Color(0xFFDC2626);
    }
  }
}

class _WorldPointMarker extends StatelessWidget {
  const _WorldPointMarker({
    required this.point,
    required this.markerWidth,
    this.onTap,
  });

  final WorldPoint point;
  final double markerWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 30.0;
    const avatarSpacing = 6.0;
    final hasUsers = point.users.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: markerWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: point.type.color,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: _PointLabel(point: point, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 24,
              height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            if (hasUsers) const SizedBox(height: 8),
            if (hasUsers)
              SizedBox(
                width: markerWidth,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: avatarSpacing,
                  runSpacing: avatarSpacing,
                  children: [
                    for (final u in point.users)
                      _UserAvatar(
                        initials: u.initials,
                        avatarUrl: u.avatarUrl,
                        size: avatarSize,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
        fontSize: 12,
        height: 1.0,
        fontWeight: FontWeight.w800,
        color: color ?? Colors.black,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.size,
  });

  final String initials;
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl.trim();
    final hasUrl = url.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: hasUrl
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _Initials(initials: initials),
                )
              : _Initials(initials: initials),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }
}
