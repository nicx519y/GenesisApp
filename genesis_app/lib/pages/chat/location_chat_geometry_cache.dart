import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef _GeometryEntry = ({
  Object version,
  double height,
  bool measured,
  double? bubbleBottom,
});

/// Layout data, not widgets or RenderObjects. Estimates are only used to find
/// an unmounted row; positioning always measures the mounted bubble surface.
class LocationChatGeometryCache {
  LocationChatGeometryCache({this.capacity = 512});
  final int capacity;
  final _entries = <Object, _GeometryEntry>{};
  double _measuredHeight = 0;
  int _measuredCount = 0;
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

  double estimate(double fallback) =>
      _measuredCount == 0 ? fallback : _measuredHeight / _measuredCount;

  void _removeMeasurement(_GeometryEntry? entry) {
    if (entry == null || !entry.measured || entry.height <= 0) return;
    _measuredCount--;
    _measuredHeight = _measuredCount == 0 ? 0 : _measuredHeight - entry.height;
  }

  double extent(
    Object key,
    Object version,
    double fallback, {
    bool storeEstimate = true,
  }) {
    final known = read(key, version);
    if (known != null) return known;
    if (!storeEstimate) {
      // Grouped archives already own their estimates. Do not let distant
      // placeholders evict measured heights used on reopen and for estimates.
      _removeMeasurement(_entries.remove(key));
      return estimate(fallback);
    }
    final height = estimate(fallback);
    _removeMeasurement(_entries[key]);
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
    if (previous?.measured != true || previous?.height != height) {
      _removeMeasurement(previous);
      if (height > 0) {
        _measuredCount++;
        _measuredHeight += height;
      }
    }
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
    final excess = _entries.length - capacity;
    if (excess <= 0) return;
    // Collect only victims before mutating the ordered map. Touching or
    // reporting an in-budget row never copies the full key collection.
    final victims = <Object>[];
    for (final candidate in _entries.keys) {
      if (protectedKeys.contains(candidate)) continue;
      victims.add(candidate);
      if (victims.length >= excess) break;
    }
    for (final victim in victims) {
      _removeMeasurement(_entries.remove(victim));
    }
  }

  void clear() {
    _entries.clear();
    _measuredCount = 0;
    _measuredHeight = 0;
  }
}

/// Each row owns its extent even while unmounted. Unlike extending the list's
/// cache to reach a distant target, pinning this sliver lays out only that row.
class LocationChatRetainedExtent {
  Object? version;
  double? height;

  double resolve(
    LocationChatGeometryCache cache,
    Object identity,
    Object nextVersion,
    double fallback, {
    bool storeEstimate = true,
  }) {
    if (version != nextVersion || height == null) {
      version = nextVersion;
      height = cache.extent(
        identity,
        nextVersion,
        fallback,
        storeEstimate: storeEstimate,
      );
    }
    return height!;
  }
}

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
    this.retainedExtent,
  });

  final LocationChatGeometryCache cache;
  final Object identity;
  final Object version;
  final bool pinned;
  final bool empty;
  final LocationChatRetainedExtent? retainedExtent;
  final WidgetBuilder builder;
  final void Function(double offset, double extent)? onExtent;

  @override
  State<LocationChatCachedSliver> createState() => _CachedSliverState();
}

class _CachedSliverState extends State<LocationChatCachedSliver> {
  final _ownExtent = LocationChatRetainedExtent();
  LocationChatRetainedExtent get _extent => widget.retainedExtent ?? _ownExtent;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      if (widget.empty) {
        widget.onExtent?.call(constraints.precedingScrollExtent, 0);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      final extent = _extent.resolve(
        widget.cache,
        widget.identity,
        widget.version,
        constraints.viewportMainAxisExtent,
      );
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
            _extent.height = size.height;
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
