import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../world_map_contract.dart';
import '../world_map_interaction_notification.dart';

const double legacyWorldMapMinScale = 1;
const double legacyWorldMapMaxScale = 2;
// 设计稿 9a/9b 原文:right:16px; bottom:176px; width:34px; height:68px;
// border-radius:12px; background:rgba(21,21,23,.6);
// border:1px solid rgba(255,255,255,.16),没有投影。
// bottom 176 是相对屏幕底,浮窗高 149,故离浮窗顶边 27。
const double legacyWorldMapZoomControlRightGap = 16;
const double legacyWorldMapZoomControlBottomGap = 27;
const double legacyWorldMapZoomControlWidth = 34;
const double legacyWorldMapZoomControlHeight = 68;
// 与左上返回按钮(GenesisBackButton:34 / 圆角 11 / 无描边)对齐。
const double legacyWorldMapZoomControlRadius = 11;
const double legacyWorldMapZoomHitAreaWidth = 48;
const double legacyWorldMapZoomHitAreaHeight = 88;
const double legacyWorldMapZoomDragExtent = 96;
const Color legacyWorldMapZoomControlBackgroundColor = Color(0x99151517);
// 描边从 50% 白降到设计稿的 16% —— 之前整整重了三倍。
const Color legacyWorldMapZoomControlBorderColor = Color(0x29FFFFFF);
// 1px 在 3x 屏上就是 3 个物理像素,比设计稿看着重。取半像素。
const double legacyWorldMapZoomControlBorderWidth = 0.5;
const Color legacyWorldMapZoomControlEnabledColor = Color(0xFFFFFFFF);
const Color legacyWorldMapZoomControlDisabledColor = Color(0xFF777777);
const String legacyWorldMapZoomInIconAsset =
    'assets/custom-icons/svg/map_zoom_in.svg';
const String legacyWorldMapZoomOutIconAsset =
    'assets/custom-icons/svg/map_zoom_out.svg';

typedef LegacyWorldMapOverlayBuilder =
    Widget Function(
      BuildContext context,
      Matrix4 transform,
      ValueChanged<PointerDownEvent> onOverlayPointerDown,
    );
typedef LegacyWorldMapZoomControlChanged =
    void Function(Object token, void Function(double delta)? zoomByControl);

class LegacyWorldMapZoomableContent extends StatefulWidget {
  const LegacyWorldMapZoomableContent({
    super.key,
    required this.background,
    required this.contentSize,
    required this.initialScale,
    required this.initialFocus,
    this.initialViewportVerticalOffsetFraction = 0,
    required this.initialTransformKey,
    required this.initialViewportSize,
    required this.overlayBuilder,
    required this.onMapTap,
    required this.onScaleChanged,
    required this.onHorizontalPanStateChanged,
    required this.onZoomControlChanged,
  });

  static const double minScale = legacyWorldMapMinScale;
  static const double maxScale = legacyWorldMapMaxScale;
  static const double doubleTapScale = 1.5;

  final Widget background;
  final Size contentSize;
  final double initialScale;
  final Offset? initialFocus;
  final double initialViewportVerticalOffsetFraction;
  final String initialTransformKey;
  final Size initialViewportSize;
  final LegacyWorldMapOverlayBuilder overlayBuilder;
  final VoidCallback? onMapTap;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<WorldMapHorizontalPanState> onHorizontalPanStateChanged;
  final LegacyWorldMapZoomControlChanged onZoomControlChanged;

  @override
  State<LegacyWorldMapZoomableContent> createState() =>
      LegacyWorldMapZoomableContentState();
}

class LegacyWorldMapZoomableContentState
    extends State<LegacyWorldMapZoomableContent> {
  late final TransformationController _transformationController;
  final Object _zoomControlToken = Object();
  final Set<int> _activePointers = <int>{};
  final Set<int> _overlayPointers = <int>{};
  final Map<int, Offset> _activePointerPositions = <int, Offset>{};
  bool _interactionActive = false;
  Duration? _lastTapTime;
  Offset? _lastTapLocalPosition;
  int? _mapTapPointer;
  Offset? _mapTapStartPosition;
  bool _mapTapStartedOnOverlay = false;
  bool _mapTapMoved = false;
  Matrix4? _manualGestureStartMatrix;
  Offset? _manualGestureStartFocal;
  double? _manualGestureStartDistance;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController(
      _initialTransformForSize(widget.initialViewportSize),
    );
    _transformationController.addListener(_notifyTransformChanged);
    widget.onZoomControlChanged(_zoomControlToken, zoomByControl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyHorizontalPanState();
    });
  }

  @override
  void didUpdateWidget(covariant LegacyWorldMapZoomableContent oldWidget) {
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
    _transformationController.removeListener(_notifyTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _notifyTransformChanged() {
    widget.onScaleChanged(_transformationController.value.getMaxScaleOnAxis());
    _notifyHorizontalPanState();
  }

  void _notifyHorizontalPanState() {
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final viewportSize = renderObject.size;
    if (viewportSize.isEmpty || widget.contentSize.isEmpty) return;

    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translationX = matrix.storage[12];
    final minX = math.min(
      0.0,
      viewportSize.width - widget.contentSize.width * scale,
    );
    widget.onHorizontalPanStateChanged(
      WorldMapHorizontalPanState(
        canScrollLeft: translationX < -0.5,
        canScrollRight: translationX > minX + 0.5,
      ),
    );
  }

  void _applyInitialTransform(Size size) {
    _transformationController.value = _initialTransformForSize(size);
  }

  Matrix4 _initialTransformForSize(Size size) {
    final scale = widget.initialScale
        .clamp(
          LegacyWorldMapZoomableContent.minScale,
          LegacyWorldMapZoomableContent.maxScale,
        )
        .toDouble();
    if (size.isEmpty || widget.contentSize.isEmpty) {
      return Matrix4.identity();
    }

    final focus = widget.initialFocus ?? const Offset(0.5, 0.5);
    final clampedFocus = Offset(
      focus.dx.clamp(0.0, 1.0).toDouble(),
      focus.dy.clamp(0.0, 1.0).toDouble(),
    );
    final contentFocus = Offset(
      widget.contentSize.width * clampedFocus.dx,
      widget.contentSize.height * clampedFocus.dy,
    );
    final verticalOffsetFraction = widget.initialViewportVerticalOffsetFraction
        .clamp(-0.25, 0.25)
        .toDouble();
    final center = Offset(
      size.width / 2,
      size.height * (0.5 + verticalOffsetFraction),
    );
    return _transformMatrixForSize(
      size: size,
      scale: scale,
      translation: center - contentFocus * scale,
    );
  }

  bool get _isZoomed {
    return _transformationController.value.getMaxScaleOnAxis() >
        LegacyWorldMapZoomableContent.minScale + 0.01;
  }

  bool get _canPan {
    if (!mounted) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return _isZoomed;
    final viewportSize = renderObject.size;
    final scale = _transformationController.value.getMaxScaleOnAxis();
    return widget.contentSize.width * scale > viewportSize.width + 0.5 ||
        widget.contentSize.height * scale > viewportSize.height + 0.5;
  }

  void _dispatchMapInteraction(bool active) {
    if (!mounted) return;
    if (_interactionActive == active) return;
    _interactionActive = active;
    WorldMapInteractionNotification(active: active).dispatch(context);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!mounted) return;
    if (_activePointers.isEmpty) {
      _handlePossibleDoubleTap(event);
      _mapTapPointer = event.pointer;
      _mapTapStartPosition = event.localPosition;
      _mapTapStartedOnOverlay = false;
      _mapTapMoved = false;
    }
    _activePointers.add(event.pointer);
    _activePointerPositions[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2 || _canPan) {
      _dispatchMapInteraction(true);
    }
    _startManualGestureIfNeeded();
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    if (!mounted) return;
    if (_mapTapPointer == event.pointer) {
      _mapTapStartedOnOverlay = true;
    }
    _overlayPointers.add(event.pointer);
    _startManualGestureIfNeeded();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted) return;
    if (!_activePointers.contains(event.pointer)) return;
    if (_mapTapPointer == event.pointer) {
      final start = _mapTapStartPosition;
      if (start != null && (event.localPosition - start).distance > 12) {
        _mapTapMoved = true;
      }
    }
    _activePointerPositions[event.pointer] = event.localPosition;

    if (_activePointerPositions.length >= 2) {
      _startManualGestureIfNeeded();
      _updateManualScaleGesture();
      return;
    }

    if (_canPan && _overlayPointers.contains(event.pointer)) {
      _updateManualPanGesture(event);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (!mounted) return;
    if (event is PointerUpEvent &&
        _mapTapPointer == event.pointer &&
        !_mapTapStartedOnOverlay &&
        !_mapTapMoved &&
        _activePointers.length == 1) {
      widget.onMapTap?.call();
    }
    _activePointers.remove(event.pointer);
    _overlayPointers.remove(event.pointer);
    _activePointerPositions.remove(event.pointer);
    if (_mapTapPointer == event.pointer) {
      _mapTapPointer = null;
      _mapTapStartPosition = null;
      _mapTapStartedOnOverlay = false;
      _mapTapMoved = false;
    }
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
        .clamp(
          LegacyWorldMapZoomableContent.minScale,
          LegacyWorldMapZoomableContent.maxScale,
        )
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
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final size = renderObject.size;
    if (size.isEmpty) return;
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
    if (size.isEmpty || widget.contentSize.isEmpty) {
      return Matrix4.identity();
    }

    final scaledContentWidth = widget.contentSize.width * scale;
    final scaledContentHeight = widget.contentSize.height * scale;
    final clampedTranslation = Offset(
      _clampAxisTranslation(size.width, scaledContentWidth, translation.dx),
      _clampAxisTranslation(size.height, scaledContentHeight, translation.dy),
    );
    return Matrix4.identity()
      ..translateByDouble(clampedTranslation.dx, clampedTranslation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  double _clampAxisTranslation(
    double viewportExtent,
    double scaledContentExtent,
    double translation,
  ) {
    if (scaledContentExtent <= viewportExtent) {
      return (viewportExtent - scaledContentExtent) / 2;
    }
    return translation
        .clamp(viewportExtent - scaledContentExtent, 0.0)
        .toDouble();
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
    if (!mounted) return;
    if (_isZoomed) {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.attached) {
        final size = renderObject.size;
        final contentCenter = Offset(
          widget.contentSize.width / 2,
          widget.contentSize.height / 2,
        );
        _setTransform(
          LegacyWorldMapZoomableContent.minScale,
          Offset(size.width / 2, size.height / 2) - contentCenter,
        );
      }
      _dispatchMapInteraction(false);
      return;
    }

    final scale = LegacyWorldMapZoomableContent.doubleTapScale;
    _setTransform(
      scale,
      Offset(
        focalPoint.dx - focalPoint.dx * scale,
        focalPoint.dy - focalPoint.dy * scale,
      ),
    );
  }

  void zoomByControl(double delta) {
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final size = renderObject.size;
    if (size.isEmpty) return;

    final matrix = _transformationController.value;
    final values = matrix.storage;
    final currentScale = matrix.getMaxScaleOnAxis();
    final targetScale = (currentScale + delta)
        .clamp(
          LegacyWorldMapZoomableContent.minScale,
          LegacyWorldMapZoomableContent.maxScale,
        )
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
                  minScale: LegacyWorldMapZoomableContent.minScale,
                  maxScale: LegacyWorldMapZoomableContent.maxScale,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  onInteractionStart: (details) {
                    if (!mounted) return;
                    if (details.pointerCount > 1 || _canPan) {
                      _dispatchMapInteraction(true);
                    }
                  },
                  onInteractionUpdate: (details) {
                    if (!mounted) return;
                    if (details.pointerCount > 1 || _canPan) {
                      _dispatchMapInteraction(true);
                    }
                  },
                  onInteractionEnd: (_) {
                    if (!mounted) return;
                    if (_activePointers.isEmpty) {
                      _dispatchMapInteraction(false);
                    }
                  },
                  child: SizedBox(
                    key: const ValueKey<String>('world-map-scaled-content'),
                    width: widget.contentSize.width,
                    height: widget.contentSize.height,
                    child: widget.background,
                  ),
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

class LegacyWorldMapZoomControl extends StatelessWidget {
  const LegacyWorldMapZoomControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  }) : assert(min > 0),
       assert(max > min);

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  double get _progress =>
      (math.log(value / min) / math.log(max / min)).clamp(0.0, 1.0).toDouble();

  void _handleVerticalDrag(DragUpdateDetails details) {
    final targetProgress =
        (_progress - details.delta.dy / legacyWorldMapZoomDragExtent)
            .clamp(0.0, 1.0)
            .toDouble();
    onChanged(min * math.pow(max / min, targetProgress).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('world-map-zoom-drag-area'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _handleVerticalDrag,
      child: SizedBox(
        width: legacyWorldMapZoomHitAreaWidth,
        height: legacyWorldMapZoomHitAreaHeight,
        child: Align(
          alignment: Alignment.bottomRight,
          child: DecoratedBox(
            key: const ValueKey<String>('world-map-zoom-control'),
            decoration: BoxDecoration(
              color: legacyWorldMapZoomControlBackgroundColor,
              borderRadius: BorderRadius.circular(
                legacyWorldMapZoomControlRadius,
              ),
              border: Border.all(
                color: legacyWorldMapZoomControlBorderColor,
                width: legacyWorldMapZoomControlBorderWidth,
              ),
              // 设计稿这个控件没有投影,去掉后描边才不会显得重。
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                legacyWorldMapZoomControlRadius,
              ),
              child: SizedBox(
                width: legacyWorldMapZoomControlWidth,
                height: legacyWorldMapZoomControlHeight,
                child: Column(
                  children: [
                    Expanded(
                      child: _MapZoomButton(
                        key: const ValueKey<String>('world-map-zoom-in'),
                        iconAsset: legacyWorldMapZoomInIconAsset,
                        label: 'Zoom in on map',
                        color: canZoomIn
                            ? legacyWorldMapZoomControlEnabledColor
                            : legacyWorldMapZoomControlDisabledColor,
                        onTap: canZoomIn ? onZoomIn : null,
                      ),
                    ),
                    // 设计稿:第二格带 border-top 1px rgba(255,255,255,.16)。
                    // 中间原本那个拖拽 grip 设计稿里没有,已移除。
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: legacyWorldMapZoomControlBorderColor,
                              width: legacyWorldMapZoomControlBorderWidth,
                            ),
                          ),
                        ),
                        child: _MapZoomButton(
                          key: const ValueKey<String>('world-map-zoom-out'),
                          iconAsset: legacyWorldMapZoomOutIconAsset,
                          label: 'Zoom out of map',
                          color: canZoomOut
                              ? legacyWorldMapZoomControlEnabledColor
                              : legacyWorldMapZoomControlDisabledColor,
                          onTap: canZoomOut ? onZoomOut : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
