import 'package:flutter/material.dart';

class SearchBarPlaceholder extends StatelessWidget {
  const SearchBarPlaceholder({
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
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.backgroundColor = const Color(0xFFF2F2F2),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.iconColor = const Color(0xFF9E9E9E),
    this.iconSize = 20,
    this.hintStyle = const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
    this.textStyle = const TextStyle(color: Color(0xFF222222), fontSize: 14),
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
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final Color iconColor;
  final double iconSize;
  final TextStyle hintStyle;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final editable = controller != null;
    final child = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: iconColor, size: iconSize),
          const SizedBox(width: 8),
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
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: hintStyle,
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    style: textStyle,
                  )
                : Text(
                    hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: hintStyle,
                  ),
          ),
          if (editable &&
              onClear != null &&
              (controller?.text.trim().isNotEmpty ?? false))
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
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
