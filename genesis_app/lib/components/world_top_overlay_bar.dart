import 'package:flutter/material.dart';

import '../ui/components/genesis_fixed_underline_indicator.dart';
import '../ui/components/genesis_search_field.dart';
import '../ui/components/genesis_tab_bar.dart';
import '../ui/theme/genesis_ui_theme.dart';

const _worldTopTabTextColor = Color(0xFF111111);
const _worldTopOverlayHeight = genesisSearchFieldHeight;

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
          width: _worldTopOverlayHeight,
          height: _worldTopOverlayHeight,
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
            height: _worldTopOverlayHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicatorSize: TabBarIndicatorSize.label,
              indicator: GenesisFixedUnderlineIndicator(
                color: uiTheme.tabIndicatorColor,
                width: uiTheme.tabIndicatorWidth,
                height: uiTheme.tabIndicatorHeight,
                bottomPadding: genesisTabIndicatorBottomPadding,
              ),
              labelColor: _worldTopTabTextColor,
              unselectedLabelColor: _worldTopTabTextColor,
              labelStyle: uiTheme.bodyStrongStyle.copyWith(fontSize: 16),
              unselectedLabelStyle: uiTheme.bodyStyle.copyWith(fontSize: 16),
              tabs: [
                const Tab(
                  height: _worldTopOverlayHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Map'),
                    ],
                  ),
                ),
                Tab(
                  height: _worldTopOverlayHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
