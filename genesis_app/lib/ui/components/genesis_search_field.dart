import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';

class GenesisSearchField extends StatelessWidget {
  const GenesisSearchField({
    super.key,
    this.hintText = 'Explore',
    this.onTap,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.textInputAction = TextInputAction.search,
    this.readOnly = false,
    this.autofocus = false,
    this.height = 38,
    this.padding = const EdgeInsets.symmetric(horizontal: GenesisSpacing.xl),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.iconColor,
    this.iconSize = 20,
    this.iconAsset,
    this.hintStyle,
    this.textStyle,
  });

  final String hintText;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextInputAction textInputAction;
  final bool readOnly;
  final bool autofocus;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final Color? iconColor;
  final double iconSize;
  final String? iconAsset;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    final effectiveHintStyle = hintStyle ?? uiTheme.searchHintStyle;
    final effectiveTextStyle = textStyle ?? uiTheme.searchTextStyle;
    final editable = controller != null;
    final child = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? uiTheme.searchBackgroundColor,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        borderRadius: borderRadius ?? uiTheme.searchBorderRadius,
      ),
      child: Row(
        children: [
          if (iconAsset == null)
            Icon(
              Icons.search,
              color: iconColor ?? uiTheme.searchIconColor,
              size: iconSize,
            )
          else
            Image.asset(
              iconAsset!,
              width: iconSize,
              height: iconSize,
              color: iconColor,
              excludeFromSemantics: true,
            ),
          const SizedBox(width: GenesisSpacing.md),
          Expanded(
            child: editable
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    textInputAction: textInputAction,
                    readOnly: readOnly,
                    autofocus: autofocus,
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
          if (editable &&
              onClear != null &&
              (controller?.text.trim().isNotEmpty ?? false))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: SizedBox(
                width: height,
                height: height,
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: iconColor ?? uiTheme.searchIconColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
