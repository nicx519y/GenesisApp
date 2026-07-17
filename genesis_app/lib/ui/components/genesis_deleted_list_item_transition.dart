import 'package:flutter/material.dart';

class GenesisDeletedListItemTransition extends StatelessWidget {
  const GenesisDeletedListItemTransition({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  static double heightFactorForProgress(double progress) {
    final collapseProgress = _intervalProgress(progress, 0.15, 1);
    return 1 - Curves.easeInOutCubic.transform(collapseProgress);
  }

  static double opacityForProgress(double progress) {
    final fadeProgress = _intervalProgress(progress, 0.3, 0.75);
    return 1 - Curves.easeInCubic.transform(fadeProgress);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    return ClipRect(
      child: Align(
        heightFactor: heightFactorForProgress(normalizedProgress),
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: opacityForProgress(normalizedProgress),
          child: child,
        ),
      ),
    );
  }
}

double _intervalProgress(double progress, double start, double end) {
  if (end <= start) return progress >= end ? 1 : 0;
  return ((progress - start) / (end - start)).clamp(0.0, 1.0).toDouble();
}
