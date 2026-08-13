part of 'origin_world_page.dart';

extension _OriginWorldPageMapShell on _OriginWorldPageState {
  Widget _buildPersistentMapOverlay(
    double top, {
    int locationCount = 0,
    bool tabsInteractive = true,
  }) {
    return Positioned(
      left: 12,
      right: 60,
      top: top + 8,
      child: WorldTopOverlayBar(
        pointsCount: locationCount,
        controller: _tabController,
        onTabTap: _handleMapModeTabTap,
        secondaryTabIsIntro: true,
        tabsEnabled: tabsInteractive,
      ),
    );
  }

  Widget _buildMapOnlyScaffold({
    required double topPadding,
    required Widget mapOverlay,
    required Widget map,
    Widget Function(double minChildSize)? bottomSheetOverlayBuilder,
    Widget? bottomOverlay,
    Widget? topOverlay,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _baseStatusBarStyle,
      child: Scaffold(
        backgroundColor: originWorldDetailSheetBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final bottomSafeArea = GenesisSafeAreaInsets.bottom(context);
            final mapHeight = originWorldMapHeightFor(
              viewportHeight: viewportHeight,
              bottomSafeArea: bottomSafeArea,
            );
            final sheetHostHeight = viewportHeight;
            final sheetMinChildSize = sheetHostHeight <= 0
                ? _OriginDetailDraggableSheet.defaultInitialChildSize
                : ((sheetHostHeight - mapHeight) / sheetHostHeight)
                      .clamp(0.08, 0.42)
                      .toDouble();
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    key: const ValueKey<String>('origin-map-viewport'),
                    width: double.infinity,
                    height: mapHeight,
                    child: map,
                  ),
                ),
                mapOverlay,
                if (bottomSheetOverlayBuilder != null)
                  Positioned.fill(
                    child: bottomSheetOverlayBuilder(sheetMinChildSize),
                  ),
                if (bottomOverlay != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: bottomOverlay,
                  ),
                if (topOverlay != null) topOverlay,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInitialLoadingScaffold(
    double topPadding, {
    OriginDetail? origin,
  }) {
    final hasInitialDialogue =
        origin != null && _originHasInitialDialogueLoadingContent(origin);
    return _buildMapOnlyScaffold(
      topPadding: topPadding,
      mapOverlay: _buildPersistentMapOverlay(
        topPadding,
        tabsInteractive: false,
      ),
      map: ColoredBox(
        key: const ValueKey<String>('origin-map-loading-background'),
        color: _tilemapLoadingBackgroundColor,
      ),
      bottomSheetOverlayBuilder: (minChildSize) => _OriginDetailLoadingSheet(
        minChildSize: minChildSize,
        hasInitialDialogue: hasInitialDialogue,
      ),
      bottomOverlay: const _OriginBottomLaunchBarLoading(),
    );
  }
}

bool _originHasInitialDialogueLoadingContent(OriginDetail origin) {
  final locationIds = <String>{
    for (final location in origin.allLocations)
      if (location.locationId.trim().isNotEmpty) location.locationId.trim(),
  };
  if (locationIds.isEmpty) return false;

  final initLocationGroup = origin.initLocationGroup;
  if (initLocationGroup != null &&
      locationIds.contains(initLocationGroup.locationId.trim()) &&
      initLocationGroup.initialDialogue.any(
        (line) => line.content.trim().isNotEmpty,
      )) {
    return true;
  }

  for (final tick in origin.ticks) {
    final result = tick['tick_result'] is Map
        ? (tick['tick_result'] as Map).cast<String, dynamic>()
        : tick;
    final groups = result['location_groups'] ?? tick['location_groups'];
    if (groups is! List) continue;
    for (final rawGroup in groups.whereType<Map>()) {
      final group = rawGroup.cast<String, dynamic>();
      final locationId = _mapString(group, const [
        'location_id',
        'loc_id',
        'id',
      ]);
      if (!locationIds.contains(locationId)) continue;
      final dialogue =
          group['initial_dialogue'] ??
          group['initialDialogue'] ??
          group['dialogue'];
      if (dialogue is! List) continue;
      final hasContent = dialogue.whereType<Map>().any(
        (rawLine) => _mapString(rawLine, const ['content', 'text']).isNotEmpty,
      );
      if (hasContent) return true;
    }
  }
  return false;
}

class _OriginDetailLoadingSheet extends StatelessWidget {
  const _OriginDetailLoadingSheet({
    required this.minChildSize,
    required this.hasInitialDialogue,
  });

  final double minChildSize;
  final bool hasInitialDialogue;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: minChildSize,
          child: DecoratedBox(
            key: const ValueKey<String>('origin-detail-loading-sheet'),
            decoration: const BoxDecoration(
              color: originWorldDetailSheetBackgroundColor,
              borderRadius: GenesisRadii.sheet,
            ),
            child: ClipRRect(
              borderRadius: GenesisRadii.sheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: originDetailSheetHeaderHeightForTesting,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: originDetailSheetHandleTopOffsetForTesting,
                          child: _OriginSheetDragHandle(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: hasInitialDialogue
                        ? const _OriginInitialDialogueLoadingContent()
                        : const _OriginRoleSetupLoadingContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginInitialDialogueLoadingContent extends StatelessWidget {
  const _OriginInitialDialogueLoadingContent();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OriginLoadingBone(
                key: ValueKey<String>('origin-loading-dialogue-icon'),
                width: 16,
                height: 16,
                radius: 8,
              ),
              SizedBox(width: 4),
              _OriginLoadingBone(width: 124, height: 16),
            ],
          ),
          SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OriginLoadingBone(
                key: ValueKey<String>('origin-loading-dialogue-avatar'),
                width: 40,
                height: 40,
                radius: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OriginLoadingBone(width: 92, height: 11),
                    SizedBox(height: 6),
                    _OriginLoadingBone(
                      widthFactor: 0.78,
                      height: 32,
                      radius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OriginRoleSetupLoadingContent extends StatelessWidget {
  const _OriginRoleSetupLoadingContent();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(10, 10, 10, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OriginLoadingBone(width: 126, height: 19),
          SizedBox(height: 16),
          _OriginLoadingBone(
            key: ValueKey<String>('origin-loading-role-card'),
            width: _OriginSetupRoleSection._cardWidth,
            height:
                _OriginSetupRoleSection._cardWidth +
                _OriginSetupRoleSection._buttonHeight,
            radius: 12,
          ),
        ],
      ),
    );
  }
}

class _OriginLoadingBone extends StatelessWidget {
  const _OriginLoadingBone({
    super.key,
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bone = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD9DDE2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return bone;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: bone,
    );
  }
}

class _OriginBottomLaunchBarLoading extends StatelessWidget {
  const _OriginBottomLaunchBarLoading();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      key: const ValueKey<String>('origin-bottom-launch-loading'),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: originWorldDetailSheetBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: GenesisBottomSafePadding(
            minimum: GenesisBottomNavigation.minBottomPadding,
            child: const SizedBox(
              height: GenesisBottomNavigation.defaultHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _OriginLoadingBone(width: 128, height: 19),
                    ),
                  ),
                  SizedBox(width: 18),
                  _OriginLoadingBone(
                    key: ValueKey<String>('origin-loading-launch-button'),
                    width: 140,
                    height: 35,
                    radius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginBottomLaunchBar extends StatelessWidget {
  const _OriginBottomLaunchBar({
    required this.origin,
    required this.launching,
    required this.onLaunch,
  });

  static double heightFor(BuildContext context) {
    return GenesisBottomNavigation.defaultHeight +
        GenesisSafeAreaInsets.bottom(
          context,
          minimum: GenesisBottomNavigation.minBottomPadding,
        );
  }

  final OriginDetail origin;
  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('origin-bottom-launch-blur'),
      decoration: const BoxDecoration(
        color: originWorldDetailSheetBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: GenesisBottomSafePadding(
          minimum: GenesisBottomNavigation.minBottomPadding,
          child: SizedBox(
            height: GenesisBottomNavigation.defaultHeight,
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      originDisplayName(origin.name, fallback: origin.oid),
                      key: const ValueKey<String>('origin-bottom-origin-name'),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B6192),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                GenesisPrimaryButton(
                  label: 'Launch',
                  leadingIcon: SvgPicture.asset(
                    launchIconAsset,
                    key: const ValueKey<String>('origin-bottom-launch-icon'),
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  iconGap: 6,
                  onPressed: launching ? null : onLaunch,
                  width: 140,
                  height: 35,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  isLoading: launching,
                  loadingSize: 22,
                  loadingStrokeWidth: 2.4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
