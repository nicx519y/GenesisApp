import 'dart:math' as math;

import 'package:flutter/material.dart';

const genesisImageViewerOpenDuration = Duration(milliseconds: 320);

/// Captured in the root overlay's coordinates before pushing the viewer.
class GenesisImageViewerSource {
  const GenesisImageViewerSource({
    required this.rect,
    required this.previewImageProvider,
    required this.previewImage,
    this.borderRadius = BorderRadius.zero,
    this.alignment = Alignment.center,
    this.onOpeningChanged,
  });

  final Rect rect;
  final ImageProvider<Object> previewImageProvider;

  /// Owns the captured frame until the viewer route has closed.
  final ImageInfo previewImage;
  double get aspectRatio =>
      previewImage.image.width / previewImage.image.height;
  final BorderRadius borderRadius;
  final Alignment alignment;
  final ValueChanged<bool>? onOpeningChanged;

  bool get isValid =>
      rect.isFinite && !rect.isEmpty && aspectRatio.isFinite && aspectRatio > 0;
}

/// Holds the source's layout/cache while hiding its painted copy in flight.
class GenesisImageViewerSourceAnchor extends StatefulWidget {
  const GenesisImageViewerSourceAnchor({
    super.key,
    required this.previewImageProvider,
    required this.child,
    required this.onTap,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.borderRadius = BorderRadius.zero,
  });

  final ImageProvider<Object> previewImageProvider;
  final Widget child;
  final ValueChanged<GenesisImageViewerSource> onTap;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius borderRadius;

  @override
  State<GenesisImageViewerSourceAnchor> createState() =>
      GenesisImageViewerSourceAnchorState();
}

class GenesisImageViewerSourceAnchorState
    extends State<GenesisImageViewerSourceAnchor> {
  bool _opening = false;
  ImageStream? _previewStream;
  ImageStreamListener? _previewListener;
  ImageInfo? _previewFrame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePreview();
  }

  @override
  void didUpdateWidget(covariant GenesisImageViewerSourceAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewImageProvider != widget.previewImageProvider) {
      _resolvePreview();
    }
  }

  void _resolvePreview() {
    _releasePreview();
    final stream = widget.previewImageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (info, _) {
        _previewFrame?.dispose();
        _previewFrame = info;
      },
      onError: (_, _) {
        _previewFrame?.dispose();
        _previewFrame = null;
      },
    );
    _previewStream = stream;
    _previewListener = listener;
    stream.addListener(listener);
  }

  void _releasePreview() {
    final listener = _previewListener;
    if (listener != null) _previewStream?.removeListener(listener);
    _previewListener = null;
    _previewStream = null;
    _previewFrame?.dispose();
    _previewFrame = null;
  }

  @override
  void dispose() {
    _releasePreview();
    super.dispose();
  }

  void _openingChanged(bool opening) {
    if (mounted && opening != _opening) setState(() => _opening = opening);
  }

  GenesisImageViewerSource? _capture() {
    final box = context.findRenderObject();
    final overlay = Navigator.of(
      context,
      rootNavigator: true,
    ).overlay?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) return null;

    // Retain a decoded frame while mounted. Resolving a fresh AssetImage on tap
    // may obtain its key asynchronously even when its pixels are already cached.
    final frame = _previewFrame?.clone();
    if (frame == null) return null;
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    if (size.isEmpty || box.size.isEmpty) {
      frame.dispose();
      return null;
    }
    final fitted = applyBoxFit(widget.fit, size, box.size);
    final localRect = widget.alignment
        .inscribe(fitted.destination, Offset.zero & box.size)
        .intersect(Offset.zero & box.size);
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      localRect,
    );
    if (!rect.isFinite || rect.isEmpty) {
      frame.dispose();
      return null;
    }
    return GenesisImageViewerSource(
      rect: rect,
      previewImageProvider: widget.previewImageProvider,
      previewImage: frame,
      borderRadius: widget.borderRadius,
      alignment: widget.alignment,
      onOpeningChanged: _openingChanged,
    );
  }

  /// Opens from the measured source for one-shot notification navigation.
  void open() {
    if (_opening || !mounted) return;
    final source = _capture();
    // A blank/loading thumbnail cannot supply a frame or a valid opening flight.
    if (source != null) widget.onTap(source);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _opening ? null : open,
    child: Opacity(opacity: _opening ? 0 : 1, child: widget.child),
  );
}

/// Animates a single cached frame; the viewer lays out and loads its full image
/// underneath without painting or handling gestures until the flight finishes.
class GenesisImageViewerOpenTransition extends StatefulWidget {
  const GenesisImageViewerOpenTransition({
    super.key,
    required this.animation,
    required this.source,
    required this.child,
    this.bottomInset = 0,
  });

  final Animation<double> animation;
  final GenesisImageViewerSource source;
  final Widget child;
  final double bottomInset;

  @override
  State<GenesisImageViewerOpenTransition> createState() =>
      _GenesisImageViewerOpenTransitionState();
}

class _GenesisImageViewerOpenTransitionState
    extends State<GenesisImageViewerOpenTransition> {
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_statusChanged);
    if (widget.animation.isCompleted) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.source.onOpeningChanged?.call(false);
      });
    }
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.reverse) {
      _finished = true;
      widget.source.onOpeningChanged?.call(false);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_statusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    builder: (context, _) {
      if (_finished || widget.animation.status == AnimationStatus.reverse) {
        return FadeTransition(opacity: widget.animation, child: widget.child);
      }
      final progress = Curves.easeOutCubic.transform(widget.animation.value);
      if (progress >= 1) return widget.child;
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = width / widget.source.aspectRatio;
          // Match the viewer: fitWidth, centered short images, tall images at top.
          final target = Rect.fromLTWH(
            0,
            math.max(
              0,
              (constraints.maxHeight - widget.bottomInset - height) / 2,
            ),
            width,
            height,
          );
          final rect = Rect.lerp(widget.source.rect, target, progress)!;
          return IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 0, child: widget.child),
                ColoredBox(color: Colors.black.withValues(alpha: progress)),
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    key: const ValueKey('genesis-image-viewer-opening-image'),
                    borderRadius: BorderRadius.lerp(
                      widget.source.borderRadius,
                      BorderRadius.zero,
                      progress,
                    )!,
                    child: RawImage(
                      image: widget.source.previewImage.image,
                      scale: widget.source.previewImage.scale,
                      fit: BoxFit.cover,
                      alignment: Alignment.lerp(
                        widget.source.alignment,
                        Alignment.center,
                        progress,
                      )!,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
