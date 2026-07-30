part of 'tilemap_renderer_library.dart';

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({
    required this.tile,
    required this.name,
    required this.avatars,
  });

  final TilemapCell tile;
  final String name;
  final List<UserAvatar> avatars;
}

const double _tilemapLocationLabelMaxWidth = 141;
const double _tilemapLocationLabelHorizontalPadding = 3;
const double _tilemapLocationLabelVerticalPadding = 4;
const TextStyle _tilemapLocationLabelTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 10,
  height: 1.2,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.w600,
);

double _tilemapLocationLabelHeight(BuildContext context, String name) {
  final painter =
      TextPainter(
        text: TextSpan(text: name, style: _tilemapLocationLabelTextStyle),
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth:
            _tilemapLocationLabelMaxWidth -
            _tilemapLocationLabelHorizontalPadding * 2,
      );
  return painter.height + _tilemapLocationLabelVerticalPadding * 2;
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
    required this.onLabelTap,
    required this.onAvatarTap,
    required this.anchor,
  });

  final String name;
  final List<UserAvatar> avatars;
  final VoidCallback? onLabelTap;
  final VoidCallback? onAvatarTap;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Transform.translate(
          offset: Offset(0, -_tilemapLocationLabelHeight(context, name)),
          child: Semantics(
            label: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLabelTap,
                  child: Container(
                    key: ValueKey<String>('tile-location-bubble-body-$name'),
                    constraints: const BoxConstraints(
                      maxWidth: _tilemapLocationLabelMaxWidth,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: _tilemapLocationLabelHorizontalPadding,
                      vertical: _tilemapLocationLabelVerticalPadding,
                    ),
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
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: _tilemapLocationLabelTextStyle,
                    ),
                  ),
                ),
                if (avatars.isNotEmpty) ...[
                  const SizedBox(height: tilemapLocationLabelToAvatarSpacing),
                  TilemapLocationAvatars(
                    avatars: avatars,
                    onAvatarTap: onAvatarTap,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectedTileHighlight extends StatelessWidget {
  const _ProjectedTileHighlight({
    super.key,
    required this.tile,
    required this.projection,
    required this.opacity,
  });

  final TilemapCell tile;
  final TilemapProjection projection;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final polygon = projection.polygonForTile(tile);
    final bounds = _boundsForOffsets(polygon);
    return Positioned.fromRect(
      rect: bounds,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TileHighlightPainter(
            polygon: polygon
                .map((point) => point - bounds.topLeft)
                .toList(growable: false),
            color: tilemapLocationHighlightColor.withValues(
              alpha: opacity.clamp(0, 1).toDouble(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileHighlightPainter extends CustomPainter {
  const _TileHighlightPainter({required this.polygon, required this.color});

  final List<Offset> polygon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 3 || color.a <= 0) return;
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TileHighlightPainter oldDelegate) {
    return oldDelegate.polygon != polygon || oldDelegate.color != color;
  }
}
