import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class GenesisStaticNetworkImage extends StatefulWidget {
  const GenesisStaticNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.onImageLoaded,
    this.cacheManager,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final WidgetBuilder? placeholder;
  final Widget Function(BuildContext context, Object error)? errorWidget;
  final VoidCallback? onImageLoaded;
  final BaseCacheManager? cacheManager;

  @override
  State<GenesisStaticNetworkImage> createState() =>
      _GenesisStaticNetworkImageState();
}

class _GenesisStaticNetworkImageState extends State<GenesisStaticNetworkImage> {
  bool _didNotifyLoaded = false;

  @override
  void didUpdateWidget(covariant GenesisStaticNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheManager != widget.cacheManager ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height ||
        oldWidget.fit != widget.fit) {
      _didNotifyLoaded = false;
    }
  }

  void _notifyLoaded() {
    if (_didNotifyLoaded) return;
    _didNotifyLoaded = true;
    widget.onImageLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio =
            MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
        final logicalWidth = _resolveLogicalDimension(
          widget.width,
          constraints.maxWidth,
        );
        final logicalHeight = _resolveLogicalDimension(
          widget.height,
          constraints.maxHeight,
        );
        final provider = GenesisStaticNetworkImageProvider(
          imageUrl: widget.imageUrl.trim(),
          cacheManager: widget.cacheManager,
          cacheWidth: _decodePixelDimension(logicalWidth, devicePixelRatio),
          cacheHeight: _decodePixelDimension(logicalHeight, devicePixelRatio),
          fit: widget.fit,
        );
        return Image(
          image: provider,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              _notifyLoaded();
              return child;
            }
            return widget.placeholder?.call(context) ??
                SizedBox(width: widget.width, height: widget.height);
          },
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget?.call(context, error) ??
                SizedBox(width: widget.width, height: widget.height);
          },
        );
      },
    );
  }
}

@immutable
class GenesisStaticNetworkImageProvider
    extends ImageProvider<GenesisStaticNetworkImageProvider> {
  GenesisStaticNetworkImageProvider({
    required String imageUrl,
    BaseCacheManager? cacheManager,
    this.cacheWidth,
    this.cacheHeight,
    this.fit,
  }) : imageUrl = imageUrl.trim(),
       cacheManager = cacheManager ?? DefaultCacheManager();

  final String imageUrl;
  final BaseCacheManager cacheManager;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit? fit;

  @override
  Future<GenesisStaticNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<GenesisStaticNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    GenesisStaticNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return _GenesisOneFrameImageStreamCompleter(
      _loadFirstFrame(key, decode),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('Image URL', key.imageUrl),
      ],
    );
  }

  Future<ImageInfo> _loadFirstFrame(
    GenesisStaticNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    if (key.imageUrl.isEmpty) {
      throw StateError('Image URL is empty');
    }
    final file = await key.cacheManager.getSingleFile(key.imageUrl);
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final hasTargetSize = key.cacheWidth != null || key.cacheHeight != null;
    final codec = await decode(
      buffer,
      getTargetSize: hasTargetSize
          ? (intrinsicWidth, intrinsicHeight) =>
                key._targetImageSize(intrinsicWidth, intrinsicHeight)
          : null,
    );
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image, scale: 1);
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is GenesisStaticNetworkImageProvider &&
        other.imageUrl == imageUrl &&
        identical(other.cacheManager, cacheManager) &&
        other.cacheWidth == cacheWidth &&
        other.cacheHeight == cacheHeight &&
        other.fit == fit;
  }

  @override
  int get hashCode => Object.hash(
    imageUrl,
    identityHashCode(cacheManager),
    cacheWidth,
    cacheHeight,
    fit,
  );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'GenesisStaticNetworkImageProvider')}'
      '("$imageUrl", cacheWidth: $cacheWidth, cacheHeight: $cacheHeight)';

  ui.TargetImageSize _targetImageSize(int intrinsicWidth, int intrinsicHeight) {
    if (fit == BoxFit.none) {
      return ui.TargetImageSize(width: intrinsicWidth, height: intrinsicHeight);
    }

    final inputSize = Size(
      intrinsicWidth.toDouble(),
      intrinsicHeight.toDouble(),
    );
    final fitted = applyBoxFit(
      fit ?? BoxFit.scaleDown,
      inputSize,
      Size(
        (cacheWidth ?? intrinsicWidth).toDouble(),
        (cacheHeight ?? intrinsicHeight).toDouble(),
      ),
    );
    final source = fitted.source;
    final destination = fitted.destination;
    final targetWidth = source.width <= 0
        ? intrinsicWidth
        : (intrinsicWidth * destination.width / source.width).ceil();
    final targetHeight = source.height <= 0
        ? intrinsicHeight
        : (intrinsicHeight * destination.height / source.height).ceil();
    return ui.TargetImageSize(
      width: math.max(1, math.min(targetWidth, intrinsicWidth)),
      height: math.max(1, math.min(targetHeight, intrinsicHeight)),
    );
  }
}

double? _resolveLogicalDimension(double? explicit, double constrained) {
  if (explicit != null && explicit.isFinite && explicit > 0) return explicit;
  if (constrained.isFinite && constrained > 0) return constrained;
  return null;
}

int? _decodePixelDimension(double? logical, double devicePixelRatio) {
  if (logical == null) return null;
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return math.max(1, (logical * ratio).ceil());
}

class _GenesisOneFrameImageStreamCompleter extends ImageStreamCompleter {
  _GenesisOneFrameImageStreamCompleter(
    Future<ImageInfo> image, {
    InformationCollector? informationCollector,
  }) {
    final keepAliveHandle = keepAlive();
    image
        .then<void>(
          setImage,
          onError: (Object error, StackTrace stack) {
            reportError(
              context: ErrorDescription(
                'resolving a Genesis static network image stream',
              ),
              exception: error,
              stack: stack,
              informationCollector: informationCollector,
              silent: true,
            );
          },
        )
        .whenComplete(keepAliveHandle.dispose);
  }
}
