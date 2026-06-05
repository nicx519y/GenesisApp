import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/custom_icon_assets.dart';
import '../icons/my_flutter_app_icons.dart';
import '../ui/components/genesis_list_image.dart';
import 'world_point.dart';

class WorldLocationList extends StatelessWidget {
  const WorldLocationList({super.key, required this.points, this.onPointTap});

  final List<WorldPoint> points;
  final ValueChanged<WorldPoint>? onPointTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
      itemCount: points.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _PointListItem(point: points[index], onTap: onPointTap);
      },
    );
  }
}

class _PointListItem extends StatelessWidget {
  const _PointListItem({required this.point, required this.onTap});

  final WorldPoint point;
  final ValueChanged<WorldPoint>? onTap;

  @override
  Widget build(BuildContext context) {
    final depthIndent = math.max(0, point.depth) * 15.0;
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
                  const SizedBox(height: 4),
                  _PointSummaryRow(description: point.locationDescription),
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
