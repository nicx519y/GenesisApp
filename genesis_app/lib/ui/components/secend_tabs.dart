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
    this.expanded = false,
    this.verticalPadding = secendTabsVerticalPadding,
  });

  final List<String> labels;
  final TabController? controller;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final double? labelFontSize;
  final bool expanded;
  final double verticalPadding;

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
        expanded: expanded,
      ),
    );
  }
}
