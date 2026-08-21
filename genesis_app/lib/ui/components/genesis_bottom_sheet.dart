import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_radii.dart';
import '../tokens/genesis_control_metrics.dart';
import 'genesis_control_icons.dart';
import 'genesis_modal_border.dart';

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
    const visualSize = GenesisControlMetrics.closeButtonVisualSize;
    const hitScale = GenesisControlMetrics.minimumTapTarget / visualSize;
    return Transform.scale(
      scale: hitScale,
      transformHitTests: true,
      child: Transform.scale(
        scale: 1 / hitScale,
        transformHitTests: false,
        child: SizedBox.square(
          key: buttonKey,
          dimension: visualSize,
          child: IconButton(
            tooltip: 'Close',
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: visualSize,
              height: visualSize,
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(visualSize),
              maximumSize: const Size.square(visualSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: GenesisCloseIcon(
              size: 14,
              color: context.genesisColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class GenesisBottomSheetSurface extends StatelessWidget {
  const GenesisBottomSheetSurface({
    super.key,
    required this.child,
    this.maintainBottomViewPadding = false,
    this.borderRadius = GenesisRadii.sheet,
  });

  final Widget child;
  final bool maintainBottomViewPadding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.genesisColors.surface,
      shape: genesisModalShape(context, borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: child,
      ),
    );
  }
}

class GenesisBottomSheetHeader extends StatelessWidget {
  const GenesisBottomSheetHeader({
    super.key,
    required this.title,
    this.trailing,
    this.titleTextStyle,
  });

  final String title;
  final Widget? trailing;
  final TextStyle? titleTextStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

enum GenesisBottomSheetLayout { fixed, content, scrollable }

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
  }) : layout = GenesisBottomSheetLayout.fixed;

  const GenesisBottomSheetPanel.content({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 14),
    this.titleBottomSpacing = 20,
    this.titleTextStyle,
    this.maintainBottomViewPadding = false,
    this.showHeader = true,
  }) : height = null,
       layout = GenesisBottomSheetLayout.content;

  const GenesisBottomSheetPanel.scrollable({
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
  }) : layout = GenesisBottomSheetLayout.scrollable;

  static const BorderRadius borderRadius = GenesisRadii.sheet;
  static const TextStyle titleStyle = TextStyle(
    fontSize: 17,
    height: 20 / 17,
    fontWeight: FontWeight.w800,
  );

  final String title;
  final double? height;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final double titleBottomSpacing;
  final TextStyle? titleTextStyle;
  final bool maintainBottomViewPadding;
  final bool showHeader;
  final GenesisBottomSheetLayout layout;

  @override
  Widget build(BuildContext context) {
    final header = <Widget>[
      if (showHeader) ...[
        GenesisBottomSheetHeader(
          title: title,
          trailing: trailing,
          titleTextStyle: titleTextStyle,
        ),
        SizedBox(height: titleBottomSpacing),
      ],
    ];
    final panel = switch (layout) {
      GenesisBottomSheetLayout.content => Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...header, child],
        ),
      ),
      GenesisBottomSheetLayout.fixed => SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...header,
              Expanded(child: child),
            ],
          ),
        ),
      ),
      GenesisBottomSheetLayout.scrollable => SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...header,
              Expanded(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    };
    return GenesisBottomSheetSurface(
      maintainBottomViewPadding: maintainBottomViewPadding,
      child: panel,
    );
  }
}
