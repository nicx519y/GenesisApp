import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../world_point.dart';
import 'tilemap_fog.dart';
import 'tilemap_location_avatars.dart';
import 'tilemap_model.dart';

export 'tilemap_fog.dart';

const double tilemapBaseTileExtent = 16;
const double tilemapPlaceholderScale = 10;
const double tilemapInitialHorizontalMargin = 16;
const double tilemapMinScale = 5;
const double tilemapMaxScale = 22;
const double tilemapInitialScaleFactorMin = 0.5;
const double tilemapInitialScaleFactorMax = 2;
const double tilemapDefaultInitialScaleFactor = 0.86;
const bool tilemapDefaultBlendFogWithShadowTiles = true;
const bool tilemapDefaultShowShadowZeroBorders = false;
const bool tilemapDefaultShowLocationImageFlow = true;
const double tilemapDefaultLocationImageFlowAngleDegrees = 267.88;
const double tilemapDefaultLocationImageFlowOpacity = 0.49;
const double tilemapDefaultLocationImageFlowDurationSeconds = 7.50;
const TilemapLocationImageFlowBlendMode
tilemapDefaultLocationImageFlowBlendMode =
    TilemapLocationImageFlowBlendMode.plus;
const double tilemapLocationImageFlowDurationSecondsMin = 0.5;
const double tilemapLocationImageFlowDurationSecondsMax = 10;
const double tilemapLocationImageFlowActiveFraction = 2 / 3;
const double tilemapLocationImageFlowBandWidthFraction = 0.18;

@immutable
class TilemapLocationImageFlowGradientPoint {
  const TilemapLocationImageFlowGradientPoint({
    required this.position,
    required this.color,
  });

  final double position;
  final Color color;

  TilemapLocationImageFlowGradientPoint copyWith({
    double? position,
    Color? color,
  }) {
    return TilemapLocationImageFlowGradientPoint(
      position: position ?? this.position,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TilemapLocationImageFlowGradientPoint &&
        other.position == position &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(position, color);
}

enum TilemapLocationImageFlowBlendMode { normal, screen, overlay, plus }

const List<TilemapLocationImageFlowGradientPoint>
tilemapDefaultLocationImageFlowGradientPoints = [
  TilemapLocationImageFlowGradientPoint(position: 0, color: Color(0x00624700)),
  TilemapLocationImageFlowGradientPoint(
    position: 0.24,
    color: Color(0x556AFFA6),
  ),
  TilemapLocationImageFlowGradientPoint(
    position: 0.51,
    color: Color(0xD9B9B088),
  ),
  TilemapLocationImageFlowGradientPoint(
    position: 0.76,
    color: Color(0x55FFD86A),
  ),
  TilemapLocationImageFlowGradientPoint(position: 1, color: Color(0x00926C00)),
];

typedef TilemapTileActionHandler = Future<void> Function(TilemapCell tile);
typedef TilemapLocationNameResolver = String? Function(TilemapCell tile);
typedef TilemapLocationAvatarsResolver =
    List<UserAvatar> Function(TilemapCell tile);

enum TilemapVisualMode { light, dark }

const TilemapVisualMode tilemapDefaultVisualMode = TilemapVisualMode.dark;

@immutable
class TilemapVisualStyle {
  const TilemapVisualStyle({
    required this.backgroundColor,
    required this.gridLineColor,
  });

  final Color backgroundColor;
  final Color gridLineColor;
}

const TilemapVisualStyle tilemapLightVisualStyle = TilemapVisualStyle(
  backgroundColor: Color(0xFFFAFAF8),
  gridLineColor: Color(0xFFD7D6D2),
);
const TilemapVisualStyle tilemapDarkVisualStyle = TilemapVisualStyle(
  backgroundColor: Color(0xFF37362E),
  gridLineColor: Color(0xFF2E2D26),
);

TilemapVisualStyle tilemapVisualStyleFor(TilemapVisualMode mode) {
  return switch (mode) {
    TilemapVisualMode.light => tilemapLightVisualStyle,
    TilemapVisualMode.dark => tilemapDarkVisualStyle,
  };
}

const Color tilemapLocationHighlightColor = Color(0xFFFFD54F);
const Color tilemapShadowZeroBorderColor = Color(0xFFFFFF00);
const double tilemapShadowZeroBorderWidth = 2;

class TilemapGridBackground extends StatelessWidget {
  const TilemapGridBackground({
    super.key,
    this.visualMode = tilemapDefaultVisualMode,
  });

  final TilemapVisualMode visualMode;

  @override
  Widget build(BuildContext context) {
    final visualStyle = tilemapVisualStyleFor(visualMode);
    return ColoredBox(
      key: const ValueKey<String>('tilemap-grid-background'),
      color: visualStyle.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height,
          );
          const projection = TilemapProjection(
            mapWidth: tilemapBaseTileExtent,
            mapHeight: tilemapBaseTileExtent,
            tileExtent: tilemapBaseTileExtent,
            originX: 0,
          );
          return CustomPaint(
            painter: _TilemapInfiniteGridPainter(
              projection: projection,
              scale: tilemapPlaceholderScale,
              translation: size.center(Offset.zero),
              lineColor: visualStyle.gridLineColor,
            ),
          );
        },
      ),
    );
  }
}

class TilemapProjection {
  const TilemapProjection({
    required this.mapWidth,
    required this.mapHeight,
    required this.tileExtent,
    required this.originX,
  });

  final double mapWidth;
  final double mapHeight;
  final double tileExtent;
  final double originX;

  double get tileDiamondWidth => tileExtent;
  double get tileDiamondHeight => tileExtent / 2;
  double get tileDiamondWidthToHeightRatio =>
      tileDiamondWidth / tileDiamondHeight;

  static TilemapProjection fit({
    required int mapWidth,
    required int mapHeight,
    required double viewportWidth,
    required double viewportHeight,
    double viewportMargin = 16,
  }) {
    final usableWidth = math.max(1.0, viewportWidth - viewportMargin * 2);
    final usableHeight = math.max(1.0, viewportHeight - viewportMargin * 2);
    final tileExtentByWidth = usableWidth * 2 / (mapWidth + mapHeight);
    final heightUnits = 1 + (mapWidth + mapHeight - 2) / 4;
    final tileExtentByHeight = usableHeight / heightUnits;
    final tileExtent = math.max(
      1.0,
      math.min(tileExtentByWidth, tileExtentByHeight),
    );

    return TilemapProjection(
      mapWidth: (mapWidth + mapHeight) * tileExtent / 2,
      mapHeight: heightUnits * tileExtent,
      tileExtent: tileExtent,
      originX: (mapHeight - 1) * tileExtent / 2,
    );
  }

  static TilemapProjection fixed({
    required int mapWidth,
    required int mapHeight,
    double tileExtent = tilemapBaseTileExtent,
  }) {
    final heightUnits = 1 + (mapWidth + mapHeight - 2) / 4;
    return TilemapProjection(
      mapWidth: (mapWidth + mapHeight) * tileExtent / 2,
      mapHeight: heightUnits * tileExtent,
      tileExtent: tileExtent,
      originX: (mapHeight - 1) * tileExtent / 2,
    );
  }

  Offset topLeftForTile(TilemapCell tile) {
    return Offset(
      originX + (tile.x - tile.y) * tileExtent / 2,
      (tile.x + tile.y) * tileExtent / 4,
    );
  }

  Offset imageTopLeftForTile(TilemapCell tile) {
    final top = topLeftForTile(tile);
    return Offset(top.dx - tileExtent / 2, top.dy - tileExtent / 2);
  }

  List<Offset> polygonForTile(TilemapCell tile) {
    final top = topLeftForTile(tile);
    return <Offset>[
      top,
      Offset(top.dx + tileExtent / 2, top.dy + tileExtent / 4),
      Offset(top.dx, top.dy + tileExtent / 2),
      Offset(top.dx - tileExtent / 2, top.dy + tileExtent / 4),
    ];
  }

  Offset centerForTile(TilemapCell tile) {
    final polygon = polygonForTile(tile);
    final total = polygon.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + point,
    );
    return total / polygon.length.toDouble();
  }

  bool containsPointInTile(TilemapCell tile, Offset point) {
    return _containsPointInPolygon(point, polygonForTile(tile));
  }

  double tilePixelSize({
    required double scale,
    required double devicePixelRatio,
  }) {
    return tileExtent * scale * devicePixelRatio;
  }

  Rect imageBoundsForTiles(Iterable<TilemapCell> tiles) {
    final points = <Offset>[];
    for (final tile in tiles) {
      final topLeft = imageTopLeftForTile(tile);
      points
        ..add(topLeft)
        ..add(Offset(topLeft.dx + tileExtent, topLeft.dy + tileExtent));
    }
    return _boundsForOffsets(points);
  }
}

Matrix4 tilemapInitialTransform({
  required Size viewportSize,
  required Size mapSize,
  Rect? contentBounds,
  double horizontalMargin = tilemapInitialHorizontalMargin,
  double initialScaleFactor = 1,
}) {
  final bounds = contentBounds ?? Offset.zero & mapSize;
  final scale = tilemapInitialScaleForContentWidth(
    viewportWidth: viewportSize.width,
    contentWidth: bounds.width,
    horizontalMargin: horizontalMargin,
    initialScaleFactor: initialScaleFactor,
  );
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportSize.width / 2 - bounds.center.dx * scale,
      viewportSize.height / 2 - bounds.center.dy * scale + 20,
      0,
    );
}

List<TilemapCell> tilemapInitialContentTiles(Iterable<TilemapCell> tiles) {
  final allTiles = tiles.toList(growable: false);
  final shadowZeroTiles = allTiles
      .where((tile) => !tile.hasShadow)
      .toList(growable: false);
  return shadowZeroTiles.isEmpty ? allTiles : shadowZeroTiles;
}

double tilemapInitialScaleForContentWidth({
  required double viewportWidth,
  required double contentWidth,
  double horizontalMargin = tilemapInitialHorizontalMargin,
  double initialScaleFactor = 1,
}) {
  if (!viewportWidth.isFinite ||
      viewportWidth <= 0 ||
      !contentWidth.isFinite ||
      contentWidth <= 0) {
    return tilemapMinScale;
  }
  final resolvedMargin = horizontalMargin.isFinite
      ? math.max(0.0, horizontalMargin)
      : 0.0;
  final resolvedScaleFactor = initialScaleFactor.isFinite
      ? initialScaleFactor.clamp(
          tilemapInitialScaleFactorMin,
          tilemapInitialScaleFactorMax,
        )
      : 1.0;
  final usableWidth = math.max(1.0, viewportWidth - resolvedMargin * 2);
  return (usableWidth / contentWidth * resolvedScaleFactor)
      .clamp(tilemapMinScale, tilemapMaxScale)
      .toDouble();
}

double tilemapTransformScale(Matrix4 transform) => transform.storage[0].abs();

Matrix4 tilemapGestureTransform({
  required Matrix4 startTransform,
  required Offset startFocalPoint,
  required Offset currentFocalPoint,
  required double gestureScale,
  double minScale = tilemapMinScale,
  double maxScale = tilemapMaxScale,
}) {
  final startScale = tilemapTransformScale(startTransform);
  final rawTargetScale = startScale * gestureScale;
  final targetScale = rawTargetScale.clamp(minScale, maxScale).toDouble();
  final sceneFocalPoint = MatrixUtils.transformPoint(
    Matrix4.inverted(startTransform),
    startFocalPoint,
  );
  return tilemapTransformForSceneFocalPoint(
    sceneFocalPoint: sceneFocalPoint,
    viewportFocalPoint: currentFocalPoint,
    scale: targetScale,
  );
}

Matrix4 tilemapTransformForSceneFocalPoint({
  required Offset sceneFocalPoint,
  required Offset viewportFocalPoint,
  required double scale,
}) {
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setTranslationRaw(
      viewportFocalPoint.dx - sceneFocalPoint.dx * scale,
      viewportFocalPoint.dy - sceneFocalPoint.dy * scale,
      0,
    );
}

Offset tilemapLocationBubbleSceneAnchor(
  TilemapProjection projection,
  TilemapCell tile,
) {
  return projection.centerForTile(tile) + Offset(0, projection.tileExtent / 8);
}

double tilemapLocationImageFlowPhase(TilemapCell tile) {
  final hash = (tile.x * 73856093) ^ (tile.y * 19349663);
  return (hash & 0xFFFF) / 0x10000;
}

double? tilemapLocationImageFlowProgress({
  required double animationValue,
  required double phase,
}) {
  final cycle = (animationValue + phase) % 1;
  if (cycle >= tilemapLocationImageFlowActiveFraction) return null;
  return cycle / tilemapLocationImageFlowActiveFraction;
}

Duration tilemapLocationImageFlowDurationForSeconds(double seconds) {
  final resolved =
      (seconds.isFinite
              ? seconds
              : tilemapDefaultLocationImageFlowDurationSeconds)
          .clamp(
            tilemapLocationImageFlowDurationSecondsMin,
            tilemapLocationImageFlowDurationSecondsMax,
          )
          .toDouble();
  return Duration(
    microseconds: (resolved * Duration.microsecondsPerSecond).round(),
  );
}

BlendMode tilemapLocationImageFlowCanvasBlendMode(
  TilemapLocationImageFlowBlendMode mode,
) {
  return switch (mode) {
    TilemapLocationImageFlowBlendMode.normal => BlendMode.srcATop,
    TilemapLocationImageFlowBlendMode.screen => BlendMode.screen,
    TilemapLocationImageFlowBlendMode.overlay => BlendMode.overlay,
    TilemapLocationImageFlowBlendMode.plus => BlendMode.plus,
  };
}

Rect tilemapVisibleSceneBounds({
  required Matrix4 transform,
  required Size viewportSize,
}) {
  final inverse = Matrix4.inverted(transform);
  return _boundsForOffsets([
    MatrixUtils.transformPoint(inverse, Offset.zero),
    MatrixUtils.transformPoint(inverse, Offset(viewportSize.width, 0)),
    MatrixUtils.transformPoint(
      inverse,
      Offset(viewportSize.width, viewportSize.height),
    ),
    MatrixUtils.transformPoint(inverse, Offset(0, viewportSize.height)),
  ]);
}

Rect tilemapRetainedSceneBounds(Rect visibleSceneBounds) {
  return Rect.fromLTRB(
    visibleSceneBounds.left - visibleSceneBounds.width / 2,
    visibleSceneBounds.top - visibleSceneBounds.height / 2,
    visibleSceneBounds.right + visibleSceneBounds.width / 2,
    visibleSceneBounds.bottom + visibleSceneBounds.height / 2,
  );
}

String resolveTilemapAssetForDisplaySize(
  String baseUrl,
  double displayTilePixelSize,
) {
  final suffixStart = _tilemapUrlSuffixStart(baseUrl);
  final path = baseUrl.substring(0, suffixStart);
  final normalizedPath = path.toLowerCase();
  if (!normalizedPath.endsWith('.png') && !normalizedPath.endsWith('.webp')) {
    throw TilemapConfigException(
      'Tile asset base URL must end with .png or .webp: $baseUrl.',
    );
  }
  final requestedSize =
      displayTilePixelSize.isFinite && displayTilePixelSize > 0
      ? displayTilePixelSize.ceil()
      : 128;
  const availableSizes = <int>[128, 256, 512, 1024];
  final resolvedSize = availableSizes.firstWhere(
    (size) => size >= requestedSize,
    orElse: () => availableSizes.last,
  );
  return '$path?x-oss-process=image/resize,w_$resolvedSize,'
      'image/format,webp';
}

int _tilemapUrlSuffixStart(String url) {
  final queryIndex = url.indexOf('?');
  final fragmentIndex = url.indexOf('#');
  var suffixStart = url.length;
  if (queryIndex >= 0 && queryIndex < suffixStart) suffixStart = queryIndex;
  if (fragmentIndex >= 0 && fragmentIndex < suffixStart) {
    suffixStart = fragmentIndex;
  }
  return suffixStart;
}

class _TilemapRenderRecord {
  const _TilemapRenderRecord({
    required this.tile,
    required this.imageTopLeft,
    required this.imageBounds,
    required this.paintOrder,
  });

  final TilemapCell tile;
  final Offset imageTopLeft;
  final Rect imageBounds;
  final int paintOrder;
}

class _TilemapRenderIndex {
  _TilemapRenderIndex({
    required TilemapProjection projection,
    required Iterable<TilemapCell> tiles,
  }) : bucketSize = projection.tileExtent * 4 {
    final sortedTiles = tiles.toList(growable: false)
      ..sort(_compareTilesForPaint);
    for (var paintOrder = 0; paintOrder < sortedTiles.length; paintOrder += 1) {
      final tile = sortedTiles[paintOrder];
      final imageTopLeft = projection.imageTopLeftForTile(tile);
      final record = _TilemapRenderRecord(
        tile: tile,
        imageTopLeft: imageTopLeft,
        imageBounds: imageTopLeft & Size.square(projection.tileExtent),
        paintOrder: paintOrder,
      );
      _insert(record);
      hasFogTiles = hasFogTiles || tile.hasShadow;
      hasShadowZeroTiles = hasShadowZeroTiles || !tile.hasShadow;
    }
  }

  final double bucketSize;
  final Map<(int, int), List<_TilemapRenderRecord>> _buckets = {};
  bool hasFogTiles = false;
  bool hasShadowZeroTiles = false;

  List<_TilemapRenderRecord> query(Rect bounds) {
    final candidates = <_TilemapRenderRecord>{};
    for (var y = _bucketFor(bounds.top); y <= _bucketFor(bounds.bottom); y++) {
      for (
        var x = _bucketFor(bounds.left);
        x <= _bucketFor(bounds.right);
        x++
      ) {
        final bucket = _buckets[(x, y)];
        if (bucket != null) candidates.addAll(bucket);
      }
    }
    final result =
        candidates
            .where(
              (record) => _rectsIntersectOrTouch(record.imageBounds, bounds),
            )
            .toList(growable: false)
          ..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    return result;
  }

  List<_TilemapRenderRecord> queryPoint(Offset point) {
    final candidates = _buckets[(_bucketFor(point.dx), _bucketFor(point.dy))];
    if (candidates == null) return const [];
    final result =
        candidates
            .where((record) => _rectContainsPoint(record.imageBounds, point))
            .toList(growable: false)
          ..sort((a, b) => a.paintOrder.compareTo(b.paintOrder));
    return result;
  }

  void _insert(_TilemapRenderRecord record) {
    final bounds = record.imageBounds;
    for (var y = _bucketFor(bounds.top); y <= _bucketFor(bounds.bottom); y++) {
      for (
        var x = _bucketFor(bounds.left);
        x <= _bucketFor(bounds.right);
        x++
      ) {
        _buckets.putIfAbsent((x, y), () => []).add(record);
      }
    }
  }

  int _bucketFor(double coordinate) => (coordinate / bucketSize).floor();
}

int _compareTilesForPaint(TilemapCell a, TilemapCell b) {
  final diagonal = (a.x + a.y).compareTo(b.x + b.y);
  if (diagonal != 0) return diagonal;
  return a.x.compareTo(b.x);
}

bool _rectsIntersectOrTouch(Rect a, Rect b) {
  return a.left <= b.right &&
      a.right >= b.left &&
      a.top <= b.bottom &&
      a.bottom >= b.top;
}

bool _rectContainsPoint(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

bool _rectContainsRect(Rect outer, Rect inner) {
  return inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
}

class TilemapRenderer extends StatefulWidget {
  const TilemapRenderer({
    super.key,
    required this.config,
    this.onTileAction,
    this.locationNameForTile,
    this.locationAvatarsForTile,
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
  });

  final TilemapConfig config;
  final TilemapTileActionHandler? onTileAction;
  final TilemapLocationNameResolver? locationNameForTile;
  final TilemapLocationAvatarsResolver? locationAvatarsForTile;
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
          _syncInitialTransform(
            viewportSize: viewportSize,
            mapSize: mapSize,
            contentBounds: contentBounds,
            initialScaleFactor: widget.initialScaleFactor,
          );
          return SizedBox(
            width: viewportWidth,
            height: viewportHeight,
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
                  _transformationController.value = tilemapGestureTransform(
                    startTransform: _gestureStartTransform,
                    startFocalPoint: _gestureStartFocalPoint,
                    currentFocalPoint: details.localFocalPoint,
                    gestureScale: details.scale,
                  );
                },
                onTapUp: (details) {
                  widget.onMapTap?.call();
                  unawaited(_handleTap(details.localPosition, projection));
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
                      projection.tileExtent / tilemapFogSamplesPerTileExtent,
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
                          widget.locationNameForTile?.call(tile)?.trim() ?? '';
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
                        return Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                key: const ValueKey<String>('tilemap-grid'),
                                painter: _TilemapInfiniteGridPainter(
                                  projection: projection,
                                  scale: scale,
                                  translation: Offset(
                                    matrix.getTranslation().x,
                                    matrix.getTranslation().y,
                                  ),
                                  lineColor: visualStyle.gridLineColor,
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
                                        painter: _TilemapFogPainter(fogField!),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Transform(
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
                                              widget.config.baseAssetUrlForTile(
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
                                                      record.tile.cellKey,
                                                    )
                                            ? _locationImageFlowController
                                            : null,
                                        locationImageFlowPhase:
                                            tilemapLocationImageFlowPhase(
                                              record.tile,
                                            ),
                                        locationImageFlowAngleDegrees: widget
                                            .locationImageFlowAngleDegrees,
                                        locationImageFlowGradientPoints: widget
                                            .locationImageFlowGradientPoints,
                                        locationImageFlowOpacity:
                                            widget.locationImageFlowOpacity,
                                        locationImageFlowBlendMode:
                                            widget.locationImageFlowBlendMode,
                                        fogField:
                                            widget.blendFogWithShadowTiles &&
                                                record.tile.hasShadow
                                            ? fogField
                                            : null,
                                        onImageError: widget.onImageError,
                                      ),
                                    if (highlightedTile != null)
                                      _ProjectedTileHighlight(
                                        key: ValueKey<String>(
                                          'tile-highlight-${highlightedTile.x}-${highlightedTile.y}',
                                        ),
                                        tile: highlightedTile,
                                        projection: projection,
                                        opacity: _highlightOpacity.value,
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
                                anchor: MatrixUtils.transformPoint(
                                  matrix,
                                  tilemapLocationBubbleSceneAnchor(
                                    projection,
                                    label.tile,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
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

  void _syncInitialTransform({
    required Size viewportSize,
    required Size mapSize,
    required Rect contentBounds,
    required double initialScaleFactor,
  }) {
    if (_lastViewportSize == viewportSize &&
        _lastMapSize == mapSize &&
        _lastContentBounds == contentBounds &&
        _lastInitialScaleFactor == initialScaleFactor) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastMapSize = mapSize;
    _lastContentBounds = contentBounds;
    _lastInitialScaleFactor = initialScaleFactor;
    if (_hasUserTransformedMap) return;
    _transformationController.value = tilemapInitialTransform(
      viewportSize: viewportSize,
      mapSize: mapSize,
      contentBounds: contentBounds,
      initialScaleFactor: initialScaleFactor,
    );
  }
}

class _TilemapLocationLabelData {
  const _TilemapLocationLabelData({
    required this.tile,
    required this.name,
    required this.avatars,
  });

  final TilemapCell tile;
  final String name;
  final List<UserAvatar> avatars;
}

class _TilemapInfiniteGridPainter extends CustomPainter {
  const _TilemapInfiniteGridPainter({
    required this.projection,
    required this.scale,
    required this.translation,
    required this.lineColor,
  });

  final TilemapProjection projection;
  final double scale;
  final Offset translation;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!scale.isFinite || scale <= 0 || size.isEmpty) return;

    final spacing = projection.tileExtent * scale / 2;
    if (!spacing.isFinite || spacing <= 0) return;

    final positiveSlopeBase =
        translation.dy - translation.dx / 2 - projection.originX * scale / 2;
    final negativeSlopeBase =
        translation.dy + translation.dx / 2 + projection.originX * scale / 2;
    final path = Path();

    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: -size.width / 2,
      maxIntercept: size.height,
      baseIntercept: positiveSlopeBase,
      spacing: spacing,
      slope: 0.5,
    );
    _appendParallelGridLines(
      path: path,
      width: size.width,
      minIntercept: 0,
      maxIntercept: size.height + size.width / 2,
      baseIntercept: negativeSlopeBase,
      spacing: spacing,
      slope: -0.5,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapInfiniteGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.translation != translation ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.projection.mapWidth != projection.mapWidth ||
        oldDelegate.projection.mapHeight != projection.mapHeight ||
        oldDelegate.projection.tileExtent != projection.tileExtent ||
        oldDelegate.projection.originX != projection.originX;
  }
}

void _appendParallelGridLines({
  required Path path,
  required double width,
  required double minIntercept,
  required double maxIntercept,
  required double baseIntercept,
  required double spacing,
  required double slope,
}) {
  final firstIndex = ((minIntercept - baseIntercept) / spacing).floor() - 1;
  final lastIndex = ((maxIntercept - baseIntercept) / spacing).ceil() + 1;
  for (var index = firstIndex; index <= lastIndex; index += 1) {
    final intercept = baseIntercept + index * spacing;
    path
      ..moveTo(0, intercept)
      ..lineTo(width, slope * width + intercept);
  }
}

class _TilemapLocationBubble extends StatelessWidget {
  const _TilemapLocationBubble({
    super.key,
    required this.name,
    required this.avatars,
    required this.anchor,
  });

  final String name;
  final List<UserAvatar> avatars;
  final Offset anchor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, 0),
          child: Semantics(
            label: name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  key: ValueKey<String>('tile-location-pointer-$name'),
                  size: const Size(8, 6.93),
                  painter: const _TilemapLocationBubblePointerPainter(),
                ),
                Container(
                  key: ValueKey<String>('tile-location-bubble-body-$name'),
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFF3B4E),
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3A3A3A),
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (avatars.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TilemapLocationAvatars(avatars: avatars),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TilemapLocationBubblePointerPainter extends CustomPainter {
  const _TilemapLocationBubblePointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawShadow(path, const Color(0x24000000), 3, true)
      ..drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(
    covariant _TilemapLocationBubblePointerPainter oldDelegate,
  ) {
    return false;
  }
}

class _ProjectedTileHighlight extends StatelessWidget {
  const _ProjectedTileHighlight({
    super.key,
    required this.tile,
    required this.projection,
    required this.opacity,
  });

  final TilemapCell tile;
  final TilemapProjection projection;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final polygon = projection.polygonForTile(tile);
    final bounds = _boundsForOffsets(polygon);
    return Positioned.fromRect(
      rect: bounds,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TileHighlightPainter(
            polygon: polygon
                .map((point) => point - bounds.topLeft)
                .toList(growable: false),
            color: tilemapLocationHighlightColor.withValues(
              alpha: opacity.clamp(0, 1).toDouble(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileHighlightPainter extends CustomPainter {
  const _TileHighlightPainter({required this.polygon, required this.color});

  final List<Offset> polygon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 3 || color.a <= 0) return;
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TileHighlightPainter oldDelegate) {
    return oldDelegate.polygon != polygon || oldDelegate.color != color;
  }
}

class _ProjectedTile extends StatelessWidget {
  const _ProjectedTile({
    super.key,
    required this.tile,
    required this.asset,
    required this.topLeft,
    required this.extent,
    this.locationImageFlowAnimation,
    this.locationImageFlowPhase = 0,
    this.locationImageFlowAngleDegrees =
        tilemapDefaultLocationImageFlowAngleDegrees,
    this.locationImageFlowGradientPoints =
        tilemapDefaultLocationImageFlowGradientPoints,
    this.locationImageFlowOpacity = tilemapDefaultLocationImageFlowOpacity,
    this.locationImageFlowBlendMode = tilemapDefaultLocationImageFlowBlendMode,
    this.fogField,
    this.onImageError,
  });

  final TilemapCell tile;
  final String asset;
  final Offset topLeft;
  final double extent;
  final Animation<double>? locationImageFlowAnimation;
  final double locationImageFlowPhase;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
  final TilemapFogField? fogField;
  final ValueChanged<Object>? onImageError;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      semanticLabel: '${tile.type} ${tile.x},${tile.y}',
      errorBuilder: (context, error, stackTrace) {
        onImageError?.call(error);
        return const SizedBox.shrink();
      },
    );
    final field = fogField;
    final fogVertices = field?.shadowTileVertices[tile.cellKey];
    final animation = locationImageFlowAnimation;
    final imageWithFlow = animation == null
        ? image
        : _TilemapImageFlow(
            key: ValueKey<String>(
              'tile-location-image-flow-${tile.x}-${tile.y}',
            ),
            animation: animation,
            phase: locationImageFlowPhase,
            isolateRepaint: fogVertices == null,
            angleDegrees: locationImageFlowAngleDegrees,
            gradientPoints: locationImageFlowGradientPoints,
            opacity: locationImageFlowOpacity,
            blendMode: locationImageFlowBlendMode,
            child: image,
          );
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: extent,
      height: extent,
      child: field == null || fogVertices == null
          ? imageWithFlow
          : _TilemapFogBlend(
              key: ValueKey<String>('tile-fog-blend-${tile.x}-${tile.y}'),
              vertices: fogVertices,
              sceneTopLeft: topLeft,
              child: imageWithFlow,
            ),
    );
  }
}

class _TilemapImageFlow extends SingleChildRenderObjectWidget {
  const _TilemapImageFlow({
    super.key,
    required this.animation,
    required this.phase,
    required this.isolateRepaint,
    required this.angleDegrees,
    required this.gradientPoints,
    required this.opacity,
    required this.blendMode,
    required super.child,
  });

  final Animation<double> animation;
  final double phase;
  final bool isolateRepaint;
  final double angleDegrees;
  final List<TilemapLocationImageFlowGradientPoint> gradientPoints;
  final double opacity;
  final TilemapLocationImageFlowBlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTilemapImageFlow(
      animation: animation,
      phase: phase,
      isolateRepaint: isolateRepaint,
      angleDegrees: angleDegrees,
      gradientPoints: gradientPoints,
      opacity: opacity,
      blendMode: blendMode,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTilemapImageFlow renderObject,
  ) {
    renderObject
      ..animation = animation
      ..phase = phase
      ..isolateRepaint = isolateRepaint
      ..angleDegrees = angleDegrees
      ..gradientPoints = gradientPoints
      ..opacity = opacity
      ..blendMode = blendMode;
  }
}

class _RenderTilemapImageFlow extends RenderProxyBox {
  _RenderTilemapImageFlow({
    required Animation<double> animation,
    required double phase,
    required bool isolateRepaint,
    required double angleDegrees,
    required List<TilemapLocationImageFlowGradientPoint> gradientPoints,
    required double opacity,
    required TilemapLocationImageFlowBlendMode blendMode,
  }) : _animation = animation,
       _phase = phase,
       _isolateRepaint = isolateRepaint,
       _angleDegrees = angleDegrees,
       _gradientPoints = gradientPoints,
       _opacity = opacity,
       _blendMode = blendMode;

  Animation<double> _animation;
  double _phase;
  bool _isolateRepaint;
  double _angleDegrees;
  List<TilemapLocationImageFlowGradientPoint> _gradientPoints;
  double _opacity;
  TilemapLocationImageFlowBlendMode _blendMode;
  bool _wasPaused = false;

  set animation(Animation<double> value) {
    if (identical(_animation, value)) return;
    if (attached) _animation.removeListener(_handleAnimationTick);
    _animation = value;
    if (attached) _animation.addListener(_handleAnimationTick);
    _wasPaused = false;
    markNeedsPaint();
  }

  set phase(double value) {
    if (_phase == value) return;
    _phase = value;
    _wasPaused = false;
    markNeedsPaint();
  }

  set isolateRepaint(bool value) {
    if (_isolateRepaint == value) return;
    _isolateRepaint = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set angleDegrees(double value) {
    if (_angleDegrees == value) return;
    _angleDegrees = value;
    markNeedsPaint();
  }

  set gradientPoints(List<TilemapLocationImageFlowGradientPoint> value) {
    if (identical(_gradientPoints, value)) return;
    _gradientPoints = value;
    markNeedsPaint();
  }

  set opacity(double value) {
    if (_opacity == value) return;
    _opacity = value;
    markNeedsPaint();
  }

  set blendMode(TilemapLocationImageFlowBlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => _isolateRepaint;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_handleAnimationTick);
  }

  @override
  void detach() {
    _animation.removeListener(_handleAnimationTick);
    super.detach();
  }

  void _handleAnimationTick() {
    final isPaused =
        tilemapLocationImageFlowProgress(
          animationValue: _animation.value,
          phase: _phase,
        ) ==
        null;
    if (isPaused && _wasPaused) return;
    _wasPaused = isPaused;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final progress = tilemapLocationImageFlowProgress(
      animationValue: _animation.value,
      phase: _phase,
    );
    if (progress == null) {
      context.paintChild(child, offset);
      return;
    }

    final canvas = context.canvas;
    final layerBounds = offset & size;
    final angleDegrees = _angleDegrees.isFinite
        ? _angleDegrees
        : tilemapDefaultLocationImageFlowAngleDegrees;
    final angleRadians = angleDegrees * math.pi / 180;
    final direction = Offset(math.cos(angleRadians), math.sin(angleRadians));
    final horizontalProjection = size.width * direction.dx;
    final verticalProjection = size.height * direction.dy;
    final projections = <double>[
      0,
      horizontalProjection,
      verticalProjection,
      horizontalProjection + verticalProjection,
    ];
    final minProjection = projections.reduce(math.min);
    final maxProjection = projections.reduce(math.max);
    final bandWidth = size.width * tilemapLocationImageFlowBandWidthFraction;
    final centerDistance =
        minProjection -
        bandWidth +
        progress * (maxProjection - minProjection + bandWidth * 2);
    final gradientStart = offset + direction * (centerDistance - bandWidth / 2);
    final gradientEnd = offset + direction * (centerDistance + bandWidth / 2);
    final points = _gradientPoints.length >= 2
        ? (_gradientPoints.toList(growable: false)
            ..sort((a, b) => a.position.compareTo(b.position)))
        : tilemapDefaultLocationImageFlowGradientPoints;
    final opacity = _opacity.clamp(0.0, 1.0).toDouble();
    final colors = <Color>[
      for (final point in points)
        point.color.withValues(
          alpha: (point.color.a * opacity).clamp(0.0, 1.0).toDouble(),
        ),
    ];
    final stops = <double>[
      for (final point in points) point.position.clamp(0.0, 1.0).toDouble(),
    ];

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(gradientStart, gradientEnd, colors, stops);
    final canvasBlendMode = tilemapLocationImageFlowCanvasBlendMode(_blendMode);

    canvas.saveLayer(layerBounds, Paint());
    context.paintChild(child, offset);
    canvas.save();
    canvas.clipRect(layerBounds);
    if (_blendMode == TilemapLocationImageFlowBlendMode.normal) {
      canvas.drawRect(layerBounds, gradientPaint..blendMode = canvasBlendMode);
    } else {
      canvas.saveLayer(layerBounds, Paint()..blendMode = canvasBlendMode);
      canvas.drawRect(layerBounds, gradientPaint);
      canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstIn);
      context.paintChild(child, offset);
      canvas
        ..restore()
        ..restore();
    }
    canvas
      ..restore()
      ..restore();
  }
}

class _TilemapFogBlend extends SingleChildRenderObjectWidget {
  const _TilemapFogBlend({
    super.key,
    required this.vertices,
    required this.sceneTopLeft,
    required super.child,
  });

  final ui.Vertices vertices;
  final Offset sceneTopLeft;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTilemapFogBlend(
      vertices: vertices,
      sceneTopLeft: sceneTopLeft,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTilemapFogBlend renderObject,
  ) {
    renderObject
      ..vertices = vertices
      ..sceneTopLeft = sceneTopLeft;
  }
}

class _RenderTilemapFogBlend extends RenderProxyBox {
  _RenderTilemapFogBlend({
    required ui.Vertices vertices,
    required Offset sceneTopLeft,
  }) : _vertices = vertices,
       _sceneTopLeft = sceneTopLeft;

  ui.Vertices _vertices;
  Offset _sceneTopLeft;

  set vertices(ui.Vertices value) {
    if (identical(_vertices, value)) return;
    _vertices = value;
    markNeedsPaint();
  }

  set sceneTopLeft(Offset value) {
    if (_sceneTopLeft == value) return;
    _sceneTopLeft = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final layerBounds = offset & size;
    canvas.saveLayer(layerBounds, Paint());
    if (child != null) context.paintChild(child!, offset);
    canvas
      ..save()
      ..clipRect(layerBounds)
      ..translate(offset.dx - _sceneTopLeft.dx, offset.dy - _sceneTopLeft.dy)
      ..drawVertices(
        _vertices,
        tilemapFogVertexBlendMode,
        Paint()
          ..color = Colors.white
          ..blendMode = BlendMode.srcATop,
      )
      ..restore()
      ..restore();
  }
}

class _TilemapFogPainter extends CustomPainter {
  const _TilemapFogPainter(this.field);

  final TilemapFogField field;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..saveLayer(field.bounds, Paint())
      ..drawVertices(
        field.vertices,
        tilemapFogVertexBlendMode,
        Paint()..color = Colors.white,
      )
      // The fog sits behind the sorted tile layer. Land footprints are clear,
      // while shadow tile pixels receive fog in their own isolated paint pass.
      ..drawPath(field.landPath, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TilemapFogPainter oldDelegate) {
    return !identical(oldDelegate.field, field);
  }
}

class _TilemapShadowZeroBorderPainter extends CustomPainter {
  const _TilemapShadowZeroBorderPainter({
    required this.projection,
    required this.tiles,
    required this.scale,
  });

  final TilemapProjection projection;
  final List<TilemapCell> tiles;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (final tile in tiles) {
      if (tile.hasShadow) continue;
      path.addPolygon(projection.polygonForTile(tile), true);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tilemapShadowZeroBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = tilemapShadowZeroBorderWidth / scale
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _TilemapShadowZeroBorderPainter oldDelegate) {
    return !identical(oldDelegate.projection, projection) ||
        !identical(oldDelegate.tiles, tiles) ||
        oldDelegate.scale != scale;
  }
}

Rect _boundsForOffsets(List<Offset> points) {
  if (points.isEmpty) return Rect.zero;
  var left = points.first.dx;
  var top = points.first.dy;
  var right = points.first.dx;
  var bottom = points.first.dy;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _containsPointInPolygon(Offset point, List<Offset> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects =
        (pi.dy > point.dy) != (pj.dy > point.dy) &&
        point.dx <
            (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
    if (intersects) inside = !inside;
  }
  return inside;
}
