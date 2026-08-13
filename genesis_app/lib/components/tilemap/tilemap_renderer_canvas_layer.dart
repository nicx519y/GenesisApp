part of 'tilemap_renderer_library.dart';

class _TilemapCanvasTileEntry {
  const _TilemapCanvasTileEntry({
    required this.record,
    required this.asset,
    required this.extent,
    required this.locationImageFlowAnimation,
    required this.locationImageFlowPhase,
    required this.locationImageFlowAngleDegrees,
    required this.locationImageFlowGradientPoints,
    required this.locationImageFlowOpacity,
    required this.locationImageFlowBlendMode,
    required this.fogField,
    required this.rasterizeFogComposite,
    required this.onImageError,
    required this.onImageFrame,
  });

  final _TilemapRenderRecord record;
  final String asset;
  final double extent;
  final Animation<double>? locationImageFlowAnimation;
  final double locationImageFlowPhase;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
  final TilemapFogField? fogField;
  final bool rasterizeFogComposite;
  final ValueChanged<Object> onImageError;
  final VoidCallback onImageFrame;

  bool get requiresEffectChild {
    if (locationImageFlowAnimation != null) return true;
    return fogField?.shadowTileVertices.containsKey(record.tile.cellKey) ??
        false;
  }
}

class _TilemapCanvasTileLayer extends StatefulWidget {
  const _TilemapCanvasTileLayer({
    required this.mapSize,
    required this.frameGeneration,
    required this.tiles,
  });

  final Size mapSize;
  final int frameGeneration;
  final List<_TilemapCanvasTileEntry> tiles;

  @override
  State<_TilemapCanvasTileLayer> createState() =>
      _TilemapCanvasTileLayerState();
}

class _TilemapCanvasTileLayerState extends State<_TilemapCanvasTileLayer> {
  final Map<String, _TilemapCanvasImageLease> _leases =
      <String, _TilemapCanvasImageLease>{};
  final Map<String, String> _requestedAssetByTileKey = <String, String>{};
  final Map<String, String> _displayedAssetByTileKey = <String, String>{};
  final Map<String, String> _reportedAssetByTileKey = <String, String>{};
  final Set<_TilemapCanvasImageLease> _scheduledErrorLeases =
      <_TilemapCanvasImageLease>{};
  bool _syncingImages = false;
  bool _compositeDirty = true;
  Widget? _cachedComposite;
  TilemapCanvasRenderStats? _lastPublishedStats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncImages();
  }

  @override
  void didUpdateWidget(covariant _TilemapCanvasTileLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final frameGenerationChanged =
        oldWidget.frameGeneration != widget.frameGeneration;
    if (frameGenerationChanged) {
      _reportedAssetByTileKey.clear();
      _compositeDirty = true;
    }
    if (oldWidget.mapSize != widget.mapSize ||
        !_tilemapCanvasEntriesPaintEquivalent(oldWidget.tiles, widget.tiles)) {
      _compositeDirty = true;
    }
    if (!_tilemapCanvasEntriesUseSameImages(oldWidget.tiles, widget.tiles) ||
        (frameGenerationChanged &&
            _leases.values.any((lease) => lease.failed))) {
      _syncImages();
    }
  }

  void _syncImages() {
    _syncingImages = true;
    _compositeDirty = true;
    final retainedTileKeys = <String>{
      for (final entry in widget.tiles) entry.record.tile.cellKey,
    };
    final previousRequestedAssetByTileKey = Map<String, String>.of(
      _requestedAssetByTileKey,
    );
    _requestedAssetByTileKey.removeWhere(
      (tileKey, _) => !retainedTileKeys.contains(tileKey),
    );
    _displayedAssetByTileKey.removeWhere(
      (tileKey, _) => !retainedTileKeys.contains(tileKey),
    );
    _reportedAssetByTileKey.removeWhere(
      (tileKey, _) => !retainedTileKeys.contains(tileKey),
    );

    for (final entry in widget.tiles) {
      final tileKey = entry.record.tile.cellKey;
      _requestedAssetByTileKey[tileKey] = entry.asset;
      _ensureLease(entry.asset);
      if (previousRequestedAssetByTileKey[tileKey] != entry.asset) {
        _reportedAssetByTileKey.remove(tileKey);
      }
      final requestedLease = _leases[entry.asset];
      if (requestedLease?.imageInfo != null) {
        _displayedAssetByTileKey[tileKey] = entry.asset;
        continue;
      }
      final displayedAsset = _displayedAssetByTileKey[tileKey];
      if (displayedAsset == null ||
          _leases[displayedAsset]?.imageInfo == null) {
        _displayedAssetByTileKey.remove(tileKey);
      }
    }
    _releaseUnusedLeases();
    _syncingImages = false;
  }

  void _ensureLease(String asset) {
    final previousLease = _leases[asset];
    if (previousLease != null && !previousLease.failed) return;
    if (previousLease != null) {
      previousLease.stopListening();
      _leases.remove(asset);
    }
    final provider = GenesisStaticNetworkImageProvider(imageUrl: asset);
    final stream = provider.resolve(
      createLocalImageConfiguration(context, size: widget.mapSize),
    );
    final lease = _TilemapCanvasImageLease(stream);
    _leases[asset] = lease;
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        _handleImageFrame(asset, lease, imageInfo);
      },
      onError: (Object error, StackTrace? stackTrace) {
        _handleImageError(asset, lease, error);
      },
    );
    lease.listener = listener;
    stream.addListener(listener);
  }

  void _handleImageFrame(
    String asset,
    _TilemapCanvasImageLease lease,
    ImageInfo imageInfo,
  ) {
    if (!mounted || !identical(_leases[asset], lease)) {
      imageInfo.dispose();
      return;
    }
    final previousInfo = lease.imageInfo;
    lease.failed = false;
    lease.imageInfo = imageInfo;
    if (previousInfo != null) _disposeImageInfoAfterFrame(previousInfo);
    for (final entry in _requestedAssetByTileKey.entries) {
      if (entry.value == asset) {
        _displayedAssetByTileKey[entry.key] = asset;
      }
    }
    _releaseUnusedLeases();
    _compositeDirty = true;
    if (!_syncingImages) setState(() {});
  }

  void _handleImageError(
    String asset,
    _TilemapCanvasImageLease lease,
    Object error,
  ) {
    if (!mounted || !identical(_leases[asset], lease)) return;
    lease.failed = true;
    final failedInfo = lease.imageInfo;
    lease.imageInfo = null;
    if (failedInfo != null) _disposeImageInfoAfterFrame(failedInfo);
    _displayedAssetByTileKey.removeWhere(
      (_, displayedAsset) => displayedAsset == asset,
    );
    _compositeDirty = true;
    if (!_syncingImages) setState(() {});
    if (!_scheduledErrorLeases.add(lease)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledErrorLeases.remove(lease);
      if (!mounted || !identical(_leases[asset], lease)) return;
      var reportedError = false;
      for (final entry in widget.tiles) {
        if (entry.asset != asset) continue;
        reportedError = true;
        entry.onImageError(error);
      }
      if (reportedError) WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _releaseUnusedLeases() {
    final activeAssets = <String>{
      ..._requestedAssetByTileKey.values,
      ..._displayedAssetByTileKey.values,
    };
    for (final asset in _leases.keys.toList(growable: false)) {
      if (activeAssets.contains(asset)) continue;
      final lease = _leases.remove(asset)!;
      lease.stopListening();
      final imageInfo = lease.imageInfo;
      lease.imageInfo = null;
      if (imageInfo != null) _disposeImageInfoAfterFrame(imageInfo);
    }
  }

  void _disposeImageInfoAfterFrame(ImageInfo imageInfo) {
    WidgetsBinding.instance.addPostFrameCallback((_) => imageInfo.dispose());
  }

  bool _handleLayerPainted() {
    if (!mounted) return false;
    var reportedFrame = false;
    for (final entry in widget.tiles) {
      final tileKey = entry.record.tile.cellKey;
      final requestedAsset = _requestedAssetByTileKey[tileKey];
      if (requestedAsset == null ||
          _displayedAssetByTileKey[tileKey] != requestedAsset ||
          _leases[requestedAsset]?.imageInfo == null ||
          _reportedAssetByTileKey[tileKey] == requestedAsset) {
        continue;
      }
      _reportedAssetByTileKey[tileKey] = requestedAsset;
      reportedFrame = true;
      entry.onImageFrame();
    }
    return reportedFrame;
  }

  @override
  Widget build(BuildContext context) {
    final cachedComposite = _cachedComposite;
    if (!_compositeDirty && cachedComposite != null) {
      return cachedComposite;
    }
    final invertColors =
        MediaQuery.maybeInvertColorsOf(context) ??
        SemanticsBinding.instance.accessibilityFeatures.invertColors;
    final renderItems = <_TilemapCanvasRenderItem>[];
    final effectChildren = <Widget>[];
    final runEntries = <_TilemapCanvasTileEntry>[];
    String? runAsset;
    ui.Image? runImage;

    void flushRun() {
      final image = runImage;
      if (image != null && runEntries.isNotEmpty) {
        renderItems.add(
          _TilemapCanvasDrawRun.fromEntries(
            image: image,
            entries: List<_TilemapCanvasTileEntry>.of(runEntries),
          ),
        );
      }
      runEntries.clear();
      runAsset = null;
      runImage = null;
    }

    for (final entry in widget.tiles) {
      final tileKey = entry.record.tile.cellKey;
      final displayedAsset = _displayedAssetByTileKey[tileKey];
      final image = displayedAsset == null
          ? null
          : _leases[displayedAsset]?.imageInfo?.image;
      if (entry.requiresEffectChild) {
        flushRun();
        renderItems.add(
          _TilemapCanvasChildItem(
            offset: entry.record.imageTopLeft,
            extent: entry.extent,
            tileKey: tileKey,
            hasImage: image != null,
          ),
        );
        effectChildren.add(
          KeyedSubtree(
            key: ValueKey<String>(
              'tile-${entry.record.tile.x}-${entry.record.tile.y}',
            ),
            child: _ProjectedTileContent(
              tile: entry.record.tile,
              asset: displayedAsset ?? entry.asset,
              topLeft: entry.record.imageTopLeft,
              extent: entry.extent,
              locationImageFlowAnimation: entry.locationImageFlowAnimation,
              locationImageFlowPhase: entry.locationImageFlowPhase,
              locationImageFlowAngleDegrees:
                  entry.locationImageFlowAngleDegrees,
              locationImageFlowGradientPoints:
                  entry.locationImageFlowGradientPoints,
              locationImageFlowOpacity: entry.locationImageFlowOpacity,
              locationImageFlowBlendMode: entry.locationImageFlowBlendMode,
              fogField: entry.fogField,
              rasterizeFogComposite: entry.rasterizeFogComposite,
              child: image == null
                  ? const SizedBox.expand()
                  : Semantics(
                      container: true,
                      label:
                          '${entry.record.tile.type} '
                          '${entry.record.tile.x},${entry.record.tile.y}',
                      image: true,
                      child: RawImage(
                        image: image,
                        fit: BoxFit.contain,
                        invertColors: invertColors,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
            ),
          ),
        );
        continue;
      }
      if (image == null || displayedAsset == null) {
        flushRun();
        continue;
      }
      if (runAsset != displayedAsset) {
        flushRun();
        runAsset = displayedAsset;
        runImage = image;
      }
      runEntries.add(entry);
    }
    flushRun();

    final displayedAssets = <String>{
      for (final asset in _displayedAssetByTileKey.values)
        if (_leases[asset]?.imageInfo != null) asset,
    };
    final stats = TilemapCanvasRenderStats(
      tileCount: widget.tiles.length,
      imageCount: displayedAssets.length,
      drawCallCount: renderItems.whereType<_TilemapCanvasDrawRun>().length,
      renderObjectCount: 1,
    );
    _publishStats(stats);
    final composite = _TilemapCanvasComposite(
      key: const ValueKey<String>('tilemap-canvas-tile-layer'),
      mapSize: widget.mapSize,
      textDirection: Directionality.of(context),
      invertColors: invertColors,
      items: renderItems,
      onPainted: _handleLayerPainted,
      children: effectChildren,
    );
    _cachedComposite = composite;
    _compositeDirty = false;
    return composite;
  }

  void _publishStats(TilemapCanvasRenderStats stats) {
    if (_lastPublishedStats == stats) return;
    _lastPublishedStats = stats;
    debugTilemapCanvasRenderStatsChanged?.call(stats);
  }

  @override
  void dispose() {
    for (final lease in _leases.values) {
      lease.stopListening();
      lease.imageInfo?.dispose();
      lease.imageInfo = null;
    }
    _leases.clear();
    super.dispose();
  }
}

bool _tilemapCanvasEntriesUseSameImages(
  List<_TilemapCanvasTileEntry> first,
  List<_TilemapCanvasTileEntry> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index += 1) {
    final firstEntry = first[index];
    final secondEntry = second[index];
    if (firstEntry.record.tile.cellKey != secondEntry.record.tile.cellKey ||
        firstEntry.asset != secondEntry.asset) {
      return false;
    }
  }
  return true;
}

bool _tilemapCanvasEntriesPaintEquivalent(
  List<_TilemapCanvasTileEntry> first,
  List<_TilemapCanvasTileEntry> second,
) {
  if (!_tilemapCanvasEntriesUseSameImages(first, second)) return false;
  for (var index = 0; index < first.length; index += 1) {
    final firstEntry = first[index];
    final secondEntry = second[index];
    if (!identical(firstEntry.record, secondEntry.record) ||
        firstEntry.extent != secondEntry.extent ||
        !identical(
          firstEntry.locationImageFlowAnimation,
          secondEntry.locationImageFlowAnimation,
        ) ||
        firstEntry.locationImageFlowPhase !=
            secondEntry.locationImageFlowPhase ||
        firstEntry.locationImageFlowAngleDegrees !=
            secondEntry.locationImageFlowAngleDegrees ||
        !listEquals(
          firstEntry.locationImageFlowGradientPoints,
          secondEntry.locationImageFlowGradientPoints,
        ) ||
        firstEntry.locationImageFlowOpacity !=
            secondEntry.locationImageFlowOpacity ||
        firstEntry.locationImageFlowBlendMode !=
            secondEntry.locationImageFlowBlendMode ||
        !identical(firstEntry.fogField, secondEntry.fogField) ||
        firstEntry.rasterizeFogComposite != secondEntry.rasterizeFogComposite) {
      return false;
    }
  }
  return true;
}

class _TilemapCanvasImageLease {
  _TilemapCanvasImageLease(this.stream);

  final ImageStream stream;
  late final ImageStreamListener listener;
  ImageInfo? imageInfo;
  bool failed = false;
  bool _listening = true;

  void stopListening() {
    if (!_listening) return;
    _listening = false;
    stream.removeListener(listener);
  }
}

sealed class _TilemapCanvasRenderItem {
  const _TilemapCanvasRenderItem();
}

class _TilemapCanvasDrawRun extends _TilemapCanvasRenderItem {
  _TilemapCanvasDrawRun.fromEntries({
    required this.image,
    required List<_TilemapCanvasTileEntry> entries,
  }) : transforms = Float32List(entries.length * 4),
       rects = Float32List(entries.length * 4),
       semantics = List<_TilemapCanvasSemanticEntry>.unmodifiable(
         entries.map(
           (entry) => _TilemapCanvasSemanticEntry(
             tileKey: entry.record.tile.cellKey,
             rect: entry.record.imageBounds,
             label:
                 '${entry.record.tile.type} '
                 '${entry.record.tile.x},${entry.record.tile.y}',
           ),
         ),
       ),
       cullRect = entries
           .map((entry) => entry.record.imageBounds)
           .reduce((first, second) => first.expandToInclude(second)) {
    final sourceWidth = image.width.toDouble();
    final sourceHeight = image.height.toDouble();
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final scale = math.min(
        entry.extent / sourceWidth,
        entry.extent / sourceHeight,
      );
      final destinationWidth = sourceWidth * scale;
      final destinationHeight = sourceHeight * scale;
      final transformIndex = index * 4;
      transforms[transformIndex] = scale;
      transforms[transformIndex + 1] = 0;
      transforms[transformIndex + 2] =
          entry.record.imageTopLeft.dx + (entry.extent - destinationWidth) / 2;
      transforms[transformIndex + 3] =
          entry.record.imageTopLeft.dy + (entry.extent - destinationHeight) / 2;
      rects[transformIndex] = 0;
      rects[transformIndex + 1] = 0;
      rects[transformIndex + 2] = sourceWidth;
      rects[transformIndex + 3] = sourceHeight;
    }
  }

  final ui.Image image;
  final Float32List transforms;
  final Float32List rects;
  final List<_TilemapCanvasSemanticEntry> semantics;
  final Rect cullRect;
}

class _TilemapCanvasSemanticEntry {
  const _TilemapCanvasSemanticEntry({
    required this.tileKey,
    required this.rect,
    required this.label,
  });

  final String tileKey;
  final Rect rect;
  final String label;
}

class _TilemapCanvasChildItem extends _TilemapCanvasRenderItem {
  const _TilemapCanvasChildItem({
    required this.offset,
    required this.extent,
    required this.tileKey,
    required this.hasImage,
  });

  final Offset offset;
  final double extent;
  final String tileKey;
  final bool hasImage;
}

class _TilemapCanvasComposite extends MultiChildRenderObjectWidget {
  const _TilemapCanvasComposite({
    super.key,
    required this.mapSize,
    required this.textDirection,
    required this.invertColors,
    required this.items,
    required this.onPainted,
    required super.children,
  });

  final Size mapSize;
  final TextDirection textDirection;
  final bool invertColors;
  final List<_TilemapCanvasRenderItem> items;
  final ValueGetter<bool> onPainted;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTilemapCanvasComposite(
      mapSize: mapSize,
      textDirection: textDirection,
      invertColors: invertColors,
      items: items,
      onPainted: onPainted,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTilemapCanvasComposite renderObject,
  ) {
    renderObject
      ..mapSize = mapSize
      ..textDirection = textDirection
      ..invertColors = invertColors
      ..items = items
      ..onPainted = onPainted;
  }
}

class _TilemapCanvasParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTilemapCanvasComposite extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderTilemapCanvasComposite({
    required Size mapSize,
    required TextDirection textDirection,
    required bool invertColors,
    required List<_TilemapCanvasRenderItem> items,
    required ValueGetter<bool> onPainted,
  }) : _mapSize = mapSize,
       _textDirection = textDirection,
       _invertColors = invertColors,
       _items = items,
       _onPainted = onPainted;

  Size _mapSize;
  TextDirection _textDirection;
  bool _invertColors;
  List<_TilemapCanvasRenderItem> _items;
  ValueGetter<bool> _onPainted;
  bool _paintCallbackScheduled = false;
  bool _disposed = false;
  final Map<String, SemanticsNode> _plainTileSemantics =
      <String, SemanticsNode>{};

  set mapSize(Size value) {
    if (_mapSize == value) return;
    _mapSize = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  set invertColors(bool value) {
    if (_invertColors == value) return;
    _invertColors = value;
    markNeedsPaint();
  }

  set items(List<_TilemapCanvasRenderItem> value) {
    if (identical(_items, value)) return;
    _items = value;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  set onPainted(ValueGetter<bool> value) {
    _onPainted = value;
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _TilemapCanvasParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.constrain(_mapSize);
    var child = firstChild;
    for (final item in _items) {
      if (item is! _TilemapCanvasChildItem) continue;
      assert(child != null);
      if (child == null) break;
      child.layout(
        BoxConstraints.tight(Size.square(item.extent)),
        parentUsesSize: true,
      );
      final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
      parentData.offset = item.offset;
      child = parentData.nextSibling;
    }
    assert(child == null);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    var paintedAnImage = false;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..invertColors = _invertColors;
    for (final item in _items) {
      switch (item) {
        case _TilemapCanvasDrawRun():
          context.canvas
            ..save()
            ..translate(offset.dx, offset.dy)
            ..drawRawAtlas(
              item.image,
              item.transforms,
              item.rects,
              null,
              null,
              item.cullRect,
              paint,
            )
            ..restore();
          paintedAnImage = true;
        case _TilemapCanvasChildItem():
          assert(child != null);
          if (child == null) continue;
          final parentData =
              child.parentData! as ContainerBoxParentData<RenderBox>;
          context.paintChild(child, offset + parentData.offset);
          paintedAnImage = paintedAnImage || item.hasImage;
          child = parentData.nextSibling;
      }
    }
    if (paintedAnImage) {
      context.setIsComplexHint();
      _schedulePaintedCallback();
    }
  }

  void _schedulePaintedCallback() {
    if (_paintCallbackScheduled) return;
    _paintCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paintCallbackScheduled = false;
      if (!_disposed && attached) {
        if (_onPainted()) WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return false;
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = _items.any(
      (item) => item is _TilemapCanvasDrawRun && item.semantics.isNotEmpty,
    );
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    final retainedTileKeys = <String>{};
    final nodesInPaintOrder = <SemanticsNode>[];
    final effectChildNodes = children.iterator;
    for (final item in _items) {
      switch (item) {
        case _TilemapCanvasDrawRun():
          for (final entry in item.semantics) {
            retainedTileKeys.add(entry.tileKey);
            final tileNode = _plainTileSemantics.putIfAbsent(
              entry.tileKey,
              () => SemanticsNode(
                key: ValueKey<String>('tile-semantic-${entry.tileKey}'),
              ),
            );
            final tileConfig = SemanticsConfiguration()
              ..label = entry.label
              ..textDirection = _textDirection
              ..isImage = true;
            tileNode
              ..rect = entry.rect
              ..updateWith(
                config: tileConfig,
                childrenInInversePaintOrder: const <SemanticsNode>[],
              );
            nodesInPaintOrder.add(tileNode);
          }
        case _TilemapCanvasChildItem():
          if (item.hasImage && effectChildNodes.moveNext()) {
            nodesInPaintOrder.add(effectChildNodes.current);
          }
      }
    }
    while (effectChildNodes.moveNext()) {
      nodesInPaintOrder.add(effectChildNodes.current);
    }
    _plainTileSemantics.removeWhere(
      (tileKey, _) => !retainedTileKeys.contains(tileKey),
    );
    super.assembleSemanticsNode(node, config, nodesInPaintOrder);
  }

  @override
  void clearSemantics() {
    _plainTileSemantics.clear();
    super.clearSemantics();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
    transform.translateByDouble(
      parentData.offset.dx,
      parentData.offset.dy,
      0,
      1,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _plainTileSemantics.clear();
    super.dispose();
  }
}
