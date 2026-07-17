import 'package:flutter/material.dart';

import 'genesis_static_network_image.dart';
import '../text/genesis_text_input_formatters.dart';
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
    this.showFallbackWhileLoading = false,
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
    final safeName = genesisDisplaySafeText(name);
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
      name: safeName,
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
        : GenesisStaticNetworkImage(
            key: imageKey,
            imageUrl: resolvedUrl,
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            alignment: alignment,
            onImageLoaded: () {
              _notifyAvatarVisibility(onVisibilityChanged, true);
            },
            placeholder: (context) {
              _notifyAvatarVisibility(
                onVisibilityChanged,
                showFallbackWhileLoading,
              );
              return showFallbackWhileLoading ? fallback : hiddenPlaceholder;
            },
            errorWidget: (context, error) {
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
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

String initialsForAvatarName(String name) {
  final cleaned = genesisDisplaySafeText(
    name,
  ).trim().replaceAll(RegExp(r'\s+'), ' ');
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
  final safeName = genesisDisplaySafeText(name);
  final seed = safeName.trim().isEmpty ? '?' : safeName.trim();
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
