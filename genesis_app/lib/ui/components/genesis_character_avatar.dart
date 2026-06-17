import 'package:flutter/material.dart';

import '../../icons/my_flutter_app_icons.dart';
import '../tokens/genesis_avatar_radii.dart';
import 'genesis_avatar.dart';

class GenesisCharacterAvatar extends StatefulWidget {
  const GenesisCharacterAvatar({
    super.key,
    required this.url,
    required this.name,
    this.showStar = false,
    this.size = 48,
    this.borderRadius = GenesisAvatarRadii.character,
    this.starSize = 12,
    this.starColor = const Color(0xFFF42C47),
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
  State<GenesisCharacterAvatar> createState() => _GenesisCharacterAvatarState();
}

class _GenesisCharacterAvatarState extends State<GenesisCharacterAvatar> {
  late bool _hasVisibleAvatar;

  bool get _shouldHideUntilImageReady {
    final resolvedUrl = widget.url.trim();
    if (!widget.showFallbackWhenUnavailable && resolvedUrl.isEmpty) {
      return true;
    }
    return !widget.showFallbackWhileLoading &&
        resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('assets/');
  }

  bool get _initialVisibleAvatar => !_shouldHideUntilImageReady;

  @override
  void initState() {
    super.initState();
    _hasVisibleAvatar = _initialVisibleAvatar;
  }

  @override
  void didUpdateWidget(covariant GenesisCharacterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.showFallbackWhileLoading != widget.showFallbackWhileLoading ||
        oldWidget.showFallbackWhenUnavailable !=
            widget.showFallbackWhenUnavailable) {
      _hasVisibleAvatar = _initialVisibleAvatar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = widget.url.trim();
    final showDecorations = _hasVisibleAvatar;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: showDecorations
                  ? widget.boxShadow
                  : const <BoxShadow>[],
              border: showDecorations ? widget.border : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: GenesisAvatar(
                  url: resolvedUrl,
                  name: widget.name,
                  size: widget.size,
                  borderRadius: widget.borderRadius,
                  showFallbackWhileLoading: widget.showFallbackWhileLoading,
                  showFallbackWhenUnavailable:
                      widget.showFallbackWhenUnavailable,
                  onVisibilityChanged: _handleAvatarVisibilityChanged,
                ),
              ),
            ),
          ),
          if (widget.showStar && showDecorations)
            Positioned(
              top: -widget.starSize / 4 - 2,
              right: -widget.starSize / 4 - 3,
              child: Icon(
                MyFlutterApp.redstarCharIcon,
                size: widget.starSize,
                color: widget.starColor,
              ),
            ),
        ],
      ),
    );
  }

  void _handleAvatarVisibilityChanged(bool isVisible) {
    if (!mounted || _hasVisibleAvatar == isVisible) return;
    setState(() {
      _hasVisibleAvatar = isVisible;
    });
  }
}
