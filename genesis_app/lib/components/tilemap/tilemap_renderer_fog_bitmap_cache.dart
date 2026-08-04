part of 'tilemap_renderer_library.dart';

class _TilemapFogBlend extends SingleChildRenderObjectWidget {
  const _TilemapFogBlend({
    super.key,
    required this.vertices,
    required this.sceneTopLeft,
    required this.rasterizationEnabled,
    required this.rasterPixelRatio,
    required super.child,
  });

  final ui.Vertices vertices;
  final Offset sceneTopLeft;
  final bool rasterizationEnabled;
  final double rasterPixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTilemapFogBlend(
      vertices: vertices,
      sceneTopLeft: sceneTopLeft,
      rasterizationEnabled: rasterizationEnabled,
      rasterPixelRatio: rasterPixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTilemapFogBlend renderObject,
  ) {
    renderObject
      ..vertices = vertices
      ..sceneTopLeft = sceneTopLeft
      ..rasterizationEnabled = rasterizationEnabled
      ..rasterPixelRatio = rasterPixelRatio;
  }
}

class _RenderTilemapFogBlend extends RenderProxyBox {
  _RenderTilemapFogBlend({
    required ui.Vertices vertices,
    required Offset sceneTopLeft,
    required bool rasterizationEnabled,
    required double rasterPixelRatio,
  }) : _vertices = vertices,
       _sceneTopLeft = sceneTopLeft,
       _rasterizationEnabled = rasterizationEnabled,
       _rasterPixelRatio = rasterPixelRatio;

  ui.Vertices _vertices;
  Offset _sceneTopLeft;
  bool _rasterizationEnabled;
  double _rasterPixelRatio;
  ui.Image? _rasterizedComposite;
  int _compositeGeneration = 0;
  int? _pendingCaptureGeneration;
  bool _rasterizationSuppressedForGeneration = false;
  int _debugBlendPaintCount = 0;
  int _debugRasterizedPaintCount = 0;

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

  set rasterizationEnabled(bool value) {
    if (_rasterizationEnabled == value) {
      if (value) _TilemapFogRasterBudget.touch(this);
      return;
    }
    _rasterizationEnabled = value;
    markNeedsPaint();
  }

  set rasterPixelRatio(double value) {
    final resolvedValue = value.isFinite && value > 0 ? value : 1.0;
    if (_rasterPixelRatio == resolvedValue) return;
    _rasterPixelRatio = resolvedValue;
    markNeedsPaint();
  }

  bool get debugHasRasterizedComposite => _rasterizedComposite != null;

  int get debugBlendPaintCount => _debugBlendPaintCount;

  int get debugRasterizedPaintCount => _debugRasterizedPaintCount;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final rasterizedComposite = _rasterizedComposite;
    if (rasterizedComposite != null) {
      _TilemapFogRasterBudget.touch(this);
      assert(() {
        _debugRasterizedPaintCount += 1;
        return true;
      }());
      context.canvas.drawImageRect(
        rasterizedComposite,
        Rect.fromLTWH(
          0,
          0,
          rasterizedComposite.width.toDouble(),
          rasterizedComposite.height.toDouble(),
        ),
        offset & size,
        Paint()..filterQuality = FilterQuality.none,
      );
      return;
    }

    assert(() {
      _debugBlendPaintCount += 1;
      return true;
    }());
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

    // This repaint boundary is invalidated only when the tile image, fog
    // vertices, or scene position changes. Hint the compositor to raster-cache
    // the completed image + fog blend so ancestor transforms can reuse it
    // without replaying the saveLayer/drawVertices operations.
    context.setIsComplexHint();
    if (_rasterizationEnabled && !_rasterizationSuppressedForGeneration) {
      _scheduleCompositeCapture();
    }
  }

  @override
  void markNeedsPaint() {
    _discardRasterizedComposite();
    super.markNeedsPaint();
  }

  void _scheduleCompositeCapture() {
    final generation = _compositeGeneration;
    if (_pendingCaptureGeneration == generation) return;
    _pendingCaptureGeneration = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || generation != _compositeGeneration) {
        if (_pendingCaptureGeneration == generation) {
          _pendingCaptureGeneration = null;
        }
        return;
      }
      _TilemapFogRasterQueue.schedule(this, generation);
    });
  }

  Future<void> _captureComposite(int generation) async {
    if (!attached || generation != _compositeGeneration) {
      _finishCapture(generation);
      return;
    }
    final boundaryLayer = layer;
    if (boundaryLayer is! OffsetLayer ||
        size.isEmpty ||
        !boundaryLayer.supportsRasterization()) {
      _finishCapture(generation);
      return;
    }

    ui.Image? image;
    try {
      image = await boundaryLayer.toImage(
        Offset.zero & size,
        pixelRatio: _rasterPixelRatio,
      );
    } catch (_) {
      _finishCapture(generation);
      return;
    }

    if (!attached || generation != _compositeGeneration) {
      image.dispose();
      _finishCapture(generation);
      return;
    }
    final imageBytes = image.width * image.height * 4;
    if (!_TilemapFogRasterBudget.retain(this, imageBytes)) {
      image.dispose();
      _rasterizationSuppressedForGeneration = true;
      _finishCapture(generation);
      return;
    }
    _rasterizedComposite = image;
    _finishCapture(generation);
    // Re-record this boundary once with a single image draw. Calling super
    // intentionally keeps the freshly captured composite alive.
    super.markNeedsPaint();
  }

  void _finishCapture(int generation) {
    if (_pendingCaptureGeneration == generation) {
      _pendingCaptureGeneration = null;
    }
  }

  void _discardRasterizedComposite() {
    _compositeGeneration += 1;
    _pendingCaptureGeneration = null;
    _rasterizationSuppressedForGeneration = false;
    _TilemapFogRasterQueue.cancel(this);
    _TilemapFogRasterBudget.release(this);
    _rasterizedComposite?.dispose();
    _rasterizedComposite = null;
  }

  void _evictRasterizedCompositeFromBudget() {
    final image = _rasterizedComposite;
    if (image == null) return;
    _compositeGeneration += 1;
    _rasterizationSuppressedForGeneration = true;
    _rasterizedComposite = null;
    image.dispose();
    // Keep this generation on the retained-layer fallback until a real input
    // change or visibility transition makes another capture worthwhile.
    super.markNeedsPaint();
  }

  @override
  void dispose() {
    _discardRasterizedComposite();
    super.dispose();
  }
}

class _TilemapFogRasterBudget {
  static const int _maxBytes = 32 * 1024 * 1024;
  static final Map<_RenderTilemapFogBlend, int> _retainedBytes = Map.identity();
  static int _totalBytes = 0;

  static bool retain(_RenderTilemapFogBlend owner, int bytes) {
    release(owner);
    if (bytes <= 0 || bytes > _maxBytes) return false;
    while (_totalBytes + bytes > _maxBytes && _retainedBytes.isNotEmpty) {
      final oldest = _retainedBytes.keys.first;
      final releasedBytes = _retainedBytes.remove(oldest)!;
      _totalBytes -= releasedBytes;
      oldest._evictRasterizedCompositeFromBudget();
    }
    _retainedBytes[owner] = bytes;
    _totalBytes += bytes;
    return true;
  }

  static void release(_RenderTilemapFogBlend owner) {
    final bytes = _retainedBytes.remove(owner);
    if (bytes != null) _totalBytes -= bytes;
  }

  static void touch(_RenderTilemapFogBlend owner) {
    final bytes = _retainedBytes.remove(owner);
    if (bytes != null) _retainedBytes[owner] = bytes;
  }
}

class _TilemapFogRasterQueue {
  static const int _maxConcurrentCaptures = 1;
  static final List<_TilemapFogRasterRequest> _pending = [];
  static int _activeCaptures = 0;

  static void schedule(_RenderTilemapFogBlend owner, int generation) {
    _pending.add(_TilemapFogRasterRequest(WeakReference(owner), generation));
    _drain();
  }

  static void cancel(_RenderTilemapFogBlend owner) {
    _pending.removeWhere((request) {
      final target = request.owner.target;
      return target == null || identical(target, owner);
    });
  }

  static void _drain() {
    while (_activeCaptures < _maxConcurrentCaptures && _pending.isNotEmpty) {
      final request = _pending.removeAt(0);
      _activeCaptures += 1;
      unawaited(_run(request));
    }
  }

  static Future<void> _run(_TilemapFogRasterRequest request) async {
    try {
      final owner = request.owner.target;
      if (owner != null) {
        await owner._captureComposite(request.generation);
      }
    } catch (_) {
      // Snapshotting is an optional optimization. The retained complex layer
      // remains the fallback if a backend cannot capture this frame.
    } finally {
      _activeCaptures -= 1;
      _drain();
    }
  }
}

class _TilemapFogRasterRequest {
  const _TilemapFogRasterRequest(this.owner, this.generation);

  final WeakReference<_RenderTilemapFogBlend> owner;
  final int generation;
}

final RegExp _tilemapFogRasterWidthPattern = RegExp(
  r'(?:^|[?,])w_(\d+)(?:[,&#]|$)',
);

double _tilemapFogRasterPixelRatio({
  required String asset,
  required double tileExtent,
}) {
  if (!tileExtent.isFinite || tileExtent <= 0) return 1;
  final match = _tilemapFogRasterWidthPattern.firstMatch(asset);
  final assetWidth = int.tryParse(match?.group(1) ?? '');
  if (assetWidth == null || assetWidth <= 0) return 1;
  return math.max(1, assetWidth / tileExtent);
}

@visibleForTesting
bool debugTilemapFogBlendHasRasterizedComposite(RenderObject renderObject) {
  return renderObject is _RenderTilemapFogBlend &&
      renderObject.debugHasRasterizedComposite;
}

@visibleForTesting
int debugTilemapFogBlendPaintCount(RenderObject renderObject) {
  return renderObject is _RenderTilemapFogBlend
      ? renderObject.debugBlendPaintCount
      : 0;
}

@visibleForTesting
int debugTilemapFogRasterizedPaintCount(RenderObject renderObject) {
  return renderObject is _RenderTilemapFogBlend
      ? renderObject.debugRasterizedPaintCount
      : 0;
}
