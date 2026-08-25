import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_typography.dart';

/// A compact muted action used inside image cards and immersive surfaces.
class GenesisCardActionButton extends StatelessWidget {
  const GenesisCardActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.surfaceKey,
    this.interactionKey,
    this.height = 34,
    this.borderRadius = 11,
    this.fontSize = 11,
    this.lineHeight = 1,
    this.backdropBlurSigma = 0,
  }) : icon = null,
       tooltip = null;

  const GenesisCardActionButton.icon({
    super.key,
    required IconData this.icon,
    required String this.tooltip,
    required this.onPressed,
    this.surfaceKey,
    this.interactionKey,
    this.height = 34,
    this.borderRadius = 11,
    this.backdropBlurSigma = 0,
  }) : label = null,
       fontSize = 11,
       lineHeight = 1;

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Key? surfaceKey;
  final Key? interactionKey;
  final double height;
  final double borderRadius;
  final double fontSize;
  final double lineHeight;

  /// >0 时按钮底做毛玻璃(背景 backdrop 模糊),用于叠在图像上的场景,
  /// 如角色卡的 Select(设计稿 9i:blur 10)。
  final double backdropBlurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final enabled = onPressed != null;
    final foreground = enabled ? colors.textPrimary : colors.textMuted;
    final iconData = icon;
    final content = iconData == null
        ? Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GenesisTypography.supporting.copyWith(
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: FontWeight.w800,
              color: foreground,
              decoration: TextDecoration.none,
            ),
          )
        : Icon(iconData, size: 15, color: foreground);

    Widget surface = Material(
      key: surfaceKey,
      color: colors.foregroundStrong.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: interactionKey,
        onTap: onPressed,
        child: Center(child: content),
      ),
    );
    if (backdropBlurSigma > 0) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: backdropBlurSigma,
            sigmaY: backdropBlurSigma,
          ),
          child: surface,
        ),
      );
    }
    Widget result = Semantics(
      button: true,
      enabled: enabled,
      label: label ?? tooltip,
      child: SizedBox(
        width: iconData == null ? null : height,
        height: height,
        child: surface,
      ),
    );
    if (tooltip case final tooltip?) {
      result = Tooltip(message: tooltip, child: result);
    }
    return result;
  }
}
