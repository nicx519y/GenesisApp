part of 'tilemap_renderer_library.dart';

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({
    required this.tile,
    required this.name,
    required this.avatars,
    required this.showRecentChat,
    required this.showEvent,
  });

  final TilemapCell tile;
  final String name;
  final List<UserAvatar> avatars;
  final bool showRecentChat;
  final bool showEvent;
}

class _TilemapInfiniteGridPainter extends CustomPainter {
  const _TilemapInfiniteGridPainter({
    required this.projection,
    required this.scale,
    required this.translation,
    required this.lineColor,
  });

  final TilemapProjection projection;
  final double scale;
  final Offset translation;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!scale.isFinite || scale <= 0 || size.isEmpty) return;

    final spacing = projection.tileExtent * scale / 2;
    if (!spacing.isFinite || spacing <= 0) return;

    final positiveSlopeBase =
        translation.dy - translation.dx / 2 - projection.originX * scale / 2;
    final negativeSlopeBase =
        translation.dy + translation.dx / 2 + projection.originX * scale / 2;
    final path = Path();

    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: -size.width / 2,
      maxIntercept: size.height,
      baseIntercept: positiveSlopeBase,
      spacing: spacing,
      slope: 0.5,
    );
    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: 0,
      maxIntercept: size.height + size.width / 2,
      baseIntercept: negativeSlopeBase,
      spacing: spacing,
      slope: -0.5,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapInfiniteGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.translation != translation ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.projection.mapWidth != projection.mapWidth ||
        oldDelegate.projection.mapHeight != projection.mapHeight ||
        oldDelegate.projection.tileExtent != projection.tileExtent ||
        oldDelegate.projection.originX != projection.originX;
  }
}

void _appendParallelGridLines({
  required Path path,
  required double width,
  required double minIntercept,
  required double maxIntercept,
  required double baseIntercept,
  required double spacing,
  required double slope,
}) {
  final firstIndex = ((minIntercept - baseIntercept) / spacing).floor() - 1;
  final lastIndex = ((maxIntercept - baseIntercept) / spacing).ceil() + 1;
  for (var index = firstIndex; index <= lastIndex; index += 1) {
    final intercept = baseIntercept + index * spacing;
    path
      ..moveTo(0, intercept)
      ..lineTo(width, slope * width + intercept);
  }
}

class _TilemapLocationBubble extends StatelessWidget {
  const _TilemapLocationBubble({
    super.key,
    required this.name,
    required this.avatars,
    required this.showRecentChat,
    required this.showEvent,
    required this.onLabelTap,
    required this.onAvatarTap,
    required this.anchor,
  });

  final String name;
  final List<UserAvatar> avatars;
  final bool showRecentChat;
  final bool showEvent;
  final VoidCallback? onLabelTap;
  final VoidCallback? onAvatarTap;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    final metrics = resolveWorldMapLocationMarkerMetrics(
      context,
      name: name,
      avatarCount: avatars.length,
    );
    return Positioned(
      left: anchor.dx - metrics.pillWidth / 2,
      top: anchor.dy - metrics.anchorCenterY,
      child: WorldMapLocationMarker(
        name: name,
        avatars: avatars,
        eventCount: showEvent ? 1 : 0,
        highlighted: showRecentChat,
        metrics: metrics,
        onLabelTap: onLabelTap,
        onAvatarTap: onAvatarTap,
      ),
    );
  }
}
