import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class GenesisCharacterAvatar extends StatelessWidget {
  const GenesisCharacterAvatar({
    super.key,
    required this.url,
    required this.name,
    this.showStar = false,
    this.size = 48,
    this.borderRadius = 8,
    this.starSize = 12,
    this.starColor = const Color(0xFFFF1535),
    this.boxShadow = const <BoxShadow>[],
  });

  final String url;
  final String name;
  final bool showStar;
  final double size;
  final double borderRadius;
  final double starSize;
  final Color starColor;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: size / 3,
          height: 1,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8D8D8D),
        ),
      ),
    );

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
                child: _AvatarImage(url: resolvedUrl, fallback: fallback),
              ),
            ),
          ),
          if (showStar)
            Positioned(
              top: -starSize / 4,
              right: -starSize / 4,
              child: Icon(Icons.auto_awesome, size: starSize, color: starColor),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return fallback;
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return '?';
  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}
