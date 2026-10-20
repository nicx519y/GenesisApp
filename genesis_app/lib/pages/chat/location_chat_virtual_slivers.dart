import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'location_chat_geometry_cache.dart';

/// Current-window extents survive sheet recreation without filling the
/// measured-geometry LRU with estimates. No widgets or render objects retained.
class LocationChatVirtualExtentCache {
  final _entries = <Object, LocationChatRetainedExtent>{};

  int get length => _entries.length;
  void clear() => _entries.clear();
}

/// Two-level virtualization: distant blocks have one extent-only render node.
/// A visible or explicitly pinned block mounts its bounded row-sliver window.
/// Heights are owned by the current timeline, not by ephemeral block membership.
class LocationChatVirtualSlivers extends StatefulWidget {
  const LocationChatVirtualSlivers({
    super.key,
    required this.rows,
    this.extentCache,
  });

  final List<LocationChatCachedSliver> rows;
  final LocationChatVirtualExtentCache? extentCache;

  @override
  State<LocationChatVirtualSlivers> createState() =>
      _LocationChatVirtualSliversState();
}

class _LocationChatVirtualSliversState
    extends State<LocationChatVirtualSlivers> {
  static const blockSize = 24;
  final _localCache = LocationChatVirtualExtentCache();
  Map<Object, LocationChatRetainedExtent> get _extents =>
      (widget.extentCache ?? _localCache)._entries;

  @override
  Widget build(BuildContext context) {
    final ids = widget.rows.map((row) => row.identity).toSet();
    _extents.removeWhere((id, _) => !ids.contains(id));
    final blocks = <Widget>[];
    for (var start = 0; start < widget.rows.length; start += blockSize) {
      final end = (start + blockSize).clamp(0, widget.rows.length);
      final rows = widget.rows.sublist(start, end);
      final extents = [
        for (final row in rows)
          _extents.putIfAbsent(row.identity, LocationChatRetainedExtent.new),
      ];
      blocks.add(
        _VirtualBlock(
          key: ValueKey(start ~/ blockSize),
          rows: rows,
          extents: extents,
        ),
      );
    }
    return _PositionedSliverGroup(children: blocks);
  }
}

class _VirtualBlock extends StatelessWidget {
  const _VirtualBlock({super.key, required this.rows, required this.extents});

  final List<LocationChatCachedSliver> rows;
  final List<LocationChatRetainedExtent> extents;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      var total = 0.0;
      var pinned = false;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (!row.empty) {
          total += extents[i].resolve(
            row.cache,
            row.identity,
            row.version,
            constraints.viewportMainAxisExtent,
            storeEstimate: false,
          );
        }
        pinned = pinned || row.pinned;
      }
      final visible =
          constraints.remainingCacheExtent > 0 &&
          constraints.scrollOffset + constraints.cacheOrigin <= total;
      if (!pinned && !visible) {
        // Offscreen rows still participate in reading sections and bounds.
        // Publish numerical offsets without constructing row elements/bodies.
        var offset = constraints.precedingScrollExtent;
        for (var i = 0; i < rows.length; i++) {
          final height = rows[i].empty ? 0.0 : extents[i].height!;
          rows[i].onExtent?.call(offset, height);
          offset += height;
        }
        return SliverToBoxAdapter(child: SizedBox(height: total));
      }
      return _PositionedSliverGroup(
        children: [
          for (var i = 0; i < rows.length; i++)
            LocationChatCachedSliver(
              key: ValueKey(rows[i].identity),
              cache: rows[i].cache,
              identity: rows[i].identity,
              version: rows[i].version,
              pinned: rows[i].pinned,
              empty: rows[i].empty,
              retainedExtent: extents[i],
              onExtent: rows[i].onExtent,
              builder: rows[i].builder,
            ),
        ],
      );
    },
  );
}

/// Flutter co-locates invisible trailing slivers at a group's paint edge.
/// Pinned rows need their actual content position, including in nested groups.
class _PositionedSliverGroup extends MultiChildRenderObjectWidget {
  const _PositionedSliverGroup({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPositionedSliverGroup();
}

class _RenderPositionedSliverGroup extends RenderSliverMainAxisGroup {
  @override
  void performLayout() {
    super.performLayout();
    if (geometry?.scrollOffsetCorrection != null) return;
    var child = firstChild;
    while (child != null) {
      if (!child.geometry!.visible && child.constraints.scrollOffset == 0) {
        final data = child.parentData! as SliverPhysicalParentData;
        data.paintOffset = Offset(
          0,
          child.constraints.precedingScrollExtent -
              constraints.precedingScrollExtent -
              constraints.scrollOffset,
        );
      }
      child = childAfter(child);
    }
  }
}
