import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens/genesis_avatar_radii.dart';
import '../../utils/genesis_image_resource.dart';

class GenesisAvatar extends StatelessWidget {
  const GenesisAvatar({
    super.key,
    required this.name,
    this.url = '',
    this.size = 48,
    this.width,
    this.height,
    this.borderRadius = GenesisAvatarRadii.user,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.imageKey,
    this.textStyle,
    this.showFallbackWhileLoading = true,
    this.showFallbackWhenUnavailable = true,
    this.onVisibilityChanged,
  });

  final String name;
  final String url;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final Alignment alignment;
  final Key? imageKey;
  final TextStyle? textStyle;
  final bool showFallbackWhileLoading;
  final bool showFallbackWhenUnavailable;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    final imageWidth = resolvedWidth.isFinite ? resolvedWidth : null;
    final imageHeight = resolvedHeight.isFinite ? resolvedHeight : null;
    final resolvedUrl = selectGenesisImageUrl(
      url,
      logicalWidth: imageWidth,
      logicalHeight: imageHeight,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
    final fallback = GenesisAvatarFallback(
      name: name,
      width: resolvedWidth,
      height: resolvedHeight,
      borderRadius: borderRadius,
      textStyle: textStyle,
    );
    final hiddenPlaceholder = SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
    );

    if (resolvedUrl.isEmpty) {
      _notifyAvatarVisibility(onVisibilityChanged, showFallbackWhenUnavailable);
      return showFallbackWhenUnavailable ? fallback : hiddenPlaceholder;
    }

    final image = resolvedUrl.startsWith('assets/')
        ? Image.asset(
            resolvedUrl,
            key: imageKey,
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            alignment: alignment,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                _notifyAvatarVisibility(onVisibilityChanged, true);
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _notifyAvatarVisibility(
                onVisibilityChanged,
                showFallbackWhenUnavailable,
              );
              return showFallbackWhenUnavailable ? fallback : hiddenPlaceholder;
            },
          )
        : CachedNetworkImage(
            key: imageKey,
            imageUrl: resolvedUrl,
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            alignment: alignment,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            imageBuilder: (context, imageProvider) {
              _notifyAvatarVisibility(onVisibilityChanged, true);
              return Image(
                image: imageProvider,
                width: imageWidth,
                height: imageHeight,
                fit: fit,
                alignment: alignment,
              );
            },
            placeholder: (context, url) {
              _notifyAvatarVisibility(
                onVisibilityChanged,
                showFallbackWhileLoading,
              );
              return showFallbackWhileLoading ? fallback : hiddenPlaceholder;
            },
            errorWidget: (context, url, error) {
              _notifyAvatarVisibility(
                onVisibilityChanged,
                showFallbackWhenUnavailable,
              );
              return showFallbackWhenUnavailable ? fallback : hiddenPlaceholder;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: image,
      ),
    );
  }
}

void _notifyAvatarVisibility(ValueChanged<bool>? callback, bool isVisible) {
  if (callback == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    callback(isVisible);
  });
}

class GenesisAvatarFallback extends StatelessWidget {
  const GenesisAvatarFallback({
    super.key,
    required this.name,
    this.size = 48,
    this.width,
    this.height,
    this.borderRadius = GenesisAvatarRadii.user,
    this.textStyle,
  });

  final String name;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    final label = initialsForAvatarName(name);
    final fontBase = resolvedHeight.isFinite ? resolvedHeight : size;
    final fontSize = (fontBase * 0.34).clamp(11.0, 28.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: resolvedWidth,
        height: resolvedHeight,
        color: avatarColorForName(name),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style:
              textStyle ??
              TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

String initialsForAvatarName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return '?';

  final cjkChars = cleaned.characters
      .where((char) => _isCjkCodePoint(char.runes.first))
      .toList(growable: false);
  if (cjkChars.isNotEmpty) {
    if (cjkChars.length <= 2) return cjkChars.first;
    return cjkChars.skip(cjkChars.length - 2).join();
  }

  final words = cleaned
      .split(RegExp(r"[\s._\-]+"))
      .where((word) => word.trim().isNotEmpty)
      .toList(growable: false);
  if (words.isNotEmpty) {
    return words
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
  }

  return cleaned.characters.first.toUpperCase();
}

Color avatarColorForName(String name) {
  final seed = name.trim().isEmpty ? '?' : name.trim();
  final hash = seed.runes.fold<int>(
    0,
    (value, rune) => ((value * 131) + rune) & 0x7fffffff,
  );
  final hue = (hash % 360).toDouble();
  final saturation = 0.52 + ((hash >> 4) % 18) / 100;
  final lightness = 0.42 + ((hash >> 9) % 10) / 100;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}

bool _isCjkCodePoint(int codePoint) {
  return (codePoint >= 0x4E00 && codePoint <= 0x9FFF) ||
      (codePoint >= 0x3400 && codePoint <= 0x4DBF) ||
      (codePoint >= 0xF900 && codePoint <= 0xFAFF);
}
