import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../tokens/genesis_avatar_radii.dart';
import 'genesis_avatar.dart';

class GenesisCharacterAvatar extends StatelessWidget {
  const GenesisCharacterAvatar({
    super.key,
    required this.url,
    required this.name,
    this.showStar = false,
    this.size = 48,
    this.borderRadius = GenesisAvatarRadii.character,
    this.starSize = 12,
    this.starColor = const Color(0xFFFF2442),
    this.boxShadow = const <BoxShadow>[],
    this.showFallbackWhileLoading = true,
    this.showFallbackWhenUnavailable = true,
    this.border,
  });

  final String url;
  final String name;
  final bool showStar;
  final double size;
  final double borderRadius;
  final double starSize;
  final Color starColor;
  final List<BoxShadow> boxShadow;
  final bool showFallbackWhileLoading;
  final bool showFallbackWhenUnavailable;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: boxShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: SizedBox(
                width: size,
                height: size,
                child: GenesisAvatar(
                  url: resolvedUrl,
                  name: name,
                  size: size,
                  borderRadius: borderRadius,
                  showFallbackWhileLoading: showFallbackWhileLoading,
                  showFallbackWhenUnavailable: showFallbackWhenUnavailable,
                ),
              ),
            ),
          ),
          if (border != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: border,
                  ),
                ),
              ),
            ),
          if (showStar)
            Positioned(
              top: -starSize / 4 - 2,
              right: -starSize / 4 - 3,
              child: Icon(
                MyFlutterApp.redstarCharIcon,
                size: starSize,
                color: starColor,
              ),
            ),
        ],
      ),
    );
  }
}
