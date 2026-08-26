import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../ui/components/genesis_skeleton.dart';

enum _GenesisListSkeletonType { world, originGrid }

class GenesisListLoadingSkeleton extends StatelessWidget {
  const GenesisListLoadingSkeleton.worldList({super.key, this.itemCount = 4})
    : _type = _GenesisListSkeletonType.world;

  const GenesisListLoadingSkeleton.originGrid({super.key, this.itemCount = 8})
    : _type = _GenesisListSkeletonType.originGrid;

  final int itemCount;
  final _GenesisListSkeletonType _type;

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: switch (_type) {
        _GenesisListSkeletonType.world => _WorldListSkeleton(
          itemCount: itemCount,
        ),
        _GenesisListSkeletonType.originGrid => _OriginGridSkeleton(
          itemCount: itemCount,
        ),
      },
    );
  }
}

class _WorldListSkeleton extends StatelessWidget {
  const _WorldListSkeleton({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey<String>('genesis-world-list-skeleton'),
      primary: false,
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: _WorldSkeletonItem(),
        );
      },
    );
  }
}

class _WorldSkeletonItem extends StatelessWidget {
  const _WorldSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBone(
          key: ValueKey<String>('genesis-world-list-thumbnail-skeleton'),
          width: 60,
          height: 78,
          borderRadius: 8,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBone(widthFactor: 0.42, height: 14, borderRadius: 4),
              SizedBox(height: 7),
              _SkeletonBone(widthFactor: 0.5, height: 11, borderRadius: 4),
              SizedBox(height: 7),
              _SkeletonBone(widthFactor: 0.96, height: 11, borderRadius: 4),
              SizedBox(height: 5),
              _SkeletonBone(widthFactor: 0.7, height: 11, borderRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginGridSkeleton extends StatelessWidget {
  const _OriginGridSkeleton({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.builder(
      key: const ValueKey<String>('genesis-origin-grid-skeleton'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      itemCount: itemCount,
      itemBuilder: (context, index) => const _OriginGridSkeletonItem(),
    );
  }
}

class _OriginGridSkeletonItem extends StatelessWidget {
  const _OriginGridSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 2 / 3,
          child: _SkeletonBone(
            key: ValueKey<String>('genesis-origin-grid-cover-skeleton'),
            borderRadius: 11,
          ),
        ),
        const SizedBox(height: 5),
        const _SkeletonBone(widthFactor: 0.72, height: 14, borderRadius: 4),
        const SizedBox(height: 5),
        const _SkeletonBone(widthFactor: 0.96, height: 10, borderRadius: 4),
        const SizedBox(height: 5),
        const _SkeletonBone(widthFactor: 0.66, height: 10, borderRadius: 4),
        const SizedBox(height: 5),
        const _SkeletonLineRow(widths: [52, 58], height: 20, borderRadius: 6),
      ],
    );
  }
}

class _SkeletonLineRow extends StatelessWidget {
  const _SkeletonLineRow({
    required this.widths,
    required this.height,
    this.borderRadius = 4,
  });

  final List<double> widths;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in widths.indexed) ...[
          _SkeletonBone(
            width: entry.$2,
            height: height,
            borderRadius: borderRadius,
          ),
          if (entry.$1 != widths.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

typedef _SkeletonShimmer = GenesisShimmer;
typedef _SkeletonBone = GenesisSkeletonBone;
