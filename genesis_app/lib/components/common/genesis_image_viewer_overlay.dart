import 'package:flutter/material.dart';

import '../../utils/genesis_image_resource.dart';

Future<void> showGenesisImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  final urls = imageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (urls.isEmpty) return Future<void>.value();

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GenesisImageViewerOverlay(
        imageUrls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class GenesisImageViewerOverlay extends StatefulWidget {
  const GenesisImageViewerOverlay({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<GenesisImageViewerOverlay> createState() =>
      _GenesisImageViewerOverlayState();
}

class _GenesisImageViewerOverlayState extends State<GenesisImageViewerOverlay> {
  static const double _dismissDragDistance = 20;
  static const double _maxDragScaleReduction = 0.1;
  static const double _pageViewportFraction = 1.035;

  late final PageController _pageController;
  late final List<TransformationController> _transformationControllers;
  late int _currentIndex;
  final Set<int> _activePointers = <int>{};
  bool _pinchGestureActive = false;
  Offset? _dragStart;
  double _dragOffsetY = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: _pageViewportFraction,
    );
    _transformationControllers = List<TransformationController>.generate(
      widget.imageUrls.length,
      (_) => TransformationController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handlePageChanged(int index) {
    setState(() => _currentIndex = index);
    for (var i = 0; i < _transformationControllers.length; i += 1) {
      if (i == index) continue;
      _transformationControllers[i].value = Matrix4.identity();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasPinching = _pinchGestureActive;
    _activePointers.remove(event.pointer);
    if (wasPinching) {
      if (_activePointers.length < 2) {
        setState(() {
          _pinchGestureActive = false;
          _dragStart = null;
          _dragOffsetY = 0;
        });
      }
      return;
    }
    final shouldDismiss = _dragOffsetY >= _dismissDragDistance;
    _dragStart = null;
    if (shouldDismiss) {
      Navigator.of(context).pop();
      return;
    }
    if (_dragOffsetY == 0) return;
    setState(() => _dragOffsetY = 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pinchGestureActive) {
      if (_dragOffsetY != 0) setState(() => _dragOffsetY = 0);
      return;
    }
    final start = _dragStart;
    if (start == null) return;
    final delta = event.position - start;
    final nextOffset = delta.dy > delta.dx.abs()
        ? delta.dy.clamp(0.0, 280.0)
        : 0.0;
    if (nextOffset == _dragOffsetY) return;
    setState(() => _dragOffsetY = nextOffset);
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_dragOffsetY / _dismissDragDistance).clamp(0.0, 1.0);
    final dragScale = 1 - _maxDragScaleReduction * dragProgress;
    return Material(
      key: const ValueKey('genesis-image-viewer-surface'),
      color: Color.lerp(Colors.black, Colors.transparent, dragProgress * 0.32),
      child: Listener(
        onPointerDown: (event) {
          _activePointers.add(event.pointer);
          _dragStart = event.position;
          final nextPinchActive = _activePointers.length > 1;
          if (_dragOffsetY != 0 || nextPinchActive != _pinchGestureActive) {
            setState(() {
              _pinchGestureActive = nextPinchActive;
              _dragOffsetY = 0;
            });
          }
        },
        onPointerCancel: (event) {
          _activePointers.remove(event.pointer);
          _dragStart = null;
          final nextPinchActive = _activePointers.length > 1;
          if (_dragOffsetY != 0 || nextPinchActive != _pinchGestureActive) {
            setState(() {
              _pinchGestureActive = nextPinchActive;
              _dragOffsetY = 0;
            });
          }
        },
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.translate(
                key: const ValueKey('genesis-image-viewer-drag-translation'),
                offset: Offset(0, _dragOffsetY),
                child: Transform.scale(
                  key: const ValueKey('genesis-image-viewer-drag-transform'),
                  scale: dragScale,
                  child: PageView.builder(
                    key: const ValueKey('genesis-image-viewer-page-view'),
                    controller: _pageController,
                    physics: _pinchGestureActive
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      return _ViewerPageSlot(
                        viewportFraction: _pageViewportFraction,
                        child: _ViewerImage(
                          index: index,
                          url: widget.imageUrls[index],
                          controller: _transformationControllers[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: DecoratedBox(
                    key: const ValueKey(
                      'genesis-image-viewer-close-background',
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 36,
                      child: IconButton(
                        key: const ValueKey('genesis-image-viewer-close'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 16),
                  child: _ViewerPageDots(
                    count: widget.imageUrls.length,
                    currentIndex: _currentIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerPageSlot extends StatelessWidget {
  const _ViewerPageSlot({required this.viewportFraction, required this.child});

  final double viewportFraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth / viewportFraction;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: viewportWidth,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}

class _ViewerImage extends StatelessWidget {
  const _ViewerImage({
    required this.index,
    required this.url,
    required this.controller,
  });

  final int index;
  final String url;
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox.expand(
          child: InteractiveViewer(
            key: ValueKey('genesis-image-viewer-interactive-$index'),
            transformationController: controller,
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              key: ValueKey('genesis-image-viewer-image-$index'),
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: _ImageByUrl(url: url, fit: BoxFit.fitWidth),
            ),
          ),
        );
      },
    );
  }
}

class _ViewerPageDots extends StatelessWidget {
  const _ViewerPageDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('genesis-image-viewer-page-dots'),
      height: 18,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < count; index += 1)
                AnimatedContainer(
                  key: ValueKey('genesis-image-viewer-dot-$index'),
                  width: index == currentIndex ? 8 : 6,
                  height: index == currentIndex ? 8 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentIndex
                        ? Colors.white
                        : Colors.white38,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageByUrl extends StatelessWidget {
  const _ImageByUrl({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF202020),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 28, color: Colors.white54),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageUrl = selectGenesisImageUrl(
          url,
          logicalWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null,
          logicalHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null,
          devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
        );
        if (imageUrl.isEmpty) return fallback;
        if (imageUrl.startsWith('assets/')) {
          return SizedBox.expand(
            child: Image.asset(
              imageUrl,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
          );
        }
        return SizedBox.expand(
          child: Image.network(
            imageUrl,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          ),
        );
      },
    );
  }
}
