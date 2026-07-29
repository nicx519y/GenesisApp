part of 'tilemap_renderer_library.dart';

class TilemapRenderer extends StatefulWidget {
  const TilemapRenderer({
    super.key,
    required this.config,
    this.onTileAction,
    this.locationNameForTile,
    this.locationAvatarsForTile,
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onMapTap,
    this.onImageError,
    this.visualMode = tilemapDefaultVisualMode,
    this.fogControlPoints = tilemapDefaultFogControlPoints,
    this.blendFogWithShadowTiles = tilemapDefaultBlendFogWithShadowTiles,
    this.showShadowZeroBorders = tilemapDefaultShowShadowZeroBorders,
    this.showLocationImageFlow = tilemapDefaultShowLocationImageFlow,
    this.locationImageFlowAngleDegrees =
        tilemapDefaultLocationImageFlowAngleDegrees,
    this.locationImageFlowGradientPoints =
        tilemapDefaultLocationImageFlowGradientPoints,
    this.locationImageFlowOpacity = tilemapDefaultLocationImageFlowOpacity,
    this.locationImageFlowDurationSeconds =
        tilemapDefaultLocationImageFlowDurationSeconds,
    this.locationImageFlowBlendMode = tilemapDefaultLocationImageFlowBlendMode,
    this.initialScaleFactor = tilemapDefaultInitialScaleFactor,
    this.dragBoundaryPaddingTiles = tilemapDefaultDragBoundaryPaddingTiles,
  });

  final TilemapConfig config;
  final TilemapTileActionHandler? onTileAction;
  final TilemapLocationNameResolver? locationNameForTile;
  final TilemapLocationAvatarsResolver? locationAvatarsForTile;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onMapTap;
  final ValueChanged<Object>? onImageError;
  final TilemapVisualMode visualMode;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool showShadowZeroBorders;
  final bool showLocationImageFlow;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final double locationImageFlowDurationSeconds;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
  final double initialScaleFactor;
  final double dragBoundaryPaddingTiles;

  @override
  State<TilemapRenderer> createState() => _TilemapRendererState();
}

class _TilemapRendererState extends State<TilemapRenderer>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _highlightController;
  late final AnimationController _locationImageFlowController;
  late final Animation<double> _highlightOpacity;
  Matrix4 _gestureStartTransform = Matrix4.identity();
  Offset _gestureStartFocalPoint = Offset.zero;
  Size? _lastViewportSize;
  Size? _lastMapSize;
  Rect? _lastContentBounds;
  double? _lastInitialScaleFactor;
  Rect? _lastDragBoundary;
  TilemapConfig? _renderIndexConfig;
  double? _renderIndexMapWidth;
  double? _renderIndexMapHeight;
  double? _renderIndexTileExtent;
  double? _renderIndexOriginX;
  _TilemapRenderIndex? _renderIndex;
  TilemapFogGeometry? _fogGeometry;
  Rect? _retainedSceneBounds;
  List<_TilemapRenderRecord> _retainedRecords = const [];
  List<TilemapCell> _retainedTiles = const [];
  Rect? _fogBounds;
  List<TilemapFogControlPoint>? _fogControlPoints;
  List<TilemapCell>? _fogRenderTiles;
  TilemapFogField? _fogField;
  bool _hasLocationImageFlowTiles = false;
  bool _locationImageFlowSyncScheduled = false;
  bool _hasUserTransformedMap = false;
  bool _isRunningTileAction = false;
  String? _highlightedTileKey;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _locationImageFlowController = AnimationController(
      vsync: this,
      duration: tilemapLocationImageFlowDurationForSeconds(
        widget.locationImageFlowDurationSeconds,
      ),
    );
    _highlightOpacity = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOutCubic,
    ).drive(Tween<double>(begin: 0.48, end: 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLocationImageFlowAnimation();
  }

  @override
  void didUpdateWidget(covariant TilemapRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showLocationImageFlow != widget.showLocationImageFlow) {
      _syncLocationImageFlowAnimation();
    }
    if (oldWidget.locationImageFlowDurationSeconds !=
        widget.locationImageFlowDurationSeconds) {
      _locationImageFlowController
        ..stop()
        ..duration = tilemapLocationImageFlowDurationForSeconds(
          widget.locationImageFlowDurationSeconds,
        );
      _syncLocationImageFlowAnimation();
    }
  }

  void _syncLocationImageFlowAnimation() {
    final shouldAnimate =
        widget.showLocationImageFlow &&
        _hasLocationImageFlowTiles &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate) {
      if (!_locationImageFlowController.isAnimating) {
        _locationImageFlowController.repeat(
          period: tilemapLocationImageFlowDurationForSeconds(
            widget.locationImageFlowDurationSeconds,
          ),
        );
      }
      return;
    }
    _locationImageFlowController
      ..stop()
      ..value = 0;
  }

  void _updateLocationImageFlowDemand(bool hasTiles) {
    if (_hasLocationImageFlowTiles == hasTiles) return;
    _hasLocationImageFlowTiles = hasTiles;
    if (_locationImageFlowSyncScheduled) return;
    _locationImageFlowSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationImageFlowSyncScheduled = false;
      if (mounted) _syncLocationImageFlowAnimation();
    });
  }

  @override
  void dispose() {
    _locationImageFlowController.dispose();
    _highlightController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final showLocationImageFlow =
        widget.showLocationImageFlow &&
        !MediaQuery.disableAnimationsOf(context);
    final visualStyle = tilemapVisualStyleFor(widget.visualMode);
    return ColoredBox(
      key: const ValueKey<String>('tilemap-renderer-background'),
      color: visualStyle.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final viewportHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final projection = TilemapProjection.fixed(
            mapWidth: widget.config.width,
            mapHeight: widget.config.height,
          );
          final renderIndex = _ensureRenderIndex(projection);
          final viewportSize = Size(viewportWidth, viewportHeight);
          final mapSize = Size(projection.mapWidth, projection.mapHeight);
          final contentBounds = projection.imageBoundsForTiles(
            tilemapInitialContentTiles(widget.config.tiles),
          );
          final dragBoundary = tilemapDragBoundaryForShadowTiles(
            projection: projection,
            tiles: widget.config.tiles,
            paddingTiles: widget.dragBoundaryPaddingTiles,
          );
          _syncInitialTransform(
            viewportSize: viewportSize,
            mapSize: mapSize,
            contentBounds: contentBounds,
            initialScaleFactor: widget.initialScaleFactor,
            dragBoundary: dragBoundary,
          );
          return SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: GestureDetector(
                      key: const ValueKey<String>('tilemap-gesture-layer'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _hasUserTransformedMap = true;
                        _gestureStartTransform = _transformationController.value
                            .clone();
                        _gestureStartFocalPoint = details.localFocalPoint;
                      },
                      onScaleUpdate: (details) {
                        final gestureTransform = tilemapGestureTransform(
                          startTransform: _gestureStartTransform,
                          startFocalPoint: _gestureStartFocalPoint,
                          currentFocalPoint: details.localFocalPoint,
                          gestureScale: details.scale,
                        );
                        _transformationController.value =
                            tilemapConstrainTransformToBoundary(
                              transform: gestureTransform,
                              viewportSize: viewportSize,
                              sceneBoundary: dragBoundary,
                            );
                      },
                      onTapUp: (details) {
                        widget.onMapTap?.call();
                        unawaited(
                          _handleTap(details.localPosition, projection),
                        );
                      },
                      child: ValueListenableBuilder<Matrix4>(
                        valueListenable: _transformationController,
                        builder: (context, matrix, _) {
                          final scale = tilemapTransformScale(matrix);
                          final tilePixelSize = projection.tilePixelSize(
                            scale: scale,
                            devicePixelRatio: devicePixelRatio,
                          );
                          final visibleSceneBounds = tilemapVisibleSceneBounds(
                            transform: matrix,
                            viewportSize: viewportSize,
                          );
                          final records = _resolveRetainedRecords(
                            renderIndex: renderIndex,
                            visibleSceneBounds: visibleSceneBounds,
                          );
                          final tiles = _retainedTiles;
                          final fogBounds = _retainedSceneBounds!.inflate(
                            projection.tileExtent /
                                tilemapFogSamplesPerTileExtent,
                          );
                          final fogField = !renderIndex.hasFogTiles
                              ? null
                              : _resolveFogField(
                                  projection: projection,
                                  fogBounds: fogBounds,
                                );
                          final locationLabels = <_TilemapLocationLabelData>[];
                          final locationImageFlowTileKeys = <String>{};
                          for (final tile in tiles) {
                            if (!tile.isLocationTile) continue;
                            final name =
                                widget.locationNameForTile
                                    ?.call(tile)
                                    ?.trim() ??
                                '';
                            if (name.isEmpty) continue;
                            if (!tile.hasShadow) {
                              locationImageFlowTileKeys.add(tile.cellKey);
                            }
                            locationLabels.add(
                              _TilemapLocationLabelData(
                                tile: tile,
                                name: name,
                                avatars:
                                    widget.locationAvatarsForTile?.call(tile) ??
                                    const <UserAvatar>[],
                              ),
                            );
                          }
                          _updateLocationImageFlowDemand(
                            showLocationImageFlow &&
                                locationImageFlowTileKeys.isNotEmpty,
                          );
                          return AnimatedBuilder(
                            animation: _highlightController,
                            builder: (context, _) {
                              final highlightedTile = _highlightedTile(
                                tiles,
                                _highlightOpacity.value,
                              );
                              final visibleCharacterIds = <String>{
                                for (final label in locationLabels)
                                  for (final avatar in label.avatars)
                                    if (avatar.id.trim().isNotEmpty)
                                      avatar.id.trim(),
                              };
                              return TilemapMessageBubblePlayback(
                                messageBubbles: widget.messageBubbles,
                                visibleCharacterIds: visibleCharacterIds,
                                paused: widget.messageBubblePlaybackPaused,
                                builder: (context, activeBubble) {
                                  _TilemapLocationLabelData? activeBubbleLabel;
                                  var activeBubbleAvatarIndex = -1;
                                  if (activeBubble != null) {
                                    for (final label in locationLabels) {
                                      final avatarIndex = label.avatars
                                          .indexWhere(
                                            (avatar) =>
                                                avatar.id.trim() ==
                                                activeBubble.characterId.trim(),
                                          );
                                      if (avatarIndex < 0) continue;
                                      activeBubbleLabel = label;
                                      activeBubbleAvatarIndex = avatarIndex;
                                      break;
                                    }
                                  }
                                  final activeBubbleLocationAnchor =
                                      activeBubbleLabel == null
                                      ? null
                                      : MatrixUtils.transformPoint(
                                          matrix,
                                          tilemapLocationBubbleSceneAnchor(
                                            projection,
                                            activeBubbleLabel.tile,
                                          ),
                                        );
                                  final activeBubbleAvatarTopLeft =
                                      activeBubbleLocationAnchor == null
                                      ? null
                                      : tilemapMessageBubbleAvatarTopLeft(
                                          locationBubbleAnchor:
                                              activeBubbleLocationAnchor,
                                          avatarIndex: activeBubbleAvatarIndex,
                                          avatarCount:
                                              activeBubbleLabel!.avatars.length,
                                        );
                                  return Stack(
                                    fit: StackFit.expand,
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(
                                          key: const ValueKey<String>(
                                            'tilemap-grid',
                                          ),
                                          painter: _TilemapInfiniteGridPainter(
                                            projection: projection,
                                            scale: scale,
                                            translation: Offset(
                                              matrix.getTranslation().x,
                                              matrix.getTranslation().y,
                                            ),
                                            lineColor:
                                                visualStyle.gridLineColor,
                                          ),
                                        ),
                                      ),
                                      if (renderIndex.hasFogTiles)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            key: const ValueKey<String>(
                                              'tilemap-fog-layer',
                                            ),
                                            child: Transform(
                                              transform: matrix,
                                              alignment: Alignment.topLeft,
                                              child: SizedBox(
                                                width: projection.mapWidth,
                                                height: projection.mapHeight,
                                                child: CustomPaint(
                                                  key: const ValueKey<String>(
                                                    'tilemap-fog-paint',
                                                  ),
                                                  painter: _TilemapFogPainter(
                                                    fogField!,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Transform(
                                        key: const ValueKey<String>(
                                          'tilemap-tile-transform',
                                        ),
                                        transform: matrix,
                                        alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: projection.mapWidth,
                                          height: projection.mapHeight,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              for (final record in records)
                                                _ProjectedTile(
                                                  key: ValueKey<String>(
                                                    'tile-${record.tile.x}-'
                                                    '${record.tile.y}',
                                                  ),
                                                  tile: record.tile,
                                                  asset:
                                                      resolveTilemapAssetForDisplaySize(
                                                        widget.config
                                                            .baseAssetUrlForTile(
                                                              record.tile,
                                                            ),
                                                        tilePixelSize,
                                                      ),
                                                  topLeft: record.imageTopLeft,
                                                  extent: projection.tileExtent,
                                                  locationImageFlowAnimation:
                                                      showLocationImageFlow &&
                                                          locationImageFlowTileKeys
                                                              .contains(
                                                                record
                                                                    .tile
                                                                    .cellKey,
                                                              )
                                                      ? _locationImageFlowController
                                                      : null,
                                                  locationImageFlowPhase:
                                                      tilemapLocationImageFlowPhase(
                                                        record.tile,
                                                      ),
                                                  locationImageFlowAngleDegrees:
                                                      widget
                                                          .locationImageFlowAngleDegrees,
                                                  locationImageFlowGradientPoints:
                                                      widget
                                                          .locationImageFlowGradientPoints,
                                                  locationImageFlowOpacity: widget
                                                      .locationImageFlowOpacity,
                                                  locationImageFlowBlendMode: widget
                                                      .locationImageFlowBlendMode,
                                                  fogField:
                                                      widget.blendFogWithShadowTiles &&
                                                          record.tile.hasShadow
                                                      ? fogField
                                                      : null,
                                                  onImageError:
                                                      widget.onImageError,
                                                ),
                                              if (highlightedTile != null)
                                                _ProjectedTileHighlight(
                                                  key: ValueKey<String>(
                                                    'tile-highlight-${highlightedTile.x}-${highlightedTile.y}',
                                                  ),
                                                  tile: highlightedTile,
                                                  projection: projection,
                                                  opacity:
                                                      _highlightOpacity.value,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (widget.showShadowZeroBorders &&
                                          renderIndex.hasShadowZeroTiles)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            key: const ValueKey<String>(
                                              'tilemap-shadow-zero-border-layer',
                                            ),
                                            child: Transform(
                                              transform: matrix,
                                              alignment: Alignment.topLeft,
                                              child: SizedBox(
                                                width: projection.mapWidth,
                                                height: projection.mapHeight,
                                                child: CustomPaint(
                                                  key: const ValueKey<String>(
                                                    'tilemap-shadow-zero-border-paint',
                                                  ),
                                                  painter:
                                                      _TilemapShadowZeroBorderPainter(
                                                        projection: projection,
                                                        tiles: tiles,
                                                        scale: scale,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      for (final label in locationLabels)
                                        _TilemapLocationBubble(
                                          key: ValueKey<String>(
                                            'tile-location-label-'
                                            '${label.tile.x}-${label.tile.y}',
                                          ),
                                          name: label.name,
                                          avatars: label.avatars,
                                          onLabelTap:
                                              widget.onTileAction == null
                                              ? null
                                              : () => _handleOverlayTileTap(
                                                  label.tile,
                                                ),
                                          onAvatarTap:
                                              widget.onTileAction == null
                                              ? null
                                              : () => _handleOverlayTileTap(
                                                  label.tile,
                                                ),
                                          anchor: MatrixUtils.transformPoint(
                                            matrix,
                                            tilemapLocationBubbleSceneAnchor(
                                              projection,
                                              label.tile,
                                            ),
                                          ),
                                        ),
                                      if (activeBubble != null &&
                                          activeBubbleLabel != null &&
                                          activeBubbleAvatarTopLeft != null)
                                        TilemapCharacterMessageBubble(
                                          text: activeBubble.content,
                                          avatarTopLeft:
                                              activeBubbleAvatarTopLeft,
                                          viewportWidth: viewportSize.width,
                                          onTap: widget.onTileAction == null
                                              ? null
                                              : () => _handleOverlayTileTap(
                                                  activeBubbleLabel!.tile,
                                                ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: legacyWorldMapZoomControlRightGap,
                  bottom: legacyWorldMapZoomControlBottomGap,
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, matrix, child) {
                      final scale = tilemapTransformScale(matrix);
                      return LegacyWorldMapZoomControl(
                        canZoomIn: scale < tilemapMaxScale - 0.001,
                        canZoomOut: scale > tilemapMinScale + 0.001,
                        onZoomIn: () => _zoomByControl(
                          zoomIn: true,
                          viewportSize: viewportSize,
                          dragBoundary: dragBoundary,
                        ),
                        onZoomOut: () => _zoomByControl(
                          zoomIn: false,
                          viewportSize: viewportSize,
                          dragBoundary: dragBoundary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _TilemapRenderIndex _ensureRenderIndex(TilemapProjection projection) {
    final existing = _renderIndex;
    if (existing != null &&
        identical(_renderIndexConfig, widget.config) &&
        _renderIndexMapWidth == projection.mapWidth &&
        _renderIndexMapHeight == projection.mapHeight &&
        _renderIndexTileExtent == projection.tileExtent &&
        _renderIndexOriginX == projection.originX) {
      return existing;
    }

    final index = _TilemapRenderIndex(
      projection: projection,
      tiles: widget.config.tiles,
    );
    _renderIndexConfig = widget.config;
    _renderIndexMapWidth = projection.mapWidth;
    _renderIndexMapHeight = projection.mapHeight;
    _renderIndexTileExtent = projection.tileExtent;
    _renderIndexOriginX = projection.originX;
    _renderIndex = index;
    _fogGeometry = index.hasFogTiles
        ? prepareTilemapFogGeometry(
            tiles: widget.config.tiles,
            polygonForTile: projection.polygonForTile,
            tileExtent: projection.tileExtent,
            verticalScale: projection.tileDiamondWidthToHeightRatio,
          )
        : null;
    _retainedSceneBounds = null;
    _retainedRecords = const [];
    _retainedTiles = const [];
    _fogBounds = null;
    _fogControlPoints = null;
    _fogRenderTiles = null;
    _fogField = null;
    return index;
  }

  List<_TilemapRenderRecord> _resolveRetainedRecords({
    required _TilemapRenderIndex renderIndex,
    required Rect visibleSceneBounds,
  }) {
    final retainedBounds = _retainedSceneBounds;
    if (retainedBounds != null &&
        _rectContainsRect(retainedBounds, visibleSceneBounds)) {
      return _retainedRecords;
    }

    final nextBounds = tilemapRetainedSceneBounds(visibleSceneBounds);
    final nextRecords = renderIndex.query(nextBounds);
    _retainedSceneBounds = nextBounds;
    _retainedRecords = nextRecords;
    _retainedTiles = List<TilemapCell>.unmodifiable(
      nextRecords.map((record) => record.tile),
    );
    return nextRecords;
  }

  TilemapFogField _resolveFogField({
    required TilemapProjection projection,
    required Rect fogBounds,
  }) {
    if (_fogBounds == fogBounds &&
        identical(_fogControlPoints, widget.fogControlPoints) &&
        identical(_fogRenderTiles, _retainedTiles) &&
        _fogField != null) {
      return _fogField!;
    }
    final field = buildTilemapFogField(
      fieldBounds: fogBounds,
      tiles: widget.config.tiles,
      polygonForTile: projection.polygonForTile,
      imageBoundsForTile: (tile) =>
          projection.imageTopLeftForTile(tile) &
          Size.square(projection.tileExtent),
      tileExtent: projection.tileExtent,
      tileDiamondWidth: projection.tileDiamondWidth,
      tileDiamondHeight: projection.tileDiamondHeight,
      verticalScale: projection.tileDiamondWidthToHeightRatio,
      controlPoints: widget.fogControlPoints,
      geometry: _fogGeometry,
      renderTiles: _retainedTiles,
    );
    _fogBounds = fogBounds;
    _fogControlPoints = widget.fogControlPoints;
    _fogRenderTiles = _retainedTiles;
    _fogField = field;
    return field;
  }

  TilemapCell? _highlightedTile(List<TilemapCell> sortedTiles, double opacity) {
    final highlightedTileKey = _highlightedTileKey;
    if (highlightedTileKey == null || opacity <= 0.001) return null;
    for (final tile in sortedTiles) {
      if (tile.cellKey == highlightedTileKey) return tile;
    }
    return null;
  }

  Future<void> _handleTap(
    Offset localPosition,
    TilemapProjection projection,
  ) async {
    if (_isRunningTileAction) return;
    final scenePosition = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformationController.value),
      localPosition,
    );
    final renderIndex = _ensureRenderIndex(projection);
    final candidates = renderIndex.queryPoint(scenePosition);
    for (final record in candidates.reversed) {
      final tile = record.tile;
      if (!tile.isLocationTile) continue;
      if (!projection.containsPointInTile(tile, scenePosition)) continue;
      setState(() {
        _highlightedTileKey = tile.cellKey;
      });
      _highlightController.forward(from: 0);
      await _runTileAction(tile);
      return;
    }
  }

  Future<void> _runTileAction(TilemapCell tile) async {
    final onTileAction = widget.onTileAction;
    if (onTileAction == null) return;
    _isRunningTileAction = true;
    try {
      await onTileAction(tile);
    } finally {
      _isRunningTileAction = false;
    }
  }

  void _handleOverlayTileTap(TilemapCell tile) {
    if (_isRunningTileAction) return;
    unawaited(_runTileAction(tile));
  }

  void _syncInitialTransform({
    required Size viewportSize,
    required Size mapSize,
    required Rect contentBounds,
    required double initialScaleFactor,
    required Rect? dragBoundary,
  }) {
    final dragBoundaryChanged = _lastDragBoundary != dragBoundary;
    if (_lastViewportSize == viewportSize &&
        _lastMapSize == mapSize &&
        _lastContentBounds == contentBounds &&
        _lastInitialScaleFactor == initialScaleFactor &&
        !dragBoundaryChanged) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    _lastContentBounds = contentBounds;
    _lastInitialScaleFactor = initialScaleFactor;
    _lastDragBoundary = dragBoundary;
    if (_hasUserTransformedMap) {
      if (dragBoundaryChanged) {
        _transformationController.value = tilemapConstrainTransformToBoundary(
          transform: _transformationController.value,
          viewportSize: viewportSize,
          sceneBoundary: dragBoundary,
        );
      }
      return;
    }
    final initialTransform = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: mapSize,
      contentBounds: contentBounds,
      initialScaleFactor: initialScaleFactor,
    );
    _transformationController.value = tilemapConstrainTransformToBoundary(
      transform: initialTransform,
      viewportSize: viewportSize,
      sceneBoundary: dragBoundary,
    );
  }

  void _zoomByControl({
    required bool zoomIn,
    required Size viewportSize,
    required Rect? dragBoundary,
  }) {
    _hasUserTransformedMap = true;
    final currentTransform = _transformationController.value;
    final currentScale = tilemapTransformScale(currentTransform);
    final targetScale =
        (zoomIn
                ? currentScale * tilemapZoomControlScaleFactor
                : currentScale / tilemapZoomControlScaleFactor)
            .clamp(tilemapMinScale, tilemapMaxScale)
            .toDouble();
    if ((targetScale - currentScale).abs() < 0.001) return;
    final viewportCenter = viewportSize.center(Offset.zero);
    final sceneCenter = MatrixUtils.transformPoint(
      Matrix4.inverted(currentTransform),
      viewportCenter,
    );
    final nextTransform = tilemapTransformForSceneFocalPoint(
      sceneFocalPoint: sceneCenter,
      viewportFocalPoint: viewportCenter,
      scale: targetScale,
    );
    _transformationController.value = tilemapConstrainTransformToBoundary(
      transform: nextTransform,
      viewportSize: viewportSize,
      sceneBoundary: dragBoundary,
    );
  }
}
