import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';

import '../../../ui/components/genesis_static_network_image.dart';
import '../../../utils/genesis_image_resource.dart';

const double miniPhonePostThumbnailHeight = 200;
const double miniPhonePostThumbnailMaxWidth = 290;

GenesisStaticNetworkImageProvider miniPhonePostThumbnailProvider(
  String url, {
  required double width,
  required double devicePixelRatio,
}) {
  final ratio = genesisImageDevicePixelRatio(devicePixelRatio);
  return GenesisStaticNetworkImageProvider(
    imageUrl: resizeGenesisImageUrlToHeight(
      url,
      logicalHeight: miniPhonePostThumbnailHeight,
      devicePixelRatio: ratio,
    ),
    cacheWidth: (width * ratio).ceil(),
    cacheHeight: (miniPhonePostThumbnailHeight * ratio).ceil(),
    fit: BoxFit.contain,
  );
}

class MiniPhonePostThumbnail extends StatelessWidget {
  const MiniPhonePostThumbnail({
    super.key,
    required this.imageUrl,
    required this.onTap,
  });

  final String imageUrl;
  final void Function(
    ImageProvider<Object> preview,
    GenesisImageViewerSource? source,
  )
  onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(
        constraints.maxWidth,
        miniPhonePostThumbnailMaxWidth,
      );
      final preview = miniPhonePostThumbnailProvider(
        imageUrl,
        width: width,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      final url = preview.imageUrl;
      return GenesisImageViewerSourceAnchor(
        previewImageProvider: preview,
        alignment: Alignment.centerLeft,
        onTap: (source) => onTap(preview, source),
        child: SizedBox(
          width: width,
          height: miniPhonePostThumbnailHeight,
          child: GenesisStaticNetworkImage(
            key: ValueKey(url),
            imageUrl: url,
            width: width,
            height: miniPhonePostThumbnailHeight,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            placeholder: (_) => const SizedBox.expand(),
            errorWidget: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
    },
  );
}
