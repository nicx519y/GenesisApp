import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../ui/components/genesis_character_avatar.dart';
import '../ui/components/genesis_static_network_image.dart';
import '../ui/tokens/genesis_avatar_radii.dart';
import '../ui/tokens/genesis_colors.dart';
import '../utils/genesis_image_resource.dart';
import 'world_map_interaction_notification.dart';
import 'world_location_list.dart';
import 'world_point.dart';

export 'world_location_list.dart';
export 'world_point.dart';

const String kWorldMapFallbackBackgroundAsset =
    'assets/images/map_default/root_default.webp';
const double _worldMapAvatarImageLogicalSize = 42;
const double _worldMapPreviewImageLogicalWidth = 120;
const Duration _worldMapBubbleDisplayDuration = Duration(seconds: 4);
const Duration _worldMapBubbleGapDuration = Duration(milliseconds: 500);
const int _worldMapBubblePageMaxCharacters = 144;
const double _worldMapZoomControlRightGap = 12;
const double _worldMapZoomControlBottomGap = 30;
const double _worldMapZoomControlWidth = 30;
const double _worldMapZoomControlHeight = 68;
const double _worldMapZoomControlRadius = 12;
const String _worldMapZoomInIconAsset =
    'assets/custom-icons/svg/map_zoom_in.svg';
const String _worldMapZoomOutIconAsset =
    'assets/custom-icons/svg/map_zoom_out.svg';

@visibleForTesting
Color worldMapAvatarBorderColorForTesting({
  required bool isPlayerControlledRole,
}) {
  return isPlayerControlledRole ? GenesisColors.brand : const Color(0xFFDDDDDD);
}

@visibleForTesting
Offset? worldMapInitialZoomFocusForTesting(List<WorldPoint> points) {
  return _worldMapInitialZoomFocusForPoints(points);
}

Offset? _worldMapInitialZoomFocusForPoints(List<WorldPoint> points) {
  WorldPoint? target;
  for (final point in points) {
    if (point.users.isEmpty) continue;
    final current = target;
    if (current == null || point.users.length > current.users.length) {
      target = point;
    }
  }
  return target?.position;
}

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

@immutable
class WorldMapHorizontalPanState {
  const WorldMapHorizontalPanState({
    required this.canScrollLeft,
    required this.canScrollRight,
  });

  final bool canScrollLeft;
  final bool canScrollRight;
}

class WorldMapMessageBubble {
  const WorldMapMessageBubble({
    required this.characterId,
    required this.content,
  });

  final String characterId;
  final String content;
}

class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    required this.points,
    this.listPoints,
    this.locationNodes = const <WorldMapLocationNode>[],
    this.listLocationNodes = const <WorldMapLocationNode>[],
    this.mapImageUrl = '',
    this.preloadMapImageUrls = const <String>[],
    this.fallbackOnEmptyMapUrl = true,
    this.dimmed = false,
    this.showPointsList = false,
    this.pointsListPhysics,
    this.pointsListOuterScrollHandoff = true,
    this.overlayTop = 0,
    this.drillExitTop = 68,
    this.drillExitMaxWidth,
    this.onDrillIntoLocation,
    this.onHorizontalPanStateChanged,
    this.onPointTap,
    this.activeBubble,
    this.messageBubbles = const <WorldMapMessageBubble>[],
    this.messageBubblePlaybackPaused = false,
    this.initialZoomScale = _ZoomableMapContent.minScale,
  });

  final List<WorldPoint> points;
  final List<WorldPoint>? listPoints;
  final List<WorldMapLocationNode> locationNodes;
  final List<WorldMapLocationNode> listLocationNodes;
  final String mapImageUrl;
  final List<String> preloadMapImageUrls;
  final bool fallbackOnEmptyMapUrl;
  final bool dimmed;
  final bool showPointsList;
  final ScrollPhysics? pointsListPhysics;
  final bool pointsListOuterScrollHandoff;
  final double overlayTop;
  final double drillExitTop;
  final double? drillExitMaxWidth;
  final VoidCallback? onDrillIntoLocation;
  final ValueChanged<WorldMapHorizontalPanState>? onHorizontalPanStateChanged;
  final WorldPointTapCallback? onPointTap;
  final WorldMapMessageBubble? activeBubble;
  final List<WorldMapMessageBubble> messageBubbles;
  final bool messageBubblePlaybackPaused;
  final double initialZoomScale;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  ScrollController? _horizontalScrollController;
  ScrollController? _verticalScrollController;
  final List<_WorldMapLocationTrailEntry> _locationTrail =
      <_WorldMapLocationTrailEntry>[];
  final Set<String> _pendingLocationTapKeys = <String>{};
  final Map<String, Size> _mapImageDimensionsByUrl = <String, Size>{};
  final Set<String> _pendingMapImageDimensionUrls = <String>{};
  Timer? _messageBubblePlaybackTimer;
  int _messageBubblePlaybackIndex = 0;
  int _messageBubblePageIndex = 0;
  bool _messageBubbleVisible = true;
  double _mapZoomScale = _ZoomableMapContent.minScale;
  String _messageBubblePlaybackSignature = '';
  List<WorldMapMessageBubble> _visibleMessageBubblesForPlayback =
      const <WorldMapMessageBubble>[];
  String _lastLoggedLocationTreeSignature = '';
  String _scrollControllerSignature = '';
  WorldMapHorizontalPanState? _lastHorizontalPanState;
  Object? _activeZoomControlToken;
  void Function(double delta)? _zoomByControl;
  _MapTransitionSpec _mapTransition = const _MapTransitionSpec(
    origin: Alignment.center,
    direction: _MapTransitionDirection.drillIn,
  );

  bool get _hasDrillTree => widget.locationNodes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mapZoomScale = widget.initialZoomScale
        .clamp(_ZoomableMapContent.minScale, _ZoomableMapContent.maxScale)
        .toDouble();
    _debugPrintLocationTree('init');
  }

  @override
  void didUpdateWidget(covariant WorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugPrintLocationTree('update');
    if (oldWidget.messageBubblePlaybackPaused !=
        widget.messageBubblePlaybackPaused) {
      if (widget.messageBubblePlaybackPaused) {
        _stopMessageBubblePlayback();
      } else {
        _ensureMessageBubblePlayback();
      }
    }
    if (!_hasDrillTree) {
      if (_locationTrail.isNotEmpty) {
        _locationTrail.clear();
      }
      return;
    }

    final currentId = _locationTrail.isEmpty ? '' : _locationTrail.last.id;
    if (currentId.isNotEmpty && _findNode(currentId) == null) {
      _locationTrail.clear();
    }
  }

  @override
  void dispose() {
    _stopMessageBubblePlayback();
    _horizontalScrollController?.removeListener(_notifyHorizontalPanState);
    _horizontalScrollController?.dispose();
    _verticalScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentNode = _currentNode;
    final visibleNodes = _hasDrillTree
        ? (currentNode == null ? _initialVisibleNodes : currentNode.children)
        : const <WorldMapLocationNode>[];
    final visiblePoints = _hasDrillTree
        ? visibleNodes.map((node) => node.point).toList(growable: false)
        : widget.points;
    final flattenedPoints = _hasDrillTree
        ? _flattenNodes(
            widget.locationNodes,
          ).map((node) => node.point).toList(growable: false)
        : widget.listPoints ?? widget.points;
    final currentMapImageUrl =
        currentNode?.mapImageUrl.trim().isNotEmpty == true
        ? currentNode!.mapImageUrl
        : _initialMapImageUrl;
    final rawPreloadMapImageUrls = _hasDrillTree
        ? visibleNodes
              .map((node) => node.mapImageUrl.trim())
              .where((url) => url.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : widget.preloadMapImageUrls;
    final exitLocationLabel = currentNode?.point.name ?? '';
    final visibleMessageBubbles = _visibleMessageBubblesForPoints(
      visiblePoints,
    );
    if (widget.messageBubblePlaybackPaused) {
      _stopMessageBubblePlayback();
    } else {
      _syncMessageBubblePlayback(visibleMessageBubbles);
    }
    final activeBubble =
        widget.activeBubble ??
        (widget.messageBubblePlaybackPaused
            ? null
            : _activeBubbleFromVisible(visibleMessageBubbles));

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio =
            MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
        final designSize = _mapDesignSize(currentMapImageUrl);
        final viewport = _MapViewport.cover(
          viewportWidth: constraints.maxWidth,
          viewportHeight: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : constraints.maxWidth / (designSize.width / designSize.height),
          designWidth: designSize.width,
          designHeight: designSize.height,
        );
        final backgroundUrl = _selectWorldMapImageUrl(
          currentMapImageUrl,
          logicalWidth: viewport.width,
          devicePixelRatio: devicePixelRatio,
        );
        final backgroundPreviewUrl = _selectWorldMapPreviewImageUrl(
          currentMapImageUrl,
        );
        final preloadMapImageUrls = rawPreloadMapImageUrls
            .map(
              (url) => _selectWorldMapImageUrl(
                url,
                logicalWidth: viewport.width,
                devicePixelRatio: devicePixelRatio,
              ),
            )
            .where((url) => url.isNotEmpty)
            .toSet()
            .toList(growable: false);
        final preloadAvatarUrls = _preloadAvatarUrls(
          visiblePoints,
          devicePixelRatio: devicePixelRatio,
        );
        final mapKeyId = _locationTrail.isEmpty
            ? '__world_root__'
            : _locationTrail.last.id;
        final mapKey = ValueKey<String>(mapKeyId);
        final initialFocus = _worldMapInitialZoomFocusForPoints(visiblePoints);
        final initialTransformKey = [
          mapKeyId,
          currentMapImageUrl,
          widget.initialZoomScale.toStringAsFixed(3),
        ].join('|');
        _syncMapScrollControllers(
          signature:
              '$currentMapImageUrl|$mapKeyId|${constraints.maxWidth}|${constraints.maxHeight}|${viewport.width}|${viewport.height}',
          horizontalInitialOffset: _centerScrollOffset(
            contentExtent: viewport.width,
            viewportExtent: constraints.maxWidth,
          ),
          verticalInitialOffset: _centerScrollOffset(
            contentExtent: viewport.height,
            viewportExtent: constraints.maxHeight,
          ),
        );
        _scheduleHorizontalPanStateNotification();
        final verticalScrollController = _verticalScrollController!;
        final horizontalScrollController = _horizontalScrollController!;
        return Stack(
          children: [
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  controller: verticalScrollController,
                  primary: false,
                  scrollDirection: Axis.vertical,
                  physics: viewport.height > constraints.maxHeight + 0.5
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    height: viewport.height,
                    child: SingleChildScrollView(
                      controller: horizontalScrollController,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      physics: viewport.width > constraints.maxWidth + 0.5
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        key: const ValueKey<String>('world-map-scaled-content'),
                        width: viewport.width,
                        height: viewport.height,
                        child: _WorldMapTransitionSurface(
                          mapKey: mapKey,
                          transition: _mapTransition,
                          child: Stack(
                            children: [
                              Positioned(
                                left: viewport.left,
                                top: viewport.top,
                                width: viewport.width,
                                height: viewport.height,
                                child: _ZoomableMapContent(
                                  background: _MapBackgroundDeck(
                                    currentUrl: backgroundUrl,
                                    previewUrl: backgroundPreviewUrl,
                                    preloadUrls: preloadMapImageUrls,
                                    preloadAvatarUrls: preloadAvatarUrls,
                                    fallbackOnEmptyUrl:
                                        widget.fallbackOnEmptyMapUrl,
                                  ),
                                  initialScale: widget.initialZoomScale,
                                  initialFocus: initialFocus,
                                  initialTransformKey: initialTransformKey,
                                  initialViewportSize: Size(
                                    viewport.width,
                                    viewport.height,
                                  ),
                                  overlayBuilder:
                                      (
                                        context,
                                        transform,
                                        onOverlayPointerDown,
                                      ) => Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          IgnorePointer(
                                            ignoring: widget.showPointsList,
                                            child: Opacity(
                                              opacity: widget.showPointsList
                                                  ? 0.6
                                                  : 1,
                                              child: Stack(
                                                children: [
                                                  for (final p in visiblePoints)
                                                    _WorldPointPositioned(
                                                      point: p,
                                                      width: viewport.width,
                                                      height: viewport.height,
                                                      transform: transform,
                                                      messageBubble:
                                                          _bubbleForPoint(
                                                            p,
                                                            activeBubble,
                                                          ),
                                                      onPointerDown:
                                                          onOverlayPointerDown,
                                                      onTap: _pointTapHandler(
                                                        p,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          IgnorePointer(
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              color: widget.dimmed
                                                  ? Colors.black.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.transparent,
                                            ),
                                          ),
                                        ],
                                      ),
                                  onScaleChanged: _handleMapZoomScaleChanged,
                                  onZoomControlChanged:
                                      _handleZoomControlChanged,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showPointsList)
              Positioned.fill(child: ColoredBox(color: Colors.white)),
            if (widget.showPointsList)
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: WorldLocationList(
                        points: flattenedPoints,
                        locationNodes: widget.listLocationNodes.isNotEmpty
                            ? widget.listLocationNodes
                            : widget.locationNodes,
                        physics: widget.pointsListPhysics,
                        enableOuterScrollHandoff:
                            widget.pointsListOuterScrollHandoff,
                        padding: EdgeInsets.fromLTRB(
                          12,
                          widget.overlayTop + 8,
                          12,
                          12,
                        ),
                        onPointTap: (point) {
                          widget.onPointTap?.call(_withCurrentMapImage(point));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (_locationTrail.isNotEmpty && !widget.showPointsList)
              Positioned(
                left: 12,
                top: widget.drillExitTop,
                child: _ConstrainedMaxWidth(
                  maxWidth: widget.drillExitMaxWidth,
                  child: _ExitLocationButton(
                    label: exitLocationLabel,
                    onPressed: _exitLocation,
                  ),
                ),
              ),
            if (!widget.showPointsList)
              Positioned(
                right: _worldMapZoomControlRightGap,
                bottom: _worldMapZoomControlBottomGap,
                child: _MapZoomControl(
                  canZoomIn:
                      _mapZoomScale < _ZoomableMapContent.maxScale - 0.001,
                  canZoomOut:
                      _mapZoomScale > _ZoomableMapContent.minScale + 0.001,
                  onZoomIn: () => _zoomByControl?.call(0.25),
                  onZoomOut: () => _zoomByControl?.call(-0.25),
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleMapZoomScaleChanged(double scale) {
    if ((_mapZoomScale - scale).abs() < 0.001) return;
    setState(() {
      _mapZoomScale = scale;
    });
  }

  void _handleZoomControlChanged(
    Object token,
    void Function(double delta)? zoomByControl,
  ) {
    if (zoomByControl == null) {
      if (identical(_activeZoomControlToken, token)) {
        _activeZoomControlToken = null;
        _zoomByControl = null;
      }
      return;
    }

    _activeZoomControlToken = token;
    _zoomByControl = zoomByControl;
  }

  VoidCallback? _pointTapHandler(WorldPoint point) {
    if (_hasDrillTree) {
      final node = _findPointNode(point);
      if (node == null) return null;
      final chatTarget = _chatTargetForNode(node);
      if (chatTarget != null && widget.onPointTap == null) return null;
      return () {
        unawaited(_handlePointTap(point));
      };
    }
    if (widget.onPointTap == null) return null;
    return () {
      unawaited(_handlePointTap(point));
    };
  }

  Future<void> _handlePointTap(WorldPoint point) async {
    if (_hasDrillTree) {
      final node = _findPointNode(point);
      if (node != null) {
        final chatTarget = _chatTargetForNode(node);
        if (chatTarget != null) {
          await _runLocationTapLocked(
            _locationTapKey(chatTarget),
            () => widget.onPointTap?.call(_withCurrentMapImage(chatTarget)),
          );
          return;
        }
        final displayNode = _displayNodeForDrill(node);
        await _runLocationTapLocked(_locationTapKey(point), () async {
          widget.onDrillIntoLocation?.call();
          final origin = _mapTransitionOrigin(point);
          final path = displayNode.id == node.id
              ? _nodePath(displayNode.id)
              : <String>[displayNode.id];
          setState(() {
            _mapTransition = _MapTransitionSpec(
              origin: origin,
              direction: _MapTransitionDirection.drillIn,
            );
            _locationTrail
              ..clear()
              ..addAll(
                (path.isEmpty ? <String>[displayNode.id] : path).map(
                  (id) => _WorldMapLocationTrailEntry(
                    id: id,
                    origin: id == displayNode.id ? origin : Alignment.center,
                  ),
                ),
              );
          });
          await WidgetsBinding.instance.endOfFrame;
        });
        return;
      }
    }

    await _runLocationTapLocked(
      _locationTapKey(point),
      () => widget.onPointTap?.call(_withCurrentMapImage(point)),
    );
  }

  WorldPoint _withCurrentMapImage(WorldPoint point) {
    final currentMapImageUrl = _currentMapImageUrl.trim();
    if (currentMapImageUrl.isEmpty || point.mapImageUrl == currentMapImageUrl) {
      return point;
    }
    return WorldPoint(
      id: point.id,
      name: point.name,
      type: point.type,
      position: point.position,
      users: point.users,
      sceneId: point.sceneId,
      pointId: point.pointId,
      iconUrl: point.iconUrl,
      mapImageUrl: currentMapImageUrl,
      description: point.description,
      locationDescription: point.locationDescription,
      depth: point.depth,
      isLeafLocation: point.isLeafLocation,
    );
  }

  Future<void> _runLocationTapLocked(
    String key,
    FutureOr<void> Function() action,
  ) async {
    if (key.isNotEmpty && !_pendingLocationTapKeys.add(key)) return;
    try {
      await action();
    } finally {
      if (key.isNotEmpty) _pendingLocationTapKeys.remove(key);
    }
  }

  String _locationTapKey(WorldPoint point) {
    final sceneId = point.sceneId.trim();
    if (sceneId.isNotEmpty) return sceneId;
    final pointId = point.pointId.trim();
    if (pointId.isNotEmpty) return pointId;
    return point.id.trim();
  }

  void _exitLocation() {
    if (_locationTrail.isEmpty) return;
    widget.onDrillIntoLocation?.call();
    final origin = _locationTrail.last.origin;
    setState(() {
      _mapTransition = _MapTransitionSpec(
        origin: origin,
        direction: _MapTransitionDirection.drillOut,
      );
      _locationTrail.removeLast();
    });
  }

  WorldMapLocationNode? get _currentNode {
    if (_locationTrail.isEmpty) return null;
    return _findNode(_locationTrail.last.id);
  }

  List<WorldMapLocationNode> get _initialVisibleNodes {
    final explicitRootChildren = widget.locationNodes
        .where((node) => node.isRoot)
        .expand((node) => node.children)
        .toList(growable: false);
    if (explicitRootChildren.isNotEmpty ||
        widget.locationNodes.any((node) => node.isRoot)) {
      return explicitRootChildren;
    }

    return widget.locationNodes;
  }

  String get _initialMapImageUrl {
    final detailMapImageUrl = widget.mapImageUrl.trim();
    if (detailMapImageUrl.isNotEmpty) return widget.mapImageUrl;

    for (final node in widget.locationNodes) {
      if (!node.isRoot) continue;
      final rootMapImageUrl = node.mapImageUrl.trim();
      if (rootMapImageUrl.isNotEmpty) return rootMapImageUrl;
    }
    return widget.mapImageUrl;
  }

  String get _currentMapImageUrl {
    final currentNode = _currentNode;
    return currentNode?.mapImageUrl.trim().isNotEmpty == true
        ? currentNode!.mapImageUrl
        : _initialMapImageUrl;
  }

  WorldMapLocationNode? _findPointNode(WorldPoint point) {
    final targetId = _pointLocationId(point);
    if (targetId.isEmpty) return null;
    return _findNode(targetId);
  }

  WorldPoint? _chatTargetForNode(WorldMapLocationNode node) {
    final explicitTarget = node.chatTargetPoint;
    if (explicitTarget != null) return explicitTarget;
    if (node.children.isEmpty) return node.point;
    final singleLeaf = _singleLeafDescendant(node);
    return singleLeaf?.point;
  }

  List<WorldMapMessageBubble> _visibleMessageBubblesForPoints(
    List<WorldPoint> points,
  ) {
    if (widget.messageBubbles.isEmpty) return const <WorldMapMessageBubble>[];
    final visibleCharacterIds = <String>{};
    for (final point in points) {
      for (final user in point.users) {
        final id = user.id.trim();
        if (id.isNotEmpty) visibleCharacterIds.add(id);
      }
    }
    if (visibleCharacterIds.isEmpty) return const <WorldMapMessageBubble>[];
    return widget.messageBubbles
        .where(
          (bubble) =>
              visibleCharacterIds.contains(bubble.characterId.trim()) &&
              bubble.content.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  WorldMapMessageBubble? _activeBubbleFromVisible(
    List<WorldMapMessageBubble> visibleBubbles,
  ) {
    if (visibleBubbles.isEmpty) return null;
    if (!_messageBubbleVisible) return null;
    final index = _messageBubblePlaybackIndex % visibleBubbles.length;
    final bubble = visibleBubbles[index];
    final pages = _messageBubblePages(bubble.content);
    final page = pages.isEmpty
        ? ''
        : pages[_messageBubblePageIndex % pages.length];
    if (page.isEmpty) return null;
    return WorldMapMessageBubble(
      characterId: bubble.characterId,
      content: page,
    );
  }

  void _syncMessageBubblePlayback(List<WorldMapMessageBubble> visibleBubbles) {
    final signature = _messageBubblePlaybackKey(visibleBubbles);
    if (signature.isEmpty) {
      _messageBubblePlaybackSignature = '';
      _visibleMessageBubblesForPlayback = const <WorldMapMessageBubble>[];
      _messageBubbleVisible = false;
      _stopMessageBubblePlayback();
      return;
    }
    if (_messageBubblePlaybackSignature != signature) {
      _messageBubblePlaybackSignature = signature;
      _visibleMessageBubblesForPlayback = visibleBubbles;
      _messageBubblePlaybackIndex = 0;
      _messageBubblePageIndex = 0;
      _messageBubbleVisible = true;
      _stopMessageBubblePlayback();
    } else {
      _visibleMessageBubblesForPlayback = visibleBubbles;
    }
    if (_messageBubblePlaybackIndex >= visibleBubbles.length) {
      _messageBubblePlaybackIndex = 0;
      _messageBubblePageIndex = 0;
    }
    _ensureMessageBubblePlayback();
  }

  void _ensureMessageBubblePlayback() {
    if (widget.messageBubblePlaybackPaused ||
        _messageBubblePlaybackTimer != null ||
        _messageBubblePlaybackSignature.isEmpty) {
      return;
    }
    final duration = _messageBubbleVisible
        ? _worldMapBubbleDisplayDuration
        : _worldMapBubbleGapDuration;
    _messageBubblePlaybackTimer = Timer(duration, () {
      _messageBubblePlaybackTimer = null;
      if (!mounted || _messageBubblePlaybackSignature.isEmpty) return;
      setState(() {
        if (_messageBubbleVisible) {
          final activeBubble = _activeBubbleForPlayback();
          final pageCount = activeBubble == null
              ? 1
              : _messageBubblePages(activeBubble.content).length;
          if (_messageBubblePageIndex + 1 < pageCount) {
            _messageBubblePageIndex += 1;
          } else {
            _messageBubbleVisible = false;
          }
        } else {
          _messageBubblePlaybackIndex += 1;
          _messageBubblePageIndex = 0;
          _messageBubbleVisible = true;
        }
      });
      _ensureMessageBubblePlayback();
    });
  }

  void _stopMessageBubblePlayback() {
    _messageBubblePlaybackTimer?.cancel();
    _messageBubblePlaybackTimer = null;
  }

  String _messageBubblePlaybackKey(List<WorldMapMessageBubble> bubbles) {
    if (bubbles.isEmpty) return '';
    return bubbles
        .map((bubble) => '${bubble.characterId.trim()}\u{1f}${bubble.content}')
        .join('\u{1e}');
  }

  List<String> _messageBubblePages(String content) {
    return worldMapMessageBubblePagesForTesting(content);
  }

  WorldMapMessageBubble? _activeBubbleForPlayback() {
    final bubbles = _visibleMessageBubblesForPlayback;
    if (bubbles.isEmpty) return null;
    return bubbles[_messageBubblePlaybackIndex % bubbles.length];
  }

  WorldMapMessageBubble? _bubbleForPoint(
    WorldPoint point,
    WorldMapMessageBubble? bubble,
  ) {
    if (bubble == null) return null;
    final characterId = bubble.characterId.trim();
    if (characterId.isEmpty || bubble.content.trim().isEmpty) return null;
    for (final user in point.users) {
      if (user.id.trim() == characterId) return bubble;
    }
    return null;
  }

  WorldMapLocationNode? _singleLeafDescendant(WorldMapLocationNode node) {
    var current = node;
    while (current.children.length == 1) {
      current = current.children.single;
    }
    return current.children.isEmpty ? current : null;
  }

  WorldMapLocationNode _displayNodeForDrill(WorldMapLocationNode node) {
    var current = node;
    while (current.children.length == 1 &&
        current.children.single.children.isNotEmpty) {
      current = current.children.single;
    }
    return current;
  }

  WorldMapLocationNode? _findNode(String nodeId) {
    final targetId = nodeId.trim();
    if (targetId.isEmpty) return null;

    WorldMapLocationNode? visit(WorldMapLocationNode node) {
      if (node.id == targetId) return node;
      for (final child in node.children) {
        final match = visit(child);
        if (match != null) return match;
      }
      return null;
    }

    for (final root in widget.locationNodes) {
      final match = visit(root);
      if (match != null) return match;
    }
    return null;
  }

  List<String> _nodePath(String nodeId) {
    final targetId = nodeId.trim();
    if (targetId.isEmpty) return const <String>[];

    List<String>? visit(WorldMapLocationNode node) {
      if (node.id == targetId) return <String>[node.id];
      for (final child in node.children) {
        final childPath = visit(child);
        if (childPath != null) return <String>[node.id, ...childPath];
      }
      return null;
    }

    for (final root in widget.locationNodes) {
      final path = visit(root);
      if (path != null) {
        final hiddenRootId = root.id.trim();
        if (root.isRoot &&
            hiddenRootId.isNotEmpty &&
            path.isNotEmpty &&
            path.first == hiddenRootId) {
          return path.skip(1).toList(growable: false);
        }
        return path;
      }
    }
    return const <String>[];
  }

  List<WorldMapLocationNode> _flattenNodes(List<WorldMapLocationNode> nodes) {
    return <WorldMapLocationNode>[
      for (final node in nodes) ...[node, ..._flattenNodes(node.children)],
    ];
  }

  List<String> _preloadAvatarUrls(
    List<WorldPoint> visiblePoints, {
    required double devicePixelRatio,
  }) {
    return visiblePoints
        .expand((point) => point.users)
        .map(
          (user) => _selectWorldMapAvatarUrl(
            user.avatarUrl,
            devicePixelRatio: devicePixelRatio,
          ).trim(),
        )
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  void _syncMapScrollControllers({
    required String signature,
    required double horizontalInitialOffset,
    required double verticalInitialOffset,
  }) {
    if (_scrollControllerSignature == signature &&
        _horizontalScrollController != null &&
        _verticalScrollController != null) {
      return;
    }

    final previousHorizontalController = _horizontalScrollController;
    final previousVerticalController = _verticalScrollController;
    previousHorizontalController?.removeListener(_notifyHorizontalPanState);

    final horizontalController = ScrollController(
      initialScrollOffset: horizontalInitialOffset,
    );
    horizontalController.addListener(_notifyHorizontalPanState);
    _horizontalScrollController = horizontalController;
    _verticalScrollController = ScrollController(
      initialScrollOffset: verticalInitialOffset,
    );
    _scrollControllerSignature = signature;
    _lastHorizontalPanState = null;

    if (previousHorizontalController != null ||
        previousVerticalController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previousHorizontalController?.dispose();
        previousVerticalController?.dispose();
      });
    }
  }

  double _centerScrollOffset({
    required double contentExtent,
    required double viewportExtent,
  }) {
    return math.max(0, (contentExtent - viewportExtent) / 2);
  }

  void _scheduleHorizontalPanStateNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyHorizontalPanState();
    });
  }

  void _notifyHorizontalPanState() {
    final callback = widget.onHorizontalPanStateChanged;
    if (callback == null) return;

    var canScrollLeft = false;
    var canScrollRight = false;
    final horizontalScrollController = _horizontalScrollController;
    if (horizontalScrollController != null &&
        horizontalScrollController.hasClients) {
      final position = horizontalScrollController.position;
      canScrollLeft = position.pixels > position.minScrollExtent + 0.5;
      canScrollRight = position.pixels < position.maxScrollExtent - 0.5;
    }

    final nextState = WorldMapHorizontalPanState(
      canScrollLeft: canScrollLeft,
      canScrollRight: canScrollRight,
    );
    final previousState = _lastHorizontalPanState;
    if (previousState != null &&
        previousState.canScrollLeft == nextState.canScrollLeft &&
        previousState.canScrollRight == nextState.canScrollRight) {
      return;
    }
    _lastHorizontalPanState = nextState;
    callback(nextState);
  }

  Size _mapDesignSize(String mapImageUrl) {
    const fallbackSize = Size(1024, 1536);
    final url = mapImageUrl.trim();
    if (url.isEmpty) return fallbackSize;
    final cachedSize = _mapImageDimensionsByUrl[url];
    if (cachedSize != null && !cachedSize.isEmpty) return cachedSize;
    _resolveMapImageDimensions(url);
    return fallbackSize;
  }

  void _resolveMapImageDimensions(String url) {
    if (_pendingMapImageDimensionUrls.contains(url)) return;
    _pendingMapImageDimensionUrls.add(url);

    final ImageProvider imageProvider = url.startsWith('assets/')
        ? AssetImage(url)
        : NetworkImage(url);
    final stream = imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        stream.removeListener(listener);
        _pendingMapImageDimensionUrls.remove(url);
        final image = imageInfo.image;
        final size = Size(image.width.toDouble(), image.height.toDouble());
        if (size.isEmpty) return;
        _applyResolvedMapImageDimensions(url, size);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        _pendingMapImageDimensionUrls.remove(url);
        debugPrint(
          '[WorldMap] resolve map dimensions failed url="$url": $error',
        );
      },
    );
    stream.addListener(listener);
  }

  void _applyResolvedMapImageDimensions(String url, Size size) {
    final previousSize = _mapImageDimensionsByUrl[url];
    if (previousSize == size) return;
    _mapImageDimensionsByUrl[url] = size;
    if (!mounted) return;

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }

    setState(() {});
  }

  void _debugPrintLocationTree(String reason) {
    if (!kDebugMode) return;

    final buffer = StringBuffer();
    for (final node in widget.locationNodes) {
      _writeLocationNodeDebug(buffer, node, 0);
    }

    final treeText = buffer.toString();
    final signature = [
      widget.mapImageUrl,
      _initialMapImageUrl,
      treeText,
    ].join('\n');
    if (signature == _lastLoggedLocationTreeSignature) return;
    _lastLoggedLocationTreeSignature = signature;

    debugPrint(
      '[WorldMap] location tree $reason: '
      'roots=${widget.locationNodes.length}, '
      'widgetMapUrl="${widget.mapImageUrl}", '
      'initialMapUrl="$_initialMapImageUrl"',
    );
    if (widget.locationNodes.isEmpty) {
      debugPrint('[WorldMap] location tree is empty');
      return;
    }
    debugPrint(treeText);
  }

  void _writeLocationNodeDebug(
    StringBuffer buffer,
    WorldMapLocationNode node,
    int depth,
  ) {
    final indent = '  ' * depth;
    buffer.writeln(
      '$indent- id="${node.id}" '
      'name="${node.point.name}" '
      'pointId="${node.point.id}" '
      'sceneId="${node.point.sceneId}" '
      'isRoot=${node.isRoot} '
      'pointDepth=${node.point.depth} '
      'isLeafPoint=${node.point.isLeafLocation} '
      'children=${node.children.length} '
      'mapUrl="${node.mapImageUrl}"',
    );
    for (final child in node.children) {
      _writeLocationNodeDebug(buffer, child, depth + 1);
    }
  }
}

class _MapViewport {
  const _MapViewport({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  factory _MapViewport.cover({
    required double viewportWidth,
    required double viewportHeight,
    required double designWidth,
    required double designHeight,
  }) {
    final widthScale = viewportWidth / designWidth;
    final heightScale = viewportHeight / designHeight;
    final scale = math.max(widthScale, heightScale);
    final width = designWidth * scale;
    final height = designHeight * scale;

    return _MapViewport(left: 0, top: 0, width: width, height: height);
  }
}

class _ExitLocationButton extends StatelessWidget {
  const _ExitLocationButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim();
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = displayLabel.isEmpty
            ? 0.0
            : (TextPainter(
                text: TextSpan(text: displayLabel, style: textStyle),
                maxLines: 1,
                textDirection: Directionality.of(context),
              )..layout()).width;
        final desiredWidth =
            36.0 + (displayLabel.isEmpty ? 0.0 : textWidth + 12);
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : desiredWidth;
        final buttonWidth = math.min(desiredWidth, maxWidth);

        return SizedBox(
          width: buttonWidth,
          height: 36,
          child: Container(
            padding: EdgeInsets.only(
              left: 0,
              right: displayLabel.isEmpty ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPressed,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.subdirectory_arrow_left,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                    if (displayLabel.isNotEmpty)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            displayLabel,
                            maxLines: 1,
                            style: textStyle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConstrainedMaxWidth extends StatelessWidget {
  const _ConstrainedMaxWidth({required this.maxWidth, required this.child});

  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth;
    if (resolvedMaxWidth == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
      child: child,
    );
  }
}

class _WorldMapTransitionSurface extends StatelessWidget {
  const _WorldMapTransitionSurface({
    required this.mapKey,
    required this.transition,
    required this.child,
  });

  final LocalKey mapKey;
  final _MapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(seconds: 1),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return _WorldMapZoomFadeTransition(
          animation: animation,
          incoming: child.key == mapKey,
          transition: transition,
          child: child,
        );
      },
      child: KeyedSubtree(key: mapKey, child: child),
    );
  }
}

class _WorldMapZoomFadeTransition extends StatelessWidget {
  const _WorldMapZoomFadeTransition({
    required this.animation,
    required this.incoming,
    required this.transition,
    required this.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final _MapTransitionSpec transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: incoming ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final scale = _transitionScale(t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: transition.origin,
            child: child,
          ),
        );
      },
    );
  }

  double _transitionScale(double t) {
    return switch (transition.direction) {
      _MapTransitionDirection.drillIn =>
        incoming ? _lerpDouble(0.56, 1, t) : _lerpDouble(1.68, 1, t),
      _MapTransitionDirection.drillOut =>
        incoming ? _lerpDouble(1.68, 1, t) : _lerpDouble(0.56, 1, t),
    };
  }
}

class _WorldMapLocationTrailEntry {
  const _WorldMapLocationTrailEntry({required this.id, required this.origin});

  final String id;
  final Alignment origin;
}

class _MapTransitionSpec {
  const _MapTransitionSpec({required this.origin, required this.direction});

  final Alignment origin;
  final _MapTransitionDirection direction;
}

enum _MapTransitionDirection { drillIn, drillOut }

String _pointLocationId(WorldPoint point) {
  final sceneId = point.sceneId.trim();
  if (sceneId.isNotEmpty) return sceneId;
  final pointId = point.pointId.trim();
  if (pointId.isNotEmpty) return pointId;
  return point.id.trim();
}

Alignment _mapTransitionOrigin(WorldPoint point) {
  final dx = point.position.dx.clamp(0.0, 1.0).toDouble();
  final dy = point.position.dy.clamp(0.0, 1.0).toDouble();
  return Alignment(dx * 2 - 1, dy * 2 - 1);
}

String _selectWorldMapImageUrl(
  String url, {
  required double logicalWidth,
  required double devicePixelRatio,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  return resizeGenesisImageUrl(
    trimmed,
    logicalWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
  ).trim();
}

String _selectWorldMapPreviewImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  return resizeGenesisImageUrl(
    trimmed,
    logicalWidth: _worldMapPreviewImageLogicalWidth,
    devicePixelRatio: 1,
  ).trim();
}

String _selectWorldMapAvatarUrl(
  String url, {
  required double devicePixelRatio,
}) {
  return selectGenesisImageUrl(
    url,
    logicalWidth: _worldMapAvatarImageLogicalSize,
    logicalHeight: _worldMapAvatarImageLogicalSize,
    devicePixelRatio: devicePixelRatio,
  ).trim();
}

double _lerpDouble(double begin, double end, double t) {
  return begin + (end - begin) * t;
}

class _MapBackgroundDeck extends StatefulWidget {
  const _MapBackgroundDeck({
    required this.currentUrl,
    required this.previewUrl,
    required this.preloadUrls,
    required this.preloadAvatarUrls,
    required this.fallbackOnEmptyUrl,
  });

  final String currentUrl;
  final String previewUrl;
  final List<String> preloadUrls;
  final List<String> preloadAvatarUrls;
  final bool fallbackOnEmptyUrl;

  @override
  State<_MapBackgroundDeck> createState() => _MapBackgroundDeckState();
}

class _MapBackgroundDeckState extends State<_MapBackgroundDeck> {
  int _preloadGeneration = 0;
  String _loadedCurrentUrl = '';

  @override
  void didUpdateWidget(covariant _MapBackgroundDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUrl.trim() != widget.currentUrl.trim()) {
      _loadedCurrentUrl = '';
      _preloadGeneration++;
    }
  }

  void _handleCurrentLoaded() {
    final current = widget.currentUrl.trim();
    if (_loadedCurrentUrl == current) return;
    _loadedCurrentUrl = current;
    final generation = ++_preloadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _preloadGeneration) return;
      unawaited(_preloadSecondaryImages(current, generation));
    });
  }

  Future<void> _preloadSecondaryImages(String current, int generation) async {
    final avatarUrls = widget.preloadAvatarUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
    for (final url in avatarUrls) {
      if (!mounted || generation != _preloadGeneration) return;
      try {
        await precacheImage(_avatarImageProvider(url), context);
      } catch (error) {
        debugPrint('[WorldMap] preload avatar failed url="$url": $error');
      }
    }

    final urls = widget.preloadUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && url != current)
        .toSet()
        .toList(growable: false);

    for (final url in urls) {
      if (!mounted || generation != _preloadGeneration) return;
      try {
        await precacheImage(_mapImageProvider(url), context);
      } catch (error) {
        debugPrint('[WorldMap] preload map image failed url="$url": $error');
      }
    }
  }

  ImageProvider _mapImageProvider(String url) {
    return url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url);
  }

  ImageProvider _avatarImageProvider(String url) {
    return url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return _MapBackground(
      url: widget.currentUrl.trim(),
      previewUrl: widget.previewUrl.trim(),
      fallbackOnEmptyUrl: widget.fallbackOnEmptyUrl,
      onLoaded: _handleCurrentLoaded,
    );
  }
}

typedef _MapOverlayBuilder =
    Widget Function(
      BuildContext context,
      Matrix4 transform,
      ValueChanged<PointerDownEvent> onOverlayPointerDown,
    );
typedef _ZoomControlChanged =
    void Function(Object token, void Function(double delta)? zoomByControl);

class _ZoomableMapContent extends StatefulWidget {
  const _ZoomableMapContent({
    required this.background,
    required this.initialScale,
    required this.initialFocus,
    required this.initialTransformKey,
    required this.initialViewportSize,
    required this.overlayBuilder,
    required this.onScaleChanged,
    required this.onZoomControlChanged,
  });

  static const double minScale = 1;
  static const double maxScale = 2;
  static const double doubleTapScale = 1.5;

  final Widget background;
  final double initialScale;
  final Offset? initialFocus;
  final String initialTransformKey;
  final Size initialViewportSize;
  final _MapOverlayBuilder overlayBuilder;
  final ValueChanged<double> onScaleChanged;
  final _ZoomControlChanged onZoomControlChanged;

  @override
  State<_ZoomableMapContent> createState() => _ZoomableMapContentState();
}

class _ZoomableMapContentState extends State<_ZoomableMapContent> {
  late final TransformationController _transformationController;
  final Object _zoomControlToken = Object();
  final Set<int> _activePointers = <int>{};
  final Set<int> _overlayPointers = <int>{};
  final Map<int, Offset> _activePointerPositions = <int, Offset>{};
  bool _interactionActive = false;
  Duration? _lastTapTime;
  Offset? _lastTapLocalPosition;
  Matrix4? _manualGestureStartMatrix;
  Offset? _manualGestureStartFocal;
  double? _manualGestureStartDistance;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController(
      _initialTransformForSize(widget.initialViewportSize),
    );
    _transformationController.addListener(_notifyScaleChanged);
    widget.onZoomControlChanged(_zoomControlToken, zoomByControl);
  }

  @override
  void didUpdateWidget(covariant _ZoomableMapContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onZoomControlChanged != widget.onZoomControlChanged) {
      oldWidget.onZoomControlChanged(_zoomControlToken, null);
      widget.onZoomControlChanged(_zoomControlToken, zoomByControl);
    }
    if (oldWidget.initialTransformKey != widget.initialTransformKey) {
      _applyInitialTransform(widget.initialViewportSize);
    }
  }

  @override
  void dispose() {
    widget.onZoomControlChanged(_zoomControlToken, null);
    _transformationController.removeListener(_notifyScaleChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _notifyScaleChanged() {
    widget.onScaleChanged(_transformationController.value.getMaxScaleOnAxis());
  }

  void _applyInitialTransform(Size size) {
    _transformationController.value = _initialTransformForSize(size);
  }

  Matrix4 _initialTransformForSize(Size size) {
    final scale = widget.initialScale
        .clamp(_ZoomableMapContent.minScale, _ZoomableMapContent.maxScale)
        .toDouble();
    if (size.isEmpty || scale <= _ZoomableMapContent.minScale + 0.001) {
      return Matrix4.identity();
    }

    final focus = widget.initialFocus ?? const Offset(0.5, 0.5);
    final clampedFocus = Offset(
      focus.dx.clamp(0.0, 1.0).toDouble(),
      focus.dy.clamp(0.0, 1.0).toDouble(),
    );
    final contentFocus = Offset(
      size.width * clampedFocus.dx,
      size.height * clampedFocus.dy,
    );
    final center = Offset(size.width / 2, size.height / 2);
    return _transformMatrixForSize(
      size: size,
      scale: scale,
      translation: center - contentFocus * scale,
    );
  }

  bool get _isZoomed {
    return _transformationController.value.getMaxScaleOnAxis() >
        _ZoomableMapContent.minScale + 0.01;
  }

  void _dispatchMapInteraction(bool active) {
    if (_interactionActive == active) return;
    _interactionActive = active;
    WorldMapInteractionNotification(active: active).dispatch(context);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) _handlePossibleDoubleTap(event);
    _activePointers.add(event.pointer);
    _activePointerPositions[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2 || _isZoomed) {
      _dispatchMapInteraction(true);
    }
    _startManualGestureIfNeeded();
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    _overlayPointers.add(event.pointer);
    _startManualGestureIfNeeded();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.contains(event.pointer)) return;
    _activePointerPositions[event.pointer] = event.localPosition;

    if (_activePointerPositions.length >= 2) {
      _startManualGestureIfNeeded();
      _updateManualScaleGesture();
      return;
    }

    if (_isZoomed && _overlayPointers.contains(event.pointer)) {
      _updateManualPanGesture(event);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _overlayPointers.remove(event.pointer);
    _activePointerPositions.remove(event.pointer);
    if (_activePointers.length < 2) _clearManualScaleGesture();
    if (_activePointers.isEmpty) {
      _dispatchMapInteraction(false);
    }
  }

  void _startManualGestureIfNeeded() {
    if (_activePointerPositions.length < 2) {
      return;
    }
    if (_manualGestureStartMatrix != null) return;

    final points = _activePointerPositions.values.take(2).toList();
    _manualGestureStartMatrix = Matrix4.copy(_transformationController.value);
    _manualGestureStartFocal = _focalPoint(points);
    _manualGestureStartDistance = (points[0] - points[1]).distance;
  }

  void _updateManualScaleGesture() {
    final startMatrix = _manualGestureStartMatrix;
    final startFocal = _manualGestureStartFocal;
    final startDistance = _manualGestureStartDistance;
    if (startMatrix == null || startFocal == null || startDistance == null) {
      return;
    }

    final points = _activePointerPositions.values.take(2).toList();
    if (points.length < 2) return;
    final currentDistance = (points[0] - points[1]).distance;
    if (startDistance <= 0 || currentDistance <= 0) return;

    final startScale = startMatrix.getMaxScaleOnAxis();
    final targetScale = (startScale * currentDistance / startDistance)
        .clamp(_ZoomableMapContent.minScale, _ZoomableMapContent.maxScale)
        .toDouble();
    final currentFocal = _focalPoint(points);
    final startValues = startMatrix.storage;
    final contentFocal = Offset(
      (startFocal.dx - startValues[12]) / startScale,
      (startFocal.dy - startValues[13]) / startScale,
    );
    final translation = currentFocal - contentFocal * targetScale;
    _setTransform(targetScale, translation);
    _dispatchMapInteraction(true);
  }

  void _updateManualPanGesture(PointerMoveEvent event) {
    final matrix = _transformationController.value;
    final values = matrix.storage;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = Offset(values[12], values[13]) + event.delta;
    _setTransform(scale, translation);
    _dispatchMapInteraction(true);
  }

  void _setTransform(double scale, Offset translation) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    _transformationController.value = _transformMatrixForSize(
      size: size,
      scale: scale,
      translation: translation,
    );
  }

  Matrix4 _transformMatrixForSize({
    required Size size,
    required double scale,
    required Offset translation,
  }) {
    if (size.isEmpty || scale <= _ZoomableMapContent.minScale + 0.001) {
      return Matrix4.identity();
    }

    final minX = size.width - size.width * scale;
    final minY = size.height - size.height * scale;
    final clampedTranslation = Offset(
      translation.dx.clamp(minX, 0.0).toDouble(),
      translation.dy.clamp(minY, 0.0).toDouble(),
    );
    return Matrix4.identity()
      ..translateByDouble(clampedTranslation.dx, clampedTranslation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Offset _focalPoint(List<Offset> points) {
    return Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
  }

  void _clearManualScaleGesture() {
    _manualGestureStartMatrix = null;
    _manualGestureStartFocal = null;
    _manualGestureStartDistance = null;
  }

  void _handlePossibleDoubleTap(PointerDownEvent event) {
    final lastTapTime = _lastTapTime;
    final lastTapLocalPosition = _lastTapLocalPosition;
    final currentPosition = event.localPosition;
    final isDoubleTap =
        lastTapTime != null &&
        lastTapLocalPosition != null &&
        event.timeStamp - lastTapTime <= const Duration(milliseconds: 300) &&
        (currentPosition - lastTapLocalPosition).distance <= 48;

    if (isDoubleTap) {
      _lastTapTime = null;
      _lastTapLocalPosition = null;
      _toggleDoubleTapZoom(currentPosition);
      return;
    }

    _lastTapTime = event.timeStamp;
    _lastTapLocalPosition = currentPosition;
  }

  void _toggleDoubleTapZoom(Offset focalPoint) {
    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
      _dispatchMapInteraction(false);
      return;
    }

    final scale = _ZoomableMapContent.doubleTapScale;
    _setTransform(
      scale,
      Offset(
        focalPoint.dx - focalPoint.dx * scale,
        focalPoint.dy - focalPoint.dy * scale,
      ),
    );
  }

  void zoomByControl(double delta) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    if (size.isEmpty) return;

    final matrix = _transformationController.value;
    final values = matrix.storage;
    final currentScale = matrix.getMaxScaleOnAxis();
    final targetScale = (currentScale + delta)
        .clamp(_ZoomableMapContent.minScale, _ZoomableMapContent.maxScale)
        .toDouble();
    if ((targetScale - currentScale).abs() < 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final translation = Offset(values[12], values[13]);
    final contentCenter = (center - translation) / currentScale;
    _setTransform(targetScale, center - contentCenter * targetScale);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerEnd,
            onPointerCancel: _handlePointerEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _ZoomableMapContent.minScale,
                  maxScale: _ZoomableMapContent.maxScale,
                  boundaryMargin: EdgeInsets.zero,
                  onInteractionStart: (details) {
                    if (details.pointerCount > 1 || _isZoomed) {
                      _dispatchMapInteraction(true);
                    }
                  },
                  onInteractionUpdate: (details) {
                    if (details.pointerCount > 1 || _isZoomed) {
                      _dispatchMapInteraction(true);
                    }
                  },
                  onInteractionEnd: (_) {
                    if (_activePointers.isEmpty) {
                      _dispatchMapInteraction(false);
                    }
                  },
                  child: SizedBox.expand(child: widget.background),
                ),
                AnimatedBuilder(
                  animation: _transformationController,
                  builder: (context, _) => widget.overlayBuilder(
                    context,
                    _transformationController.value,
                    _handleOverlayPointerDown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapZoomControl extends StatelessWidget {
  const _MapZoomControl({
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  static const Color _enabledColor = Color(0xFF111111);
  static const Color _disabledColor = Color(0xFFC7C7C7);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('world-map-zoom-control'),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(_worldMapZoomControlRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_worldMapZoomControlRadius),
        child: SizedBox(
          width: _worldMapZoomControlWidth,
          height: _worldMapZoomControlHeight,
          child: Column(
            children: [
              Expanded(
                child: _MapZoomButton(
                  key: const ValueKey<String>('world-map-zoom-in'),
                  iconAsset: _worldMapZoomInIconAsset,
                  label: '放大地图',
                  color: canZoomIn ? _enabledColor : _disabledColor,
                  onTap: canZoomIn ? onZoomIn : null,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
              Expanded(
                child: _MapZoomButton(
                  key: const ValueKey<String>('world-map-zoom-out'),
                  iconAsset: _worldMapZoomOutIconAsset,
                  label: '缩小地图',
                  color: canZoomOut ? _enabledColor : _disabledColor,
                  onTap: canZoomOut ? onZoomOut : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: SvgPicture.asset(
              iconAsset,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapBackground extends StatefulWidget {
  const _MapBackground({
    required this.url,
    this.previewUrl = '',
    this.fallbackOnEmptyUrl = true,
    this.onLoaded,
  });

  final String url;
  final String previewUrl;
  final bool fallbackOnEmptyUrl;
  final VoidCallback? onLoaded;

  @override
  State<_MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<_MapBackground> {
  bool _showFullImage = false;

  @override
  void initState() {
    super.initState();
    _scheduleFullImage();
  }

  @override
  void didUpdateWidget(covariant _MapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.previewUrl != widget.previewUrl) {
      _showFullImage = false;
      _scheduleFullImage();
    }
  }

  void _notifyLoaded() {
    final callback = widget.onLoaded;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  void _scheduleFullImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showFullImage) return;
      setState(() {
        _showFullImage = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = widget.url.trim();
    if (trimmedUrl.isEmpty) {
      _notifyLoaded();
      return widget.fallbackOnEmptyUrl
          ? const _FallbackMapBackground()
          : const _MapBackgroundPlaceholder();
    }

    if (trimmedUrl.startsWith('assets/')) {
      return Image.asset(
        trimmedUrl,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) _notifyLoaded();
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          _notifyLoaded();
          return const _FallbackMapBackground();
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _MapBackgroundPreview(
          url: widget.previewUrl,
          fallbackOnEmptyUrl: widget.fallbackOnEmptyUrl,
        ),
        if (_showFullImage)
          GenesisStaticNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            onImageLoaded: _notifyLoaded,
            placeholder: (_) => const SizedBox.shrink(),
            errorWidget: (context, error) {
              _notifyLoaded();
              return widget.fallbackOnEmptyUrl
                  ? const _FallbackMapBackground()
                  : const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}

class _MapBackgroundPreview extends StatelessWidget {
  const _MapBackgroundPreview({
    required this.url,
    required this.fallbackOnEmptyUrl,
  });

  final String url;
  final bool fallbackOnEmptyUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || trimmedUrl.startsWith('assets/')) {
      return fallbackOnEmptyUrl
          ? const _FallbackMapBackground()
          : const _MapBackgroundPlaceholder();
    }

    return GenesisStaticNetworkImage(
      imageUrl: trimmedUrl,
      fit: BoxFit.cover,
      placeholder: (_) => const _MapBackgroundPlaceholder(),
      errorWidget: (context, error) {
        return fallbackOnEmptyUrl
            ? const _FallbackMapBackground()
            : const _MapBackgroundPlaceholder();
      },
    );
  }
}

class _FallbackMapBackground extends StatelessWidget {
  const _FallbackMapBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kWorldMapFallbackBackgroundAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _MapBackgroundPlaceholder(),
    );
  }
}

class _MapBackgroundPlaceholder extends StatelessWidget {
  const _MapBackgroundPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFFF3F4F6));
  }
}

class _WorldPointPositioned extends StatelessWidget {
  const _WorldPointPositioned({
    required this.point,
    required this.width,
    required this.height,
    this.transform,
    this.messageBubble,
    required this.onPointerDown,
    required this.onTap,
  });

  final WorldPoint point;
  final double width;
  final double height;
  final Matrix4? transform;
  final WorldMapMessageBubble? messageBubble;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  static const double _labelLineHeight = 12;
  static const double _labelHorizontalPadding = 6;
  static const double _labelVerticalPadding = 8;
  static const double _wideLabelRuneWidth = 14;
  static const double _narrowLabelRuneWidth = 6;
  static const double _maxLabelTextWidth = 90;
  static const double _maxLabelBoxWidth =
      _maxLabelTextWidth + _labelHorizontalPadding;
  static const double _pointSize = 8;
  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _labelToPointSpacing = 6;
  static const double _avatarTopGap = 10;

  double _markerWidth(int userCount) {
    final count = userCount;
    final avatarWidth = _avatarGroupWidth(count);
    final labelMaxWidth = _labelMaxWidth();
    return math.max(math.max(_pointSize, avatarWidth), labelMaxWidth);
  }

  double _labelHeight(String text) {
    final estimatedTextWidth = _estimatedLabelTextWidth(text);
    final lineCount = math.max(
      1,
      (estimatedTextWidth / _maxLabelTextWidth).ceil(),
    );
    return lineCount * _labelLineHeight + _labelVerticalPadding;
  }

  double _labelMaxWidth() {
    return math.min(_maxLabelBoxWidth, width);
  }

  double _estimatedLabelTextWidth(String text) {
    var width = 0.0;
    for (final rune in text.runes) {
      width += _isWideLabelRune(rune)
          ? _wideLabelRuneWidth
          : _narrowLabelRuneWidth;
    }
    return width;
  }

  bool _isWideLabelRune(int rune) {
    return (rune >= 0x1100 && rune <= 0x11FF) ||
        (rune >= 0x2E80 && rune <= 0xA4CF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0xFE10 && rune <= 0xFE6F) ||
        (rune >= 0xFF00 && rune <= 0xFFEF) ||
        (rune >= 0x20000 && rune <= 0x3FFFD);
  }

  double _markerHeight(int userCount) {
    final count = userCount;
    final pointCenterY =
        _labelHeight(point.name) + _labelToPointSpacing + _pointSize / 2;
    if (count <= 0) return pointCenterY + _pointSize / 2;
    if (count < 4) return pointCenterY + _avatarTopGap + _avatarSize;
    if (count == 4) {
      return pointCenterY + _avatarTopGap + _avatarSize * 2 + _avatarSpacing;
    }

    final radius = _avatarRingRadius(count);
    return pointCenterY + radius * 2 + _avatarTopGap + _avatarSize;
  }

  double _avatarGroupWidth(int count) {
    if (count <= 0) return 0;
    if (count < 4) {
      return count * _avatarSize + (count - 1) * _avatarSpacing;
    }
    if (count == 4) return _avatarSize * 2 + _avatarSpacing;
    return _avatarRingRadius(count) * 2 + _avatarSize;
  }

  double _avatarRingRadius(int count) {
    if (count < 4) return 0;
    final minimumChord = count > 5
        ? _avatarSize * 0.88
        : _avatarSize + _avatarSpacing;
    final radius = minimumChord / (2 * math.sin(math.pi / count));
    return math.max(_avatarSize * 0.88, radius);
  }

  @override
  Widget build(BuildContext context) {
    final users = point.users;
    final labelMaxWidth = _labelMaxWidth();
    final markerWidth = _markerWidth(users.length);
    final markerHeight = _markerHeight(users.length);
    final pointCenterY =
        _labelHeight(point.name) + _labelToPointSpacing + _pointSize / 2;

    final baseX = (point.position.dx * width).clamp(0, width).toDouble();
    final baseY = (point.position.dy * height).clamp(0, height).toDouble();
    final transformedAnchor = _transformedAnchor(baseX, baseY);
    final x = transformedAnchor.dx;
    final y = transformedAnchor.dy;

    final shouldClamp = transform == null;
    final maxLeft = (width - markerWidth) > 0 ? (width - markerWidth) : 0.0;
    final maxTop = (height - markerHeight) > 0 ? (height - markerHeight) : 0.0;

    final rawLeft = x - markerWidth / 2;
    final rawTop = y - pointCenterY;
    final left = shouldClamp ? rawLeft.clamp(0.0, maxLeft).toDouble() : rawLeft;
    final top = shouldClamp ? rawTop.clamp(0.0, maxTop).toDouble() : rawTop;

    return Positioned(
      left: left,
      top: top,
      width: markerWidth,
      height: markerHeight,
      child: _WorldPointMarker(
        point: point,
        users: users,
        labelMaxWidth: labelMaxWidth,
        markerWidth: markerWidth,
        markerHeight: markerHeight,
        pointCenterY: pointCenterY,
        messageBubble: messageBubble,
        onPointerDown: onPointerDown,
        onTap: onTap,
      ),
    );
  }

  Offset _transformedAnchor(double x, double y) {
    final matrix = transform;
    if (matrix == null) return Offset(x, y);
    final values = matrix.storage;
    return Offset(
      values[0] * x + values[4] * y + values[12],
      values[1] * x + values[5] * y + values[13],
    );
  }
}

class _WorldPointMarker extends StatelessWidget {
  const _WorldPointMarker({
    required this.point,
    required this.users,
    required this.labelMaxWidth,
    required this.markerWidth,
    required this.markerHeight,
    required this.pointCenterY,
    this.messageBubble,
    required this.onPointerDown,
    this.onTap,
  });

  final WorldPoint point;
  final List<UserAvatar> users;
  final double labelMaxWidth;
  final double markerWidth;
  final double markerHeight;
  final double pointCenterY;
  final WorldMapMessageBubble? messageBubble;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final VoidCallback? onTap;

  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _avatarTopGap = 10;
  static const double _pointSize = 8;

  double _ringRadius(int count) {
    if (count < 4) return 0;
    final minimumChord = count > 5
        ? _avatarSize * 0.88
        : _avatarSize + _avatarSpacing;
    final radius = minimumChord / (2 * math.sin(math.pi / count));
    return math.max(_avatarSize * 0.88, radius);
  }

  @override
  Widget build(BuildContext context) {
    final hasUsers = users.isNotEmpty;
    final avatars = users;
    final bubbleIndex = messageBubble == null
        ? -1
        : avatars.indexWhere(
            (avatar) => avatar.id.trim() == messageBubble!.characterId.trim(),
          );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: onPointerDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: markerWidth,
          height: markerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: labelMaxWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 4,
                        ),
                        child: _PointLabel(point: point, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: markerWidth / 2 - _pointSize / 2,
                top: pointCenterY - _pointSize / 2,
                width: _pointSize,
                height: _pointSize,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF008D68),
                  ),
                ),
              ),
              if (hasUsers)
                for (int i = 0; i < avatars.length; i++)
                  _PositionedMapAvatar(
                    key: ValueKey<String>(
                      'map-positioned-avatar-${_mapAvatarStableKey(avatars[i])}',
                    ),
                    user: avatars[i],
                    left: _avatarLeft(i, avatars.length),
                    top: _avatarTop(i, avatars.length),
                  ),
              if (messageBubble != null && bubbleIndex >= 0)
                _PositionedMapMessageBubble(
                  text: messageBubble!.content,
                  avatarLeft: _avatarLeft(bubbleIndex, avatars.length),
                  avatarTop: _avatarTop(bubbleIndex, avatars.length),
                  markerWidth: markerWidth,
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _avatarLeft(int index, int count) {
    if (count < 4) {
      final rowWidth = count * _avatarSize + (count - 1) * _avatarSpacing;
      return markerWidth / 2 -
          rowWidth / 2 +
          index * (_avatarSize + _avatarSpacing);
    }
    if (count == 4) {
      final gridWidth = _avatarSize * 2 + _avatarSpacing;
      final column = index % 2;
      return markerWidth / 2 -
          gridWidth / 2 +
          column * (_avatarSize + _avatarSpacing);
    }

    final radius = _ringRadius(count);
    final ringCenterX = markerWidth / 2;
    final angle = -math.pi / 2 + math.pi * 2 * index / count;
    return ringCenterX + math.cos(angle) * radius - _avatarSize / 2;
  }

  double _avatarTop(int index, int count) {
    if (count < 4) return pointCenterY + _avatarTopGap;
    if (count == 4) {
      final row = index ~/ 2;
      return pointCenterY +
          _avatarTopGap +
          row * (_avatarSize + _avatarSpacing);
    }

    final radius = _ringRadius(count);
    final ringCenterY = pointCenterY + radius + _avatarTopGap + _avatarSize / 2;
    final angle = -math.pi / 2 + math.pi * 2 * index / count;
    return ringCenterY + math.sin(angle) * radius - _avatarSize / 2;
  }
}

class _PositionedMapMessageBubble extends StatelessWidget {
  const _PositionedMapMessageBubble({
    required this.text,
    required this.avatarLeft,
    required this.avatarTop,
    required this.markerWidth,
  });

  final String text;
  final double avatarLeft;
  final double avatarTop;
  final double markerWidth;

  static const double _avatarSize = 42;
  static const double _bubbleGap = 8;
  static const double _bubbleWidth = 220;
  static const double _pointerWidth = 12;
  static const double _pointerHeight = 10;

  @override
  Widget build(BuildContext context) {
    final centeredLeft = avatarLeft + _avatarSize / 2 - _bubbleWidth / 2;
    final left = centeredLeft.clamp(
      -_bubbleWidth / 2,
      math.max(markerWidth - _bubbleWidth / 2, -_bubbleWidth / 2),
    );

    return Positioned(
      left: left.toDouble(),
      top: avatarTop + _avatarSize + _bubbleGap - _pointerHeight,
      width: _bubbleWidth,
      child: IgnorePointer(
        child: _MapMessageBubble(
          text: text,
          pointerLeft: (avatarLeft + _avatarSize / 2 - left.toDouble())
              .clamp(_pointerWidth * 1.5, _bubbleWidth - _pointerWidth * 1.5)
              .toDouble(),
        ),
      ),
    );
  }
}

class _MapMessageBubble extends StatelessWidget {
  const _MapMessageBubble({required this.text, required this.pointerLeft});

  final String text;
  final double pointerLeft;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: pointerLeft - 6,
          top: 0,
          width: 12,
          height: 10,
          child: CustomPaint(
            painter: const _MapMessageBubblePointerPainter(color: Colors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            key: const ValueKey<String>('world-map-message-bubble-body'),
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapMessageBubblePointerPainter extends CustomPainter {
  const _MapMessageBubblePointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MapMessageBubblePointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

@visibleForTesting
List<String> worldMapMessageBubblePagesForTesting(String content) {
  final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return const <String>[];
  final pages = <String>[];
  var remaining = normalized;
  while (remaining.length > _worldMapBubblePageMaxCharacters) {
    var split = remaining.lastIndexOf(' ', _worldMapBubblePageMaxCharacters);
    if (split <= 0) split = _worldMapBubblePageMaxCharacters;
    pages.add(remaining.substring(0, split).trim());
    remaining = remaining.substring(split).trim();
  }
  if (remaining.isNotEmpty) pages.add(remaining);
  return List<String>.unmodifiable(pages);
}

class _PointLabel extends StatelessWidget {
  const _PointLabel({required this.point, this.color});

  final WorldPoint point;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      point.name,
      textAlign: TextAlign.center,
      softWrap: true,
      style: TextStyle(
        fontSize: 10,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.black,
      ),
    );
  }
}

class _PositionedMapAvatar extends StatelessWidget {
  const _PositionedMapAvatar({
    super.key,
    required this.user,
    required this.left,
    required this.top,
  });

  final UserAvatar user;
  final double left;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: _MapAvatarImage(
        key: ValueKey<String>('map-avatar-${_mapAvatarStableKey(user)}'),
        url: user.avatarUrl,
        name: (user.name ?? user.initials).trim(),
        showStar: user.showStar,
        isPlayerControlledRole: user.isPlayerControlledRole,
      ),
    );
  }
}

class _MapAvatarImage extends StatelessWidget {
  const _MapAvatarImage({
    super.key,
    required this.url,
    required this.name,
    required this.showStar,
    required this.isPlayerControlledRole,
  });

  final String url;
  final String name;
  final bool showStar;
  final bool isPlayerControlledRole;

  static const double _size = _worldMapAvatarImageLogicalSize;

  @override
  Widget build(BuildContext context) {
    return GenesisCharacterAvatar(
      url: url,
      name: name,
      size: _size,
      borderRadius: GenesisAvatarRadii.character,
      showStar: showStar,
      showFallbackWhileLoading: false,
      showFallbackWhenUnavailable: true,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
      border: Border.all(
        color: worldMapAvatarBorderColorForTesting(
          isPlayerControlledRole: isPlayerControlledRole,
        ),
        width: 1,
      ),
    );
  }
}

String _mapAvatarStableKey(UserAvatar user) {
  final id = user.id.trim();
  final avatarUrl = user.avatarUrl.trim();
  final name = (user.name ?? user.initials).trim();
  return '$id|$avatarUrl|$name';
}
