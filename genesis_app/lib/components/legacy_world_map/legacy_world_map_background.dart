import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/components/genesis_static_network_image.dart';
import '../../utils/genesis_image_resource.dart';

const String kWorldMapFallbackBackgroundAsset =
    'assets/images/map_default/root_default.webp';
const double legacyWorldMapAvatarImageLogicalSize = 36;
const double legacyWorldMapPreviewImageLogicalWidth = 120;

String legacyWorldMapImageUrl(
  String url, {
  required double logicalWidth,
  required double devicePixelRatio,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  return resizeGenesisImageUrl(
    trimmed,
    logicalWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
  ).trim();
}

String legacyWorldMapPreviewImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  return resizeGenesisImageUrl(
    trimmed,
    logicalWidth: legacyWorldMapPreviewImageLogicalWidth,
    devicePixelRatio: 1,
  ).trim();
}

String legacyWorldMapAvatarUrl(String url, {required double devicePixelRatio}) {
  return selectGenesisImageUrl(
    url,
    logicalWidth: legacyWorldMapAvatarImageLogicalSize,
    logicalHeight: legacyWorldMapAvatarImageLogicalSize,
    devicePixelRatio: devicePixelRatio,
  ).trim();
}

class LegacyWorldMapViewport {
  const LegacyWorldMapViewport({required this.width, required this.height});

  final double width;
  final double height;

  factory LegacyWorldMapViewport.cover({
    required double viewportWidth,
    required double viewportHeight,
    required double designWidth,
    required double designHeight,
  }) {
    final widthScale = viewportWidth / designWidth;
    final heightScale = viewportHeight / designHeight;
    final scale = math.max(widthScale, heightScale);
    final width = designWidth * scale;
    final height = designHeight * scale;

    return LegacyWorldMapViewport(width: width, height: height);
  }
}

class LegacyWorldMapBackgroundDeck extends StatefulWidget {
  const LegacyWorldMapBackgroundDeck({
    super.key,
    required this.currentUrl,
    required this.previewUrl,
    required this.preloadUrls,
    required this.preloadAvatarUrls,
    required this.fallbackOnEmptyUrl,
  });

  final String currentUrl;
  final String previewUrl;
  final List<String> preloadUrls;
  final List<String> preloadAvatarUrls;
  final bool fallbackOnEmptyUrl;

  @override
  State<LegacyWorldMapBackgroundDeck> createState() =>
      LegacyWorldMapBackgroundDeckState();
}

class LegacyWorldMapBackgroundDeckState
    extends State<LegacyWorldMapBackgroundDeck> {
  int _preloadGeneration = 0;
  String _loadedCurrentUrl = '';

  @override
  void didUpdateWidget(covariant LegacyWorldMapBackgroundDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUrl.trim() != widget.currentUrl.trim()) {
      _loadedCurrentUrl = '';
      _preloadGeneration++;
    }
  }

  void _handleCurrentLoaded() {
    final current = widget.currentUrl.trim();
    if (_loadedCurrentUrl == current) return;
    _loadedCurrentUrl = current;
    final generation = ++_preloadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _preloadGeneration) return;
      unawaited(_preloadSecondaryImages(current, generation));
    });
  }

  Future<void> _preloadSecondaryImages(String current, int generation) async {
    final avatarUrls = widget.preloadAvatarUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList(growable: false);
    for (final url in avatarUrls) {
      if (!mounted || generation != _preloadGeneration) return;
      try {
        await precacheImage(
          _avatarImageProvider(url),
          context,
          onError: (exception, stackTrace) {
            debugPrint(
              '[WorldMap] preload avatar failed url="$url": $exception',
            );
          },
        );
      } catch (error) {
        debugPrint('[WorldMap] preload avatar failed url="$url": $error');
      }
    }

    final urls = widget.preloadUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty && url != current)
        .toSet()
        .toList(growable: false);

    for (final url in urls) {
      if (!mounted || generation != _preloadGeneration) return;
      try {
        await precacheImage(
          _mapImageProvider(url),
          context,
          onError: (exception, stackTrace) {
            debugPrint(
              '[WorldMap] preload map image failed url="$url": $exception',
            );
          },
        );
      } catch (error) {
        debugPrint('[WorldMap] preload map image failed url="$url": $error');
      }
    }
  }

  ImageProvider _mapImageProvider(String url) {
    return url.startsWith('assets/')
        ? AssetImage(url)
        : GenesisStaticNetworkImageProvider(imageUrl: url);
  }

  ImageProvider _avatarImageProvider(String url) {
    return url.startsWith('assets/')
        ? AssetImage(url)
        : GenesisStaticNetworkImageProvider(imageUrl: url);
  }

  @override
  Widget build(BuildContext context) {
    return _MapBackground(
      url: widget.currentUrl.trim(),
      previewUrl: widget.previewUrl.trim(),
      fallbackOnEmptyUrl: widget.fallbackOnEmptyUrl,
      onLoaded: _handleCurrentLoaded,
    );
  }
}

class _MapBackground extends StatefulWidget {
  const _MapBackground({
    required this.url,
    this.previewUrl = '',
    this.fallbackOnEmptyUrl = true,
    this.onLoaded,
  });

  final String url;
  final String previewUrl;
  final bool fallbackOnEmptyUrl;
  final VoidCallback? onLoaded;

  @override
  State<_MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<_MapBackground> {
  bool _showFullImage = false;

  @override
  void initState() {
    super.initState();
    _scheduleFullImage();
  }

  @override
  void didUpdateWidget(covariant _MapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.previewUrl != widget.previewUrl) {
      _showFullImage = false;
      _scheduleFullImage();
    }
  }

  void _notifyLoaded() {
    final callback = widget.onLoaded;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  void _scheduleFullImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showFullImage) return;
      setState(() {
        _showFullImage = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = widget.url.trim();
    if (trimmedUrl.isEmpty) {
      _notifyLoaded();
      return widget.fallbackOnEmptyUrl
          ? const _FallbackMapBackground()
          : const _MapBackgroundPlaceholder();
    }

    if (trimmedUrl.startsWith('assets/')) {
      return Image.asset(
        trimmedUrl,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) _notifyLoaded();
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          _notifyLoaded();
          return const _FallbackMapBackground();
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _MapBackgroundPreview(
          url: widget.previewUrl,
          fallbackOnEmptyUrl: widget.fallbackOnEmptyUrl,
        ),
        if (_showFullImage)
          GenesisStaticNetworkImage(
            imageUrl: trimmedUrl,
            fit: BoxFit.cover,
            onImageLoaded: _notifyLoaded,
            placeholder: (_) => const SizedBox.shrink(),
            errorWidget: (context, error) {
              _notifyLoaded();
              return widget.fallbackOnEmptyUrl
                  ? const _FallbackMapBackground()
                  : const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}

class _MapBackgroundPreview extends StatelessWidget {
  const _MapBackgroundPreview({
    required this.url,
    required this.fallbackOnEmptyUrl,
  });

  final String url;
  final bool fallbackOnEmptyUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || trimmedUrl.startsWith('assets/')) {
      return fallbackOnEmptyUrl
          ? const _FallbackMapBackground()
          : const _MapBackgroundPlaceholder();
    }

    return GenesisStaticNetworkImage(
      imageUrl: trimmedUrl,
      fit: BoxFit.cover,
      placeholder: (_) => const _MapBackgroundPlaceholder(),
      errorWidget: (context, error) {
        return fallbackOnEmptyUrl
            ? const _FallbackMapBackground()
            : const _MapBackgroundPlaceholder();
      },
    );
  }
}

class _FallbackMapBackground extends StatelessWidget {
  const _FallbackMapBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kWorldMapFallbackBackgroundAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _MapBackgroundPlaceholder(),
    );
  }
}

class _MapBackgroundPlaceholder extends StatelessWidget {
  const _MapBackgroundPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFFF3F4F6));
  }
}
