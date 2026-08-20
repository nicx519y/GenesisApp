import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons/custom_icon_assets.dart';
import '../ui/components/recent_chat_marker.dart';
import '../ui/components/genesis_list_image.dart';
import '../ui/theme/genesis_semantic_colors.dart';
import '../ui/tokens/genesis_image_radii.dart';
import '../utils/genesis_image_resource.dart';
import 'world_details_shell.dart';
import 'world_point.dart';

const String _locationDefaultImageAsset =
    'assets/images/map_default/location_default.webp';

typedef WorldLocationNodeHeaderBuilder =
    Widget? Function(BuildContext context, WorldPoint point, int level);
typedef WorldLocationNodeFooterBuilder =
    Widget? Function(BuildContext context, WorldPoint point, int level);

enum _WorldLocationListRowKind { flatPoint, nodeHeader, nodeFooter }

class _WorldLocationListRow {
  const _WorldLocationListRow._({
    required this.kind,
    required this.point,
    required this.level,
    this.node,
    this.showDivider = false,
  });

  const _WorldLocationListRow.flatPoint(
    WorldPoint point, {
    required bool showDivider,
  }) : this._(
         kind: _WorldLocationListRowKind.flatPoint,
         point: point,
         level: 0,
         showDivider: showDivider,
       );

  _WorldLocationListRow.nodeHeader(WorldMapLocationNode node, int level)
    : this._(
        kind: _WorldLocationListRowKind.nodeHeader,
        point: node.point,
        node: node,
        level: level,
      );

  _WorldLocationListRow.nodeFooter(WorldMapLocationNode node, int level)
    : this._(
        kind: _WorldLocationListRowKind.nodeFooter,
        point: node.point,
        node: node,
        level: level,
      );

  final _WorldLocationListRowKind kind;
  final WorldPoint point;
  final WorldMapLocationNode? node;
  final int level;
  final bool showDivider;
}

class WorldLocationList extends StatefulWidget {
  const WorldLocationList({
    super.key,
    required this.points,
    this.locationNodes = const <WorldMapLocationNode>[],
    this.physics,
    this.scrollController,
    this.enableOuterScrollHandoff = true,
    this.lazyBuildRows = false,
    this.compactSheetStyle = false,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    this.recentChatLocationIds = const <String>{},
    this.onPointTap,
    this.onNodeHeaderTap,
    this.nodeHeaderBuilder,
    this.nodeFooterBuilder,
    this.header,
    this.footer,
  });

  final List<WorldPoint> points;
  final List<WorldMapLocationNode> locationNodes;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;
  final bool enableOuterScrollHandoff;
  final bool lazyBuildRows;
  final bool compactSheetStyle;
  final EdgeInsetsGeometry padding;
  final Set<String> recentChatLocationIds;
  final ValueChanged<WorldPoint>? onPointTap;
  final ValueChanged<WorldPoint>? onNodeHeaderTap;
  final WorldLocationNodeHeaderBuilder? nodeHeaderBuilder;
  final WorldLocationNodeFooterBuilder? nodeFooterBuilder;
  final Widget? header;
  final Widget? footer;

  @override
  State<WorldLocationList> createState() => _WorldLocationListState();
}

class _WorldLocationListState extends State<WorldLocationList> {
  final ScrollController _listController = ScrollController();
  ScrollController? _outerController;
  bool _outerPageAtTop = true;
  bool _pointerActive = false;
  bool _needsPhysicsRebuild = false;
  bool _draggedOuterDuringPointer = false;
  VelocityTracker? _velocityTracker;

  static const double _ballisticHandoffMinVelocity = 80;
  static const double _ballisticHandoffDistanceFactor = 0.18;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setOuterController(
      widget.enableOuterScrollHandoff
          ? WorldDetailsPanelScrollControllerScope.maybeOf(context)
          : null,
    );
  }

  @override
  void didUpdateWidget(covariant WorldLocationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableOuterScrollHandoff != widget.enableOuterScrollHandoff) {
      _setOuterController(
        widget.enableOuterScrollHandoff
            ? WorldDetailsPanelScrollControllerScope.maybeOf(context)
            : null,
      );
    }
  }

  @override
  void dispose() {
    _outerController?.removeListener(_handleOuterScroll);
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerController = _outerController;
    final rows = widget.lazyBuildRows
        ? (widget.locationNodes.isNotEmpty
              ? _flattenNodeRows(widget.locationNodes)
              : _flattenPointRows(widget.points))
        : const <_WorldLocationListRow>[];
    final headerOffset = widget.header == null ? 0 : 1;
    final itemCount =
        rows.length + headerOffset + (widget.footer == null ? 0 : 1);
    return Listener(
      onPointerDown: (event) {
        _pointerActive = true;
        _draggedOuterDuringPointer = false;
        _velocityTracker = VelocityTracker.withKind(event.kind)
          ..addPosition(event.timeStamp, event.localPosition);
      },
      onPointerUp: (_) {
        _applyOuterPointerFling();
        _finishPointer();
      },
      onPointerCancel: (_) {
        _finishPointer();
      },
      onPointerMove: (event) {
        _velocityTracker?.addPosition(event.timeStamp, event.localPosition);
        if (outerController == null ||
            !outerController.hasClients ||
            !widget.enableOuterScrollHandoff) {
          return;
        }

        final dragDelta = event.delta.dy;
        if (!_outerPageAtTop) {
          if (_applyOuterDrag(outerController, dragDelta)) {
            _draggedOuterDuringPointer = true;
          }
          return;
        }

        if (!_listController.hasClients) return;
        final position = _listController.position;
        final atBottom = position.extentAfter <= 0.5;
        final atTop = position.extentBefore <= 0.5;
        final draggingPastBottom = dragDelta < 0 && atBottom;
        final draggingPastTop = dragDelta > 0 && atTop;
        if (!draggingPastBottom && !draggingPastTop) return;
        if (_applyOuterDrag(outerController, dragDelta)) {
          _draggedOuterDuringPointer = true;
        }
      },
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          if (outerController == null ||
              !outerController.hasClients ||
              !widget.enableOuterScrollHandoff ||
              notification.metrics.axis != Axis.vertical) {
            return false;
          }
          if (!_outerPageAtTop) return false;

          final dragDelta = notification.dragDetails?.delta.dy;
          if (dragDelta != null) {
            return _applyOuterDrag(outerController, dragDelta);
          }
          return _applyOuterOverscroll(
            outerController,
            overscroll: notification.overscroll,
            velocity: notification.velocity,
          );
        },
        child: widget.lazyBuildRows
            ? ListView.builder(
                controller: widget.scrollController ?? _listController,
                physics: _listPhysics,
                padding: widget.padding,
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (widget.header != null && index == 0) {
                    return widget.header!;
                  }
                  final rowIndex = index - headerOffset;
                  if (rowIndex >= rows.length) return widget.footer!;
                  return _buildRow(rows[rowIndex]);
                },
              )
            : ListView(
                controller: widget.scrollController ?? _listController,
                physics: _listPhysics,
                padding: widget.padding,
                children: [
                  if (widget.header != null) widget.header!,
                  if (widget.locationNodes.isNotEmpty)
                    ..._buildEagerNodeRows(widget.locationNodes)
                  else
                    ..._buildEagerFlatPointRows(widget.points),
                  if (widget.footer != null) widget.footer!,
                ],
              ),
      ),
    );
  }

  ScrollPhysics get _listPhysics {
    return widget.physics ??
        (_outerPageAtTop
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const NeverScrollableScrollPhysics());
  }

  List<Widget> _buildEagerFlatPointRows(List<WorldPoint> points) {
    return [
      for (var index = 0; index < points.length; index++) ...[
        _PointListItem(
          point: points[index],
          level: points[index].depth,
          compactSheetStyle: widget.compactSheetStyle,
          showRecentChatIcon: _pointMatchesLocationIds(
            points[index],
            widget.recentChatLocationIds,
          ),
          onTap: widget.onPointTap,
        ),
        if (index < points.length - 1) Divider(height: 1),
      ],
    ];
  }

  List<Widget> _buildEagerNodeRows(List<WorldMapLocationNode> nodes) {
    return _buildEagerNodeRowsAtLevel(nodes, 0);
  }

  List<Widget> _buildEagerNodeRowsAtLevel(
    List<WorldMapLocationNode> nodes,
    int level,
  ) {
    final rows = <Widget>[];
    for (final node in nodes) {
      final hideSyntheticRootHeader =
          node.point.name.trim().isEmpty && node.children.isNotEmpty;
      if (hideSyntheticRootHeader) {
        rows.addAll(_buildEagerNodeRowsAtLevel(node.children, level));
        continue;
      }
      if (node.children.isEmpty && node.point.isLeafLocation) {
        final customHeader = widget.nodeHeaderBuilder?.call(
          context,
          node.point,
          level,
        );
        if (customHeader != null) {
          rows.add(customHeader);
          final customFooter = widget.nodeFooterBuilder?.call(
            context,
            node.point,
            level,
          );
          if (customFooter != null) rows.add(customFooter);
          continue;
        }
        rows.add(
          _LocationCard(
            point: node.point,
            targetPoint: node.chatTargetPoint ?? node.point,
            showRecentChatIcon: _nodeMatchesLocationIds(
              node,
              widget.recentChatLocationIds,
            ),
            level: level,
            indent: level * 15.0,
            compactSheetStyle: widget.compactSheetStyle,
            onTap: widget.onPointTap,
          ),
        );
        continue;
      }
      final customHeader = widget.nodeHeaderBuilder?.call(
        context,
        node.point,
        level,
      );
      rows.add(
        customHeader ??
            _NodeHeader(
              point: node.point,
              level: level,
              compactSheetStyle: widget.compactSheetStyle,
              showRecentChatIcon: _nodeMatchesLocationIds(
                node,
                widget.recentChatLocationIds,
              ),
              onTap: widget.onNodeHeaderTap,
            ),
      );
      rows.addAll(_buildEagerNodeRowsAtLevel(node.children, level + 1));
      final customFooter = widget.nodeFooterBuilder?.call(
        context,
        node.point,
        level,
      );
      if (customFooter != null) rows.add(customFooter);
    }
    return rows;
  }

  List<_WorldLocationListRow> _flattenPointRows(List<WorldPoint> points) {
    return List<_WorldLocationListRow>.generate(
      points.length,
      (index) => _WorldLocationListRow.flatPoint(
        points[index],
        showDivider: index < points.length - 1,
      ),
      growable: false,
    );
  }

  List<_WorldLocationListRow> _flattenNodeRows(
    List<WorldMapLocationNode> nodes,
  ) {
    final rows = <_WorldLocationListRow>[];
    _appendNodeRows(rows, nodes, 0);
    return rows;
  }

  void _appendNodeRows(
    List<_WorldLocationListRow> rows,
    List<WorldMapLocationNode> nodes,
    int level,
  ) {
    for (final node in nodes) {
      final hideSyntheticRootHeader =
          node.point.name.trim().isEmpty && node.children.isNotEmpty;
      if (hideSyntheticRootHeader) {
        _appendNodeRows(rows, node.children, level);
        continue;
      }
      rows.add(_WorldLocationListRow.nodeHeader(node, level));
      if (node.children.isEmpty) continue;
      _appendNodeRows(rows, node.children, level + 1);
      if (widget.nodeFooterBuilder != null) {
        rows.add(_WorldLocationListRow.nodeFooter(node, level));
      }
    }
  }

  Widget _buildRow(_WorldLocationListRow row) {
    if (row.kind == _WorldLocationListRowKind.flatPoint) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PointListItem(
            point: row.point,
            level: row.point.depth,
            compactSheetStyle: widget.compactSheetStyle,
            showRecentChatIcon: _pointMatchesLocationIds(
              row.point,
              widget.recentChatLocationIds,
            ),
            onTap: widget.onPointTap,
          ),
          if (row.showDivider) Divider(height: 1),
        ],
      );
    }

    final node = row.node!;
    if (row.kind == _WorldLocationListRowKind.nodeFooter) {
      return widget.nodeFooterBuilder?.call(context, row.point, row.level) ??
          const SizedBox.shrink();
    }

    final customHeader = widget.nodeHeaderBuilder?.call(
      context,
      row.point,
      row.level,
    );
    if (node.children.isEmpty && row.point.isLeafLocation) {
      if (customHeader != null) {
        final customFooter = widget.nodeFooterBuilder?.call(
          context,
          row.point,
          row.level,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [customHeader, if (customFooter != null) customFooter],
        );
      }
      return _LocationCard(
        point: row.point,
        targetPoint: node.chatTargetPoint ?? row.point,
        showRecentChatIcon: _nodeMatchesLocationIds(
          node,
          widget.recentChatLocationIds,
        ),
        level: row.level,
        indent: row.level * 15.0,
        compactSheetStyle: widget.compactSheetStyle,
        onTap: widget.onPointTap,
      );
    }
    return customHeader ??
        _NodeHeader(
          point: row.point,
          level: row.level,
          compactSheetStyle: widget.compactSheetStyle,
          showRecentChatIcon: _nodeMatchesLocationIds(
            node,
            widget.recentChatLocationIds,
          ),
          onTap: widget.onNodeHeaderTap,
        );
  }

  void _setOuterController(ScrollController? controller) {
    if (_outerController == controller) return;
    _outerController?.removeListener(_handleOuterScroll);
    _outerController = controller;
    _outerController?.addListener(_handleOuterScroll);
    _syncOuterPageAtTopState(rebuild: false);
  }

  void _handleOuterScroll() {
    _syncOuterPageAtTopState(rebuild: !_pointerActive);
  }

  void _syncOuterPageAtTopState({required bool rebuild}) {
    final atTop = _isOuterPageAtTop;
    if (atTop == _outerPageAtTop) return;
    _outerPageAtTop = atTop;
    if (rebuild && mounted) {
      _needsPhysicsRebuild = false;
      setState(() {});
    } else {
      _needsPhysicsRebuild = true;
    }
  }

  void _finishPointer() {
    _pointerActive = false;
    _draggedOuterDuringPointer = false;
    _velocityTracker = null;
    _syncOuterPageAtTopState(rebuild: true);
    if (_needsPhysicsRebuild && mounted) {
      _needsPhysicsRebuild = false;
      setState(() {});
    }
  }

  void _applyOuterPointerFling() {
    final outerController = _outerController;
    final velocityTracker = _velocityTracker;
    if (!_draggedOuterDuringPointer ||
        outerController == null ||
        !outerController.hasClients ||
        velocityTracker == null) {
      return;
    }
    final velocity = velocityTracker.getVelocity().pixelsPerSecond.dy;
    if (velocity.abs() < _ballisticHandoffMinVelocity) return;
    _animateOuterScrollDelta(
      outerController,
      -velocity * _ballisticHandoffDistanceFactor,
    );
  }

  bool get _isOuterPageAtTop {
    final controller = _outerController;
    return controller == null ||
        !controller.hasClients ||
        controller.offset <= 0.5;
  }

  bool _applyOuterDrag(ScrollController outerController, double dragDelta) {
    if (dragDelta.abs() <= 0.5) return false;
    final before = outerController.offset;
    final target = (before - dragDelta)
        .clamp(0.0, outerController.position.maxScrollExtent)
        .toDouble();
    if ((target - before).abs() <= 0.5) return false;
    outerController.jumpTo(target);
    return true;
  }

  bool _applyOuterOverscroll(
    ScrollController outerController, {
    required double overscroll,
    required double velocity,
  }) {
    var handled = false;
    if (overscroll.abs() > 0.5) {
      handled = _applyOuterScrollDelta(outerController, overscroll);
    }
    if (velocity.abs() < _ballisticHandoffMinVelocity) return handled;
    final direction = overscroll.abs() > 0.5 ? overscroll.sign : velocity.sign;
    final distance =
        (velocity.abs() * _ballisticHandoffDistanceFactor).clamp(24.0, 420.0) *
        direction;
    return _animateOuterScrollDelta(outerController, distance) || handled;
  }

  bool _applyOuterScrollDelta(
    ScrollController outerController,
    double scrollDelta,
  ) {
    if (scrollDelta.abs() <= 0.5) return false;
    final before = outerController.offset;
    final target = (before + scrollDelta)
        .clamp(0.0, outerController.position.maxScrollExtent)
        .toDouble();
    if ((target - before).abs() <= 0.5) return false;
    outerController.jumpTo(target);
    return true;
  }

  bool _animateOuterScrollDelta(
    ScrollController outerController,
    double scrollDelta,
  ) {
    if (scrollDelta.abs() <= 0.5) return false;
    final before = outerController.offset;
    final target = (before + scrollDelta)
        .clamp(0.0, outerController.position.maxScrollExtent)
        .toDouble();
    if ((target - before).abs() <= 0.5) return false;
    unawaited(
      outerController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.decelerate,
      ),
    );
    return true;
  }
}

class _PointListItem extends StatelessWidget {
  const _PointListItem({
    required this.point,
    required this.level,
    required this.compactSheetStyle,
    required this.showRecentChatIcon,
    required this.onTap,
  });

  final WorldPoint point;
  final int level;
  final bool compactSheetStyle;
  final bool showRecentChatIcon;
  final ValueChanged<WorldPoint>? onTap;

  @override
  Widget build(BuildContext context) {
    final depthIndent = point.depth < 0 ? 0.0 : point.depth * 15.0;
    final description = point.locationDescription.trim();
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(point),
      child: Padding(
        padding: EdgeInsets.only(
          left: depthIndent,
          top: compactSheetStyle ? 10 : 5,
          bottom: compactSheetStyle ? 10 : 5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PointListCover(point: point, compactSheetStyle: compactSheetStyle),
            SizedBox(width: compactSheetStyle ? 11 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: context.genesisColors.foregroundStrong,
                      ),
                      SizedBox(width: 2),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          point.name,
                          style: _locationNameStyle(
                            context,
                            level,
                            compactSheetStyle: compactSheetStyle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showRecentChatIcon) ...[
                        SizedBox(width: 5),
                        const RecentChatIcon(),
                      ],
                    ],
                  ),
                  SizedBox(height: level >= 2 ? 8 : 4),
                  if (point.users.isNotEmpty)
                    _PointCharacterGroups(
                      users: point.users,
                      compactSheetStyle: compactSheetStyle,
                    ),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    _PointSummaryRow(description: description),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeHeader extends StatelessWidget {
  const _NodeHeader({
    required this.point,
    required this.level,
    required this.compactSheetStyle,
    required this.showRecentChatIcon,
    required this.onTap,
  });

  final WorldPoint point;
  final int level;
  final bool compactSheetStyle;
  final bool showRecentChatIcon;
  final ValueChanged<WorldPoint>? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(point),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          level * 15.0 + (compactSheetStyle ? 13 : 0),
          compactSheetStyle ? 9 : 5,
          0,
          compactSheetStyle ? 2 : 5,
        ),
        child: Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                compactSheetStyle ? point.name : '- ${point.name}',
                style: _locationNameStyle(
                  context,
                  level,
                  compactSheetStyle: compactSheetStyle,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (compactSheetStyle) ...[
              const Spacer(),
              Text(
                point.users.isEmpty ? 'Empty' : '${point.users.length} here',
                style: TextStyle(
                  color: context.genesisColors.textSecondary,
                  fontSize: 9.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (showRecentChatIcon) ...[
              SizedBox(width: 5),
              const RecentChatIcon(),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.point,
    required this.targetPoint,
    required this.showRecentChatIcon,
    required this.level,
    required this.indent,
    required this.compactSheetStyle,
    required this.onTap,
  });

  final WorldPoint point;
  final WorldPoint targetPoint;
  final bool showRecentChatIcon;
  final int level;
  final double indent;
  final bool compactSheetStyle;
  final ValueChanged<WorldPoint>? onTap;

  @override
  Widget build(BuildContext context) {
    final description = point.locationDescription.trim();
    return InkWell(
      key: ValueKey<String>('world-location-card-${point.id}'),
      onTap: onTap == null ? null : () => onTap!(targetPoint),
      child: Container(
        margin: EdgeInsets.only(left: indent + (compactSheetStyle ? 15 : 0)),
        padding: EdgeInsets.symmetric(vertical: compactSheetStyle ? 10 : 5),
        decoration: compactSheetStyle
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.genesisColors.dividerAction,
                    width: 1,
                  ),
                ),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LocationCardCover(
              point: point,
              compactSheetStyle: compactSheetStyle,
            ),
            SizedBox(width: compactSheetStyle ? 11 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: context.genesisColors.foregroundStrong,
                      ),
                      SizedBox(width: 2),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          point.name,
                          style: _locationNameStyle(
                            context,
                            level,
                            compactSheetStyle: compactSheetStyle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showRecentChatIcon) ...[
                        SizedBox(width: 5),
                        const RecentChatIcon(),
                      ],
                    ],
                  ),
                  SizedBox(height: level >= 2 ? 8 : 4),
                  if (point.users.isNotEmpty)
                    _PointCharacterGroups(
                      users: point.users,
                      compactSheetStyle: compactSheetStyle,
                    ),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    _PointSummaryRow(description: description),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _locationNameStyle(
  BuildContext context,
  int level, {
  bool compactSheetStyle = false,
}) {
  if (compactSheetStyle) {
    return TextStyle(
      fontSize: 13,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: context.genesisColors.foregroundStrong,
    );
  }
  if (level <= 0) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: context.genesisColors.foregroundStrong,
    );
  }
  return TextStyle(
    fontSize: 14,
    height: 1.2,
    fontWeight: level == 1 ? FontWeight.w600 : FontWeight.w400,
    color: context.genesisColors.foregroundStrong,
  );
}

bool _pointMatchesLocationIds(WorldPoint point, Set<String> locationIds) {
  if (locationIds.isEmpty) return false;
  final locationId = point.sceneId.trim();
  return locationId.isNotEmpty && locationIds.contains(locationId);
}

bool _nodeMatchesLocationIds(
  WorldMapLocationNode node,
  Set<String> locationIds,
) {
  if (locationIds.isEmpty) return false;
  final locationId = node.id.trim();
  if (locationId.isNotEmpty && locationIds.contains(locationId)) return true;
  return _pointMatchesLocationIds(node.point, locationIds);
}

class _PointCharacterGroups extends StatelessWidget {
  const _PointCharacterGroups({
    required this.users,
    required this.compactSheetStyle,
  });

  final List<UserAvatar> users;
  final bool compactSheetStyle;

  @override
  Widget build(BuildContext context) {
    if (compactSheetStyle) {
      final visibleUsers = users.take(3).toList(growable: false);
      final overflowCount = users.length - visibleUsers.length;
      return Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final user in visibleUsers)
            Container(
              padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
              decoration: BoxDecoration(
                color: context.genesisColors.surfaceTag,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: user.isPlayerControlledRole
                          ? Border.all(
                              color: context.genesisColors.danger,
                              width: 2,
                            )
                          : null,
                    ),
                    child: GenesisListImage(
                      imageUrl: user.avatarUrl,
                      width: 16,
                      height: 16,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _characterName(user),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: user.isPlayerControlledRole
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: user.isPlayerControlledRole
                          ? context.genesisColors.textPrimary
                          : context.genesisColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (overflowCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: context.genesisColors.surfaceTag,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+$overflowCount',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: context.genesisColors.textSecondary,
                ),
              ),
            ),
        ],
      );
    }
    final aiNames = users
        .where((user) => user.showStar)
        .map(_characterName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final nonAiNames = users
        .where((user) => !user.showStar)
        .map(_characterName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aiNames.isNotEmpty)
          _PointCharacterGroupRow(
            iconAsset: characterStatIconAsset,
            names: aiNames,
          ),
        if (aiNames.isNotEmpty && nonAiNames.isNotEmpty) SizedBox(height: 2),
        if (nonAiNames.isNotEmpty)
          _PointCharacterGroupRow(
            iconAsset: userStatIconAsset,
            names: nonAiNames,
          ),
      ],
    );
  }

  String _characterName(UserAvatar user) {
    return (user.name ?? user.initials).trim();
  }
}

class _PointCharacterGroupRow extends StatelessWidget {
  const _PointCharacterGroupRow({required this.iconAsset, required this.names});

  final String iconAsset;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 12,
          height: 15,
          child: Align(
            alignment: Alignment.topCenter,
            child: SvgPicture.asset(
              iconAsset,
              width: 12,
              height: 12,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              colorFilter: iconAsset == userStatIconAsset
                  ? ColorFilter.mode(
                      context.genesisColors.foregroundStrong,
                      BlendMode.srcIn,
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            names.join(', '),
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: context.genesisColors.foregroundStrong,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PointSummaryRow extends StatelessWidget {
  const _PointSummaryRow({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: TextStyle(
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w400,
        color: context.genesisColors.foregroundStrong,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PointListCover extends StatelessWidget {
  const _PointListCover({required this.point, required this.compactSheetStyle});

  final WorldPoint point;
  final bool compactSheetStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compactSheetStyle ? 52 : 64,
      height: compactSheetStyle ? 52 : 64,
      child: _LocationCoverImage(point: point),
    );
  }
}

class _LocationCardCover extends StatelessWidget {
  const _LocationCardCover({
    required this.point,
    required this.compactSheetStyle,
  });

  final WorldPoint point;
  final bool compactSheetStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compactSheetStyle ? 52 : 64,
      height: compactSheetStyle ? 52 : 64,
      child: _LocationCoverImage(point: point),
    );
  }
}

class _LocationCoverImage extends StatelessWidget {
  const _LocationCoverImage({required this.point});

  final WorldPoint point;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 64.0;
        final logicalHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 64.0;
        final localBytes = point.iconBytes;
        if (localBytes != null && localBytes.isNotEmpty) {
          final cacheWidth =
              (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
          return ClipRRect(
            borderRadius: GenesisImageRadii.content,
            child: Image.memory(
              localBytes,
              key: ValueKey<String>('world-location-memory-image-${point.id}'),
              width: logicalWidth,
              height: logicalHeight,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
            ),
          );
        }
        final rawUrl = point.iconUrl.trim();
        final resizedUrl = resizeGenesisImageUrl(
          rawUrl,
          logicalWidth: logicalWidth,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        return GenesisListImage(
          imageUrl: resizedUrl.isNotEmpty ? resizedUrl : rawUrl,
          width: logicalWidth,
          height: logicalHeight,
          placeholderAsset: _locationDefaultImageAsset,
        );
      },
    );
  }
}
