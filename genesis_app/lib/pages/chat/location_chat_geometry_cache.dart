import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Layout data, not widgets or RenderObjects. Estimates are only used to find
/// an unmounted row; positioning always measures the mounted bubble surface.
class LocationChatGeometryCache {
  LocationChatGeometryCache({this.capacity = 512});
  final int capacity;
  final _entries =
      <
        Object,
        ({Object version, double height, bool measured, double? bubbleBottom})
      >{};
  final Set<Object> protectedKeys = {};
  int measurements = 0;
  int hits = 0;

  int get length => _entries.length;

  double? read(Object key, Object version) {
    final value = _entries[key];
    if (value == null || value.version != version) return null;
    _entries.remove(key);
    _entries[key] = value;
    hits++;
    return value.height;
  }

  double estimate(double fallback) {
    final heights = _entries.values.where((e) => e.measured && e.height > 0);
    if (heights.isEmpty) return fallback;
    return heights.fold<double>(0, (sum, e) => sum + e.height) / heights.length;
  }

  double extent(Object key, Object version, double fallback) {
    final known = read(key, version);
    if (known != null) return known;
    final height = estimate(fallback);
    _entries[key] = (
      version: version,
      height: height,
      measured: false,
      bubbleBottom: null,
    );
    _trim();
    return height;
  }

  void report(Object key, Object version, double height) {
    if (!height.isFinite || height < 0) return;
    measurements++;
    final previous = _entries.remove(key);
    _entries[key] = (
      version: version,
      height: height,
      measured: true,
      bubbleBottom: previous?.version == version && previous?.height == height
          ? previous?.bubbleBottom
          : null,
    );
    _trim();
  }

  /// Local surface coordinate, never an absolute Y or an estimated anchor.
  void reportBubbleBottom(Object key, double bottom) {
    final entry = _entries[key];
    if (entry == null ||
        !entry.measured ||
        !bottom.isFinite ||
        bottom < 0 ||
        bottom > entry.height) {
      return;
    }
    _entries[key] = (
      version: entry.version,
      height: entry.height,
      measured: true,
      bubbleBottom: bottom,
    );
  }

  double? bubbleBottom(Object key, Object version) {
    final entry = _entries[key];
    return entry?.version == version ? entry?.bubbleBottom : null;
  }

  void _trim() {
    for (final candidate in _entries.keys.toList()) {
      if (_entries.length <= capacity) break;
      if (!protectedKeys.contains(candidate)) _entries.remove(candidate);
    }
  }

  void clear() => _entries.clear();
}

/// Each row owns its extent even while unmounted. Unlike extending the list's
/// cache to reach a distant target, pinning this sliver lays out only that row.
class LocationChatCachedSliver extends StatefulWidget {
  const LocationChatCachedSliver({
    super.key,
    required this.cache,
    required this.identity,
    required this.version,
    required this.pinned,
    required this.builder,
    this.onExtent,
    this.empty = false,
  });

  final LocationChatGeometryCache cache;
  final Object identity;
  final Object version;
  final bool pinned;
  final bool empty;
  final WidgetBuilder builder;
  final void Function(double offset, double extent)? onExtent;

  @override
  State<LocationChatCachedSliver> createState() => _CachedSliverState();
}

class _CachedSliverState extends State<LocationChatCachedSliver> {
  double? _extent;
  Object? _version;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      if (widget.empty) {
        widget.onExtent?.call(constraints.precedingScrollExtent, 0);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      if (_version != widget.version) {
        _version = widget.version;
        _extent = widget.cache.extent(
          widget.identity,
          widget.version,
          constraints.viewportMainAxisExtent,
        );
      }
      final extent = _extent!;
      widget.onExtent?.call(constraints.precedingScrollExtent, extent);
      final visible =
          constraints.remainingCacheExtent > 0 &&
          constraints.scrollOffset + constraints.cacheOrigin <= extent;
      if (!widget.pinned && !visible) {
        return SliverToBoxAdapter(child: SizedBox(height: extent));
      }
      return SliverToBoxAdapter(
        child: _Measure(
          onLayout: (size) {
            _extent = size.height;
            widget.cache.report(widget.identity, widget.version, size.height);
            widget.onExtent?.call(
              constraints.precedingScrollExtent,
              size.height,
            );
          },
          child: widget.builder(context),
        ),
      );
    },
  );
}

class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onLayout, required super.child});
  final ValueChanged<Size> onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasure(onLayout);
  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onLayout);
  ValueChanged<Size> onLayout;
  @override
  void performLayout() {
    super.performLayout();
    onLayout(size);
  }
}
