import 'package:flutter/material.dart';

import '../ui/components/genesis_fixed_underline_indicator.dart';
import '../ui/components/genesis_search_field.dart';
import '../ui/components/genesis_tab_bar.dart';
import '../ui/theme/genesis_semantic_colors.dart';
import '../ui/theme/genesis_ui_theme.dart';
import '../ui/tokens/genesis_typography.dart';
import 'world_details_shell.dart';

const _worldTopOverlayHeight = genesisSearchFieldHeight;

class WorldTopOverlayBar extends StatelessWidget {
  const WorldTopOverlayBar({
    super.key,
    required this.pointsCount,
    required this.controller,
    this.onBack,
    this.onTabTap,
    this.secondaryTabIsIntro = false,
    this.tabsEnabled = true,
  });

  final int pointsCount;
  final TabController controller;
  final VoidCallback? onBack;
  final ValueChanged<int>? onTabTap;

  /// Uses the origin-detail information view as the second tab instead of
  /// the map's location list.
  final bool secondaryTabIsIntro;
  final bool tabsEnabled;

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
    final colors = context.genesisColors;
    return Row(
      children: [
        Container(
          width: _worldTopOverlayHeight,
          height: _worldTopOverlayHeight,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            iconSize: 18,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: colors.foregroundStrong,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: IgnorePointer(
            ignoring: !tabsEnabled,
            child: Container(
              height: _worldTopOverlayHeight,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: controller,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                dividerColor: Colors.transparent,
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: secondaryTabIsIntro ? 20 : 12,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                indicatorSize: TabBarIndicatorSize.label,
                onTap: (index) => _handleTabTap(context, index),
                indicator: GenesisFixedUnderlineIndicator(
                  color: colors.danger,
                  width: uiTheme.tabIndicatorWidth,
                  height: uiTheme.tabIndicatorHeight,
                  bottomPadding: genesisTabIndicatorBottomPadding,
                ),
                labelColor: colors.textPrimary,
                unselectedLabelColor: colors.textPrimary,
                labelStyle: GenesisTypography.bodyStrong.copyWith(fontSize: 16),
                unselectedLabelStyle: GenesisTypography.body.copyWith(
                  fontSize: 16,
                ),
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
                        Icon(
                          secondaryTabIsIntro
                              ? Icons.info_outline
                              : Icons.place_outlined,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          secondaryTabIsIntro
                              ? 'Info.'
                              : 'Location ($pointsCount)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
