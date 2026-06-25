import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens/genesis_image_radii.dart';
import '../../utils/genesis_image_resource.dart';

const String genesisDefaultListImageAsset =
    'assets/images/default_list_image.png';

class GenesisListImage extends StatelessWidget {
  const GenesisListImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = GenesisImageRadii.content,
    this.placeholderAsset = genesisDefaultListImageAsset,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry borderRadius;
  final String placeholderAsset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = _selectUrl(context, constraints);
        final image = resolved.isEmpty
            ? _placeholder()
            : resolved.startsWith('assets/')
            ? Image.asset(
                resolved,
                width: _finite(width),
                height: _finite(height),
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              )
            : CachedNetworkImage(
                imageUrl: resolved,
                width: _finite(width),
                height: _finite(height),
                fit: fit,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                placeholder: (context, url) => _placeholder(),
                errorWidget: (context, url, error) => _placeholder(),
              );

        return ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(width: width, height: height, child: image),
        );
      },
    );
  }

  String _selectUrl(BuildContext context, BoxConstraints constraints) {
    return selectGenesisImageUrl(
      imageUrl,
      logicalWidth: _finite(width) ?? _finite(constraints.maxWidth),
      logicalHeight: _finite(height) ?? _finite(constraints.maxHeight),
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
  }

  Widget _placeholder() {
    return Image.asset(
      placeholderAsset,
      width: _finite(width),
      height: _finite(height),
      fit: fit,
    );
  }
}

double? _finite(double? value) {
  if (value == null || !value.isFinite) return null;
  return value;
}
