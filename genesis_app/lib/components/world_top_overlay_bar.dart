import 'package:flutter/material.dart';

import '../ui/components/genesis_fixed_underline_indicator.dart';
import '../ui/theme/genesis_ui_theme.dart';

class WorldTopOverlayBar extends StatelessWidget {
  const WorldTopOverlayBar({
    super.key,
    required this.pointsCount,
    required this.controller,
    this.onBack,
  });

  final int pointsCount;
  final TabController controller;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            iconSize: 18,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: kTextTabBarHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: controller,
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelPadding: EdgeInsets.zero,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: GenesisFixedUnderlineIndicator(
                color: uiTheme.tabIndicatorColor,
                width: uiTheme.tabIndicatorWidth,
                height: uiTheme.tabIndicatorHeight,
                bottomPadding: 7.5,
              ),
              labelColor: uiTheme.tabSelectedColor,
              unselectedLabelColor: uiTheme.tabUnselectedColor,
              labelStyle: uiTheme.bodyStrongStyle,
              unselectedLabelStyle: uiTheme.bodyStyle,
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Map'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Location ($pointsCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
