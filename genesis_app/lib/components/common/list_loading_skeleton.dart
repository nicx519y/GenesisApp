import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

enum _GenesisListSkeletonType { world, popularOrigin, originGrid }

class GenesisListLoadingSkeleton extends StatelessWidget {
  const GenesisListLoadingSkeleton.worldList({super.key, this.itemCount = 4})
    : _type = _GenesisListSkeletonType.world;

  const GenesisListLoadingSkeleton.popularOriginList({
    super.key,
    this.itemCount = 3,
  }) : _type = _GenesisListSkeletonType.popularOrigin;

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
        _GenesisListSkeletonType.popularOrigin => _PopularOriginListSkeleton(
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
      separatorBuilder: (context, index) => Divider(
        height: 25,
        thickness: 1,
        color: context.genesisColors.dividerMuted,
      ),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBone(
              key: ValueKey<String>('genesis-world-list-thumbnail-skeleton'),
              width: 60,
              height: 60,
              borderRadius: GenesisImageRadii.contentValue,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBone(widthFactor: 0.44, height: 14, borderRadius: 4),
                  SizedBox(height: 7),
                  _SkeletonLineRow(widths: [74, 86], height: 12),
                  SizedBox(height: 10),
                  _SkeletonLineRow(widths: [34, 42, 36, 38], height: 12),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _SkeletonProgressHeader(titleWidth: 104, trailingWidth: 58),
        SizedBox(height: 10),
        _SkeletonBone(widthFactor: 0.96, height: 10, borderRadius: 4),
        SizedBox(height: 7),
        _SkeletonBone(widthFactor: 0.9, height: 10, borderRadius: 4),
        SizedBox(height: 7),
        _SkeletonBone(widthFactor: 0.72, height: 10, borderRadius: 4),
      ],
    );
  }
}

class _PopularOriginListSkeleton extends StatelessWidget {
  const _PopularOriginListSkeleton({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey<String>('genesis-popular-origin-list-skeleton'),
      primary: false,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, index) => Divider(
        height: 25,
        thickness: 1,
        color: context.genesisColors.dividerMuted,
      ),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _PopularOriginSkeletonItem(),
        );
      },
    );
  }
}

class _PopularOriginSkeletonItem extends StatelessWidget {
  const _PopularOriginSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBone(
              key: ValueKey<String>(
                'genesis-popular-origin-list-thumbnail-skeleton',
              ),
              width: 60,
              height: 60,
              borderRadius: GenesisImageRadii.contentValue,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBone(widthFactor: 0.52, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  _SkeletonLineRow(widths: [74, 116], height: 12),
                  SizedBox(height: 10),
                  _SkeletonLineRow(widths: [42, 46, 40], height: 12),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _SkeletonBone(widthFactor: 0.94, height: 10, borderRadius: 4),
        SizedBox(height: 7),
        _SkeletonBone(widthFactor: 0.78, height: 10, borderRadius: 4),
        SizedBox(height: 7),
        _SkeletonBone(widthFactor: 0.54, height: 10, borderRadius: 4),
        SizedBox(height: 14),
        _SkeletonBone(
          key: ValueKey<String>('genesis-popular-origin-hero-skeleton'),
          width: 107,
          height: 160.5,
          borderRadius: GenesisImageRadii.contentValue,
        ),
        SizedBox(height: 16),
        _SkeletonProgressHeader(titleWidth: 144),
        SizedBox(height: 12),
        _SkeletonBone(widthFactor: 0.88, height: 10, borderRadius: 4),
        SizedBox(height: 7),
        _SkeletonBone(widthFactor: 0.76, height: 10, borderRadius: 4),
        SizedBox(height: 12),
        _SkeletonMetaRow(),
        SizedBox(height: 12),
        _SkeletonBone(widthFactor: 0.5, height: 12, borderRadius: 4),
        SizedBox(height: 14),
        _SkeletonEnterRow(),
      ],
    );
  }
}

class _SkeletonProgressHeader extends StatelessWidget {
  const _SkeletonProgressHeader({required this.titleWidth, this.trailingWidth});

  final double titleWidth;
  final double? trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SkeletonBone(width: 14, height: 14, borderRadius: 7),
        const SizedBox(width: 5),
        _SkeletonBone(width: titleWidth, height: 14, borderRadius: 4),
        if (trailingWidth case final width?) ...[
          const Spacer(),
          _SkeletonBone(width: width, height: 12, borderRadius: 4),
        ],
      ],
    );
  }
}

class _SkeletonMetaRow extends StatelessWidget {
  const _SkeletonMetaRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _SkeletonLineRow(widths: [82, 28], height: 12)),
        _SkeletonBone(width: 56, height: 12, borderRadius: 4),
      ],
    );
  }
}

class _SkeletonEnterRow extends StatelessWidget {
  const _SkeletonEnterRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _SkeletonBone(height: 14, borderRadius: 4)),
        SizedBox(width: 12),
        _SkeletonBone(width: 38, height: 14, borderRadius: 4),
        SizedBox(width: 4),
        _SkeletonBone(width: 20, height: 20, borderRadius: 10),
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
