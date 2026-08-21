import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';

class GenesisBackButton extends StatelessWidget {
  const GenesisBackButton({
    super.key,
    required this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.dimension = GenesisControlMetrics.backButtonVisualSize,
    this.iconSize = GenesisControlMetrics.backIconSize,
    this.tapTargetSize = GenesisControlMetrics.minimumTapTarget,
    this.borderRadius = 11,
    this.blurSigma = 10,
    this.tooltip = 'Back',
  });

  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double dimension;
  final double iconSize;
  final double tapTargetSize;
  final double borderRadius;
  final double blurSigma;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final hitScale = tapTargetSize / dimension;
    return Transform.scale(
      scale: hitScale,
      transformHitTests: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Transform.scale(
            scale: 1 / hitScale,
            transformHitTests: false,
            child: Tooltip(
              message: tooltip,
              child: SizedBox.square(
                dimension: dimension,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: Material(
                      color: backgroundColor ?? colors.controlMuted,
                      child: Center(
                        child: GenesisBackIcon(
                          size: iconSize,
                          color: foregroundColor ?? colors.foregroundStrong,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GenesisBackIcon extends StatelessWidget {
  const GenesisBackIcon({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      controlBackIconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

class GenesisChevronRightIcon extends StatelessWidget {
  const GenesisChevronRightIcon({
    super.key,
    required this.color,
    this.size = GenesisControlMetrics.appBarActionIconSize,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 2,
      child: SvgPicture.asset(
        controlBackIconAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}

class GenesisMoreIcon extends StatelessWidget {
  const GenesisMoreIcon({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      controlMoreIconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

class GenesisCloseIcon extends StatelessWidget {
  const GenesisCloseIcon({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      controlCloseIconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

class GenesisChevronDownIcon extends StatelessWidget {
  const GenesisChevronDownIcon({
    super.key,
    required this.color,
    this.width = 16,
    this.pointUp = false,
  });

  final Color color;
  final double width;
  final bool pointUp;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      controlChevronDownIconAsset,
      width: width,
      height: width * 9 / 16,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    return pointUp ? RotatedBox(quarterTurns: 2, child: icon) : icon;
  }
}
