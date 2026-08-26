import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/config/genesis_image_config.dart';
import '../../utils/genesis_image_resource.dart';
import '../../ui/components/genesis_static_network_image.dart';
import 'genesis_modal_routes.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/components/genesis_safe_area.dart';

@visibleForTesting
typedef GenesisImageViewerPrecacheImage =
    Future<void> Function(
      ImageProvider<Object> imageProvider,
      BuildContext context,
    );

@visibleForTesting
GenesisImageViewerPrecacheImage? debugGenesisImageViewerPrecacheImage;

const SystemUiOverlayStyle _kGenesisImageViewerSystemUiOverlayStyle =
    kGenesisLightSystemUiOverlayStyle;

ImageProvider<Object>? genesisImageViewerPreviewProvider(
  BuildContext context, {
  required String imageUrl,
  double? logicalWidth,
  double? logicalHeight,
  BoxFit? fit,
  double maxDevicePixelRatio = GenesisImageConfig.maxDevicePixelRatio,
}) {
  final url = imageUrl.trim();
  if (url.isEmpty) return null;
  if (url.startsWith('assets/')) return AssetImage(url);
  final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
  return GenesisStaticNetworkImageProvider(
    imageUrl: url,
    cacheWidth: _viewerDecodePixelDimension(
      logicalWidth,
      devicePixelRatio,
      maxDevicePixelRatio: maxDevicePixelRatio,
    ),
    cacheHeight: _viewerDecodePixelDimension(
      logicalHeight,
      devicePixelRatio,
      maxDevicePixelRatio: maxDevicePixelRatio,
    ),
    fit: fit,
  );
}

ImageProvider<Object>? genesisImageViewerListPreviewProvider(
  BuildContext context, {
  required String source,
  required double? logicalWidth,
  required double? logicalHeight,
  BoxFit fit = BoxFit.cover,
}) {
  final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
  final imageUrl = selectGenesisImageUrl(
    source,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  ).trim();
  return genesisImageViewerPreviewProvider(
    context,
    imageUrl: imageUrl,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    fit: fit,
  );
}

Future<void> showGenesisImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  List<ImageProvider<Object>?> previewImageProviders =
      const <ImageProvider<Object>?>[],
  int initialIndex = 0,
  double maxDevicePixelRatio = GenesisImageConfig.maxDevicePixelRatio,
}) {
  final urls = <String>[];
  final previews = <ImageProvider<Object>?>[];
  for (var index = 0; index < imageUrls.length; index += 1) {
    final url = imageUrls[index].trim();
    if (url.isEmpty) continue;
    urls.add(url);
    previews.add(
      index < previewImageProviders.length
          ? previewImageProviders[index]
          : null,
    );
  }
  if (urls.isEmpty) return Future<void>.value();

  return showGenesisGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GenesisImageViewerOverlay(
        imageUrls: urls,
        previewImageProviders: previews,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
        maxDevicePixelRatio: maxDevicePixelRatio,
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
    this.previewImageProviders = const <ImageProvider<Object>?>[],
    this.initialIndex = 0,
    this.maxDevicePixelRatio = GenesisImageConfig.maxDevicePixelRatio,
  });

  final List<String> imageUrls;
  final List<ImageProvider<Object>?> previewImageProviders;
  final int initialIndex;
  final double maxDevicePixelRatio;

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
  final Set<String> _preloadedImageUrls = <String>{};
  bool _pinchGestureActive = false;
  Offset? _dragStart;
  double _dragOffsetY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAdjacentImages();
    });
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
    _precacheAdjacentImages(centerIndex: index);
  }

  void _precacheAdjacentImages({int? centerIndex}) {
    final index = centerIndex ?? _currentIndex;
    _precacheImageAt(index - 1);
    _precacheImageAt(index + 1);
  }

  void _precacheImageAt(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    final imageUrl = _selectedViewerImageUrl(widget.imageUrls[index]);
    if (imageUrl.isEmpty || !_preloadedImageUrls.add(imageUrl)) return;
    final imageProvider = _viewerImageProvider(imageUrl);
    final precache = debugGenesisImageViewerPrecacheImage;
    final future = precache == null
        ? precacheImage(
            imageProvider,
            context,
            onError: (exception, stackTrace) {},
          )
        : precache(imageProvider, context);
    unawaited(future);
  }

  String _selectedViewerImageUrl(String source) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final size = mediaQuery?.size;
    final logicalWidth = size != null && size.width.isFinite
        ? size.width / _pageViewportFraction
        : null;
    final logicalHeight = size != null && size.height.isFinite
        ? size.height
        : null;
    return _selectViewerImageUrl(
      source,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: mediaQuery?.devicePixelRatio ?? 1,
      maxDevicePixelRatio: widget.maxDevicePixelRatio,
    );
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

  bool _canStartDismissDrag() {
    final transformation = _transformationControllers[_currentIndex].value;
    final scale = transformation.entry(0, 0);
    final translationY = transformation.getTranslation().y;
    return (scale - 1).abs() < 0.001 && translationY >= -0.5;
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_dragOffsetY / _dismissDragDistance).clamp(0.0, 1.0);
    final dragScale = 1 - _maxDragScaleReduction * dragProgress;
    return GenesisBottomSystemBarStyleScope(
      style: const GenesisBottomSystemBarStyle(color: Colors.black),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _kGenesisImageViewerSystemUiOverlayStyle,
        child: GenesisEdgeSwipeBack(
          onBack: () => Navigator.of(context).pop(),
          child: Material(
            key: const ValueKey('genesis-image-viewer-surface'),
            color: Color.lerp(
              Colors.black,
              Colors.transparent,
              dragProgress * 0.32,
            ),
            child: Listener(
              onPointerDown: (event) {
                _activePointers.add(event.pointer);
                _dragStart = _canStartDismissDrag() ? event.position : null;
                final nextPinchActive = _activePointers.length > 1;
                if (_dragOffsetY != 0 ||
                    nextPinchActive != _pinchGestureActive) {
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
                if (_dragOffsetY != 0 ||
                    nextPinchActive != _pinchGestureActive) {
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
                      key: const ValueKey(
                        'genesis-image-viewer-drag-translation',
                      ),
                      offset: Offset(0, _dragOffsetY),
                      child: Transform.scale(
                        key: const ValueKey(
                          'genesis-image-viewer-drag-transform',
                        ),
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
                                previewImageProvider:
                                    index < widget.previewImageProviders.length
                                    ? widget.previewImageProviders[index]
                                    : null,
                                controller: _transformationControllers[index],
                                maxDevicePixelRatio: widget.maxDevicePixelRatio,
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
          ),
        ),
      ),
    );
  }
}

ImageProvider<Object> _viewerImageProvider(String url) {
  if (url.startsWith('assets/')) return AssetImage(url);
  return GenesisStaticNetworkImageProvider(imageUrl: url);
}

int? _viewerDecodePixelDimension(
  double? logicalDimension,
  double devicePixelRatio, {
  double? maxDevicePixelRatio,
}) {
  if (logicalDimension == null ||
      !logicalDimension.isFinite ||
      logicalDimension <= 0) {
    return null;
  }
  final ratio = maxDevicePixelRatio == null
      ? genesisImageDevicePixelRatio(devicePixelRatio)
      : genesisImageDevicePixelRatio(
          devicePixelRatio,
          maxDevicePixelRatio: maxDevicePixelRatio,
        );
  return (logicalDimension * ratio).ceil();
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
    required this.previewImageProvider,
    required this.controller,
    required this.maxDevicePixelRatio,
  });

  final int index;
  final String url;
  final ImageProvider<Object>? previewImageProvider;
  final TransformationController controller;
  final double maxDevicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox.expand(
          child: InteractiveViewer(
            key: ValueKey('genesis-image-viewer-interactive-$index'),
            transformationController: controller,
            constrained: false,
            minScale: 1,
            maxScale: 4,
            child: ConstrainedBox(
              key: ValueKey('genesis-image-viewer-image-$index'),
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: _ProgressiveImageByUrl(
                  index: index,
                  url: url,
                  previewImageProvider: previewImageProvider,
                  fit: BoxFit.fitWidth,
                  maxDevicePixelRatio: maxDevicePixelRatio,
                ),
              ),
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

class _ProgressiveImageByUrl extends StatelessWidget {
  const _ProgressiveImageByUrl({
    required this.index,
    required this.url,
    required this.previewImageProvider,
    required this.fit,
    required this.maxDevicePixelRatio,
  });

  final int index;
  final String url;
  final ImageProvider<Object>? previewImageProvider;
  final BoxFit fit;
  final double maxDevicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio =
            MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final logicalHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;
        final fallback = SizedBox(
          width: logicalWidth,
          height: logicalWidth,
          child: Container(
            color: const Color(0xFF202020),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              size: 28,
              color: Colors.white54,
            ),
          ),
        );
        final fullImageUrl = _selectViewerImageUrl(
          url,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          devicePixelRatio: devicePixelRatio,
          maxDevicePixelRatio: maxDevicePixelRatio,
        );
        if (fullImageUrl.isEmpty) return fallback;

        final explicitPreviewProvider = previewImageProvider;
        final previewImageUrl = explicitPreviewProvider == null
            ? _selectViewerPreviewImageUrl(
                url,
                fullImageUrl: fullImageUrl,
                devicePixelRatio: devicePixelRatio,
                maxDevicePixelRatio: maxDevicePixelRatio,
              )
            : '';
        if (explicitPreviewProvider == null &&
            (previewImageUrl.isEmpty || previewImageUrl == fullImageUrl)) {
          return _buildViewerImage(
            key: ValueKey('genesis-image-viewer-full-$index'),
            imageUrl: fullImageUrl,
            width: logicalWidth,
            fit: fit,
            fallback: fallback,
            maxDevicePixelRatio: maxDevicePixelRatio,
          );
        }

        final preview = explicitPreviewProvider == null
            ? _buildViewerImage(
                key: ValueKey('genesis-image-viewer-preview-$index'),
                imageUrl: previewImageUrl,
                width: logicalWidth,
                fit: fit,
                fallback: fallback,
                maxDevicePixelRatio: maxDevicePixelRatio,
              )
            : KeyedSubtree(
                key: ValueKey('genesis-image-viewer-preview-$index'),
                child: Image(
                  image: explicitPreviewProvider,
                  width: logicalWidth,
                  fit: fit,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return fallback;
                      },
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
              );
        return _buildViewerImage(
          key: ValueKey('genesis-image-viewer-full-$index'),
          imageUrl: fullImageUrl,
          width: logicalWidth,
          fit: fit,
          fallback: preview,
          maxDevicePixelRatio: maxDevicePixelRatio,
        );
      },
    );
  }

  Widget _buildViewerImage({
    required Key key,
    required String imageUrl,
    required double? width,
    required BoxFit fit,
    required Widget fallback,
    required double maxDevicePixelRatio,
  }) {
    if (imageUrl.startsWith('assets/')) {
      return KeyedSubtree(
        key: key,
        child: Image.asset(
          imageUrl,
          width: width,
          fit: fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return fallback;
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      );
    }
    return KeyedSubtree(
      key: key,
      child: GenesisStaticNetworkImage(
        imageUrl: imageUrl,
        width: width,
        fit: fit,
        maxDevicePixelRatio: maxDevicePixelRatio,
        placeholder: (_) => fallback,
        errorWidget: (_, _) => fallback,
      ),
    );
  }
}

String _selectViewerImageUrl(
  String source, {
  required double? logicalWidth,
  required double? logicalHeight,
  required double devicePixelRatio,
  required double maxDevicePixelRatio,
}) {
  final selected = selectGenesisImageUrl(
    source,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
    maxDevicePixelRatio: maxDevicePixelRatio,
  ).trim();
  final candidate = selected.isNotEmpty ? selected : source.trim();
  final resized = resizeGenesisImageUrl(
    candidate,
    logicalWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
    maxDevicePixelRatio: maxDevicePixelRatio,
  );
  return resized.isNotEmpty ? resized : candidate;
}

String _selectViewerPreviewImageUrl(
  String source, {
  required String fullImageUrl,
  required double devicePixelRatio,
  required double maxDevicePixelRatio,
}) {
  final candidate = source.trim();
  if (candidate.isEmpty || candidate.startsWith('assets/')) return candidate;
  if (candidate.contains('x-oss-process=image/resize')) return candidate;

  final resource = GenesisImageResourceRegistry.resolve(candidate);
  final smallImageUrl = resource.smUrl.trim();
  if (smallImageUrl.isNotEmpty) {
    return localDefaultMapImageAssetForBackendImageUrl(smallImageUrl) ??
        smallImageUrl;
  }

  final resized = resizeGenesisImageUrl(
    fullImageUrl,
    logicalWidth: 120,
    devicePixelRatio: devicePixelRatio,
    maxDevicePixelRatio: maxDevicePixelRatio,
  );
  return resized.isNotEmpty ? resized : candidate;
}
