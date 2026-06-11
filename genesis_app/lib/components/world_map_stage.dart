import 'package:flutter/material.dart';

import 'world_top_overlay_bar.dart';

class WorldMapStage extends StatelessWidget {
  const WorldMapStage({
    super.key,
    required this.controller,
    required this.pointsCount,
    required this.top,
    required this.mapBuilder,
    this.onBack,
    this.showTopOverlay = true,
  });

  final TabController controller;
  final int pointsCount;
  final double top;
  final Widget Function(BuildContext context, bool pointMode) mapBuilder;
  final VoidCallback? onBack;
  final bool showTopOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => mapBuilder(context, controller.index == 1),
          ),
        ),
        if (showTopOverlay)
          Positioned(
            left: 12,
            right: 12,
            top: top,
            child: WorldTopOverlayBar(
              pointsCount: pointsCount,
              controller: controller,
              onBack: onBack,
            ),
          ),
      ],
    );
  }
}
