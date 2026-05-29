import 'package:flutter/material.dart';

class WorldDetailsPanel extends StatelessWidget {
  const WorldDetailsPanel({
    super.key,
    required this.slivers,
    this.exposedChildSize = 0.31,
    this.topGap = 0,
    this.collapsedHeightOffset = 15,
  });

  final double exposedChildSize;
  final List<Widget> slivers;
  final double topGap;
  final double collapsedHeightOffset;

  @override
  Widget build(BuildContext context) {
    return WorldDetailsShell(
      topGap: topGap,
      minChildSize: exposedChildSize,
      initialChildSize: exposedChildSize,
      collapsedHeightOffset: collapsedHeightOffset,
      contentBuilder: (scrollController) => WorldDetailsScrollContent(
        controller: scrollController,
        slivers: slivers,
      ),
    );
  }
}

class WorldDetailsShell extends StatelessWidget {
  const WorldDetailsShell({
    super.key,
    required this.contentBuilder,
    this.minChildSize = 0.25,
    this.initialChildSize = 0.25,
    this.topGap = 60,
    this.collapsedHeightOffset = 0,
  });

  final Widget Function(ScrollController) contentBuilder;
  final double minChildSize;
  final double initialChildSize;
  final double topGap;
  final double collapsedHeightOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChildSize =
            (constraints.maxHeight - topGap) / constraints.maxHeight;
        final minSize = _adjustedChildSize(minChildSize, constraints.maxHeight);
        final initialSize = _adjustedChildSize(
          initialChildSize,
          constraints.maxHeight,
        ).clamp(minSize, maxChildSize).toDouble();
        return DraggableScrollableSheet(
          minChildSize: minSize,
          initialChildSize: initialSize,
          maxChildSize: maxChildSize,
          snap: true,
          snapSizes: [minSize, maxChildSize],
          builder: (context, scrollController) {
            return Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Column(
                  children: [Expanded(child: contentBuilder(scrollController))],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _adjustedChildSize(double size, double height) {
    if (collapsedHeightOffset <= 0 || height <= 0) return size;
    final adjustedHeight = size * height - collapsedHeightOffset;
    return (adjustedHeight / height).clamp(0.0, 1.0).toDouble();
  }
}

class WorldDetailsScrollContent extends StatelessWidget {
  const WorldDetailsScrollContent({
    super.key,
    required this.controller,
    required this.slivers,
  });

  final ScrollController controller;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(controller: controller, slivers: slivers);
  }
}
