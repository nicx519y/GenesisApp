import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/components/genesis_character_avatar.dart';
import 'world_map_interaction_notification.dart';
import 'world_location_list.dart';
import 'world_point.dart';

export 'world_location_list.dart';
export 'world_point.dart';

const String kWorldMapFallbackBackgroundAsset =
    'assets/images/mock_maps/map_background.png';

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

class WorldMapLocationNode {
  const WorldMapLocationNode({
    required this.id,
    required this.point,
    this.mapImageUrl = '',
    this.isRoot = false,
    this.chatTargetPoint,
    this.children = const <WorldMapLocationNode>[],
  });

  final String id;
  final WorldPoint point;
  final String mapImageUrl;
  final bool isRoot;
  final WorldPoint? chatTargetPoint;
  final List<WorldMapLocationNode> children;
}

class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    required this.points,
    this.listPoints,
    this.locationNodes = const <WorldMapLocationNode>[],
    this.mapImageUrl = '',
    this.preloadMapImageUrls = const <String>[],
    this.fallbackOnEmptyMapUrl = true,
    this.dimmed = false,
    this.showPointsList = false,
    this.overlayTop = 0,
    this.drillExitTop = 68,
    this.onDrillIntoLocation,
    this.onPointTap,
  });

  final List<WorldPoint> points;
  final List<WorldPoint>? listPoints;
  final List<WorldMapLocationNode> locationNodes;
  final String mapImageUrl;
  final List<String> preloadMapImageUrls;
  final bool fallbackOnEmptyMapUrl;
  final bool dimmed;
  final bool showPointsList;
  final double overlayTop;
  final double drillExitTop;
  final VoidCallback? onDrillIntoLocation;
  final WorldPointTapCallback? onPointTap;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  final List<_WorldMapLocationTrailEntry> _locationTrail =
      <_WorldMapLocationTrailEntry>[];
  final Set<String> _pendingLocationTapKeys = <String>{};
  String _lastLoggedLocationTreeSignature = '';
  _MapTransitionSpec _mapTransition = const _MapTransitionSpec(
    origin: Alignment.center,
    direction: _MapTransitionDirection.drillIn,
  );

  bool get _hasDrillTree => widget.locationNodes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _debugPrintLocationTree('init');
  }

  @override
  void didUpdateWidget(covariant WorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _debugPrintLocationTree('update');
    if (!_hasDrillTree) {
      if (_locationTrail.isNotEmpty) _locationTrail.clear();
      return;
    }

    final currentId = _locationTrail.isEmpty ? '' : _locationTrail.last.id;
    if (currentId.isNotEmpty && _findNode(currentId) == null) {
      _locationTrail.clear();
    }
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
    final preloadMapImageUrls = _hasDrillTree
        ? visibleNodes
              .map((node) => node.mapImageUrl.trim())
              .where((url) => url.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : widget.preloadMapImageUrls;
    final exitLocationLabel = currentNode?.point.name ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        const designWidth = 375.0;
        const designHeight = 670.0;
        final viewport = _MapViewport.cover(
          viewportWidth: constraints.maxWidth,
          viewportHeight: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : constraints.maxWidth * designHeight / designWidth,
          designWidth: designWidth,
          designHeight: designHeight,
        );
        final backgroundUrl = currentMapImageUrl.trim();
        final mapKey = ValueKey<String>(
          _locationTrail.isEmpty ? '__world_root__' : _locationTrail.last.id,
        );
        return Stack(
          children: [
            Positioned.fill(
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
                          preloadUrls: preloadMapImageUrls,
                          fallbackOnEmptyUrl: widget.fallbackOnEmptyMapUrl,
                        ),
                        overlayBuilder: (context, transform) => Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              ignoring: widget.showPointsList,
                              child: Opacity(
                                opacity: widget.showPointsList ? 0.6 : 1,
                                child: Stack(
                                  children: [
                                    for (final p in visiblePoints)
                                      _WorldPointPositioned(
                                        point: p,
                                        width: viewport.width,
                                        height: viewport.height,
                                        transform: transform,
                                        onTap: _pointTapHandler(p),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                color: widget.dimmed
                                    ? Colors.black.withValues(alpha: 0.08)
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.showPointsList)
              Positioned.fill(child: ColoredBox(color: Colors.white)),
            if (widget.showPointsList)
              Positioned.fill(
                top: widget.overlayTop,
                child: Column(
                  children: [
                    Expanded(
                      child: WorldLocationList(
                        points: flattenedPoints,
                        onPointTap: (point) {
                          unawaited(_handlePointTap(point));
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
                child: _ExitLocationButton(
                  label: exitLocationLabel,
                  onPressed: _exitLocation,
                ),
              ),
          ],
        );
      },
    );
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
            () => widget.onPointTap?.call(chatTarget),
          );
          return;
        }
        await _runLocationTapLocked(_locationTapKey(point), () async {
          widget.onDrillIntoLocation?.call();
          final origin = _mapTransitionOrigin(point);
          final path = _nodePath(node.id);
          setState(() {
            _mapTransition = _MapTransitionSpec(
              origin: origin,
              direction: _MapTransitionDirection.drillIn,
            );
            _locationTrail
              ..clear()
              ..addAll(
                (path.isEmpty ? <String>[node.id] : path).map(
                  (id) => _WorldMapLocationTrailEntry(
                    id: id,
                    origin: id == node.id ? origin : Alignment.center,
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
      () => widget.onPointTap?.call(point),
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

  WorldMapLocationNode? _findPointNode(WorldPoint point) {
    final targetId = _pointLocationId(point);
    if (targetId.isEmpty) return null;
    return _findNode(targetId);
  }

  WorldPoint? _chatTargetForNode(WorldMapLocationNode node) {
    final explicitTarget = node.chatTargetPoint;
    if (explicitTarget != null) return explicitTarget;
    if (node.children.isEmpty) return node.point;
    if (node.children.length == 1 && node.children.single.children.isEmpty) {
      return node.children.single.chatTargetPoint ?? node.children.single.point;
    }
    return null;
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
    final viewportAspect = viewportWidth / viewportHeight;
    final designAspect = designWidth / designHeight;
    final coverByWidth = viewportAspect >= designAspect;
    final width = coverByWidth ? viewportWidth : viewportHeight * designAspect;
    final height = coverByWidth ? viewportWidth / designAspect : viewportHeight;

    return _MapViewport(
      left: (viewportWidth - width) / 2,
      top: (viewportHeight - height) / 2,
      width: width,
      height: height,
    );
  }
}

class _ExitLocationButton extends StatelessWidget {
  const _ExitLocationButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        height: 36,
        padding: EdgeInsets.only(left: 0, right: displayLabel.isEmpty ? 0 : 12),
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
              mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: Text(
                      displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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

double _lerpDouble(double begin, double end, double t) {
  return begin + (end - begin) * t;
}

class _MapBackgroundDeck extends StatelessWidget {
  const _MapBackgroundDeck({
    required this.currentUrl,
    required this.preloadUrls,
    required this.fallbackOnEmptyUrl,
  });

  final String currentUrl;
  final List<String> preloadUrls;
  final bool fallbackOnEmptyUrl;

  @override
  Widget build(BuildContext context) {
    final current = currentUrl.trim();
    final urls = preloadUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && url != current)
        .toSet()
        .toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        _MapBackground(url: current, fallbackOnEmptyUrl: fallbackOnEmptyUrl),
        for (final url in urls)
          Offstage(offstage: true, child: _MapBackground(url: url)),
      ],
    );
  }
}

typedef _MapOverlayBuilder =
    Widget Function(BuildContext context, Matrix4 transform);

class _ZoomableMapContent extends StatefulWidget {
  const _ZoomableMapContent({
    required this.background,
    required this.overlayBuilder,
  });

  static const double minScale = 1;
  static const double maxScale = 4;
  static const double doubleTapScale = 2;

  final Widget background;
  final _MapOverlayBuilder overlayBuilder;

  @override
  State<_ZoomableMapContent> createState() => _ZoomableMapContentState();
}

class _ZoomableMapContentState extends State<_ZoomableMapContent> {
  late final TransformationController _transformationController =
      TransformationController();
  final Set<int> _activePointers = <int>{};
  bool _interactionActive = false;
  Duration? _lastTapTime;
  Offset? _lastTapLocalPosition;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
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
    if (_activePointers.length >= 2 || _isZoomed) {
      _dispatchMapInteraction(true);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _dispatchMapInteraction(false);
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
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        focalPoint.dx - focalPoint.dx * scale,
        focalPoint.dy - focalPoint.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: ClipRect(
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
                if (_activePointers.isEmpty) _dispatchMapInteraction(false);
              },
              child: SizedBox.expand(child: widget.background),
            ),
            AnimatedBuilder(
              animation: _transformationController,
              builder: (context, _) => widget.overlayBuilder(
                context,
                _transformationController.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  const _MapBackground({required this.url, this.fallbackOnEmptyUrl = true});

  final String url;
  final bool fallbackOnEmptyUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return fallbackOnEmptyUrl
          ? const _FallbackMapBackground()
          : const _MapBackgroundPlaceholder();
    }

    if (trimmedUrl.startsWith('assets/')) {
      return Image.asset(
        trimmedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _FallbackMapBackground(),
      );
    }

    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _FallbackMapBackground(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const _MapBackgroundPlaceholder();
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
    required this.onTap,
  });

  final WorldPoint point;
  final double width;
  final double height;
  final Matrix4? transform;
  final VoidCallback? onTap;

  static const double _labelHeight = 20;
  static const double _pointSize = 8;
  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _labelToPointSpacing = 6;
  static const double _avatarTopGap = 10;

  double _markerWidth() {
    final count = point.users.length;
    final avatarWidth = _avatarGroupWidth(count);
    final estimatedCharWidth = 10.0;
    final labelWidth = (point.name.runes.length * estimatedCharWidth + 12)
        .clamp(_labelHeight, width)
        .toDouble();
    return math.max(math.max(_pointSize, avatarWidth), labelWidth);
  }

  double _markerHeight() {
    final count = point.users.length;
    final pointCenterY = _labelHeight + _labelToPointSpacing + _pointSize / 2;
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
    final markerWidth = _markerWidth();
    final markerHeight = _markerHeight();
    final pointCenterY = _labelHeight + _labelToPointSpacing + _pointSize / 2;

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
        markerWidth: markerWidth,
        markerHeight: markerHeight,
        pointCenterY: pointCenterY,
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
    required this.markerWidth,
    required this.markerHeight,
    required this.pointCenterY,
    this.onTap,
  });

  final WorldPoint point;
  final double markerWidth;
  final double markerHeight;
  final double pointCenterY;
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
    final hasUsers = point.users.isNotEmpty;
    final avatars = point.users;

    return GestureDetector(
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
                  constraints: BoxConstraints(maxWidth: markerWidth),
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
                        horizontal: 6,
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
                  user: avatars[i],
                  left: _avatarLeft(i, avatars.length),
                  top: _avatarTop(i, avatars.length),
                ),
          ],
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

class _PointLabel extends StatelessWidget {
  const _PointLabel({required this.point, this.color});

  final WorldPoint point;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      point.name,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        height: 1.2,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: FontWeight.w500,
        color: color ?? Colors.black,
      ),
    );
  }
}

class _PositionedMapAvatar extends StatelessWidget {
  const _PositionedMapAvatar({
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
      child: GenesisCharacterAvatar(
        url: user.avatarUrl,
        name: user.name ?? user.initials,
        showStar: user.showStar,
        size: 42,
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
      ),
    );
  }
}
