part of 'world_page.dart';

extension _WorldPageLayout on _WorldPageState {
  void _handleTilemapDisplayReadinessChanged(bool ready) {
    if (!mounted || _tilemapDisplayReady == ready) return;
    _setWorldPageState(() {
      _tilemapDisplayReady = ready;
      if (ready) {
        _tilemapDisplayError = null;
        _coverTilemapAfterInitialChat = false;
      }
    });
  }

  void _handleTilemapDisplayError(Object error) {
    if (!mounted) return;
    _setWorldPageState(() {
      _tilemapDisplayReady = false;
      _tilemapDisplayError = error;
      _coverTilemapAfterInitialChat = false;
    });
  }

  Widget _buildInitialLoadingScaffold(double topPadding) {
    final collapsedPanelHeight = worldCollapsedPanelHeightFor(context);
    return WorldDetailsPageScaffold(
      panelTopGap: 50,
      panelCollapsedHeightOffset: 120,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      persistentTopOverlay: _buildPersistentMapOverlay(topPadding),
      map: ColoredBox(
        key: const ValueKey<String>('world-map-loading-background'),
        color: kWorldMapLoadingBackgroundColor,
      ),
      fixedCollapsedPanelHeight: collapsedPanelHeight,
      fixedCollapsedPanelHeightIncludesBottomSafeArea: true,
      contentBottomPaddingOverride: 0,
      slivers: const [WorldDetailsLoadingContent()],
    );
  }

  Widget _buildPersistentMapOverlay(
    double top, {
    WorldDetail? world,
    String worldTime = '',
    int tickIndex = -1,
  }) {
    final title = world == null
        ? ''
        : (world.name.trim().isEmpty ? world.worldId : world.name.trim());
    final resolvedWorldTimeLabel = worldTimeLabel(
      tickIndex: tickIndex,
      worldTime: worldTime,
    );
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideReservedWidth =
              worldMapBackButtonLeft +
              worldMapTabsHeight +
              worldMapIdentityHorizontalGap;
          final maxIdentityWidth =
              (constraints.maxWidth - sideReservedWidth * 2)
                  .clamp(worldTimePillMinWidth, constraints.maxWidth)
                  .toDouble();
          return Stack(
            children: [
              if (_worldMainTabIndex == 0)
                Positioned(
                  left: worldMapBackButtonLeft,
                  top: top + 6,
                  child: WorldMapBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (world != null &&
                  (title.isNotEmpty || resolvedWorldTimeLabel.isNotEmpty))
                Positioned(
                  left: sideReservedWidth,
                  right: sideReservedWidth,
                  top: top + 2,
                  child: AnimatedBuilder(
                    animation:
                        _mainTabController.animation ?? _mainTabController,
                    builder: (context, _) {
                      if (_worldMainTabIndex != 0) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.topCenter,
                        child: WorldMapIdentityPill(
                          title: title,
                          timeText: resolvedWorldTimeLabel,
                          maxWidth: maxIdentityWidth,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
