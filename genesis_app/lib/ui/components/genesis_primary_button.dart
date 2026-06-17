import 'package:flutter/material.dart';

import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';

class GenesisPrimaryButton extends StatelessWidget {
  const GenesisPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.side,
    this.height,
    this.width,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(horizontal: GenesisSpacing.page),
    this.fontWeight,
    this.fontSize,
    this.borderRadius,
    this.minimumSize,
    this.tapTargetSize,
    this.isLoading = false,
    this.loadingSize = 18,
    this.loadingStrokeWidth = 2,
  });

  static const double defaultHeight = 42;
  static const BorderRadius defaultBorderRadius = GenesisRadii.button;
  static const TextStyle defaultTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final BorderSide? side;
  final double? height;
  final double? width;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;
  final FontWeight? fontWeight;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final Size? minimumSize;
  final MaterialTapTargetSize? tapTargetSize;
  final bool isLoading;
  final double loadingSize;
  final double loadingStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? defaultHeight,
      width: width ?? (fullWidth ? double.infinity : null),
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: disabledBackgroundColor,
          disabledForegroundColor: disabledForegroundColor,
          side: side,
          textStyle: defaultTextStyle.copyWith(
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? defaultBorderRadius,
          ),
          padding: padding,
          minimumSize: minimumSize,
          tapTargetSize: tapTargetSize,
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: loadingSize,
                child: CircularProgressIndicator(
                  strokeWidth: loadingStrokeWidth,
                  color: foregroundColor,
                ),
              )
            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class GenesisSecondaryButton extends StatelessWidget {
  const GenesisSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foregroundColor = const Color(0xFF111111),
    this.disabledForegroundColor,
    this.side = const BorderSide(color: Color(0xFFD9D9DF), width: 1.2),
    this.height,
    this.width,
    this.fontWeight,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? disabledForegroundColor;
  final BorderSide? side;
  final double? height;
  final double? width;
  final FontWeight? fontWeight;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? GenesisPrimaryButton.defaultHeight,
      width: width ?? double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          disabledForegroundColor: disabledForegroundColor,
          side: side,
          textStyle: GenesisPrimaryButton.defaultTextStyle.copyWith(
            fontWeight: fontWeight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                borderRadius ?? GenesisPrimaryButton.defaultBorderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: GenesisSpacing.page),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
