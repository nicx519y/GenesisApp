// ignore_for_file: use_key_in_widget_constructors

part of 'world_sections_library.dart';

List<Map<String, dynamic>> worldEventTicksAscending(
  List<Map<String, dynamic>> ticks,
) {
  final indexedTicks = ticks.indexed.toList(growable: false);
  indexedTicks.sort((a, b) {
    final tickCompare = worldEventTickNumber(
      a.$2,
    ).compareTo(worldEventTickNumber(b.$2));
    if (tickCompare != 0) return tickCompare;
    final subTickCompare = worldEventSubTickNumber(
      a.$2,
    ).compareTo(worldEventSubTickNumber(b.$2));
    if (subTickCompare != 0) return subTickCompare;
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexedTicks) entry.$2];
}

List<Map<String, dynamic>> worldMergeEventTicksAscending(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  final keyedTicks = <String, Map<String, dynamic>>{};
  final unkeyedTicks = <Map<String, dynamic>>[];
  for (final tick in [...existing, ...incoming]) {
    final key = worldEventTickIdentity(tick);
    if (key.isEmpty) {
      unkeyedTicks.add(tick);
      continue;
    }
    keyedTicks[key] = tick;
  }
  return worldEventTicksAscending([...keyedTicks.values, ...unkeyedTicks]);
}

String worldEventTickIdentity(Map<String, dynamic> tick) {
  final subTickNo = worldEventSubTickNumber(tick);
  final tickId = worldMapString(tick, const ['tick_id', 'id']);
  if (tickId.isNotEmpty) return 'id:$tickId:sub:$subTickNo';
  final tickNo = worldEventTickNumber(tick);
  if (tickNo > 0) return 'no:$tickNo:sub:$subTickNo';
  return '';
}

int worldEventTickNumber(Map<String, dynamic> tick) {
  final tickNo = worldMapString(tick, const ['tick_no', 'tick_number', 'no']);
  final parsed = int.tryParse(tickNo);
  if (parsed != null) return parsed;

  final id = worldMapString(tick, const ['tick_id', 'id']);
  final suffix = RegExp(r'(\d+)$').firstMatch(id)?.group(1);
  return int.tryParse(suffix ?? '') ?? 0;
}

int worldEventSubTickNumber(Map<String, dynamic> tick) {
  final subTickNo = worldMapString(tick, const [
    'sub_tick_no',
    'sub_tick_number',
  ]);
  return int.tryParse(subTickNo) ?? 0;
}

List<List<Map<String, dynamic>>> worldEventTickPagesAscending(
  List<Map<String, dynamic>> ticks,
) {
  final pages = <List<Map<String, dynamic>>>[];
  for (final tick in worldEventTicksAscending(ticks)) {
    final tickNo = worldEventTickNumber(tick);
    if (pages.isNotEmpty && worldEventTickNumber(pages.last.first) == tickNo) {
      pages.last.add(tick);
    } else {
      pages.add(<Map<String, dynamic>>[tick]);
    }
  }
  return pages;
}

String worldEventTickPageIdentity(List<Map<String, dynamic>> ticks) {
  if (ticks.isEmpty) return '';
  final tickNo = worldEventTickNumber(ticks.first);
  return 'tick:$tickNo';
}

class WorldEventsSection extends StatefulWidget {
  const WorldEventsSection({
    super.key,
    required this.world,
    required this.ticks,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.latestRevision,
    required this.targetTickNumber,
    required this.contentPadding,
    required this.onLoadMore,
    this.scrollController,
  });

  final WorldDetail world;
  final List<Map<String, dynamic>> ticks;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final int latestRevision;
  final int? targetTickNumber;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback onLoadMore;
  final ScrollController? scrollController;

  @override
  State<WorldEventsSection> createState() => WorldEventsSectionState();
}

class WorldEventsSectionState extends State<WorldEventsSection> {
  static const double _loadMoreExtentThreshold = 240;
  static const double _scrollToTopVisibilityThreshold = 320;
  static const Duration _scrollToTopDuration = Duration(milliseconds: 300);

  final ScrollController _fallbackScrollController = ScrollController();
  final Map<int, GlobalKey> _tickAnchors = <int, GlobalKey>{};
  var _loadMoreRequested = false;
  var _showScrollToTop = false;

  int? get _requestedTickNumber {
    final target = widget.targetTickNumber;
    return target == null || target <= 0 ? null : target;
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollToTargetOrLatest();
    _maybeLoadPendingTarget();
  }

  @override
  void didUpdateWidget(covariant WorldEventsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final worldChanged = oldWidget.world.worldId != widget.world.worldId;
    if (worldChanged) {
      _tickAnchors.clear();
      _loadMoreRequested = false;
      _showScrollToTop = false;
      _scheduleScrollToTargetOrLatest();
      _maybeLoadPendingTarget();
      return;
    }

    final ticksChanged = oldWidget.ticks.length != widget.ticks.length;
    final loadingCycleFinished = oldWidget.loadingMore && !widget.loadingMore;
    if (ticksChanged || loadingCycleFinished) {
      _loadMoreRequested = false;
    }

    if (oldWidget.latestRevision != widget.latestRevision ||
        oldWidget.targetTickNumber != widget.targetTickNumber ||
        (ticksChanged && _requestedTickNumber != null)) {
      _scheduleScrollToTargetOrLatest();
    }
    _maybeLoadPendingTarget();
  }

  @override
  void dispose() {
    _fallbackScrollController.dispose();
    super.dispose();
  }

  bool get _hasPendingTarget {
    final target = _requestedTickNumber;
    if (target == null || _containsTickNumber(target)) return false;
    if (!widget.initialLoading && !widget.loadingMore && !widget.hasMore) {
      return false;
    }
    return true;
  }

  ScrollController get _scrollController =>
      widget.scrollController ?? _fallbackScrollController;

  bool _containsTickNumber(int tickNumber) {
    return widget.ticks.any((tick) => worldEventTickNumber(tick) == tickNumber);
  }

  void _scheduleScrollToTargetOrLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _requestedTickNumber;
      if (target != null && _containsTickNumber(target)) {
        final targetContext = _tickAnchors[target]?.currentContext;
        if (targetContext != null) {
          unawaited(
            Scrollable.ensureVisible(
              targetContext,
              alignment: 0,
              duration: Duration.zero,
            ),
          );
          return;
        }
      }
      if (!_scrollController.hasClients) {
        _scheduleScrollToTargetOrLatest();
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final showScrollToTop =
        notification.metrics.pixels > _scrollToTopVisibilityThreshold;
    if (showScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = showScrollToTop);
    }
    final towardOlderEvents =
        notification is UserScrollNotification &&
            notification.direction == ScrollDirection.reverse ||
        notification is ScrollUpdateNotification &&
            (notification.scrollDelta ?? 0) > 0 ||
        notification is OverscrollNotification && notification.overscroll > 0;
    if (towardOlderEvents &&
        notification.metrics.extentAfter <= _loadMoreExtentThreshold) {
      _requestLoadMore();
    }
    return false;
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        0,
        duration: _scrollToTopDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _maybeLoadPendingTarget() {
    if (_requestedTickNumber == null ||
        !_hasPendingTarget ||
        !widget.hasMore ||
        widget.loadingMore ||
        widget.initialLoading) {
      return;
    }
    _requestLoadMore();
  }

  void _requestLoadMore() {
    if (_loadMoreRequested ||
        !widget.hasMore ||
        widget.loadingMore ||
        widget.initialLoading) {
      return;
    }
    _loadMoreRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.hasMore || widget.loadingMore || widget.initialLoading) {
        _loadMoreRequested = false;
        return;
      }
      widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingTarget = _hasPendingTarget;
    if (widget.ticks.isEmpty && widget.initialLoading && !hasPendingTarget) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: widget.contentPadding,
              child: const WorldEventLoadingSkeleton(),
            ),
          ),
        ],
      );
    }
    if (widget.ticks.isEmpty && !hasPendingTarget) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: widget.contentPadding,
              child: WorldEmptySection(
                text: widget.error == null
                    ? 'No events yet.'
                    : 'Load events failed.',
              ),
            ),
          ),
        ],
      );
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in widget.world.locations)
        worldMapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final charactersById = <String, Map<String, dynamic>>{
      for (final character in widget.world.characters)
        worldMapString(character, const ['char_id', 'character_id', 'id']):
            character,
    }..remove('');
    final fallbackBody = worldEventBody(widget.world);
    final metricUnit = worldMapString(widget.world.metric, const ['unit']);
    final entries = _buildListEntries();

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: CustomScrollView(
              key: const ValueKey<String>('world-events-tick-list'),
              controller: _scrollController,
              // 数据保持最新在前、翻转渲染:视觉上最旧在顶、最新在底(正序),
              // offset 0 仍是"最新",滚动/加载更早页的逻辑不变。
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: widget.contentPadding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = entries[index];
                      if (entry.pendingTickNumber != null) {
                        return KeyedSubtree(
                          key: ValueKey<String>(
                            'world-event-tick-pending-${entry.pendingTickNumber}',
                          ),
                          child: WorldTickPendingEventPage(
                            tickNumber: entry.pendingTickNumber!,
                          ),
                        );
                      }
                      if (entry.showsAiDisclaimer) {
                        return const AiContentDisclaimer(
                          // 与 tick 卡片同宽:不再额外内缩左右 10。
                          padding: EdgeInsets.fromLTRB(0, 0, 0, 18),
                          textAlign: TextAlign.left,
                        );
                      }

                      final tick = entry.tick!;
                      final tickNumber = worldTickEventNumber(tick);
                      final item = WorldTickEventItem(
                        key: ValueKey<String>(
                          'world-event-tick-item-${worldEventTickIdentity(tick)}',
                        ),
                        tick: tick,
                        tickNumber: tickNumber,
                        subTickNumber: worldEventSubTickNumber(tick),
                        fallbackBody: fallbackBody,
                        locationsById: locationsById,
                        charactersById: charactersById,
                        dateLabel: worldTickParagraphTimestamp(tick),
                        stackedContent: true,
                        contentLabelStyle: _worldEventContentLabelStyle(
                          context,
                        ),
                        contentTextStyle: _worldEventContentTextStyle(context),
                        contentTimestampStyle: _worldEventContentTimestampStyle(
                          context,
                        ),
                        metricUnit: metricUnit,
                        showParagraphClue: true,
                        timelineStyle: true,
                        isLast: entry.isLastInTick,
                      );
                      if (!entry.isFirstInTick) return item;
                      final anchor = _tickAnchors.putIfAbsent(
                        tickNumber,
                        GlobalKey.new,
                      );
                      return KeyedSubtree(key: anchor, child: item);
                    }, childCount: entries.length),
                  ),
                ),
                if (widget.loadingMore)
                  const SliverToBoxAdapter(
                    child: WorldEventsLoadingMoreIndicator(),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: _showScrollToTop ? 1 : 0.86,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: Semantics(
                  button: true,
                  label: 'Back to latest',
                  child: Material(
                    key: const ValueKey<String>('world-events-scroll-to-top'),
                    color: context.genesisColors.controlMuted,
                    elevation: 2,
                    shadowColor: context.genesisColors.shadow,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _scrollToTop,
                      child: SizedBox.square(
                        dimension: 36,
                        child: Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          size: 22,
                          // 白色(浅色主题下为墨色),不再用红色 primary。
                          color: context.genesisColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_WorldEventListEntry> _buildListEntries() {
    final ticks = worldEventTicksAscending(widget.ticks).reversed.toList();
    final entries = <_WorldEventListEntry>[];
    final pendingTickNumber = _hasPendingTarget ? _requestedTickNumber : null;
    var pendingAdded = false;

    for (var index = 0; index < ticks.length; index += 1) {
      final tick = ticks[index];
      final tickNumber = worldEventTickNumber(tick);
      if (!pendingAdded &&
          pendingTickNumber != null &&
          pendingTickNumber > tickNumber) {
        entries.add(_WorldEventListEntry.pending(pendingTickNumber));
        pendingAdded = true;
      }
      final isFirstInTick =
          index == 0 || worldEventTickNumber(ticks[index - 1]) != tickNumber;
      final isLastInTick =
          index == ticks.length - 1 ||
          worldEventTickNumber(ticks[index + 1]) != tickNumber;
      entries.add(
        _WorldEventListEntry.tick(
          tick,
          isFirstInTick: isFirstInTick,
          isLastInTick: isLastInTick,
        ),
      );
    }
    if (!pendingAdded && pendingTickNumber != null) {
      entries.add(_WorldEventListEntry.pending(pendingTickNumber));
    }
    if (!widget.hasMore && ticks.isNotEmpty) {
      // 列表 reverse 渲染,追加在末尾 = 显示在最顶(故事开头之上)。
      entries.add(const _WorldEventListEntry.disclaimer());
    }
    return entries;
  }
}

class _WorldEventListEntry {
  const _WorldEventListEntry.tick(
    this.tick, {
    required this.isFirstInTick,
    required this.isLastInTick,
  }) : pendingTickNumber = null,
       showsAiDisclaimer = false;

  const _WorldEventListEntry.pending(this.pendingTickNumber)
    : tick = null,
      isFirstInTick = false,
      isLastInTick = false,
      showsAiDisclaimer = false;

  const _WorldEventListEntry.disclaimer()
    : tick = null,
      pendingTickNumber = null,
      isFirstInTick = false,
      isLastInTick = false,
      showsAiDisclaimer = true;

  final Map<String, dynamic>? tick;
  final int? pendingTickNumber;
  final bool isFirstInTick;
  final bool isLastInTick;
  final bool showsAiDisclaimer;
}
