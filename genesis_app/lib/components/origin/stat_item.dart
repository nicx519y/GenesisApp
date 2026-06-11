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
    this.iconAssetScale = 1.25,
    this.iconVerticalOffset = -0.8,
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
  final double iconAssetScale;
  final double iconVerticalOffset;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.black.withValues(alpha: 0.75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (iconAsset case final asset?)
          preserveIconAssetColor
              ? Transform.translate(
                  offset: Offset(0, iconVerticalOffset),
                  child: Image.asset(
                    asset,
                    width: iconSize * iconAssetScale,
                    height: iconSize * iconAssetScale,
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
