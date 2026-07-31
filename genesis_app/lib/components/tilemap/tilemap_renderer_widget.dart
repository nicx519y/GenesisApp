part of 'tilemap_renderer_library.dart';

class TilemapRenderer extends StatefulWidget {
  const TilemapRenderer({
    super.key,
    required this.config,
    this.initialTransform,
    this.onTransformChanged,
    this.onTileAction,
    this.locationNameForTile,
    this.locationAvatarsForTile,
    this.showRecentChatForTile,
    this.preferredFocusLocationId = '',
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.onMapTap,
    this.onImageError,
    this.onViewportReady,
    this.waitForVisibleTileImageFrames = true,
    this.isForeground = true,
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
    this.initialScale = tilemapDefaultInitialScale,
    this.dragBoundaryPaddingTiles = tilemapDefaultDragBoundaryPaddingTiles,
  });

  final TilemapConfig config;
  final Matrix4? initialTransform;
  final ValueChanged<Matrix4>? onTransformChanged;
  final TilemapTileActionHandler? onTileAction;
  final TilemapLocationNameResolver? locationNameForTile;
  final TilemapLocationAvatarsResolver? locationAvatarsForTile;
  final TilemapRecentChatResolver? showRecentChatForTile;
  final String preferredFocusLocationId;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final VoidCallback? onMapTap;
  final ValueChanged<Object>? onImageError;
  final VoidCallback? onViewportReady;
  final bool waitForVisibleTileImageFrames;
  final bool isForeground;
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
  final double initialScale;
  final double dragBoundaryPaddingTiles;

  @override
  State<TilemapRenderer> createState() => _TilemapRendererState();
}

class _TilemapRendererState extends State<TilemapRenderer>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _locationImageFlowController;
  Matrix4 _gestureStartTransform = Matrix4.identity();
  Offset _gestureStartFocalPoint = Offset.zero;
  Size? _lastViewportSize;
  Size? _lastMapSize;
  Rect? _lastContentBounds;
  double? _lastInitialScale;
  Offset? _lastInitialFocus;
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
  Set<String>? _initialViewportTileKeys;
  final Set<String> _initialViewportFramedTileKeys = <String>{};
  final List<VoidCallback> _notifiedViewportReadyCallbacks = <VoidCallback>[];
  bool _viewportReadyCallbackScheduled = false;
  bool _isViewportReady = false;
  int _viewportReadyGeneration = 0;
  bool _hasViewportReadinessEnvironment = false;
  Size? _viewportReadinessSize;
  double? _viewportReadinessDevicePixelRatio;
  double? _viewportReadinessInitialScale;
  Offset? _viewportReadinessInitialFocus;
  Rect? _viewportReadinessDragBoundary;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController(
      widget.initialTransform?.clone(),
    )..addListener(_handleTransformChanged);
    _hasUserTransformedMap = widget.initialTransform != null;
    _locationImageFlowController = AnimationController(
      vsync: this,
      duration: tilemapLocationImageFlowDurationForSeconds(
        widget.locationImageFlowDurationSeconds,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLocationImageFlowAnimation();
  }

  @override
  void didUpdateWidget(covariant TilemapRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config)) {
      _resetViewportReadiness();
    } else if (!identical(oldWidget.onViewportReady, widget.onViewportReady) &&
        _isViewportReady) {
      _scheduleViewportReadyCallback();
    }
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
    _handleTransformChanged();
    _locationImageFlowController.dispose();
    _transformationController
      ..removeListener(_handleTransformChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    widget.onTransformChanged?.call(_transformationController.value.clone());
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
          final initialFocusTile = tilemapInitialFocusLocationTile(
            tiles: widget.config.tiles,
            locationAvatarsForTile: widget.locationAvatarsForTile,
            preferredLocationId: widget.preferredFocusLocationId,
          );
          final initialFocus = initialFocusTile == null
              ? null
              : projection.centerForTile(initialFocusTile);
          final dragBoundary = tilemapDragBoundaryForShadowTiles(
            projection: projection,
            tiles: widget.config.tiles,
            paddingTiles: widget.dragBoundaryPaddingTiles,
          );
          _syncViewportReadinessEnvironment(
            viewportSize: viewportSize,
            devicePixelRatio: devicePixelRatio,
            initialScale: widget.initialScale,
            initialFocus: initialFocus,
            dragBoundary: dragBoundary,
          );
          _syncInitialTransform(
            viewportSize: viewportSize,
            mapSize: mapSize,
            contentBounds: contentBounds,
            initialFocus: initialFocus,
            initialScale: widget.initialScale,
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
                          _captureInitialViewportTiles(
                            records: records,
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
                                showRecentChat:
                                    widget.showRecentChatForTile?.call(tile) ??
                                    false,
                                verticalOverflow:
                                    _tilemapLocationLabelVerticalOverflow(
                                      context,
                                      name,
                                    ),
                              ),
                            );
                          }
                          _updateLocationImageFlowDemand(
                            showLocationImageFlow &&
                                locationImageFlowTileKeys.isNotEmpty,
                          );
                          return Builder(
                            builder: (context) {
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
                                          locationLabelVerticalOverflow:
                                              activeBubbleLabel
                                                  .verticalOverflow,
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
                                                  onImageFrame: () =>
                                                      _handleTileImageFrame(
                                                        record.tile.cellKey,
                                                      ),
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
                                          showRecentChat: label.showRecentChat,
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
                                          preservePageWidth:
                                              activeBubble.preservePageWidth,
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

  void _resetViewportReadiness() {
    _viewportReadyGeneration += 1;
    _initialViewportTileKeys = null;
    _initialViewportFramedTileKeys.clear();
    _notifiedViewportReadyCallbacks.clear();
    _viewportReadyCallbackScheduled = false;
    _isViewportReady = false;
  }

  void _syncViewportReadinessEnvironment({
    required Size viewportSize,
    required double devicePixelRatio,
    required double initialScale,
    required Offset? initialFocus,
    required Rect? dragBoundary,
  }) {
    final environmentChanged =
        _hasViewportReadinessEnvironment &&
        (_viewportReadinessSize != viewportSize ||
            _viewportReadinessDevicePixelRatio != devicePixelRatio ||
            _viewportReadinessInitialScale != initialScale ||
            _viewportReadinessInitialFocus != initialFocus ||
            _viewportReadinessDragBoundary != dragBoundary);
    _hasViewportReadinessEnvironment = true;
    _viewportReadinessSize = viewportSize;
    _viewportReadinessDevicePixelRatio = devicePixelRatio;
    _viewportReadinessInitialScale = initialScale;
    _viewportReadinessInitialFocus = initialFocus;
    _viewportReadinessDragBoundary = dragBoundary;
    if (environmentChanged) _resetViewportReadiness();
  }

  void _captureInitialViewportTiles({
    required List<_TilemapRenderRecord> records,
    required Rect visibleSceneBounds,
  }) {
    if (_initialViewportTileKeys != null) {
      if (!widget.waitForVisibleTileImageFrames) {
        _scheduleViewportReadyCallback();
      }
      return;
    }

    _initialViewportTileKeys = <String>{
      for (final record in records)
        if (_rectsOverlapWithVisibleArea(
          record.imageBounds,
          visibleSceneBounds,
        ))
          record.tile.cellKey,
    };
    if (!widget.waitForVisibleTileImageFrames ||
        _initialViewportTileKeys!.isEmpty) {
      _scheduleViewportReadyCallback();
    }
  }

  bool _rectsOverlapWithVisibleArea(Rect first, Rect second) {
    final intersection = first.intersect(second);
    return intersection.width > 0 && intersection.height > 0;
  }

  void _handleTileImageFrame(String tileKey) {
    if (_isViewportReady || !widget.waitForVisibleTileImageFrames) {
      return;
    }
    final initialTileKeys = _initialViewportTileKeys;
    if (initialTileKeys == null || !initialTileKeys.contains(tileKey)) return;
    if (!_initialViewportFramedTileKeys.add(tileKey)) return;
    if (_initialViewportFramedTileKeys.containsAll(initialTileKeys)) {
      _scheduleViewportReadyCallback();
    }
  }

  void _scheduleViewportReadyCallback() {
    if (_viewportReadyCallbackScheduled) return;
    _viewportReadyCallbackScheduled = true;
    final generation = _viewportReadyGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _viewportReadyGeneration) return;
      _viewportReadyCallbackScheduled = false;
      final initialTileKeys = _initialViewportTileKeys;
      if (initialTileKeys == null) return;
      if (!_isViewportReady &&
          widget.waitForVisibleTileImageFrames &&
          initialTileKeys.isNotEmpty &&
          !_initialViewportFramedTileKeys.containsAll(initialTileKeys)) {
        return;
      }
      _isViewportReady = true;
      final callback = widget.onViewportReady;
      if (callback == null ||
          _notifiedViewportReadyCallbacks.any(
            (notifiedCallback) => identical(notifiedCallback, callback),
          )) {
        return;
      }
      _notifiedViewportReadyCallbacks.add(callback);
      callback();
    });
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
    widget.onMapTap?.call();
    unawaited(_runTileAction(tile));
  }

  void _syncInitialTransform({
    required Size viewportSize,
    required Size mapSize,
    required Rect contentBounds,
    required Offset? initialFocus,
    required double initialScale,
    required Rect? dragBoundary,
  }) {
    final dragBoundaryChanged = _lastDragBoundary != dragBoundary;
    if (_lastViewportSize == viewportSize &&
        _lastMapSize == mapSize &&
        _lastContentBounds == contentBounds &&
        _lastInitialFocus == initialFocus &&
        _lastInitialScale == initialScale &&
        !dragBoundaryChanged) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    _lastContentBounds = contentBounds;
    _lastInitialFocus = initialFocus;
    _lastInitialScale = initialScale;
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
      focus: initialFocus,
      initialScale: initialScale,
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
