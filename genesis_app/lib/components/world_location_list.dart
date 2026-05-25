import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'world_point.dart';

class WorldLocationList extends StatelessWidget {
  const WorldLocationList({super.key, required this.points, this.onPointTap});

  final List<WorldPoint> points;
  final ValueChanged<WorldPoint>? onPointTap;

  @override
  Widget build(BuildContext context) {
    final rootIndex = points.indexWhere((point) => point.depth <= 0);
    final rootPoint = rootIndex < 0 ? null : points[rootIndex];
    final listPoints = rootPoint == null
        ? points
        : [
            for (var i = 0; i < points.length; i++)
              if (i != rootIndex) points[i],
          ];
    final listRowCount = listPoints.length + (rootPoint == null ? 0 : 1);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: listRowCount,
      separatorBuilder: (context, index) {
        if (rootPoint != null && index == 0) return const SizedBox.shrink();
        return const Divider(height: 1);
      },
      itemBuilder: (context, index) {
        if (rootPoint != null && index == 0) {
          return _PointListRootHeader(point: rootPoint);
        }
        final pointIndex = rootPoint == null ? index : index - 1;
        return _PointListItem(point: listPoints[pointIndex], onTap: onPointTap);
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
                      const SizedBox(width: 4),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (final u in point.users.take(2))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person,
                                size: 12,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                u.name ?? u.initials,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    point.description.isEmpty
                        ? 'Explore this location and its stories.'
                        : point.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointListRootHeader extends StatelessWidget {
  const _PointListRootHeader({required this.point});

  final WorldPoint point;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            "- ${point.name}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _PointListCover extends StatelessWidget {
  const _PointListCover({required this.point});

  final WorldPoint point;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFF3F4F6),
      child: Center(child: _LocationPointLabel(point: point)),
    );
    final url = point.iconUrl.trim();
    return SizedBox(
      width: 64,
      height: 64,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
        child: url.isEmpty
            ? Center(child: _LocationPointLabel(point: point))
            : _PointCoverImage(url: url, fallback: fallback),
      ),
    );
  }
}

class _PointCoverImage extends StatelessWidget {
  const _PointCoverImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return fallback;
      },
    );
  }
}

class _LocationPointLabel extends StatelessWidget {
  const _LocationPointLabel({required this.point});

  final WorldPoint point;

  @override
  Widget build(BuildContext context) {
    return Text(
      point.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    );
  }
}
