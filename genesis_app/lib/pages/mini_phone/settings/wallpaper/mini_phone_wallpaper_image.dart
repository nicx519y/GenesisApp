import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../ui/components/genesis_list_image.dart';
import '../../../../ui/components/genesis_static_network_image.dart';
import '../../../../utils/genesis_image_resource.dart';

const double miniPhoneWallpaperPreviewWidth = 190;
const double miniPhoneWallpaperPreviewHeight =
    miniPhoneWallpaperPreviewWidth * 16 / 9;

/// Settings tiles and the larger preview share both download and decoded frames.
class MiniPhoneWallpaperPreview extends StatelessWidget {
  const MiniPhoneWallpaperPreview({
    super.key,
    required this.url,
    this.placeholder,
  });

  final String url;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final ratio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
    );
    final fallback =
        placeholder ??
        Image.asset('assets/mini_phone/wallpaper-01.webp', fit: BoxFit.cover);
    return Image(
      image: GenesisStaticNetworkImageProvider(
        imageUrl: resizeGenesisImageUrlToHeight(
          url,
          logicalHeight: miniPhoneWallpaperPreviewHeight,
          devicePixelRatio: ratio,
        ),
        cacheWidth: (miniPhoneWallpaperPreviewWidth * ratio).ceil(),
        cacheHeight: (miniPhoneWallpaperPreviewHeight * ratio).ceil(),
        fit: BoxFit.cover,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Keeps the current image source when saving only adds a disk-cache copy.
class MiniPhoneWallpaperImage extends StatefulWidget {
  const MiniPhoneWallpaperImage({
    super.key,
    required this.url,
    this.photo,
    this.cachedBytes,
    this.settingsPreview = false,
  });

  final String url;
  final Uint8List? photo;
  final Uint8List? cachedBytes;
  final bool settingsPreview;

  @override
  State<MiniPhoneWallpaperImage> createState() =>
      _MiniPhoneWallpaperImageState();
}

class _MiniPhoneWallpaperImageState extends State<MiniPhoneWallpaperImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.photo ?? widget.cachedBytes;
  }

  @override
  void didUpdateWidget(MiniPhoneWallpaperImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new selection changes the source; caching the same URL does not.
    // For an uploaded photo, the saved bytes are the exact preview bytes,
    // so Image retains its existing stream and decoded frame.
    if (widget.url != oldWidget.url || widget.photo != oldWidget.photo) {
      _bytes = widget.photo ?? widget.cachedBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }
    if (widget.settingsPreview &&
        widget.url.isNotEmpty &&
        !widget.url.startsWith('assets/')) {
      return MiniPhoneWallpaperPreview(url: widget.url);
    }
    return GenesisListImage(
      imageUrl: widget.url,
      borderRadius: BorderRadius.zero,
      placeholderAsset: 'assets/mini_phone/wallpaper-01.webp',
    );
  }
}
