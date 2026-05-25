import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';
import 'genesis_fixed_underline_indicator.dart';

class GenesisTabBar extends StatelessWidget {
  const GenesisTabBar({
    super.key,
    required this.labels,
    this.controller,
    this.horizontalPadding = GenesisSpacing.md,
    this.labelPadding = const EdgeInsets.symmetric(
      horizontal: GenesisSpacing.md,
    ),
    this.indicatorColor,
    this.indicatorWidth,
    this.indicatorHeight,
    this.expanded = false,
  });

  final List<String> labels;
  final TabController? controller;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final Color? indicatorColor;
  final double? indicatorWidth;
  final double? indicatorHeight;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: TabBar(
        controller: controller,
        isScrollable: !expanded,
        tabAlignment: expanded ? TabAlignment.fill : TabAlignment.start,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        labelPadding: labelPadding,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: GenesisFixedUnderlineIndicator(
          color: indicatorColor ?? uiTheme.tabIndicatorColor,
          width: indicatorWidth ?? uiTheme.tabIndicatorWidth,
          height: indicatorHeight ?? uiTheme.tabIndicatorHeight,
          bottomPadding: 5,
        ),
        labelColor: uiTheme.tabSelectedColor,
        unselectedLabelColor: uiTheme.tabUnselectedColor,
        labelStyle: uiTheme.bodyStrongStyle,
        unselectedLabelStyle: uiTheme.bodyStyle,
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}
