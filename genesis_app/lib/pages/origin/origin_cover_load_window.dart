import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../components/origin/origin_item_cover_throttled_image_provider.dart';

@immutable
class OriginCoverLoadWindow {
  const OriginCoverLoadWindow({
    required this.visibleFirstIndex,
    required this.visibleLastIndex,
    required this.prefetchFirstIndex,
    required this.prefetchLastIndex,
  });

  static const disabled = OriginCoverLoadWindow(
    visibleFirstIndex: 0,
    visibleLastIndex: -1,
    prefetchFirstIndex: 0,
    prefetchLastIndex: -1,
  );

  factory OriginCoverLoadWindow.forGrid({
    required int itemCount,
    required double scrollOffset,
    required double viewportDimension,
    required double rowStride,
    required double gridTop,
    int crossAxisCount = 2,
  }) {
    assert(itemCount > 0);
    assert(viewportDimension >= 0);
    assert(rowStride > 0);
    assert(crossAxisCount > 0);

    final viewportStart = math.max(0.0, scrollOffset - gridTop);
    final viewportEnd = math.max(
      viewportStart,
      scrollOffset + viewportDimension - gridTop,
    );
    final maxRow = (itemCount - 1) ~/ crossAxisCount;
    final firstVisibleRow = math.min(
      maxRow,
      math.max(0, (viewportStart / rowStride).floor()),
    );
    final lastVisibleRow = math.min(
      maxRow,
      math.max(
        firstVisibleRow,
        ((math.max(viewportStart, viewportEnd - 0.001)) / rowStride).floor(),
      ),
    );
    final prefetchExtent = viewportDimension / 2;
    final prefetchStart = math.max(0.0, viewportStart - prefetchExtent);
    final prefetchEnd = viewportEnd + prefetchExtent;
    final firstPrefetchRow = math.min(
      maxRow,
      math.max(0, (prefetchStart / rowStride).floor()),
    );
    final lastPrefetchRow = math.min(
      maxRow,
      math.max(
        firstPrefetchRow,
        ((math.max(prefetchStart, prefetchEnd - 0.001)) / rowStride).floor(),
      ),
    );
    return OriginCoverLoadWindow(
      visibleFirstIndex: firstVisibleRow * crossAxisCount,
      visibleLastIndex: math.min(
        itemCount - 1,
        (lastVisibleRow + 1) * crossAxisCount - 1,
      ),
      prefetchFirstIndex: firstPrefetchRow * crossAxisCount,
      prefetchLastIndex: math.min(
        itemCount - 1,
        (lastPrefetchRow + 1) * crossAxisCount - 1,
      ),
    );
  }

  final int visibleFirstIndex;
  final int visibleLastIndex;
  final int prefetchFirstIndex;
  final int prefetchLastIndex;

  OriginItemCoverLoadPriority priorityFor(int index) {
    if (index >= visibleFirstIndex && index <= visibleLastIndex) {
      return OriginItemCoverLoadPriority.visible;
    }
    if (index >= prefetchFirstIndex && index <= prefetchLastIndex) {
      return OriginItemCoverLoadPriority.prefetch;
    }
    return OriginItemCoverLoadPriority.disabled;
  }

  @override
  bool operator ==(Object other) {
    return other is OriginCoverLoadWindow &&
        other.visibleFirstIndex == visibleFirstIndex &&
        other.visibleLastIndex == visibleLastIndex &&
        other.prefetchFirstIndex == prefetchFirstIndex &&
        other.prefetchLastIndex == prefetchLastIndex;
  }

  @override
  int get hashCode => Object.hash(
    visibleFirstIndex,
    visibleLastIndex,
    prefetchFirstIndex,
    prefetchLastIndex,
  );
}
