import 'package:flutter/material.dart';

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
  });

  static const double _height = 42;
  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const TextStyle _textStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: disabledBackgroundColor,
          disabledForegroundColor: disabledForegroundColor,
          textStyle: _textStyle,
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: GenesisSpacing.page),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
