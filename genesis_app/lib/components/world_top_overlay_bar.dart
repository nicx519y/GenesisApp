import 'package:flutter/material.dart';

import '../ui/components/genesis_fixed_underline_indicator.dart';
import '../ui/components/genesis_search_field.dart';
import '../ui/components/genesis_tab_bar.dart';
import '../ui/theme/genesis_ui_theme.dart';
import 'world_details_shell.dart';

const _worldTopTabTextColor = Color(0xFF111111);
const _worldTopOverlayHeight = genesisSearchFieldHeight;
const _worldTopOverlayBackground = Color(0xE6FFFFFF);

class WorldTopOverlayBar extends StatelessWidget {
  const WorldTopOverlayBar({
    super.key,
    required this.pointsCount,
    required this.controller,
    this.onBack,
    this.onTabTap,
  });

  final int pointsCount;
  final TabController controller;
  final VoidCallback? onBack;
  final ValueChanged<int>? onTabTap;

  void _handleTabTap(BuildContext context, int index) {
    onTabTap?.call(index);
    final scrollController = WorldDetailsPanelScrollControllerScope.maybeOf(
      context,
    );
    if (scrollController == null || !scrollController.hasClients) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    return Row(
      children: [
        Container(
          width: _worldTopOverlayHeight,
          height: _worldTopOverlayHeight,
          decoration: BoxDecoration(
            color: _worldTopOverlayBackground,
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
              color: _worldTopOverlayBackground,
              borderRadius: BorderRadius.circular(12),
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
              onTap: (index) => _handleTabTap(context, index),
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
