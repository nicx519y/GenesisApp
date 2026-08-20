import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_typography.dart';

class GenesisFieldLabel extends StatelessWidget {
  const GenesisFieldLabel({
    super.key,
    required this.text,
    this.requiredIndicator = false,
    this.style,
    this.requiredColor,
  });

  final String text;
  final bool requiredIndicator;
  final TextStyle? style;
  final Color? requiredColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (requiredIndicator)
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: requiredColor ?? context.genesisColors.danger,
              ),
            ),
        ],
      ),
      style:
          style ??
          GenesisTypography.label.copyWith(
            color: context.genesisColors.textPrimary,
          ),
    );
  }
}

class GenesisFieldSupportText extends StatelessWidget {
  const GenesisFieldSupportText({
    super.key,
    required this.text,
    this.leading,
    this.style,
    this.gap = 7,
  });

  final String text;
  final Widget? leading;
  final TextStyle? style;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: gap)],
        Expanded(
          child: Text(
            text,
            style:
                style ??
                GenesisTypography.supporting.copyWith(
                  color: context.genesisColors.textSupporting,
                ),
          ),
        ),
      ],
    );
  }
}

class GenesisFieldSurface extends StatelessWidget {
  const GenesisFieldSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = GenesisRadii.input,
    this.backgroundColor,
    this.borderColor,
    this.showBorder = true,
    this.constraints,
    this.alignment,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showBorder;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: constraints,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.genesisColors.inputBackground,
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: borderColor ?? context.genesisColors.inputBorder,
              )
            : null,
      ),
      child: child,
    );
  }
}
