import 'package:flutter/material.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 14,
    this.iconColor,
    this.gap = 4,
    this.textStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    ),
  });

  final IconData icon;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final double gap;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor ?? Colors.black.withValues(alpha: 0.75),
        ),
        SizedBox(width: gap),
        Text(
          text,
          style: textStyle,
        ),
      ],
    );
  }
}
