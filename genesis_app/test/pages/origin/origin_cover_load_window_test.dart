import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_throttled_image_provider.dart';
import 'package:genesis_flutter_android/pages/origin/origin_cover_load_window.dart';

void main() {
  test('calculates visible and half-viewport prefetch rows at the top', () {
    final window = OriginCoverLoadWindow.forGrid(
      itemCount: 20,
      scrollOffset: 0,
      viewportDimension: 200,
      rowStride: 100,
      gridTop: 5,
    );

    expect(window.visibleFirstIndex, 0);
    expect(window.visibleLastIndex, 3);
    expect(window.prefetchFirstIndex, 0);
    expect(window.prefetchLastIndex, 5);
    expect(window.priorityFor(1), OriginItemCoverLoadPriority.visible);
    expect(window.priorityFor(4), OriginItemCoverLoadPriority.prefetch);
    expect(window.priorityFor(6), OriginItemCoverLoadPriority.disabled);
  });

  test('expands both sides by half a viewport in the middle', () {
    final window = OriginCoverLoadWindow.forGrid(
      itemCount: 30,
      scrollOffset: 350,
      viewportDimension: 200,
      rowStride: 100,
      gridTop: 5,
    );

    expect(window.visibleFirstIndex, 6);
    expect(window.visibleLastIndex, 11);
    expect(window.prefetchFirstIndex, 4);
    expect(window.prefetchLastIndex, 13);
  });

  test('clamps the load window to a partial final row', () {
    final window = OriginCoverLoadWindow.forGrid(
      itemCount: 9,
      scrollOffset: 10000,
      viewportDimension: 200,
      rowStride: 100,
      gridTop: 5,
    );

    expect(window.visibleFirstIndex, 8);
    expect(window.visibleLastIndex, 8);
    expect(window.prefetchFirstIndex, 8);
    expect(window.prefetchLastIndex, 8);
  });

  test('recomputes the prefetch span after a viewport resize', () {
    final compact = OriginCoverLoadWindow.forGrid(
      itemCount: 30,
      scrollOffset: 0,
      viewportDimension: 200,
      rowStride: 100,
      gridTop: 5,
    );
    final expanded = OriginCoverLoadWindow.forGrid(
      itemCount: 30,
      scrollOffset: 0,
      viewportDimension: 400,
      rowStride: 100,
      gridTop: 5,
    );

    expect(compact.prefetchLastIndex, 5);
    expect(expanded.visibleLastIndex, 7);
    expect(expanded.prefetchLastIndex, 11);
  });

  test('disabled window prevents every cover request', () {
    expect(
      OriginCoverLoadWindow.disabled.priorityFor(0),
      OriginItemCoverLoadPriority.disabled,
    );
    expect(
      OriginCoverLoadWindow.disabled.priorityFor(100),
      OriginItemCoverLoadPriority.disabled,
    );
  });
}
