import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../icons/my_flutter_app_icons.dart';
import '../ui/tokens/genesis_avatar_radii.dart';
import '../ui/tokens/genesis_colors.dart';
import '../utils/genesis_image_resource.dart';
import 'world_map_interaction_notification.dart';
import 'world_location_list.dart';
import 'world_point.dart';

export 'world_location_list.dart';
export 'world_point.dart';

const String kWorldMapFallbackBackgroundAsset =
    'assets/images/mock_maps/map_background.png';
const double _worldMapAvatarImageLogicalSize = 42;
const double _worldMapPreviewImageLogicalWidth = 120;

@visibleForTesting
Color worldMapAvatarBorderColorForTesting({
  required bool isPlayerControlledRole,
}) {
  return isPlayerControlledRole ? GenesisColors.brand : const Color(0xFFDDDDDD);
}

typedef WorldPointTapCallback = FutureOr<void> Function(WorldPoint point);

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
    this.messageBubbles = const <String, WorldMapMessageBubble>{},
    this.onDrillIntoLocation,
    this.onSecondaryMapChanged,
    this.onVisibleLocationIdsChanged,
    this.onPointTap,
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
  final Map<String, WorldMapMessageBubble> messageBubbles;
  final VoidCallback? onDrillIntoLocation;
  final ValueChanged<bool>? onSecondaryMapChanged;
  final ValueChanged<List<String>>? onVisibleLocationIdsChanged;
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
  String _lastVisibleLocationIdsSignature = '';

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
      if (_locationTrail.isNotEmpty) {
        _locationTrail.clear();
        widget.onSecondaryMapChanged?.call(false);
      }
      return;
    }

    final currentId = _locationTrail.isEmpty ? '' : _locationTrail.last.id;
    if (currentId.isNotEmpty && _findNode(currentId) == null) {
      _locationTrail.clear();
      widget.onSecondaryMapChanged?.call(false);
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
    _notifyVisibleLocationIds(visiblePoints);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio =
            MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
        const designWidth = 375.0;
        const designHeight = 670.0;
        final viewport = _MapViewport.screenWidth(
          viewportWidth: constraints.maxWidth,
          designWidth: designWidth,
          designHeight: designHeight,
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
                          previewUrl: backgroundPreviewUrl,
                          preloadUrls: preloadMapImageUrls,
                          preloadAvatarUrls: preloadAvatarUrls,
                          fallbackOnEmptyUrl: widget.fallbackOnEmptyMapUrl,
                        ),
                        overlayBuilder:
                            (context, transform, onOverlayPointerDown) => Stack(
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
                                            messageBubble:
                                                _locationTrail.isEmpty
                                                ? null
                                                : widget.messageBubbles[p
                                                      .sceneId],
                                            onPointerDown: onOverlayPointerDown,
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
                        locationNodes: widget.listLocationNodes.isNotEmpty
                            ? widget.listLocationNodes
                            : widget.locationNodes,
                        physics: widget.pointsListPhysics,
                        enableOuterScrollHandoff:
                            widget.pointsListOuterScrollHandoff,
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
            () => widget.onPointTap?.call(_withCurrentMapImage(chatTarget)),
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
          widget.onSecondaryMapChanged?.call(_locationTrail.isNotEmpty);
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
    widget.onSecondaryMapChanged?.call(_locationTrail.isNotEmpty);
  }

  void _notifyVisibleLocationIds(List<WorldPoint> points) {
    final ids = points
        .map((point) => point.sceneId.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final signature = ids.join('\u001F');
    if (signature == _lastVisibleLocationIdsSignature) return;
    _lastVisibleLocationIdsSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastVisibleLocationIdsSignature != signature) return;
      widget.onVisibleLocationIdsChanged?.call(ids);
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

  factory _MapViewport.screenWidth({
    required double viewportWidth,
    required double designWidth,
    required double designHeight,
  }) {
    final designAspect = designWidth / designHeight;
    final width = viewportWidth;
    final height = viewportWidth / designAspect;

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
    return url.startsWith('assets/')
        ? AssetImage(url)
        : CachedNetworkImageProvider(url);
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

class _ZoomableMapContent extends StatefulWidget {
  const _ZoomableMapContent({
    required this.background,
    required this.overlayBuilder,
  });

  static const double minScale = 1;
  static const double maxScale = 2;
  static const double doubleTapScale = 1.5;

  final Widget background;
  final _MapOverlayBuilder overlayBuilder;

  @override
  State<_ZoomableMapContent> createState() => _ZoomableMapContentState();
}

class _ZoomableMapContentState extends State<_ZoomableMapContent> {
  late final TransformationController _transformationController =
      TransformationController();
  final Set<int> _activePointers = <int>{};
  final Set<int> _overlayPointers = <int>{};
  final Map<int, Offset> _activePointerPositions = <int, Offset>{};
  bool _interactionActive = false;
  Duration? _lastTapTime;
  Offset? _lastTapLocalPosition;
  Matrix4? _manualGestureStartMatrix;
  Offset? _manualGestureStartFocal;
  double? _manualGestureStartDistance;
  Matrix4? _manualPanStartMatrix;
  Offset? _manualPanStartPosition;

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
    if (_overlayPointers.isEmpty) return;

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
      _clearManualPanGesture();
      _dispatchMapInteraction(false);
    } else {
      _resetManualPanGestureIfNeeded();
    }
  }

  void _startManualGestureIfNeeded() {
    if (_overlayPointers.isEmpty || _activePointerPositions.length < 2) {
      _resetManualPanGestureIfNeeded();
      return;
    }
    if (_manualGestureStartMatrix != null) return;

    final points = _activePointerPositions.values.take(2).toList();
    _manualGestureStartMatrix = Matrix4.copy(_transformationController.value);
    _manualGestureStartFocal = _focalPoint(points);
    _manualGestureStartDistance = (points[0] - points[1]).distance;
    _clearManualPanGesture();
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
    _manualPanStartMatrix ??= Matrix4.copy(_transformationController.value);
    _manualPanStartPosition ??= event.localPosition - event.delta;

    final startMatrix = _manualPanStartMatrix;
    final startPosition = _manualPanStartPosition;
    if (startMatrix == null || startPosition == null) return;

    final values = startMatrix.storage;
    final scale = startMatrix.getMaxScaleOnAxis();
    final translation =
        Offset(values[12], values[13]) + event.localPosition - startPosition;
    _setTransform(scale, translation);
    _dispatchMapInteraction(true);
  }

  void _setTransform(double scale, Offset translation) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    if (size.isEmpty || scale <= _ZoomableMapContent.minScale + 0.001) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final minX = size.width - size.width * scale;
    final minY = size.height - size.height * scale;
    final clampedTranslation = Offset(
      translation.dx.clamp(minX, 0.0).toDouble(),
      translation.dy.clamp(minY, 0.0).toDouble(),
    );
    _transformationController.value = Matrix4.identity()
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

  void _clearManualPanGesture() {
    _manualPanStartMatrix = null;
    _manualPanStartPosition = null;
  }

  void _resetManualPanGestureIfNeeded() {
    _clearManualPanGesture();
    if (_activePointerPositions.length == 1 &&
        _overlayPointers.contains(_activePointerPositions.keys.single) &&
        _isZoomed) {
      _manualPanStartMatrix = Matrix4.copy(_transformationController.value);
      _manualPanStartPosition = _activePointerPositions.values.single;
    }
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
      onPointerMove: _handlePointerMove,
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
                _handleOverlayPointerDown,
              ),
            ),
          ],
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
          Image.network(
            trimmedUrl,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) _notifyLoaded();
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _notifyLoaded();
              return widget.fallbackOnEmptyUrl
                  ? const _FallbackMapBackground()
                  : const SizedBox.shrink();
            },
            loadingBuilder: (context, child, loadingProgress) {
              return loadingProgress == null ? child : const SizedBox.shrink();
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

    return Image.network(
      trimmedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return fallbackOnEmptyUrl
            ? const _FallbackMapBackground()
            : const _MapBackgroundPlaceholder();
      },
      loadingBuilder: (context, child, loadingProgress) {
        return loadingProgress == null
            ? child
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

class WorldMapMessageBubble {
  const WorldMapMessageBubble({
    required this.locationId,
    required this.senderId,
    this.senderName = '',
    this.senderAvatarUrl = '',
    required this.content,
    required this.createdAt,
  });

  final String locationId;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String content;
  final DateTime createdAt;
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

  static const double _labelHeight = 20;
  static const double _pointSize = 8;
  static const double _avatarSize = 42;
  static const double _avatarSpacing = 4;
  static const double _labelToPointSpacing = 6;
  static const double _avatarTopGap = 10;

  double _markerWidth(int userCount) {
    final count = userCount;
    final avatarWidth = _avatarGroupWidth(count);
    final estimatedCharWidth = 10.0;
    final labelWidth = (point.name.runes.length * estimatedCharWidth + 12)
        .clamp(_labelHeight, width)
        .toDouble();
    return math.max(math.max(_pointSize, avatarWidth), labelWidth);
  }

  double _markerHeight(int userCount) {
    final count = userCount;
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
    final users = point.users;
    final markerWidth = _markerWidth(users.length);
    final markerHeight = _markerHeight(users.length);
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
        users: users,
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
    required this.markerWidth,
    required this.markerHeight,
    required this.pointCenterY,
    this.messageBubble,
    required this.onPointerDown,
    this.onTap,
  });

  final WorldPoint point;
  final List<UserAvatar> users;
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
    final bubble = messageBubble;
    final bubbleAvatarIndex = bubble == null
        ? -1
        : _bubbleAvatarIndex(bubble, avatars);

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
                    key: ValueKey<String>(
                      'map-positioned-avatar-${_mapAvatarStableKey(avatars[i])}',
                    ),
                    user: avatars[i],
                    left: _avatarLeft(i, avatars.length),
                    top: _avatarTop(i, avatars.length),
                  ),
              if (bubble != null && bubbleAvatarIndex >= 0)
                _PositionedMapMessageBubble(
                  bubble: bubble,
                  left: _avatarLeft(bubbleAvatarIndex, avatars.length),
                  top: _avatarTop(bubbleAvatarIndex, avatars.length),
                  avatarSize: _avatarSize,
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

  int _bubbleAvatarIndex(
    WorldMapMessageBubble bubble,
    List<UserAvatar> avatars,
  ) {
    final senderKey = bubble.senderId.trim().toLowerCase();
    if (senderKey.isNotEmpty) {
      for (var i = 0; i < avatars.length; i += 1) {
        if (avatars[i].id.trim().toLowerCase() == senderKey) return i;
      }
    }
    final senderNameKey = bubble.senderName.trim().toLowerCase();
    if (senderNameKey.isNotEmpty) {
      for (var i = 0; i < avatars.length; i += 1) {
        if ((avatars[i].name ?? '').trim().toLowerCase() == senderNameKey) {
          return i;
        }
      }
    }
    return -1;
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
    final avatarUrl = _selectWorldMapAvatarUrl(
      user.avatarUrl,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    );
    return Positioned(
      left: left,
      top: top,
      child: _MapAvatarImage(
        key: ValueKey<String>('map-avatar-${_mapAvatarStableKey(user)}'),
        url: avatarUrl,
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
    required this.showStar,
    required this.isPlayerControlledRole,
  });

  final String url;
  final bool showStar;
  final bool isPlayerControlledRole;

  static const double _size = _worldMapAvatarImageLogicalSize;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url.trim();
    return SizedBox(
      width: _size,
      height: _size,
      child: resolvedUrl.isEmpty
          ? const SizedBox.expand()
          : resolvedUrl.startsWith('assets/')
          ? Image.asset(
              resolvedUrl,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (!wasSynchronouslyLoaded && frame == null) {
                  return const SizedBox.expand();
                }
                return _LoadedMapAvatar(
                  showStar: showStar,
                  isPlayerControlledRole: isPlayerControlledRole,
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.expand(),
            )
          : CachedNetworkImage(
              imageUrl: resolvedUrl,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholderFadeInDuration: Duration.zero,
              imageBuilder: (context, imageProvider) => _LoadedMapAvatar(
                showStar: showStar,
                isPlayerControlledRole: isPlayerControlledRole,
                child: Image(
                  image: imageProvider,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              placeholder: (context, url) => const SizedBox.expand(),
              errorWidget: (context, url, error) => const SizedBox.expand(),
            ),
    );
  }
}

class _LoadedMapAvatar extends StatelessWidget {
  const _LoadedMapAvatar({
    required this.child,
    required this.showStar,
    required this.isPlayerControlledRole,
  });

  final Widget child;
  final bool showStar;
  final bool isPlayerControlledRole;

  static const double _size = _worldMapAvatarImageLogicalSize;
  static const double _borderRadius = GenesisAvatarRadii.character;
  static const double _starSize = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_borderRadius),
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
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: worldMapAvatarBorderColorForTesting(
                  isPlayerControlledRole: isPlayerControlledRole,
                ),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadius),
              child: child,
            ),
          ),
          if (showStar)
            Positioned(
              top: -_starSize / 4 - 2,
              right: -_starSize / 4 - 3,
              child: const Icon(
                MyFlutterApp.redstarCharIcon,
                size: _starSize,
                color: Color(0xFFFF2344),
              ),
            ),
        ],
      ),
    );
  }
}

class _PositionedMapMessageBubble extends StatelessWidget {
  const _PositionedMapMessageBubble({
    required this.bubble,
    required this.left,
    required this.top,
    required this.avatarSize,
  });

  final WorldMapMessageBubble bubble;
  final double left;
  final double top;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.6;
    final bubbleTop = top + avatarSize + 12;
    return Positioned(
      left: left + avatarSize / 2 - maxWidth / 2,
      top: bubbleTop,
      width: maxWidth,
      child: IgnorePointer(child: _MapMessageBubble(content: bubble.content)),
    );
  }
}

class _MapMessageBubble extends StatelessWidget {
  const _MapMessageBubble({required this.content});

  static const Color _backgroundColor = Color(0xFFFFFFFF);

  final String content;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _backgroundColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F1F1F),
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        Positioned(
          top: -7,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: const SizedBox.square(
              dimension: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(color: _backgroundColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _mapAvatarStableKey(UserAvatar user) {
  final id = user.id.trim();
  final avatarUrl = user.avatarUrl.trim();
  final name = (user.name ?? user.initials).trim();
  return '$id|$avatarUrl|$name';
}
