import 'package:flutter/material.dart';

class WorldDetailsShell extends StatelessWidget {
  const WorldDetailsShell({
    super.key,
    required this.contentBuilder,
    this.minChildSize = 0.25,
    this.initialChildSize = 0.25,
    this.topGap = 60,
  });

  final Widget Function(ScrollController) contentBuilder;
  final double minChildSize;
  final double initialChildSize;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChildSize =
            (constraints.maxHeight - topGap) / constraints.maxHeight;
        return DraggableScrollableSheet(
          minChildSize: minChildSize,
          initialChildSize: initialChildSize,
          maxChildSize: maxChildSize,
          snap: true,
          snapSizes: [minChildSize, maxChildSize],
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
}
