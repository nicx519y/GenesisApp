import 'package:flutter/material.dart';

/// Non-blocking submission feedback, not a signal of generation completion.
class CameraCaptureFlight extends StatelessWidget {
  const CameraCaptureFlight({
    super.key,
    required this.from,
    required this.to,
    required this.onEnd,
  });
  final Rect from, to;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 650),
    onEnd: onEnd,
    builder: (_, value, _) {
      final progress = Curves.easeInOutCubic.transform(value);
      final rect = Rect.lerp(from, to, progress)!;
      return Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: Opacity(
            opacity: value > .85 ? (1 - value) / .15 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
