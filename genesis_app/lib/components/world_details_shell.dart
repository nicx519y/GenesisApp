import 'package:flutter/material.dart';

class WorldDetailsPageScaffold extends StatelessWidget {
  const WorldDetailsPageScaffold({
    super.key,
    required this.map,
    required this.slivers,
    this.panelTopGap = defaultPanelTopGap,
    this.panelCollapsedHeightOffset = defaultPanelCollapsedHeightOffset,
    this.bottomBar,
  });

  static const double defaultPanelTopGap = 30;
  static const double defaultPanelCollapsedHeightOffset = 50;
  static const double contentHorizontalPadding = 12;
  static const double contentBottomPadding = 20;
  static const double contentBottomPaddingWithBottomBar = 126;

  final Widget map;
  final List<Widget> slivers;
  final double panelTopGap;
  final double panelCollapsedHeightOffset;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final bottomBar = this.bottomBar;
    return Scaffold(
      body: Stack(
        children: [
          map,
          WorldDetailsPanel(
            topGap: panelTopGap,
            collapsedHeightOffset: panelCollapsedHeightOffset,
            horizontalPadding: contentHorizontalPadding,
            bottomPadding: bottomBar == null
                ? contentBottomPadding
                : contentBottomPaddingWithBottomBar,
            slivers: slivers,
          ),
          if (bottomBar != null)
            Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
        ],
      ),
    );
  }
}

class WorldDetailsPanel extends StatelessWidget {
  const WorldDetailsPanel({
    super.key,
    required this.slivers,
    this.exposedChildSize = defaultExposedChildSize,
    this.topGap = 0,
    this.collapsedHeightOffset = 15,
    this.horizontalPadding = 16,
    this.bottomPadding = 0,
  });

  static const double defaultExposedChildSize = 0.31;
  static const double contentTopPadding = 20;

  final double exposedChildSize;
  final List<Widget> slivers;
  final double topGap;
  final double collapsedHeightOffset;
  final double horizontalPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = this.bottomPadding;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    return WorldDetailsShell(
      topGap: topGap,
      minChildSize: exposedChildSize,
      initialChildSize: exposedChildSize,
      collapsedHeightOffset: collapsedHeightOffset,
      contentPadding: EdgeInsets.only(
        top: contentTopPadding,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      contentBuilder: (scrollController) => WorldDetailsScrollContent(
        controller: scrollController,
        slivers: [
          ...slivers,
          if (bottomPadding > 0)
            SliverToBoxAdapter(
              child: SizedBox(height: bottomPadding + bottomSafeArea),
            ),
        ],
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
    this.contentPadding = const EdgeInsets.only(top: 8, left: 16, right: 16),
  });

  final Widget Function(ScrollController) contentBuilder;
  final double minChildSize;
  final double initialChildSize;
  final double topGap;
  final double collapsedHeightOffset;
  final EdgeInsetsGeometry contentPadding;

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
                padding: contentPadding,
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
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: CustomScrollView(controller: controller, slivers: slivers),
    );
  }
}
