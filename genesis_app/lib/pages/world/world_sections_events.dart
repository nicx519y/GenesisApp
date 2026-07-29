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
  final tickId = worldMapString(tick, const ['tick_id', 'id']);
  if (tickId.isNotEmpty) return 'id:$tickId';
  final tickNo = worldEventTickNumber(tick);
  if (tickNo > 0) return 'no:$tickNo';
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

  @override
  State<WorldEventsSection> createState() => WorldEventsSectionState();
}

class WorldEventsSectionState extends State<WorldEventsSection> {
  static const int _loadMorePageThreshold = 3;
  static const Duration _pageTurnDuration = Duration(milliseconds: 260);

  late final PageController _pageController = PageController();
  final _tickCardResetRevisions = <String, int>{};
  var _currentPage = 0;
  var _currentTickIdentity = '';
  var _animatingPage = false;
  var _showLatestWhenTicksArrive = true;

  int? get _requestedTickNumber {
    final target = widget.targetTickNumber;
    return target == null || target <= 0 ? null : target;
  }

  @override
  void initState() {
    super.initState();
    if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
      _jumpToCurrentPage();
    }
  }

  @override
  void didUpdateWidget(covariant WorldEventsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final worldChanged = oldWidget.world.worldId != widget.world.worldId;
    if (worldChanged) {
      _currentPage = 0;
      _currentTickIdentity = '';
      _showLatestWhenTicksArrive = true;
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
      }
      return;
    }

    if (oldWidget.latestRevision != widget.latestRevision ||
        oldWidget.targetTickNumber != widget.targetTickNumber) {
      _showLatestWhenTicksArrive = true;
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadPendingTarget();
      }
      return;
    }

    if (_currentTickIdentity.isEmpty) {
      if (_setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadMoreForPage(_currentPage);
      }
      return;
    }

    final nextIndex = _findPageByIdentity(_currentTickIdentity);
    if (_isPendingTargetIdentity(_currentTickIdentity)) {
      _maybeLoadPendingTarget();
    }
    if (nextIndex < 0) {
      if (_isPendingTargetIdentity(_currentTickIdentity) &&
          _setCurrentPageToRequestedTargetOrLatestIfAvailable()) {
        _jumpToCurrentPage();
        _maybeLoadMoreForPage(_currentPage);
        _maybeLoadPendingTarget();
        return;
      }
      _currentPage = _currentPage.clamp(0, _maxRenderedPage).toInt();
      _currentTickIdentity = _pageIdentityAt(_currentPage);
      _bumpTickCardResetRevisionAt(_currentPage);
      _jumpToCurrentPage();
      return;
    }
    if (nextIndex != _currentPage) {
      _currentPage = nextIndex;
      _bumpTickCardResetRevisionAt(_currentPage);
      _jumpToCurrentPage();
      _maybeLoadMoreForPage(_currentPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleTicks {
    return widget.ticks;
  }

  int get _maxRenderedPage => math.max(0, _pageCount - 1);

  int get _pageCount {
    final pendingTargetPage = _pendingTargetPage;
    if (pendingTargetPage == null) return _visibleTicks.length;
    return _visibleTicks.length + 1;
  }

  int? get _pendingTargetPage {
    final target = _requestedTickNumber;
    if (target == null || _pageIndexForTickNumber(target) != null) {
      return null;
    }
    if (!widget.initialLoading && !widget.loadingMore && !widget.hasMore) {
      return null;
    }
    return _insertionPageForTickNumber(target);
  }

  bool _setCurrentPageToRequestedTargetOrLatestIfAvailable() {
    final visibleTicks = _visibleTicks;
    final requestedTickNumber = _requestedTickNumber;
    if (requestedTickNumber != null) {
      final resolvedTargetPage = _pageIndexForTickNumber(requestedTickNumber);
      final pendingTargetPage = _pendingTargetPage;
      if (resolvedTargetPage != null || pendingTargetPage != null) {
        final targetPage = resolvedTargetPage ?? pendingTargetPage!;
        _currentPage = targetPage.clamp(0, _maxRenderedPage).toInt();
        _currentTickIdentity = _pageIdentityAt(_currentPage);
        _showLatestWhenTicksArrive = false;
        _bumpTickCardResetRevisionAt(_currentPage);
        return _pageCount > 0;
      }
    }
    if (visibleTicks.isEmpty) return false;
    final target = _showLatestWhenTicksArrive ? _maxRenderedPage : _currentPage;
    _currentPage = target.clamp(0, _maxRenderedPage).toInt();
    _currentTickIdentity = _pageIdentityAt(_currentPage);
    _showLatestWhenTicksArrive = false;
    _bumpTickCardResetRevisionAt(_currentPage);
    return true;
  }

  void _jumpToCurrentPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_pageController.hasClients) {
        _jumpToCurrentPage();
        return;
      }
      final target = _currentPage.clamp(0, _maxRenderedPage).toInt();
      _pageController.jumpToPage(target);
    });
  }

  void _handlePageChanged(int page) {
    _currentPage = page.clamp(0, _maxRenderedPage).toInt();
    _currentTickIdentity = _pageIdentityAt(_currentPage);
    _maybeLoadMoreForPage(_currentPage);
  }

  void _maybeLoadMoreForPage(int page) {
    if (!widget.hasMore || widget.loadingMore || widget.initialLoading) return;
    if (page <= _loadMorePageThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.hasMore ||
            widget.loadingMore ||
            widget.initialLoading) {
          return;
        }
        widget.onLoadMore();
      });
    }
  }

  void _maybeLoadPendingTarget() {
    if (_requestedTickNumber == null ||
        _pendingTargetPage == null ||
        !widget.hasMore ||
        widget.loadingMore ||
        widget.initialLoading) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _requestedTickNumber == null ||
          _pendingTargetPage == null ||
          !widget.hasMore ||
          widget.loadingMore ||
          widget.initialLoading) {
        return;
      }
      widget.onLoadMore();
    });
  }

  void _bumpTickCardResetRevisionAt(int page) {
    final identity = _pageIdentityAt(page);
    if (identity.isEmpty) return;
    _tickCardResetRevisions[identity] =
        (_tickCardResetRevisions[identity] ?? 0) + 1;
  }

  void _turnPage(int delta) {
    if (_animatingPage || !_pageController.hasClients) return;
    final target = (_currentPage + delta).clamp(0, _maxRenderedPage).toInt();
    if (target == _currentPage) {
      _maybeLoadMoreForPage(_currentPage);
      return;
    }
    _animatingPage = true;
    setState(() => _bumpTickCardResetRevisionAt(target));
    unawaited(
      _pageController
          .animateToPage(
            target,
            duration: _pageTurnDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (!mounted) return;
            _animatingPage = false;
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTargetPage = _pendingTargetPage;
    final hasPendingTargetPage = pendingTargetPage != null;
    if (widget.ticks.isEmpty &&
        widget.initialLoading &&
        !hasPendingTargetPage) {
      return Padding(
        padding: widget.contentPadding,
        child: const WorldEventLoadingSkeleton(),
      );
    }
    if (widget.ticks.isEmpty && !hasPendingTargetPage) {
      return Padding(
        padding: widget.contentPadding,
        child: WorldEmptySection(
          text: widget.error == null ? 'No events yet.' : 'Load events failed.',
        ),
      );
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in widget.world.locations)
        worldMapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final fallbackBody = worldEventBody(widget.world);
    final metricUnit = worldMapString(widget.world.metric, const ['unit']);
    final visibleTicks = _visibleTicks;

    return Stack(
      children: [
        PageView.builder(
          key: const ValueKey<String>('world-events-tick-pager'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pageCount,
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            if (index == pendingTargetPage) {
              final tickNumber = _requestedTickNumber ?? widget.world.tickCount;
              return WorldTickEventCardPage(
                key: ValueKey<String>('world-event-tick-pending-$tickNumber'),
                resetRevision:
                    _tickCardResetRevisions['pending_tick:$tickNumber'] ?? 0,
                hasTopEdgePage: index > 0,
                hasBottomEdgePage: index < _pageCount - 1,
                padding: widget.contentPadding,
                onTurnPage: _turnPage,
                child: WorldTickPendingEventPage(tickNumber: tickNumber),
              );
            }
            final tickIndex = _tickIndexForPage(index);
            if (tickIndex == null) return const SizedBox.shrink();
            final tick = visibleTicks[tickIndex];
            final identity = worldEventTickIdentity(tick);
            final tickNumber = worldTickEventNumber(
              tick,
              fallback: tickIndex + 1,
            );
            return WorldTickEventCardPage(
              key: ValueKey<String>('world-event-tick-$identity'),
              resetRevision: _tickCardResetRevisions[identity] ?? 0,
              hasTopEdgePage: index > 0,
              hasBottomEdgePage: index < _pageCount - 1,
              padding: widget.contentPadding,
              onTurnPage: _turnPage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tickNumber == 1)
                    const AiContentDisclaimer(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
                      textAlign: TextAlign.left,
                    ),
                  WorldTickEventItem(
                    key: ValueKey<String>('world-event-tick-item-$identity'),
                    tick: tick,
                    tickNumber: tickNumber,
                    fallbackBody: fallbackBody,
                    locationsById: locationsById,
                    dateLabel: worldTickParagraphTimestamp(tick),
                    stackedContent: true,
                    contentLabelStyle: _worldEventContentLabelStyle,
                    contentTextStyle: _worldEventContentTextStyle,
                    contentTimestampStyle: _worldEventContentTimestampStyle,
                    metricUnit: metricUnit,
                    isLast: true,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.loadingMore)
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: WorldEventsLoadingMoreIndicator(),
            ),
          ),
      ],
    );
  }

  int? _tickIndexForPage(int page) {
    final pendingTargetPage = _pendingTargetPage;
    final tickIndex = pendingTargetPage != null && page > pendingTargetPage
        ? page - 1
        : page;
    if (tickIndex < 0 || tickIndex >= _visibleTicks.length) return null;
    return tickIndex;
  }

  String _pageIdentityAt(int page) {
    final pendingTargetPage = _pendingTargetPage;
    if (pendingTargetPage != null && page == pendingTargetPage) {
      return 'pending_tick:${_requestedTickNumber ?? 0}';
    }
    final tickIndex = _tickIndexForPage(page);
    if (tickIndex == null) return '';
    return worldEventTickIdentity(_visibleTicks[tickIndex]);
  }

  int _findPageByIdentity(String identity) {
    for (var page = 0; page < _pageCount; page += 1) {
      if (_pageIdentityAt(page) == identity) return page;
    }
    return -1;
  }

  bool _isPendingTargetIdentity(String identity) {
    final target = _requestedTickNumber;
    return target != null && identity == 'pending_tick:$target';
  }

  int? _pageIndexForTickNumber(int targetTickNumber) {
    final tickIndex = _visibleTicks.indexWhere(
      (tick) => worldTickEventNumber(tick) == targetTickNumber,
    );
    if (tickIndex < 0) return null;
    return tickIndex;
  }

  int _insertionPageForTickNumber(int targetTickNumber) {
    final visibleTicks = _visibleTicks;
    for (var index = 0; index < visibleTicks.length; index += 1) {
      final tickNumber = worldTickEventNumber(visibleTicks[index]);
      if (tickNumber >= targetTickNumber) return index;
    }
    return visibleTicks.length;
  }
}
