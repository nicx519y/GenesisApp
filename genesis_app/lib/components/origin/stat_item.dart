import 'package:flutter/material.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.text,
    this.iconSize = 14,
    this.iconColor,
    this.gap = 4,
    this.textStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    ),
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final double gap;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.black.withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconAsset case final asset?)
          preserveIconAssetColor
              ? Transform.translate(
                  offset: const Offset(0, -0.8),
                  child: Image.asset(
                    asset,
                    width: iconSize * 1.25,
                    height: iconSize * 1.25,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                )
              : ImageIcon(AssetImage(asset), size: iconSize, color: color)
        else
          Icon(icon, size: iconSize, color: color),
        SizedBox(width: gap),
        Text(text, style: textStyle),
      ],
    );
  }
}
