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
  late GenesisStaticNetworkImageProvider _provider;
  bool _didNotifyLoaded = false;

  @override
  void initState() {
    super.initState();
    _provider = _createProvider();
  }

  @override
  void didUpdateWidget(covariant GenesisStaticNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheManager != widget.cacheManager) {
      _provider = _createProvider();
      _didNotifyLoaded = false;
    }
  }

  GenesisStaticNetworkImageProvider _createProvider() {
    return GenesisStaticNetworkImageProvider(
      imageUrl: widget.imageUrl.trim(),
      cacheManager: widget.cacheManager,
    );
  }

  void _notifyLoaded() {
    if (_didNotifyLoaded) return;
    _didNotifyLoaded = true;
    widget.onImageLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _provider,
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
  }
}

@immutable
class GenesisStaticNetworkImageProvider
    extends ImageProvider<GenesisStaticNetworkImageProvider> {
  GenesisStaticNetworkImageProvider({
    required String imageUrl,
    BaseCacheManager? cacheManager,
  }) : imageUrl = imageUrl.trim(),
       cacheManager = cacheManager ?? DefaultCacheManager();

  final String imageUrl;
  final BaseCacheManager cacheManager;

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
    final codec = await decode(buffer);
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
        identical(other.cacheManager, cacheManager);
  }

  @override
  int get hashCode => Object.hash(imageUrl, identityHashCode(cacheManager));

  @override
  String toString() =>
      '${objectRuntimeType(this, 'GenesisStaticNetworkImageProvider')}'
      '("$imageUrl")';
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
