import 'package:flutter/material.dart';

import 'genesis_tab_bar.dart';

const double secendTabsVerticalPadding = 3;

class SecendTabs extends StatelessWidget {
  const SecendTabs({
    super.key,
    required this.labels,
    this.controller,
    this.horizontalPadding = 8,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.labelFontSize,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorColor,
    this.indicatorWidth,
    this.indicatorHeight,
    this.expanded = false,
    this.tabAlignment,
    this.verticalPadding = secendTabsVerticalPadding,
    this.onTap,
  });

  final List<String> labels;
  final TabController? controller;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final double? labelFontSize;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Color? indicatorColor;
  final double? indicatorWidth;
  final double? indicatorHeight;
  final bool expanded;
  final TabAlignment? tabAlignment;
  final double verticalPadding;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: GenesisTabBar(
        labels: labels,
        controller: controller,
        horizontalPadding: horizontalPadding,
        labelPadding: labelPadding,
        labelFontSize: labelFontSize,
        labelStyle: labelStyle,
        unselectedLabelStyle: unselectedLabelStyle,
        labelColor: labelColor,
        unselectedLabelColor: unselectedLabelColor,
        indicatorColor: indicatorColor,
        indicatorWidth: indicatorWidth,
        indicatorHeight: indicatorHeight,
        expanded: expanded,
        tabAlignment: tabAlignment,
        onTap: onTap,
      ),
    );
  }
}
