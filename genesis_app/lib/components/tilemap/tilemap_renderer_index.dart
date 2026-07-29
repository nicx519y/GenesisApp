part of 'tilemap_renderer_library.dart';

class _TilemapRenderRecord {
  const _TilemapRenderRecord({
    required this.tile,
    required this.imageTopLeft,
    required this.imageBounds,
    required this.paintOrder,
  });

  final TilemapCell tile;
  final Offset imageTopLeft;
  final Rect imageBounds;
  final int paintOrder;
}

class _TilemapRenderIndex {
  _TilemapRenderIndex({
    required TilemapProjection projection,
    required Iterable<TilemapCell> tiles,
  }) : bucketSize = projection.tileExtent * 4 {
    final sortedTiles = tiles.toList(growable: false)
      ..sort(_compareTilesForPaint);
    for (var paintOrder = 0; paintOrder < sortedTiles.length; paintOrder += 1) {
      final tile = sortedTiles[paintOrder];
      final imageTopLeft = projection.imageTopLeftForTile(tile);
      final record = _TilemapRenderRecord(
        tile: tile,
        imageTopLeft: imageTopLeft,
        imageBounds: imageTopLeft & Size.square(projection.tileExtent),
        paintOrder: paintOrder,
      );
      _insert(record);
      hasFogTiles = hasFogTiles || tile.hasShadow;
      hasShadowZeroTiles = hasShadowZeroTiles || !tile.hasShadow;
    }
  }

  final double bucketSize;
  final Map<(int, int), List<_TilemapRenderRecord>> _buckets = {};
  bool hasFogTiles = false;
  bool hasShadowZeroTiles = false;

  List<_TilemapRenderRecord> query(Rect bounds) {
    final candidates = <_TilemapRenderRecord>{};
    for (var y = _bucketFor(bounds.top); y <= _bucketFor(bounds.bottom); y++) {
      for (
        var x = _bucketFor(bounds.left);
        x <= _bucketFor(bounds.right);
        x++
      ) {
        final bucket = _buckets[(x, y)];
        if (bucket != null) candidates.addAll(bucket);
      }
    }
    final result =
        candidates
            .where(
              (record) => _rectsIntersectOrTouch(record.imageBounds, bounds),
            )
            .toList(growable: false)
          ..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    return result;
  }

  List<_TilemapRenderRecord> queryPoint(Offset point) {
    final candidates = _buckets[(_bucketFor(point.dx), _bucketFor(point.dy))];
    if (candidates == null) return const [];
    final result =
        candidates
            .where((record) => _rectContainsPoint(record.imageBounds, point))
            .toList(growable: false)
          ..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    return result;
  }

  void _insert(_TilemapRenderRecord record) {
    final bounds = record.imageBounds;
    for (var y = _bucketFor(bounds.top); y <= _bucketFor(bounds.bottom); y++) {
      for (
        var x = _bucketFor(bounds.left);
        x <= _bucketFor(bounds.right);
        x++
      ) {
        _buckets.putIfAbsent((x, y), () => []).add(record);
      }
    }
  }

  int _bucketFor(double coordinate) => (coordinate / bucketSize).floor();
}

int _compareTilesForPaint(TilemapCell a, TilemapCell b) {
  final diagonal = (a.x + a.y).compareTo(b.x + b.y);
  if (diagonal != 0) return diagonal;
  return a.x.compareTo(b.x);
}

bool _rectsIntersectOrTouch(Rect a, Rect b) {
  return a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
}

bool _rectContainsPoint(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

bool _rectContainsRect(Rect outer, Rect inner) {
  return inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
}
