import 'dart:typed_data';
import 'dart:ui' as ui;

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
  ui.Image? _image;
  Object? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GenesisStaticNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheManager != widget.cacheManager) {
      _disposeImage();
      _error = null;
      _load();
    }
  }

  @override
  void dispose() {
    _loadToken += 1;
    _disposeImage();
    super.dispose();
  }

  Future<void> _load() async {
    final url = widget.imageUrl.trim();
    final token = ++_loadToken;
    if (url.isEmpty) {
      setState(() {
        _error = StateError('Image URL is empty');
      });
      return;
    }

    try {
      final manager = widget.cacheManager ?? DefaultCacheManager();
      final file = await manager.getSingleFile(url);
      final bytes = await file.readAsBytes();
      final image = await _firstFrame(bytes);
      if (!mounted || token != _loadToken) {
        image.dispose();
        return;
      }
      _disposeImage();
      setState(() {
        _image = image;
        _error = null;
      });
      widget.onImageLoaded?.call();
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      _disposeImage();
      setState(() {
        _error = error;
      });
    }
  }

  Future<ui.Image> _firstFrame(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _disposeImage() {
    _image?.dispose();
    _image = null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image != null) {
      return RawImage(
        image: image,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
      );
    }

    final error = _error;
    if (error != null) {
      return widget.errorWidget?.call(context, error) ??
          SizedBox(width: widget.width, height: widget.height);
    }

    return widget.placeholder?.call(context) ??
        SizedBox(width: widget.width, height: widget.height);
  }
}
