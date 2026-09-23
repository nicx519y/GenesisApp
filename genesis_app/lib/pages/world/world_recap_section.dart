import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/tokens/genesis_colors.dart';
import 'world_constants.dart';
import 'world_recap_cache.dart';
import 'world_sections.dart';

class WorldRecapSection extends StatefulWidget {
  const WorldRecapSection({
    super.key,
    required this.cache,
    required this.load,
    required this.scrollController,
    required this.active,
  });

  final WorldRecapCache cache;
  final WorldRecapLoader load;
  final ScrollController scrollController;
  final bool active;

  @override
  State<WorldRecapSection> createState() => _WorldRecapSectionState();
}

class _WorldRecapSectionState extends State<WorldRecapSection> {
  bool _loadCheckScheduled = false;

  void _scheduleLoadCheck() {
    if (_loadCheckScheduled || !widget.active) return;
    _loadCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCheckScheduled = false;
      if (!mounted || !widget.active) return;
      final controller = widget.scrollController;
      if (controller.positions.length != 1) return;
      final position = controller.position;
      if (position.hasContentDimensions && position.extentAfter < 240) {
        unawaited(widget.cache.loadMore(widget.load));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cache,
      builder: (context, _) {
        final cache = widget.cache;
        final seenTicks = <int>{};
        final showHeading = [
          for (final item in cache.items)
            item.tickNo > 0 && seenTicks.add(item.tickNo),
        ];
        _scheduleLoadCheck();
        return NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _scheduleLoadCheck();
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _scheduleLoadCheck();
              return false;
            },
            child: ListView.builder(
              key: const PageStorageKey<String>('world-recap-list'),
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(
                12,
                worldSheetVisibleContentTopGap,
                12,
                32,
              ),
              itemCount: cache.items.length + 1,
              itemBuilder: (context, index) {
                if (index == cache.items.length) return _buildFooter(cache);
                final item = cache.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeading[index]) ...[
                        Text(
                          'Tick ${item.tickNo}',
                          style: const TextStyle(
                            color: GenesisColors.darkTextSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: GenesisColors.darkTextPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(WorldRecapCache cache) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cache.hasLoaded && cache.items.isEmpty)
          const WorldEmptySection(text: 'No recap yet.'),
        if (!cache.hasLoaded ||
            cache.loadingMore ||
            cache.loadMoreError != null)
          const _RecapSkeleton(),
        if (cache.refreshError != null)
          TextButton(
            onPressed: () =>
                unawaited(cache.refresh(cache.worldId, widget.load)),
            child: const Text('Retry'),
          )
        else if (cache.loadMoreError != null)
          TextButton(
            onPressed: () =>
                unawaited(cache.loadMore(widget.load, retry: true)),
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class _RecapSkeleton extends StatelessWidget {
  const _RecapSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey<String>('world-recap-skeleton'),
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorldTickPendingSkeletonLine(widthFactor: .24, height: 10),
          SizedBox(height: 16),
          WorldTickPendingSkeletonLine(widthFactor: .96),
          SizedBox(height: 10),
          WorldTickPendingSkeletonLine(widthFactor: .88),
          SizedBox(height: 10),
          WorldTickPendingSkeletonLine(widthFactor: .64),
        ],
      ),
    );
  }
}
