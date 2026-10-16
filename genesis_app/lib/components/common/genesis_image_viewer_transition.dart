import 'dart:math' as math;

import 'package:flutter/material.dart';

const genesisImageViewerOpenDuration = Duration(milliseconds: 320);

/// Captured in the root overlay's coordinates before pushing the viewer.
class GenesisImageViewerSource {
  const GenesisImageViewerSource({
    required this.rect,
    required this.previewImageProvider,
    required this.aspectRatio,
    this.borderRadius = BorderRadius.zero,
    this.onOpeningChanged,
  });

  final Rect rect;
  final ImageProvider<Object> previewImageProvider;
  final double aspectRatio;
  final BorderRadius borderRadius;
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
  final ValueChanged<GenesisImageViewerSource?> onTap;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius borderRadius;

  @override
  State<GenesisImageViewerSourceAnchor> createState() =>
      _GenesisImageViewerSourceAnchorState();
}

class _GenesisImageViewerSourceAnchorState
    extends State<GenesisImageViewerSourceAnchor> {
  bool _opening = false;

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

    // An already displayed frame resolves synchronously from ImageCache. Do not
    // await decoding/network before opening, or invent geometry for a blank tile.
    Size? imageSize;
    final stream = widget.previewImageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener((info, _) {
      imageSize = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
    }, onError: (_, _) {});
    stream.addListener(listener);
    stream.removeListener(listener);
    final size = imageSize;
    if (size == null || size.isEmpty || box.size.isEmpty) return null;
    final fitted = applyBoxFit(widget.fit, size, box.size);
    final localRect = widget.alignment.inscribe(
      fitted.destination,
      Offset.zero & box.size,
    );
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      localRect,
    );
    if (!rect.isFinite || rect.isEmpty) return null;
    return GenesisImageViewerSource(
      rect: rect,
      previewImageProvider: widget.previewImageProvider,
      aspectRatio: size.aspectRatio,
      borderRadius: widget.borderRadius,
      onOpeningChanged: _openingChanged,
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _opening ? null : () => widget.onTap(_capture()),
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
  });

  final Animation<double> animation;
  final GenesisImageViewerSource source;
  final Widget child;

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
            math.max(0, (constraints.maxHeight - height) / 2),
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
                    child: Image(
                      image: widget.source.previewImageProvider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.expand(),
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
