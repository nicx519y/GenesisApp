import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';

class GenesisShimmer extends StatefulWidget {
  const GenesisShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Duration duration;

  @override
  State<GenesisShimmer> createState() => _GenesisShimmerState();
}

class _GenesisShimmerState extends State<GenesisShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GenesisSkeletonAnimation(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _GenesisSkeletonAnimation extends InheritedWidget {
  const _GenesisSkeletonAnimation({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GenesisSkeletonAnimation>()
      ?.animation;

  @override
  bool updateShouldNotify(covariant _GenesisSkeletonAnimation oldWidget) =>
      animation != oldWidget.animation;
}

class GenesisSkeletonBone extends StatelessWidget {
  const GenesisSkeletonBone({
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
    final animation = _GenesisSkeletonAnimation.maybeOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    Widget result = SizedBox(
      width: width,
      height: height,
      child: animation == null || disableAnimations
          ? _bone(context, 0)
          : AnimatedBuilder(
              animation: animation,
              builder: (context, _) => _bone(context, animation.value),
            ),
    );
    if (widthFactor case final factor?) {
      result = FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: result,
      );
    }
    return result;
  }

  Widget _bone(BuildContext context, double value) {
    final offset = -1.4 + (value * 2.8);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(offset - 0.8, 0),
          end: Alignment(offset + 0.8, 0),
          colors: [
            context.genesisColors.skeletonBase,
            context.genesisColors.skeletonHighlight,
            context.genesisColors.skeletonBase,
          ],
          stops: const [0.25, 0.5, 0.75],
        ),
      ),
    );
  }
}
