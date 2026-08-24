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
          panelTopRadius: 24,
          panelTopOverlap: 8,
          panelTopBandHeight: worldPanelHandleBandHeight,
          panelTopChild: const WorldDetailsDragHandleBand(),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          persistentTopOverlay: _buildPersistentMapOverlay(
            topPadding,
            world: world,
            worldTime: world?.currentTime ?? '',
            tickIndex: world?.tickCount ?? -1,
            subTickNo: world?.subTickNo ?? 0,
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
        _buildWorldBottomSafeAreaBackground(),
        _buildWorldBottomTagsOverlay(interactive: false),
      ],
    );
  }

  Widget _buildWorldBottomSafeAreaBackground() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: worldBottomSafeAreaOf(context),
      child: IgnorePointer(
        child: ColoredBox(
          key: const ValueKey<String>('world-bottom-safe-area-background'),
          color: context.genesisColors.pageBackground,
        ),
      ),
    );
  }

  Widget _buildWorldBottomTagsOverlay({required bool interactive}) {
    final bottomSafeArea = worldBottomSafeAreaOf(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomSafeArea,
      height: worldMainTabsHeight,
      child: IgnorePointer(
        key: const ValueKey<String>('world-bottom-tags-overlay'),
        ignoring: !interactive,
        child: ValueListenableBuilder<WorldBottomSheetSelection>(
          valueListenable: _worldBottomSheetSelection,
          builder: (context, selection, _) => WorldBottomTags(
            key: _worldBottomTagsContentKey,
            eventsUnread: _eventsUnread,
            showDetailUnreadDot: _hasUnreadNewUserJoin,
            selectedKind: _worldBottomSheetOpen ? selection.kind : null,
            onTap: _openWorldBottomSheet,
          ),
        ),
      ),
    );
  }

  Widget _buildPersistentMapOverlay(
    double top, {
    WorldDetail? world,
    String worldTime = '',
    int tickIndex = -1,
    int subTickNo = 0,
  }) {
    final title = world == null
        ? ''
        : (world.name.trim().isEmpty ? world.worldId : world.name.trim());
    final resolvedWorldTimeLabel = worldTimeLabel(
      tickIndex: tickIndex,
      subTickNo: subTickNo,
      worldTime: worldTime,
    );
    final resolvedWorldStatusLabel = world == null
        ? ''
        : worldMapStatusLabel(
            relationStatus: world.relationStatus,
            timeText: resolvedWorldTimeLabel,
          );
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxIdentityWidth =
              (constraints.maxWidth -
                      worldMapHeaderHorizontalPadding * 2 -
                      worldMapHeaderButtonSize -
                      worldMapHeaderTitleGap)
                  .clamp(0, constraints.maxWidth)
                  .toDouble();
          return Stack(
            children: [
              if (_worldMainTabIndex == 0)
                Positioned(
                  left: worldMapHeaderHorizontalPadding,
                  right: worldMapHeaderHorizontalPadding,
                  top: top + worldMapHeaderTopPadding,
                  child: AnimatedBuilder(
                    animation:
                        _mainTabController.animation ?? _mainTabController,
                    builder: (context, _) {
                      if (_worldMainTabIndex != 0) {
                        return const SizedBox.shrink();
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WorldMapBackButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          if (world != null &&
                              (title.isNotEmpty ||
                                  resolvedWorldStatusLabel.isNotEmpty)) ...[
                            const SizedBox(width: worldMapHeaderTitleGap),
                            Expanded(
                              child: WorldMapIdentityPill(
                                title: title,
                                statusText: resolvedWorldStatusLabel,
                                maxWidth: maxIdentityWidth,
                              ),
                            ),
                          ],
                        ],
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
