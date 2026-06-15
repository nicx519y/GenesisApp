import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

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
    final asset = iconAsset;
    final isCharacterAsset = _isCharacterAsset(asset);
    final visualSize = isCharacterAsset
        ? customCharacterIconRenderSize(iconSize)
        : asset == null
        ? iconSize
        : customIconAssetRenderSize(asset, iconSize);
    final verticalOffset = isCharacterAsset
        ? customCharacterIconVerticalOffset(iconSize)
        : iconVerticalOffset;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (asset case final asset?)
          preserveIconAssetColor
              ? Transform.translate(
                  offset: Offset(0, verticalOffset),
                  child: _StatAssetIcon(
                    asset: asset,
                    size: visualSize,
                    color: null,
                  ),
                )
              : _StatAssetIcon(asset: asset, size: visualSize, color: color)
        else
          Icon(icon, size: iconSize, color: color),
        SizedBox(width: gap),
        Text(text, style: textStyle),
      ],
    );
  }
}

bool _isCharacterAsset(String? asset) {
  return asset == characterStatIconAsset;
}

class _StatAssetIcon extends StatelessWidget {
  const _StatAssetIcon({
    required this.asset,
    required this.size,
    required this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
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
