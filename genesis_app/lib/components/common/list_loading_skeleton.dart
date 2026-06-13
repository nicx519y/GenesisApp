import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
      separatorBuilder: (context, index) =>
          const Divider(height: 25, thickness: 1, color: Color(0xFFEFEFEF)),
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
              borderRadius: 8,
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
      separatorBuilder: (context, index) =>
          const Divider(height: 25, thickness: 1, color: Color(0xFFEFEFEF)),
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
              borderRadius: 8,
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
          borderRadius: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 10,
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
            borderRadius: 14,
          ),
        ),
        const SizedBox(height: 8),
        const _SkeletonBone(widthFactor: 0.72, height: 12, borderRadius: 4),
        const SizedBox(height: 6),
        const _SkeletonBone(widthFactor: 0.96, height: 9, borderRadius: 4),
        const SizedBox(height: 6),
        const _SkeletonBone(widthFactor: 0.66, height: 9, borderRadius: 4),
        const SizedBox(height: 8),
        const _SkeletonLineRow(widths: [40, 54], height: 17, borderRadius: 2),
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

class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer({required this.child});

  final Widget child;

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonAnimation(animation: _controller, child: widget.child);
  }
}

class _SkeletonAnimation extends InheritedWidget {
  const _SkeletonAnimation({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonAnimation>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(covariant _SkeletonAnimation oldWidget) {
    return animation != oldWidget.animation;
  }
}

class _SkeletonBone extends StatelessWidget {
  const _SkeletonBone({
    super.key,
    this.width,
    this.widthFactor,
    this.height,
    this.borderRadius = 4,
  }) : assert(width == null || widthFactor == null);

  final double? width;
  final double? widthFactor;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _SkeletonAnimation.maybeOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    Widget child = SizedBox(
      width: width,
      height: height,
      child: animation == null || disableAnimations
          ? _buildDecoratedBox(0)
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) => _buildDecoratedBox(animation.value),
            ),
    );

    if (widthFactor case final factor?) {
      child = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: child,
      );
    }
    return child;
  }

  Widget _buildDecoratedBox(double animationValue) {
    final offset = -1.4 + (animationValue * 2.8);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.8, 0),
          end: Alignment(offset + 0.8, 0),
          colors: const [
            Color(0xFFE8EBF0),
            Color(0xFFF6F7F9),
            Color(0xFFE8EBF0),
          ],
          stops: const [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}
