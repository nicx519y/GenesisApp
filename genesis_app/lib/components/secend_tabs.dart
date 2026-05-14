import 'package:flutter/material.dart';

import 'origin/fixed_width_underline_indicator.dart';

class SecendTabs extends StatelessWidget {
  const SecendTabs({
    super.key,
    required this.labels,
    this.horizontalPadding = 8,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final List<String> labels;
  final double horizontalPadding;
  final EdgeInsets labelPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        labelPadding: labelPadding,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: const FixedWidthUnderlineIndicator(
          color: Color(0xFFFF3B30),
          width: 34,
          height: 3,
          bottomPadding: 5,
        ),
        labelColor: Color(0xFF111111),
        unselectedLabelColor: const Color(0xFF888888),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: [for (final label in labels) Tab(text: label)],
      ),
    );
  }
}
