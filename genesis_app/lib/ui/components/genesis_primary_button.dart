import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../theme/genesis_ui_theme.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_ui_interaction.dart';

enum GenesisButtonVariant { primary, secondary, muted, destructive }

enum GenesisButtonSize { compact, regular }

class GenesisButton extends StatelessWidget {
  const GenesisButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GenesisButtonVariant.primary,
    this.size = GenesisButtonSize.regular,
    this.onDisabledPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.side,
    this.height,
    this.width,
    this.fullWidth = true,
    this.padding,
    this.fontWeight,
    this.fontSize,
    this.borderRadius,
    this.minimumSize,
    this.tapTargetSize,
    this.isLoading = false,
    this.loadingSize = 18,
    this.loadingStrokeWidth = 2,
    this.leadingIcon,
    this.iconGap = 8,
    this.telemetryComponent = 'GenesisButton',
  });

  static const double regularHeight = 42;
  static const double compactHeight = 40;
  static const BorderRadius defaultBorderRadius = GenesisRadii.button;

  final String label;
  final VoidCallback? onPressed;
  final GenesisButtonVariant variant;
  final GenesisButtonSize size;
  final VoidCallback? onDisabledPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final BorderSide? side;
  final double? height;
  final double? width;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final FontWeight? fontWeight;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final Size? minimumSize;
  final MaterialTapTargetSize? tapTargetSize;
  final bool isLoading;
  final double loadingSize;
  final double loadingStrokeWidth;
  final Widget? leadingIcon;
  final double iconGap;
  final String telemetryComponent;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final disabled = isLoading || onPressed == null;
    final effectiveForeground = foregroundColor ?? _defaultForeground(colors);
    final effectiveDisabledForeground =
        disabledForegroundColor ?? _defaultDisabledForeground(colors);
    final uiTheme = GenesisUiTheme.of(context);
    final effectiveHeight =
        height ??
        (size == GenesisButtonSize.compact
            ? uiTheme.compactButtonHeight
            : uiTheme.regularButtonHeight);
    final effectiveTextStyle = GenesisTypography.bodyStrong.copyWith(
      fontSize: fontSize ?? (size == GenesisButtonSize.compact ? 14.0 : 16.0),
      fontWeight: fontWeight ?? FontWeight.w600,
    );
    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: size == GenesisButtonSize.compact
              ? GenesisSpacing.section
              : GenesisSpacing.page,
        );
    final child = isLoading
        ? SizedBox.square(
            dimension: loadingSize,
            child: CircularProgressIndicator(
              strokeWidth: loadingStrokeWidth,
              color: effectiveForeground,
            ),
          )
        : _GenesisButtonLabel(
            label: label,
            leadingIcon: leadingIcon,
            iconGap: iconGap,
          );

    final VoidCallback? effectiveOnPressed = disabled
        ? null
        : () {
            GenesisUiInteractionScope.notifyButton(
              context,
              GenesisButtonInteraction(
                actionId: 'button.${variant.name}.${_actionSlug(label)}',
                component: telemetryComponent,
                enabled: true,
              ),
            );
            onPressed!();
          };

    final Widget button = variant == GenesisButtonVariant.secondary
        ? OutlinedButton(
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: backgroundColor ?? Colors.transparent,
              disabledBackgroundColor:
                  disabledBackgroundColor ?? Colors.transparent,
              foregroundColor: effectiveForeground,
              disabledForegroundColor: effectiveDisabledForeground,
              side: side ?? BorderSide(color: colors.borderStrong, width: 1.2),
              textStyle: effectiveTextStyle,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? defaultBorderRadius,
              ),
              padding: effectivePadding,
              minimumSize: minimumSize,
              tapTargetSize: tapTargetSize,
            ),
            child: child,
          )
        : FilledButton(
            onPressed: effectiveOnPressed,
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor ?? _defaultBackground(colors),
              foregroundColor: effectiveForeground,
              disabledBackgroundColor:
                  disabledBackgroundColor ?? _defaultDisabledBackground(colors),
              disabledForegroundColor: effectiveDisabledForeground,
              side: side,
              textStyle: effectiveTextStyle,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius ?? defaultBorderRadius,
              ),
              padding: effectivePadding,
              minimumSize: minimumSize,
              tapTargetSize: tapTargetSize,
            ),
            child: child,
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled && onDisabledPressed != null
          ? () {
              GenesisUiInteractionScope.notifyButton(
                context,
                GenesisButtonInteraction(
                  actionId: 'button.${variant.name}.${_actionSlug(label)}',
                  component: telemetryComponent,
                  enabled: false,
                ),
              );
              onDisabledPressed!();
            }
          : null,
      child: SizedBox(
        height: effectiveHeight,
        width: width ?? (fullWidth ? double.infinity : null),
        child: button,
      ),
    );
  }

  Color _defaultBackground(GenesisSemanticColors colors) => switch (variant) {
    GenesisButtonVariant.primary => colors.primary,
    GenesisButtonVariant.secondary => Colors.transparent,
    GenesisButtonVariant.muted => colors.controlMuted,
    GenesisButtonVariant.destructive => colors.danger,
  };

  Color _defaultForeground(GenesisSemanticColors colors) => switch (variant) {
    GenesisButtonVariant.primary || GenesisButtonVariant.destructive =>
      variant == GenesisButtonVariant.primary
          ? colors.onPrimary
          : colors.onDanger,
    GenesisButtonVariant.secondary ||
    GenesisButtonVariant.muted => colors.textPrimary,
  };

  Color _defaultDisabledBackground(GenesisSemanticColors colors) =>
      switch (variant) {
        GenesisButtonVariant.primary => colors.primaryDisabled,
        GenesisButtonVariant.secondary => Colors.transparent,
        GenesisButtonVariant.muted => colors.controlMuted,
        GenesisButtonVariant.destructive => colors.danger.withValues(
          alpha: 0.55,
        ),
      };

  Color _defaultDisabledForeground(GenesisSemanticColors colors) =>
      switch (variant) {
        GenesisButtonVariant.primary || GenesisButtonVariant.destructive =>
          variant == GenesisButtonVariant.primary
              ? colors.onPrimary
              : colors.onDanger,
        GenesisButtonVariant.secondary ||
        GenesisButtonVariant.muted => colors.textDisabled,
      };
}

class GenesisPrimaryButton extends StatelessWidget {
  const GenesisPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onDisabledPressed,
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
    this.leadingIcon,
    this.iconGap = 8,
  });

  static const double defaultHeight = GenesisButton.regularHeight;
  static const BorderRadius defaultBorderRadius =
      GenesisButton.defaultBorderRadius;
  static const TextStyle defaultTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDisabledPressed;
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
  final Widget? leadingIcon;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    return GenesisButton(
      label: label,
      onPressed: onPressed,
      onDisabledPressed: onDisabledPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      side: side,
      height: height,
      width: width,
      fullWidth: fullWidth,
      padding: padding,
      fontWeight: fontWeight,
      fontSize: fontSize,
      borderRadius: borderRadius,
      minimumSize: minimumSize,
      tapTargetSize: tapTargetSize,
      isLoading: isLoading,
      loadingSize: loadingSize,
      loadingStrokeWidth: loadingStrokeWidth,
      leadingIcon: leadingIcon,
      iconGap: iconGap,
      telemetryComponent: 'GenesisPrimaryButton',
    );
  }
}

class GenesisSecondaryButton extends StatelessWidget {
  const GenesisSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foregroundColor,
    this.disabledForegroundColor,
    this.side,
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
    return GenesisButton(
      label: label,
      onPressed: onPressed,
      variant: GenesisButtonVariant.secondary,
      foregroundColor: foregroundColor,
      disabledForegroundColor: disabledForegroundColor,
      side: side,
      height: height,
      width: width,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
      telemetryComponent: 'GenesisSecondaryButton',
    );
  }
}

class _GenesisButtonLabel extends StatelessWidget {
  const _GenesisButtonLabel({
    required this.label,
    required this.leadingIcon,
    required this.iconGap,
  });

  final String label;
  final Widget? leadingIcon;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    final icon = leadingIcon;
    if (icon == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        SizedBox(width: iconGap),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

String _actionSlug(String label) {
  final normalized = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}
