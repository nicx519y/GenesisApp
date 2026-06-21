import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';
import 'genesis_fixed_underline_indicator.dart';

const double genesisTabHeight = 32;
const double genesisTabIndicatorBottomPadding = 3;

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
    this.labelFontSize,
    this.expanded = false,
    this.tabAlignment,
    this.onTap,
  });

  final List<String> labels;
  final TabController? controller;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final Color? indicatorColor;
  final double? indicatorWidth;
  final double? indicatorHeight;
  final double? labelFontSize;
  final bool expanded;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    final labelStyle = labelFontSize == null
        ? uiTheme.bodyStrongStyle
        : uiTheme.bodyStrongStyle.copyWith(fontSize: labelFontSize);
    final unselectedLabelStyle = labelFontSize == null
        ? uiTheme.bodyStyle
        : uiTheme.bodyStyle.copyWith(fontSize: labelFontSize);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: TabBar(
        controller: controller,
        isScrollable: !expanded,
        tabAlignment:
            tabAlignment ?? (expanded ? TabAlignment.fill : TabAlignment.start),
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        labelPadding: labelPadding,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: onTap,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: GenesisFixedUnderlineIndicator(
          color: indicatorColor ?? uiTheme.tabIndicatorColor,
          width: indicatorWidth ?? uiTheme.tabIndicatorWidth,
          height: indicatorHeight ?? uiTheme.tabIndicatorHeight,
          bottomPadding: genesisTabIndicatorBottomPadding,
        ),
        labelColor: uiTheme.tabSelectedColor,
        unselectedLabelColor: uiTheme.tabUnselectedColor,
        labelStyle: labelStyle,
        unselectedLabelStyle: unselectedLabelStyle,
        tabs: [
          for (final label in labels)
            Tab(height: genesisTabHeight, text: label),
        ],
      ),
    );
  }
}
