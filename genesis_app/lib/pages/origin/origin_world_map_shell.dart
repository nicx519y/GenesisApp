part of 'origin_world_page.dart';

extension _OriginWorldPageMapShell on _OriginWorldPageState {
  Widget _buildPersistentMapOverlay(double top, {OriginDetail? origin}) {
    return Positioned(
      left: 12,
      right: 12,
      top: top + 8,
      child: _OriginWorldNameOverlay(
        worldoName: origin == null
            ? originDisplayName(widget.initialName)
            : originDisplayName(origin.name, fallback: origin.oid),
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
        backgroundColor: originWorldDetailSheetBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final bottomSafeArea = GenesisSafeAreaInsets.bottom(context);
            final sheetTop = originWorldMapHeightFor(
              viewportHeight: viewportHeight,
              bottomSafeArea: bottomSafeArea,
            );
            final mapHeight = originWorldRenderedMapHeightFor(
              viewportHeight: viewportHeight,
              bottomSafeArea: bottomSafeArea,
            );
            final sheetHostHeight = viewportHeight;
            final sheetMinChildSize = sheetHostHeight <= 0
                ? _OriginDetailDraggableSheet.defaultInitialChildSize
                : ((sheetHostHeight - sheetTop) / sheetHostHeight)
                      .clamp(0.08, 1.0)
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
      mapOverlay: _buildPersistentMapOverlay(topPadding, origin: origin),
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

class _OriginWorldNameOverlay extends StatelessWidget {
  const _OriginWorldNameOverlay({required this.worldoName});

  final String worldoName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('origin-top-overlay-bar'),
      height: genesisSearchFieldHeight,
      child: Row(
        children: [
          GenesisMapGlassBackButton(
            dimension: genesisSearchFieldHeight,
            onPressed: () => Navigator.of(context).maybePop(),
            glassKey: const ValueKey<String>('origin-top-back-glass'),
            surfaceKey: const ValueKey<String>('origin-top-back-surface'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                worldoName,
                key: const ValueKey<String>('origin-top-worldo-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
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
