import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import 'genesis_control_icons.dart';
import '../text/genesis_text_input_formatters.dart';
import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_control_metrics.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import '../theme/genesis_ui_theme.dart';

const genesisSearchFieldHeight = 38.0;
const genesisCompactSearchFieldHeight = 36.0;
const genesisSearchIconSize = 15.0;

enum GenesisSearchFieldVariant { standard, compact }

class GenesisSearchField extends StatelessWidget {
  const GenesisSearchField({
    super.key,
    this.variant = GenesisSearchFieldVariant.standard,
    this.hintText = 'Explore',
    this.onTap,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.textInputAction = TextInputAction.search,
    this.readOnly = false,
    this.autofocus = false,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: GenesisSpacing.xl),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.iconColor,
    this.iconSize = genesisSearchIconSize,
    this.iconGap = GenesisSpacing.md,
    this.iconAsset,
    this.borderWidth = 1,
    this.hintStyle,
    this.textStyle,
  });

  factory GenesisSearchField.launcher({
    Key? key,
    GenesisSearchFieldVariant variant = GenesisSearchFieldVariant.standard,
    String hintText = 'Explore',
    required VoidCallback onTap,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: GenesisSpacing.xl,
    ),
  }) {
    return GenesisSearchField(
      key: key,
      variant: variant,
      hintText: hintText,
      onTap: onTap,
      readOnly: true,
      height: height,
      padding: padding,
    );
  }

  factory GenesisSearchField.editable({
    Key? key,
    GenesisSearchFieldVariant variant = GenesisSearchFieldVariant.standard,
    String hintText = 'Explore',
    required TextEditingController controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    VoidCallback? onClear,
    TextInputAction textInputAction = TextInputAction.search,
    bool autofocus = false,
    double? height,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: GenesisSpacing.xl,
    ),
  }) {
    return GenesisSearchField(
      key: key,
      variant: variant,
      hintText: hintText,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onClear: onClear,
      textInputAction: textInputAction,
      autofocus: autofocus,
      height: height,
      padding: padding,
    );
  }

  final GenesisSearchFieldVariant variant;
  final String hintText;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextInputAction textInputAction;
  final bool readOnly;
  final bool autofocus;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final Color? iconColor;
  final double iconSize;
  final double iconGap;
  final String? iconAsset;
  final double borderWidth;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    final colors = context.genesisColors;
    final compact = variant == GenesisSearchFieldVariant.compact;
    final effectiveHeight =
        height ??
        (compact
            ? uiTheme.compactSearchFieldHeight
            : uiTheme.searchFieldHeight);
    final effectiveBackgroundColor =
        backgroundColor ??
        (compact ? colors.surfaceSubtle : colors.inputBackground);
    final effectiveBorderColor =
        borderColor ?? (compact ? colors.borderSubtle : null);
    final effectiveBorderRadius =
        borderRadius ??
        (compact
            ? const BorderRadius.all(Radius.circular(12))
            : uiTheme.searchBorderRadius);
    final effectiveIconAsset = iconAsset ?? (compact ? searchIconAsset : null);
    final effectiveIconColor = iconColor ?? colors.iconMuted;
    final effectiveHintStyle = GenesisTypography.withFallback(
      hintStyle ??
          GenesisTypography.body.copyWith(
            color: colors.textDisabled,
            letterSpacing: 0,
          ),
    );
    final effectiveTextStyle = GenesisTypography.withFallback(
      textStyle ?? GenesisTypography.body.copyWith(color: colors.textPrimary),
    );
    final editable = controller != null;
    final targetHeight =
        effectiveHeight < GenesisControlMetrics.minimumTapTarget
        ? GenesisControlMetrics.minimumTapTarget
        : effectiveHeight;
    final showClear =
        editable &&
        onClear != null &&
        (controller?.text.trim().isNotEmpty ?? false);
    final child = SizedBox(
      height: targetHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              key: const ValueKey('genesis-search-field-visual'),
              width: double.infinity,
              height: effectiveHeight,
              decoration: BoxDecoration(
                color: effectiveBackgroundColor,
                border: effectiveBorderColor == null
                    ? null
                    : Border.all(
                        color: effectiveBorderColor,
                        width: borderWidth,
                      ),
                borderRadius: effectiveBorderRadius,
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              children: [
                if (effectiveIconAsset == null)
                  Icon(Icons.search, color: effectiveIconColor, size: iconSize)
                else
                  effectiveIconAsset.toLowerCase().endsWith('.svg')
                      ? SvgPicture.asset(
                          effectiveIconAsset,
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(
                            effectiveIconColor,
                            BlendMode.srcIn,
                          ),
                          excludeFromSemantics: true,
                        )
                      : Image.asset(
                          effectiveIconAsset,
                          width: iconSize,
                          height: iconSize,
                          color: effectiveIconColor,
                          excludeFromSemantics: true,
                        ),
                SizedBox(width: iconGap),
                Expanded(
                  child: editable
                      ? TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: onChanged,
                          textInputAction: textInputAction,
                          readOnly: readOnly,
                          autofocus: autofocus,
                          inputFormatters: const [
                            GenesisDisplaySafeTextInputFormatter(),
                          ],
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: effectiveHintStyle,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: effectiveTextStyle,
                        )
                      : Text(
                          hintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: effectiveHintStyle,
                        ),
                ),
                if (showClear)
                  Semantics(
                    key: const ValueKey('genesis-search-field-clear-action'),
                    button: true,
                    label: 'Clear search',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: SizedBox(
                        width: GenesisControlMetrics.minimumTapTarget,
                        height: targetHeight,
                        child: Center(
                          child: GenesisCloseIcon(
                            size: 14,
                            color: effectiveIconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final interactiveChild = onTap == null
        ? child
        : Semantics(
            button: true,
            label: hintText,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: child,
            ),
          );
    return interactiveChild;
  }
}
