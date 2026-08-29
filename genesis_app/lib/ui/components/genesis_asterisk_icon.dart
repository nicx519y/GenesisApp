import 'package:flutter/material.dart';

class GenesisAsteriskIcon extends StatelessWidget {
  const GenesisAsteriskIcon({super.key, required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GenesisAsteriskPainter(color: color),
    );
  }
}

class _GenesisAsteriskPainter extends CustomPainter {
  const _GenesisAsteriskPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.13 * scale
      ..strokeCap = StrokeCap.round;

    Offset point(double x, double y) => Offset(x * scale, y * scale);
    canvas
      ..drawLine(point(8, 2.9), point(8, 13.1), paint)
      ..drawLine(point(3.6, 5.4), point(12.4, 10.6), paint)
      ..drawLine(point(3.6, 10.6), point(12.4, 5.4), paint);
  }

  @override
  bool shouldRepaint(covariant _GenesisAsteriskPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
