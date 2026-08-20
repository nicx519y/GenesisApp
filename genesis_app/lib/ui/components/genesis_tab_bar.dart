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
    this.indicatorBottomPadding = genesisTabIndicatorBottomPadding,
    this.indicatorMatchesLabelWidth = false,
    this.labelFontSize,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelColor,
    this.unselectedLabelColor,
    this.expanded = false,
    this.tabAlignment,
    this.tabHeight = genesisTabHeight,
    this.onTap,
  });

  factory GenesisTabBar.scrollable({
    Key? key,
    required List<String> labels,
    TabController? controller,
    ValueChanged<int>? onTap,
  }) {
    return GenesisTabBar(
      key: key,
      labels: labels,
      controller: controller,
      onTap: onTap,
    );
  }

  factory GenesisTabBar.expanded({
    Key? key,
    required List<String> labels,
    TabController? controller,
    ValueChanged<int>? onTap,
  }) {
    return GenesisTabBar(
      key: key,
      labels: labels,
      controller: controller,
      expanded: true,
      onTap: onTap,
    );
  }

  factory GenesisTabBar.compact({
    Key? key,
    required List<String> labels,
    TabController? controller,
    ValueChanged<int>? onTap,
  }) {
    return GenesisTabBar(
      key: key,
      labels: labels,
      controller: controller,
      verticalPadding: 0,
      horizontalPadding: 0,
      tabHeight: 28,
      onTap: onTap,
    );
  }

  final List<String> labels;
  final TabController? controller;
  final double verticalPadding;
  final double horizontalPadding;
  final EdgeInsets labelPadding;
  final Color? indicatorColor;
  final double? indicatorWidth;
  final double? indicatorHeight;
  final double indicatorBottomPadding;
  final bool indicatorMatchesLabelWidth;
  final double? labelFontSize;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final bool expanded;
  final TabAlignment? tabAlignment;
  final double tabHeight;
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
            width: indicatorMatchesLabelWidth
                ? null
                : indicatorWidth ?? uiTheme.tabIndicatorWidth,
            height: indicatorHeight ?? uiTheme.tabIndicatorHeight,
            bottomPadding: indicatorBottomPadding,
          ),
          labelColor: labelColor ?? colors.navigationSelected,
          unselectedLabelColor:
              unselectedLabelColor ?? colors.navigationUnselected,
          labelStyle: resolvedLabelStyle,
          unselectedLabelStyle: resolvedUnselectedLabelStyle,
          tabs: [
            for (final label in labels) Tab(height: tabHeight, text: label),
          ],
        ),
      ),
    );
  }
}
