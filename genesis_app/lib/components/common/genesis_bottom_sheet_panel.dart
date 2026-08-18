import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_radii.dart';
import '../../ui/theme/genesis_semantic_colors.dart';

class GenesisBottomSheetCloseButton extends StatelessWidget {
  const GenesisBottomSheetCloseButton({
    super.key,
    required this.onPressed,
    this.buttonKey,
  });

  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: buttonKey,
      dimension: 24,
      child: IconButton(
        tooltip: 'Close',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(24),
          maximumSize: const Size.square(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          Icons.close,
          size: 24,
          color: context.genesisColors.textPrimary,
        ),
      ),
    );
  }
}

class GenesisBottomSheetPanel extends StatelessWidget {
  const GenesisBottomSheetPanel({
    super.key,
    required this.title,
    required this.height,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 14),
    this.titleBottomSpacing = 20,
    this.titleTextStyle,
    this.maintainBottomViewPadding = false,
    this.showHeader = true,
  });

  static const BorderRadius borderRadius = GenesisRadii.sheet;

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  final String title;
  final double height;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final double titleBottomSpacing;
  final TextStyle? titleTextStyle;
  final bool maintainBottomViewPadding;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.genesisColors.surface,
      borderRadius: borderRadius,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              titleTextStyle ??
                              GenesisBottomSheetPanel.titleStyle.copyWith(
                                color: context.genesisColors.textPrimary,
                              ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  SizedBox(height: titleBottomSpacing),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
