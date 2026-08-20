part of 'origin_world_page.dart';

extension _OriginWorldPageMapShell on _OriginWorldPageState {
  Widget _buildPersistentMapOverlay(
    double top, {
    OriginDetail? origin,
    int locationCount = 0,
    bool tabsInteractive = true,
  }) {
    return Positioned(
      left: 18,
      right: 18,
      top: top + 12,
      child: WorldTopOverlayBar(
        pointsCount: locationCount,
        controller: _tabController,
        onInfoTap: _openOriginInfoSheet,
        secondaryTabIsIntro: true,
        tabsEnabled: tabsInteractive,
        title: origin == null
            ? ''
            : originDisplayName(origin.name, fallback: origin.oid),
        subtitle: origin == null ? '' : 'Not started',
      ),
    );
  }

  Widget _buildMapOnlyScaffold({
    required double topPadding,
    required Widget mapOverlay,
    required Widget map,
    Widget Function(double minChildSize)? bottomSheetOverlayBuilder,
    Widget? topOverlay,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _baseStatusBarStyle,
      child: Scaffold(
        backgroundColor: context.genesisColors.surfaceSheet,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final bottomSafeArea = GenesisSafeAreaInsets.bottom(
              context,
              minimum: originWorldDetailBottomSafeAreaMinimum,
            );
            final mapHeight = originWorldMapHeightFor(
              viewportHeight: viewportHeight,
              bottomSafeArea: bottomSafeArea,
            );
            final sheetHostHeight = viewportHeight;
            final sheetMinChildSize = sheetHostHeight <= 0
                ? _OriginDetailDraggableSheet.defaultInitialChildSize
                : ((sheetHostHeight - mapHeight + originWorldMapSheetOverlap) /
                          sheetHostHeight)
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
        origin: origin,
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
            decoration: _originDetailSheetDecoration(context),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: _originDetailSheetOutlineDecoration(context),
              child: ClipRRect(
                borderRadius: _originDetailSheetBorderRadius,
                child: Padding(
                  key: const ValueKey<String>(
                    'origin-detail-loading-bottom-safe-area',
                  ),
                  padding: EdgeInsets.only(
                    bottom: GenesisSafeAreaInsets.bottom(
                      context,
                      minimum: originWorldDetailBottomSafeAreaMinimum,
                    ),
                  ),
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
                              child: _OriginSheetPageIndicator(page: 0.0),
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
            height: _OriginSetupRoleSection._cardHeight,
            radius: 16,
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
        color: context.genesisOriginColors.loadingBone,
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
