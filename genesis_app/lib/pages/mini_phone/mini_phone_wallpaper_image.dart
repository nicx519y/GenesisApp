import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../ui/components/genesis_list_image.dart';

/// Keeps the current image source when saving only adds a disk-cache copy.
class MiniPhoneWallpaperImage extends StatefulWidget {
  const MiniPhoneWallpaperImage({
    super.key,
    required this.url,
    this.photo,
    this.cachedBytes,
  });

  final String url;
  final Uint8List? photo;
  final Uint8List? cachedBytes;

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
    return GenesisListImage(
      imageUrl: widget.url,
      borderRadius: BorderRadius.zero,
      placeholderAsset: 'assets/mini_phone/wallpaper-01.png',
    );
  }
}
