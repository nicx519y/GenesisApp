import 'package:flutter/material.dart';

import '../../ui/components/genesis_static_network_image.dart';
import '../../utils/genesis_image_resource.dart';

const miniPhonePhotoThumbnailWidthTiers = <int>[90, 180, 360, 720, 1080];

/// Grid display and viewer previews must share the same cache key.
GenesisStaticNetworkImageProvider miniPhonePhotoThumbnailProvider(
  String source, {
  required double width,
  required double height,
  required double devicePixelRatio,
  required BoxFit fit,
}) {
  final resource = GenesisImageResourceRegistry.resolve(source);
  final original = resource.xlUrl.trim();
  final candidate = original.isEmpty ? source.trim() : original;
  final ratio = genesisImageDevicePixelRatio(devicePixelRatio);
  final resized = resizeGenesisImageUrl(
    candidate,
    logicalWidth: width,
    devicePixelRatio: ratio,
    nearestWidthTiers: miniPhonePhotoThumbnailWidthTiers,
  );
  return GenesisStaticNetworkImageProvider(
    imageUrl: resized.isEmpty ? candidate : resized,
    cacheWidth: (width * ratio).ceil(),
    cacheHeight: (height * ratio).ceil(),
    fit: fit,
  );
}
