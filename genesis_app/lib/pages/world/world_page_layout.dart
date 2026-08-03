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

  Widget _buildInitialLoadingScaffold(double topPadding, {WorldDetail? world}) {
    final collapsedPanelHeight = worldCollapsedPanelHeightFor(context);
    return Stack(
      children: [
        WorldDetailsPageScaffold(
          backgroundColor: _tilemapLoadingBackgroundColor,
          panelTopGap: 50,
          panelCollapsedHeightOffset: 120,
          scrollPhysics: const NeverScrollableScrollPhysics(),
          persistentTopOverlay: _buildPersistentMapOverlay(
            topPadding,
            world: world,
            worldTime: world?.currentTime ?? '',
            tickIndex: world?.tickCount ?? -1,
          ),
          map: ColoredBox(
            key: const ValueKey<String>('world-map-loading-background'),
            color: _tilemapLoadingBackgroundColor,
          ),
          fixedCollapsedPanelHeight: collapsedPanelHeight,
          fixedCollapsedPanelHeightIncludesBottomSafeArea: true,
          contentBottomPaddingOverride: 0,
          slivers: const [WorldDetailsLoadingContent()],
        ),
        _buildWorldBottomTagsOverlay(
          collapsedPanelHeight: collapsedPanelHeight,
          interactive: false,
        ),
      ],
    );
  }

  Widget _buildWorldBottomTagsOverlay({
    required double collapsedPanelHeight,
    required bool interactive,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: collapsedPanelHeight - worldMainTabsHeight,
      height: worldMainTabsHeight,
      child: IgnorePointer(
        key: const ValueKey<String>('world-bottom-tags-overlay'),
        ignoring: !interactive,
        child: WorldBottomTags(
          eventsUnread: _eventsUnread,
          showDetailUnreadDot: _hasUnreadNewUserJoin,
          onTap: _openWorldBottomSheet,
        ),
      ),
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
