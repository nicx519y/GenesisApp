import 'package:flutter/material.dart';

import '../../utils/genesis_image_resource.dart';

Future<void> showGenesisImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  final urls = imageUrls
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
  if (urls.isEmpty) return Future<void>.value();

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GenesisImageViewerOverlay(
        imageUrls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class GenesisImageViewerOverlay extends StatefulWidget {
  const GenesisImageViewerOverlay({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<GenesisImageViewerOverlay> createState() =>
      _GenesisImageViewerOverlayState();
}

class _GenesisImageViewerOverlayState extends State<GenesisImageViewerOverlay> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    if (index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 56, 0, 96),
              child: PageView.builder(
                key: const ValueKey('genesis-image-viewer-page-view'),
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return _ViewerImage(url: widget.imageUrls[index]);
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                key: const ValueKey('genesis-image-viewer-close'),
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: _ViewerThumbnailStrip(
                imageUrls: widget.imageUrls,
                currentIndex: _currentIndex,
                onTap: _jumpTo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerImage extends StatelessWidget {
  const _ViewerImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            ),
            child: _ImageByUrl(url: url, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

class _ViewerThumbnailStrip extends StatelessWidget {
  const _ViewerThumbnailStrip({
    required this.imageUrls,
    required this.currentIndex,
    required this.onTap,
  });

  final List<String> imageUrls;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        key: const ValueKey('genesis-image-viewer-thumbnails'),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          return SizedBox.square(
            dimension: 56,
            child: GestureDetector(
              key: ValueKey('genesis-image-viewer-thumbnail-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white38,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _ImageByUrl(url: imageUrls[index], fit: BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageByUrl extends StatelessWidget {
  const _ImageByUrl({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF202020),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 28, color: Colors.white54),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageUrl = selectGenesisImageUrl(
          url,
          logicalWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null,
          logicalHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null,
          devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
        );
        if (imageUrl.isEmpty) return fallback;
        if (imageUrl.startsWith('assets/')) {
          return Image.asset(
            imageUrl,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
        }
        return Image.network(
          imageUrl,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallback;
          },
        );
      },
    );
  }
}
