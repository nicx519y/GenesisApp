part of 'tilemap_renderer_library.dart';

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
