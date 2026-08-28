import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    this.iconColorMapper,
    this.crossAxisAlignment = CrossAxisAlignment.center,
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
  final ColorMapper? iconColorMapper;
  final CrossAxisAlignment crossAxisAlignment;
  final String text;
  final double iconSize;
  final Color? iconColor;
  final double gap;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.black.withValues(alpha: 0.75);
    final asset = iconAsset;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (asset case final asset?)
          preserveIconAssetColor
              ? _StatAssetIcon(
                  asset: asset,
                  size: iconSize,
                  color: null,
                  colorMapper: iconColorMapper,
                )
              : _StatAssetIcon(
                  asset: asset,
                  size: iconSize,
                  color: color,
                  colorMapper: iconColorMapper,
                )
        else
          Icon(icon, size: iconSize, color: color),
        SizedBox(width: gap),
        Text(text, style: textStyle),
      ],
    );
  }
}

class _StatAssetIcon extends StatelessWidget {
  const _StatAssetIcon({
    required this.asset,
    required this.size,
    required this.color,
    required this.colorMapper,
  });

  final String asset;
  final double size;
  final Color? color;
  final ColorMapper? colorMapper;

  @override
  Widget build(BuildContext context) {
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorMapper: colorMapper,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
        excludeFromSemantics: true,
      );
    }

    if (color == null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }

    return ImageIcon(AssetImage(asset), size: size, color: color);
  }
}
