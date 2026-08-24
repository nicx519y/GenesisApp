import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../theme/genesis_ui_theme.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import 'genesis_ui_interaction.dart';

enum GenesisButtonVariant { primary, secondary, destructive }

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
    this.loadingColor,
    this.loadingTrackColor,
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
  final Color? loadingColor;
  final Color? loadingTrackColor;
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
    final effectiveBackground = backgroundColor ?? _defaultBackground(colors);
    final effectiveLoadingBackground = backgroundColor ?? colors.primary;
    final effectiveDisabledBackground =
        disabledBackgroundColor ??
        (isLoading
            ? effectiveLoadingBackground
            : _defaultDisabledBackground(colors));
    final effectiveLoadingColor = loadingColor ?? colors.onPrimary;
    final effectiveLoadingTrackColor =
        loadingTrackColor ?? effectiveLoadingColor.withValues(alpha: 0.32);
    final uiTheme = GenesisUiTheme.of(context);
    final effectiveHeight =
        height ??
        (size == GenesisButtonSize.compact
            ? uiTheme.compactButtonHeight
            : uiTheme.regularButtonHeight);
    final effectiveTextStyle = GenesisTypography.bodyStrong.copyWith(
      fontSize: fontSize ?? (size == GenesisButtonSize.compact ? 13.0 : 15.0),
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
              color: effectiveLoadingColor,
              backgroundColor: effectiveLoadingTrackColor,
              strokeCap: StrokeCap.round,
            ),
          )
        : _GenesisButtonLabel(
            label: label,
            leadingIcon: leadingIcon,
            iconGap: iconGap,
            fontSize: effectiveTextStyle.fontSize ?? 13,
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
              disabledBackgroundColor: effectiveDisabledBackground,
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
              backgroundColor: effectiveBackground,
              foregroundColor: effectiveForeground,
              disabledBackgroundColor: effectiveDisabledBackground,
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
    GenesisButtonVariant.destructive => colors.danger,
  };

  Color _defaultForeground(GenesisSemanticColors colors) => switch (variant) {
    GenesisButtonVariant.primary || GenesisButtonVariant.destructive =>
      variant == GenesisButtonVariant.primary
          ? colors.onPrimary
          : colors.onDanger,
    GenesisButtonVariant.secondary => colors.textPrimary,
  };

  Color _defaultDisabledBackground(GenesisSemanticColors colors) =>
      switch (variant) {
        GenesisButtonVariant.primary => colors.primaryDisabled,
        GenesisButtonVariant.secondary => Colors.transparent,
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
        GenesisButtonVariant.secondary => colors.textDisabled,
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
    this.loadingColor,
    this.loadingTrackColor,
    this.leadingIcon,
    this.iconGap = 8,
  });

  static const double defaultHeight = GenesisButton.regularHeight;
  static const BorderRadius defaultBorderRadius =
      GenesisButton.defaultBorderRadius;
  static const TextStyle defaultTextStyle = TextStyle(
    fontSize: 13,
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
  final Color? loadingColor;
  final Color? loadingTrackColor;
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
      loadingColor: loadingColor,
      loadingTrackColor: loadingTrackColor,
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
    required this.fontSize,
  });

  /// Inter 的字体度量,用于把 icon 对到文字的**墨迹**中线而不是行盒中线。
  /// ascent 0.9688 / descent 0.2422(合计 1.2109),因此在 forceStrutHeight 的
  /// 紧行盒里基线落在 0.8em 处;大写字高约 0.727em,墨迹顶边在 0.073em。
  /// 墨迹中心 =(0.073 + 0.8)/2 = 0.4365em,而行盒中心是 0.5em ——
  /// 两者差 0.0635em,就是 icon 需要上移的量。
  static const double _inkCentreOffsetEm = 0.0635;

  final String label;
  final Widget? leadingIcon;
  final double iconGap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final icon = leadingIcon;
    if (icon == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    // 两步才能对齐,少一步都不够:
    // 1) forceStrutHeight 把标签压成紧行盒。否则 bodyStrong 的 height 1.4 会让
    //    12px 文字占掉约 16.8px,行距把 icon 顶高半格。
    // 2) 紧行盒之后仍然差一点,因为行盒把降部空间也算了进去,而 "Tick now"
    //    这类文案根本没有降部字母 —— 按盒居中等于把可见字形整体推高。
    //    这里按 Inter 的度量把 icon 上移 0.0635em,对到文字的墨迹中线。
    //    Transform 只影响绘制不影响布局,不会改变按钮尺寸。
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, -fontSize * _inkCentreOffsetEm),
          child: icon,
        ),
        SizedBox(width: iconGap),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: const StrutStyle(height: 1, forceStrutHeight: true),
          ),
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
