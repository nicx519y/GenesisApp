import 'package:flutter/material.dart';

import 'genesis_tab_bar.dart';

class SecendTabs extends StatelessWidget {
  const SecendTabs({
    super.key,
    required this.labels,
    this.controller,
    this.horizontalPadding = 8,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final List<String> labels;
  final TabController? controller;
  final double horizontalPadding;
  final EdgeInsets labelPadding;

  @override
  Widget build(BuildContext context) {
    return GenesisTabBar(
      labels: labels,
      controller: controller,
      horizontalPadding: horizontalPadding,
      labelPadding: labelPadding,
    );
  }
}
