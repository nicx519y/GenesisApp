import 'package:flutter/material.dart';

class GenesisFixedUnderlineIndicator extends Decoration {
  const GenesisFixedUnderlineIndicator({
    required this.color,
    required this.width,
    this.height = 3,
    this.radius = 2,
    this.bottomPadding = 0,
  });

  final Color color;
  final double width;
  final double height;
  final double radius;
  final double bottomPadding;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GenesisFixedUnderlinePainter(
      color: color,
      width: width,
      height: height,
      radius: radius,
      bottomPadding: bottomPadding,
    );
  }
}

class _GenesisFixedUnderlinePainter extends BoxPainter {
  _GenesisFixedUnderlinePainter({
    required this.color,
    required this.width,
    required this.height,
    required this.radius,
    required this.bottomPadding,
  });

  final Color color;
  final double width;
  final double height;
  final double radius;
  final double bottomPadding;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final left = offset.dx + (size.width - width) / 2;
    final top = offset.dy + size.height - height - bottomPadding;
    final rect = Rect.fromLTWH(left, top, width, height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);
  }
}
