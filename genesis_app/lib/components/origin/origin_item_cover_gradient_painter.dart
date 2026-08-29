import 'dart:math' as math;

import 'package:flutter/material.dart';

const LinearGradient originItemCoverGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0x00111111), Color(0xFF111111)],
);

/// Paints the cover readability gradient directly over the decoded image.
///
/// This keeps the image and gradient in the same paint pass without creating
/// a second, offscreen-composited bitmap for every list item.
@immutable
class OriginItemCoverGradientPainter extends CustomPainter {
  const OriginItemCoverGradientPainter({required this.transitionHeight});

  final double transitionHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final resolvedHeight = math
        .min(math.max(0, transitionHeight), size.height)
        .toDouble();
    if (resolvedHeight <= 0) return;
    final transitionRect = Rect.fromLTWH(
      0,
      size.height - resolvedHeight,
      size.width,
      resolvedHeight,
    );
    canvas.drawRect(
      transitionRect,
      Paint()..shader = originItemCoverGradient.createShader(transitionRect),
    );
  }

  @override
  bool shouldRepaint(covariant OriginItemCoverGradientPainter oldDelegate) {
    return oldDelegate.transitionHeight != transitionHeight;
  }
}
