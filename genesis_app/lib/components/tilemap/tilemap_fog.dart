import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tilemap_model.dart';

// The fog reaches solid black 1.5 tile extents outside the land edge.
const double tilemapFogFadeTileExtents = 1.5;
const double tilemapFogMaxOpacity = 1;
const double tilemapFogSamplesPerTileExtent = 4;
const BlendMode tilemapFogVertexBlendMode = BlendMode.modulate;

@immutable
class TilemapFogControlPoint {
  const TilemapFogControlPoint({required this.position, required this.opacity});

  final double position;
  final double opacity;

  TilemapFogControlPoint copyWith({double? position, double? opacity}) {
    return TilemapFogControlPoint(
      position: position ?? this.position,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TilemapFogControlPoint &&
        other.position == position &&
        other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(position, opacity);
}

const List<TilemapFogControlPoint> tilemapDefaultFogControlPoints = [
  TilemapFogControlPoint(position: 0, opacity: 0),
  TilemapFogControlPoint(position: 0.25, opacity: 0.15625),
  TilemapFogControlPoint(position: 0.5, opacity: 0.5),
  TilemapFogControlPoint(position: 0.75, opacity: 0.84375),
  TilemapFogControlPoint(position: 1, opacity: 1),
];

double tilemapFogOpacityForDistance({
  required double distance,
  required double tileExtent,
  List<TilemapFogControlPoint> controlPoints = tilemapDefaultFogControlPoints,
}) {
  if (!distance.isFinite || distance <= 0) {
    return controlPoints.isEmpty
        ? 0
        : controlPoints.first.opacity.clamp(0, 1).toDouble();
  }
  final fadeDistance = tileExtent * tilemapFogFadeTileExtents;
  if (!fadeDistance.isFinite || fadeDistance <= 0) {
    return tilemapFogMaxOpacity;
  }
  final t = (distance / fadeDistance).clamp(0.0, 1.0);
  if (controlPoints.isEmpty) return tilemapFogMaxOpacity * t;
  if (t <= controlPoints.first.position) {
    return tilemapFogMaxOpacity *
        controlPoints.first.opacity.clamp(0, 1).toDouble();
  }
  for (var index = 1; index < controlPoints.length; index += 1) {
    final previous = controlPoints[index - 1];
    final current = controlPoints[index];
    if (t > current.position) continue;
    final span = current.position - previous.position;
    final segmentT = span <= 0
        ? 1.0
        : ((t - previous.position) / span).clamp(0.0, 1.0);
    final opacity =
        previous.opacity + (current.opacity - previous.opacity) * segmentT;
    return tilemapFogMaxOpacity * opacity.clamp(0, 1).toDouble();
  }
  return tilemapFogMaxOpacity *
      controlPoints.last.opacity.clamp(0, 1).toDouble();
}

double tilemapFogDistanceToSegment({
  required Offset point,
  required Offset start,
  required Offset end,
  required double verticalScale,
}) {
  final resolvedVerticalScale = verticalScale.isFinite && verticalScale > 0
      ? verticalScale
      : 1.0;
  final scaledPoint = Offset(point.dx, point.dy * resolvedVerticalScale);
  final scaledStart = Offset(start.dx, start.dy * resolvedVerticalScale);
  final scaledEnd = Offset(end.dx, end.dy * resolvedVerticalScale);
  final delta = scaledEnd - scaledStart;
  final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
  if (lengthSquared == 0) return (scaledPoint - scaledStart).distance;
  final relative = scaledPoint - scaledStart;
  final t = ((relative.dx * delta.dx + relative.dy * delta.dy) / lengthSquared)
      .clamp(0.0, 1.0);
  return (scaledPoint - (scaledStart + delta * t)).distance;
}

class TilemapFogField {
  const TilemapFogField({
    required this.vertices,
    required this.landPath,
    required this.shadowPath,
    required this.bounds,
  });

  final ui.Vertices vertices;
  final Path landPath;
  final Path shadowPath;
  final Rect bounds;
}

TilemapFogField buildTilemapFogField({
  required Rect fieldBounds,
  required Iterable<TilemapCell> tiles,
  required List<Offset> Function(TilemapCell tile) polygonForTile,
  required double tileExtent,
  required double tileDiamondWidth,
  required double tileDiamondHeight,
  required double verticalScale,
  required List<TilemapFogControlPoint> controlPoints,
}) {
  final landTiles = tiles.where((tile) => !tile.hasShadow).toList();
  final shadowTiles = tiles.where((tile) => tile.hasShadow).toList();
  final boundary = _tilemapLandBoundary(landTiles, polygonForTile);
  final landPath = Path();
  for (final tile in landTiles) {
    landPath.addPolygon(polygonForTile(tile), true);
  }
  final shadowPath = Path();
  for (final tile in shadowTiles) {
    shadowPath.addPolygon(polygonForTile(tile), true);
  }
  final horizontalStep = tileDiamondWidth / tilemapFogSamplesPerTileExtent;
  final verticalStep = tileDiamondHeight / tilemapFogSamplesPerTileExtent;
  final columns = math.max(1, (fieldBounds.width / horizontalStep).ceil());
  final rows = math.max(1, (fieldBounds.height / verticalStep).ceil());
  final cellWidth = fieldBounds.width / columns;
  final cellHeight = fieldBounds.height / rows;
  final points = <Offset>[];
  final colors = <Color>[];
  final gridColors = List<Color>.filled(
    (columns + 1) * (rows + 1),
    Colors.transparent,
  );
  final maxDistance = tileExtent * tilemapFogFadeTileExtents;
  final boundaryIndex = _TilemapBoundaryIndex(
    boundary,
    maxDistance: maxDistance,
    verticalScale: verticalScale,
  );

  int gridIndex(int column, int row) => row * (columns + 1) + column;

  for (var row = 0; row <= rows; row += 1) {
    for (var column = 0; column <= columns; column += 1) {
      final point = Offset(
        fieldBounds.left + cellWidth * column,
        fieldBounds.top + cellHeight * row,
      );
      final distance = boundaryIndex.distanceTo(point);
      final opacity = tilemapFogOpacityForDistance(
        distance: distance,
        tileExtent: tileExtent,
        controlPoints: controlPoints,
      );
      gridColors[gridIndex(column, row)] = Color.fromARGB(
        (opacity * 0xFF).round(),
        0,
        0,
        0,
      );
    }
  }

  void addVertex(Offset point, Color color) {
    points.add(point);
    colors.add(color);
  }

  for (var row = 0; row < rows; row += 1) {
    for (var column = 0; column < columns; column += 1) {
      final topLeft = Offset(
        fieldBounds.left + cellWidth * column,
        fieldBounds.top + cellHeight * row,
      );
      final topRight = Offset(topLeft.dx + cellWidth, topLeft.dy);
      final bottomLeft = Offset(topLeft.dx, topLeft.dy + cellHeight);
      final bottomRight = Offset(
        topLeft.dx + cellWidth,
        topLeft.dy + cellHeight,
      );
      final topLeftColor = gridColors[gridIndex(column, row)];
      final topRightColor = gridColors[gridIndex(column + 1, row)];
      final bottomLeftColor = gridColors[gridIndex(column, row + 1)];
      final bottomRightColor = gridColors[gridIndex(column + 1, row + 1)];
      addVertex(topLeft, topLeftColor);
      addVertex(topRight, topRightColor);
      addVertex(bottomRight, bottomRightColor);
      addVertex(topLeft, topLeftColor);
      addVertex(bottomRight, bottomRightColor);
      addVertex(bottomLeft, bottomLeftColor);
    }
  }

  return TilemapFogField(
    vertices: ui.Vertices(ui.VertexMode.triangles, points, colors: colors),
    landPath: landPath,
    shadowPath: shadowPath,
    bounds: fieldBounds,
  );
}

List<_TilemapBoundaryEdge> _tilemapLandBoundary(
  Iterable<TilemapCell> landTiles,
  List<Offset> Function(TilemapCell tile) polygonForTile,
) {
  final edges = <String, _TilemapBoundaryEdge>{};
  for (final tile in landTiles) {
    final polygon = polygonForTile(tile);
    for (var index = 0; index < polygon.length; index += 1) {
      final edge = _TilemapBoundaryEdge(
        polygon[index],
        polygon[(index + 1) % polygon.length],
      );
      final key = edge.canonicalKey;
      // A shared edge is internal to the land union; only unmatched edges
      // remain in the outer or hole boundary.
      if (edges.remove(key) == null) edges[key] = edge;
    }
  }
  return edges.values.toList(growable: false);
}

class _TilemapBoundaryEdge {
  const _TilemapBoundaryEdge(this.start, this.end);

  final Offset start;
  final Offset end;

  String get canonicalKey {
    final startFirst =
        start.dx < end.dx || (start.dx == end.dx && start.dy <= end.dy);
    final first = startFirst ? start : end;
    final second = startFirst ? end : start;
    return '${first.dx},${first.dy}|${second.dx},${second.dy}';
  }

  double distanceTo(Offset point, {required double verticalScale}) {
    return tilemapFogDistanceToSegment(
      point: point,
      start: start,
      end: end,
      verticalScale: verticalScale,
    );
  }
}

class _TilemapBoundaryIndex {
  _TilemapBoundaryIndex(
    Iterable<_TilemapBoundaryEdge> edges, {
    required this.maxDistance,
    required this.verticalScale,
  }) : cellSize = math.max(1, maxDistance) {
    for (final edge in edges) {
      final scaledStart = _scaleOffset(edge.start);
      final scaledEnd = _scaleOffset(edge.end);
      final bounds = Rect.fromPoints(
        scaledStart,
        scaledEnd,
      ).inflate(maxDistance);
      final left = (bounds.left / cellSize).floor();
      final right = (bounds.right / cellSize).floor();
      final top = (bounds.top / cellSize).floor();
      final bottom = (bounds.bottom / cellSize).floor();
      for (var y = top; y <= bottom; y += 1) {
        for (var x = left; x <= right; x += 1) {
          _buckets.putIfAbsent((x, y), () => []).add(edge);
        }
      }
    }
  }

  final double maxDistance;
  final double verticalScale;
  final double cellSize;
  final Map<(int, int), List<_TilemapBoundaryEdge>> _buckets = {};

  Offset _scaleOffset(Offset offset) {
    return Offset(offset.dx, offset.dy * verticalScale);
  }

  double distanceTo(Offset point) {
    final scaledPoint = _scaleOffset(point);
    final candidates =
        _buckets[(
          (scaledPoint.dx / cellSize).floor(),
          (scaledPoint.dy / cellSize).floor(),
        )];
    if (candidates == null) return maxDistance;
    var distance = maxDistance;
    for (final edge in candidates) {
      distance = math.min(
        distance,
        edge.distanceTo(point, verticalScale: verticalScale),
      );
      if (distance == 0) break;
    }
    return distance;
  }
}
