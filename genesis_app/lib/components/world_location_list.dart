import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/custom_icon_assets.dart';
import '../icons/my_flutter_app_icons.dart';
import '../ui/components/genesis_list_image.dart';
import 'world_details_shell.dart';
import 'world_point.dart';

class WorldLocationList extends StatefulWidget {
  const WorldLocationList({super.key, required this.points, this.onPointTap});

  final List<WorldPoint> points;
  final ValueChanged<WorldPoint>? onPointTap;

  @override
  State<WorldLocationList> createState() => _WorldLocationListState();
}

class _WorldLocationListState extends State<WorldLocationList> {
  final ScrollController _listController = ScrollController();
  ScrollController? _outerController;
  bool _outerPageAtTop = true;
  bool _pointerActive = false;
  bool _needsPhysicsRebuild = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setOuterController(
      WorldDetailsPanelScrollControllerScope.maybeOf(context),
    );
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
    return Listener(
      onPointerDown: (_) => _pointerActive = true,
      onPointerUp: (_) {
        _finishPointer();
      },
      onPointerCancel: (_) {
        _finishPointer();
      },
      onPointerMove: (event) {
        if (outerController == null || !outerController.hasClients) {
          return;
        }

        final dragDelta = event.delta.dy;
        if (!_outerPageAtTop) {
          _applyOuterDrag(outerController, dragDelta);
          return;
        }

        if (!_listController.hasClients) return;
        final position = _listController.position;
        const handoffEdgeExtent = 72.0;
        final atBottom = position.extentAfter <= 0.5;
        final atTop = position.extentBefore <= 0.5;
        if (dragDelta < 0 &&
            position.extentAfter < handoffEdgeExtent &&
            position.extentBefore > 0) {
          final progress =
              1 - (position.extentAfter / handoffEdgeExtent).clamp(0.0, 1.0);
          _applyOuterDrag(outerController, dragDelta * progress);
        } else if ((dragDelta < 0 && atBottom) || (dragDelta > 0 && atTop)) {
          _applyOuterDrag(outerController, dragDelta);
        }
      },
      child: NotificationListener<OverscrollNotification>(
        onNotification: (notification) {
          if (outerController == null ||
              !outerController.hasClients ||
              notification.metrics.axis != Axis.vertical) {
            return false;
          }
          if (!_outerPageAtTop) return false;

          final dragDelta = notification.dragDetails?.delta.dy;
          if (dragDelta != null) {
            return _applyOuterDrag(outerController, dragDelta);
          }
          return _applyOuterDrag(outerController, -notification.overscroll);
        },
        child: ListView.separated(
          controller: _listController,
          physics: _outerPageAtTop
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: widget.points.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _PointListItem(
              point: widget.points[index],
              onTap: widget.onPointTap,
            );
          },
        ),
      ),
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
    _syncOuterPageAtTopState(rebuild: true);
    if (_needsPhysicsRebuild && mounted) {
      _needsPhysicsRebuild = false;
      setState(() {});
    }
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
}

class _PointListItem extends StatelessWidget {
  const _PointListItem({required this.point, required this.onTap});

  final WorldPoint point;
  final ValueChanged<WorldPoint>? onTap;

  @override
  Widget build(BuildContext context) {
    final depthIndent = math.max(0, point.depth) * 15.0;
    final description = point.locationDescription.trim();
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(point),
      child: Padding(
        padding: EdgeInsets.only(left: depthIndent, top: 10, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PointListCover(point: point),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: Colors.black),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          point.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (point.users.isNotEmpty)
                    _PointCharacterGroups(users: point.users),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
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

class _PointCharacterGroups extends StatelessWidget {
  const _PointCharacterGroups({required this.users});

  final List<UserAvatar> users;

  @override
  Widget build(BuildContext context) {
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
            iconAsset: aiCharacterIconAsset,
            names: aiNames,
          ),
        if (aiNames.isNotEmpty && nonAiNames.isNotEmpty)
          const SizedBox(height: 2),
        if (nonAiNames.isNotEmpty)
          _PointCharacterGroupRow(icon: MyFlutterApp.user, names: nonAiNames),
      ],
    );
  }

  String _characterName(UserAvatar user) {
    return (user.name ?? user.initials).trim();
  }
}

class _PointCharacterGroupRow extends StatelessWidget {
  const _PointCharacterGroupRow({
    this.icon,
    this.iconAsset,
    required this.names,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iconAsset == null)
          Icon(icon, size: 12, color: Colors.black)
        else
          Transform.translate(
            offset: const Offset(0, -0.8),
            child: Image.asset(
              iconAsset!,
              width: 14,
              height: 15,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            names.join(', '),
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Colors.black,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: const Icon(Icons.schedule, size: 12, color: Colors.black),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PointListCover extends StatelessWidget {
  const _PointListCover({required this.point});

  final WorldPoint point;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: GenesisListImage(imageUrl: point.iconUrl),
    );
  }
}
