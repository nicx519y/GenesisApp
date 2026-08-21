import 'dart:ui';

import 'package:flutter/material.dart';

import '../ui/components/genesis_fixed_underline_indicator.dart';
import '../ui/components/genesis_control_icons.dart';
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
    this.title,
    this.subtitle,
    this.onInfoTap,
  });

  final int pointsCount;
  final TabController controller;
  final VoidCallback? onBack;
  final ValueChanged<int>? onTabTap;

  /// Uses the origin-detail information view as the second tab instead of
  /// the map's location list.
  final bool secondaryTabIsIntro;
  final bool tabsEnabled;
  final String? title;
  final String? subtitle;
  final VoidCallback? onInfoTap;

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
    final resolvedTitle = title;
    if (resolvedTitle != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GenesisBackButton(
            key: const ValueKey<String>('worldo-title-back-button'),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedTitle,
                    key: const ValueKey<String>('worldo-title-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.immersiveForeground,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: context.genesisColors.scrim.withValues(
                            alpha: 0.6,
                          ),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        subtitle!,
                        key: const ValueKey<String>('worldo-title-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.immersiveForeground.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 9.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: context.genesisColors.scrim.withValues(
                                alpha: 0.7,
                              ),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _WorldoTopGlassButton(
            key: const ValueKey<String>('worldo-title-info-button'),
            horizontalPadding: 12,
            onTap: tabsEnabled ? onInfoTap : null,
            child: Text(
              'Info',
              style: TextStyle(
                color: colors.foregroundStrong,
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        GenesisBackButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
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

class _WorldoTopGlassButton extends StatelessWidget {
  const _WorldoTopGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.horizontalPadding = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: context.genesisColors.controlMuted,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 34,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
