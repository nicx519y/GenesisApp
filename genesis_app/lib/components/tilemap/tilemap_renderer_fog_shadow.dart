part of 'tilemap_renderer_library.dart';

class _TilemapFogPainter extends CustomPainter {
  const _TilemapFogPainter(this.field);

  final TilemapFogField field;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..saveLayer(field.bounds, Paint())
      ..drawVertices(
        field.vertices,
        tilemapFogVertexBlendMode,
        Paint()..color = Colors.white,
      )
      // The fog sits behind the sorted tile layer. Land footprints are clear,
      // while shadow tile pixels receive fog in their own isolated paint pass.
      ..drawPath(field.landPath, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TilemapFogPainter oldDelegate) {
    return !identical(oldDelegate.field, field);
  }
}

class _TilemapShadowZeroBorderPainter extends CustomPainter {
  const _TilemapShadowZeroBorderPainter({
    required this.projection,
    required this.tiles,
    required this.scale,
  });

  final TilemapProjection projection;
  final List<TilemapCell> tiles;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final tile in tiles) {
      if (tile.hasShadow) continue;
      path.addPolygon(projection.polygonForTile(tile), true);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tilemapShadowZeroBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = tilemapShadowZeroBorderWidth / scale
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapShadowZeroBorderPainter oldDelegate) {
    return !identical(oldDelegate.projection, projection) ||
        !identical(oldDelegate.tiles, tiles) ||
        oldDelegate.scale != scale;
  }
}

Rect _boundsForOffsets(List<Offset> points) {
  if (points.isEmpty) return Rect.zero;
  var left = points.first.dx;
  var top = points.first.dy;
  var right = points.first.dx;
  var bottom = points.first.dy;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _containsPointInPolygon(Offset point, List<Offset> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects =
        (pi.dy > point.dy) != (pj.dy > point.dy) &&
        point.dx <
            (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
    if (intersects) inside = !inside;
  }
  return inside;
}
