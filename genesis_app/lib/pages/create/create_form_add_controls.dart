part of 'create_form_library.dart';

class CreateAddButton extends StatelessWidget {
  const CreateAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 58,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: CustomPaint(
          painter: CreateDashedRRectPainter(
            color: context.genesisCreateColors.dash,
            radius: 8,
            strokeWidth: 1.2,
          ),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: context.genesisCreateColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateInlineAddButton extends StatelessWidget {
  const CreateInlineAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.supportingText,
    this.fontSize = 14,
    this.centered = false,
    this.verticalPadding = 8,
    this.contentPadding,
  });

  final String label;
  final VoidCallback onTap;
  final String? supportingText;
  final double fontSize;
  final bool centered;
  final double verticalPadding;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final supporting = supportingText?.trim() ?? '';
    final labelText = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (supporting.isNotEmpty)
            TextSpan(
              text: ' $supporting',
              style: TextStyle(
                color: context.genesisCreateColors.hint,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      style: TextStyle(
        color: context.genesisCreateColors.accent,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding:
            contentPadding ?? EdgeInsets.symmetric(vertical: verticalPadding),
        child: centered
            ? Align(alignment: Alignment.center, child: labelText)
            : labelText,
      ),
    );
  }
}

class CreateDashedRRectPainter extends CustomPainter {
  CreateDashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dashWidth = 8,
    this.dashSpace = 7,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      // 让 dash+gap 恰好整除路径长度,首尾衔接、圆角处不被间隙截断,
      // 不同尺寸的虚线框圆角观感才一致。
      var unitCount = (metric.length / (dashWidth + dashSpace)).round();
      if (unitCount < 1) unitCount = 1;
      final unit = metric.length / unitCount;
      final dash = unit * (dashWidth / (dashWidth + dashSpace));
      for (var i = 0; i < unitCount; i++) {
        final start = i * unit;
        canvas.drawPath(metric.extractPath(start, start + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CreateDashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}
