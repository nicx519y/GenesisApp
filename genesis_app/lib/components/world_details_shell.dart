import 'package:flutter/material.dart';

import 'world_map_interaction_notification.dart';

class WorldDetailsPageScaffold extends StatefulWidget {
  const WorldDetailsPageScaffold({
    super.key,
    required this.map,
    required this.slivers,
    this.panelTopGap = defaultPanelTopGap,
    this.panelCollapsedHeightOffset = defaultPanelCollapsedHeightOffset,
    this.bottomBar,
    this.topOverlay,
    this.persistentTopOverlay,
  });

  static const double defaultPanelTopGap = 30;
  static const double defaultPanelCollapsedHeightOffset = 50;
  static const double contentHorizontalPadding = 12;
  static const double inlineContentTopPadding = 14;
  static const double contentBottomPadding = 20;
  static const double contentBottomPaddingWithBottomBar = 126;

  final Widget map;
  final List<Widget> slivers;
  final double panelTopGap;
  final double panelCollapsedHeightOffset;
  final Widget? bottomBar;
  final Widget? topOverlay;
  final Widget? persistentTopOverlay;

  @override
  State<WorldDetailsPageScaffold> createState() =>
      _WorldDetailsPageScaffoldState();
}

class _WorldDetailsPageScaffoldState extends State<WorldDetailsPageScaffold> {
  late final ScrollController _scrollController = ScrollController();
  bool _mapInteractionActive = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomBar = widget.bottomBar;
    final topOverlay = widget.topOverlay;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight;
          final mapHeight =
              (viewportHeight *
                          (1 - WorldDetailsPanel.defaultExposedChildSize) +
                      widget.panelCollapsedHeightOffset)
                  .clamp(
                    0.0,
                    (viewportHeight - widget.panelTopGap).clamp(
                      0.0,
                      viewportHeight,
                    ),
                  )
                  .toDouble();
          final bottomPadding = bottomBar == null
              ? WorldDetailsPageScaffold.contentBottomPadding
              : WorldDetailsPageScaffold.contentBottomPaddingWithBottomBar;
          final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

          return Stack(
            children: [
              NotificationListener<WorldMapInteractionNotification>(
                onNotification: (notification) {
                  if (_mapInteractionActive != notification.active) {
                    setState(() => _mapInteractionActive = notification.active);
                  }
                  return false;
                },
                child: WorldDetailsPanelScrollControllerScope(
                  controller: _scrollController,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: _mapInteractionActive
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: mapHeight, child: widget.map),
                      ),
                      SliverToBoxAdapter(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                          child: const SizedBox(
                            height: WorldDetailsPageScaffold
                                .inlineContentTopPadding,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              WorldDetailsPageScaffold.contentHorizontalPadding,
                        ),
                        sliver: SliverMainAxisGroup(slivers: widget.slivers),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: bottomPadding + bottomSafeArea),
                      ),
                    ],
                  ),
                ),
              ),
              if (bottomBar != null)
                Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
              if (widget.persistentTopOverlay != null)
                widget.persistentTopOverlay!,
              if (topOverlay != null) topOverlay,
            ],
          );
        },
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

class WorldDetailsPanelScrollControllerScope extends InheritedWidget {
  const WorldDetailsPanelScrollControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ScrollController controller;

  static ScrollController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<
          WorldDetailsPanelScrollControllerScope
        >()
        ?.controller;
  }

  @override
  bool updateShouldNotify(WorldDetailsPanelScrollControllerScope oldWidget) {
    return oldWidget.controller != controller;
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

  static const double dragHandleTitleGap = 10;
  static const double dragHandleWidth = 55;
  static const double dragHandleHeight = 4;

  final Widget Function(ScrollController) contentBuilder;
  final double minChildSize;
  final double initialChildSize;
  final double topGap;
  final double collapsedHeightOffset;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = contentPadding.resolve(Directionality.of(context));
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
                padding: EdgeInsets.fromLTRB(
                  resolvedPadding.left,
                  0,
                  resolvedPadding.right,
                  resolvedPadding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: resolvedPadding.top,
                      child: const Center(child: WorldDetailsDragHandle()),
                    ),
                    const SizedBox(
                      height: WorldDetailsShell.dragHandleTitleGap,
                    ),
                    Expanded(
                      child: WorldDetailsPanelScrollControllerScope(
                        controller: scrollController,
                        child: contentBuilder(scrollController),
                      ),
                    ),
                  ],
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

class WorldDetailsDragHandle extends StatelessWidget {
  const WorldDetailsDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: WorldDetailsShell.dragHandleWidth,
      height: WorldDetailsShell.dragHandleHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        borderRadius: BorderRadius.all(
          Radius.circular(WorldDetailsShell.dragHandleHeight / 2),
        ),
      ),
    );
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
