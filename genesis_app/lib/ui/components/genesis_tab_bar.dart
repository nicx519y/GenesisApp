import 'package:flutter/material.dart';

import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';
import '../theme/genesis_ui_theme.dart';
import 'genesis_fixed_underline_indicator.dart';

const double genesisTabHeight = 32;
const double genesisTabIndicatorBottomPadding = 3;
const double genesisTabBarVerticalPadding = 3;

class GenesisTabBar extends StatelessWidget {
  const GenesisTabBar({
    super.key,
    required this.labels,
    this.controller,
    this.verticalPadding = genesisTabBarVerticalPadding,
    this.horizontalPadding = GenesisSpacing.md,
    this.labelPadding = const EdgeInsets.symmetric(
      horizontal: GenesisSpacing.md,
    ),
    this.indicatorColor,
    this.indicatorWidth,
    this.indicatorHeight,
    this.labelFontSize,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelColor,
    this.unselectedLabelColor,
    this.expanded = false,
    this.tabAlignment,
    this.onTap,
  });

  final List<String> labels;
  final TabController? controller;
  final double verticalPadding;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final Color? indicatorColor;
  final double? indicatorWidth;
  final double? indicatorHeight;
  final double? labelFontSize;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final bool expanded;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    final colors = context.genesisColors;
    final resolvedLabelStyle =
        labelStyle ??
        (labelFontSize == null
            ? GenesisTypography.bodyStrong
            : GenesisTypography.bodyStrong.copyWith(fontSize: labelFontSize));
    final resolvedUnselectedLabelStyle =
        unselectedLabelStyle ??
        (labelFontSize == null
            ? GenesisTypography.body
            : GenesisTypography.body.copyWith(fontSize: labelFontSize));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: TabBar(
          controller: controller,
          isScrollable: !expanded,
          tabAlignment:
              tabAlignment ??
              (expanded ? TabAlignment.fill : TabAlignment.start),
          dividerColor: Colors.transparent,
          padding: EdgeInsets.zero,
          labelPadding: labelPadding,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          onTap: onTap,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: GenesisFixedUnderlineIndicator(
            color: indicatorColor ?? colors.danger,
            width: indicatorWidth ?? uiTheme.tabIndicatorWidth,
            height: indicatorHeight ?? uiTheme.tabIndicatorHeight,
            bottomPadding: genesisTabIndicatorBottomPadding,
          ),
          labelColor: labelColor ?? colors.navigationSelected,
          unselectedLabelColor:
              unselectedLabelColor ?? colors.navigationUnselected,
          labelStyle: resolvedLabelStyle,
          unselectedLabelStyle: resolvedUnselectedLabelStyle,
          tabs: [
            for (final label in labels)
              Tab(height: genesisTabHeight, text: label),
          ],
        ),
      ),
    );
  }
}
