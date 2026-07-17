// ignore_for_file: use_key_in_widget_constructors

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/bootstrap/service_registry.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/world_map.dart';
import '../../network/models/world.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/tokens/genesis_radii.dart';
import 'world_constants.dart';
import 'world_models.dart';
import 'world_sections.dart';

class WorldBottomTags extends StatelessWidget {
  const WorldBottomTags({
    required this.onTap,
    this.eventsUnread = false,
    this.showDetailUnreadDot = false,
  });

  final ValueChanged<WorldBottomSheetKind> onTap;
  final bool eventsUnread;
  final bool showDetailUnreadDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: worldMainTabsHeight,
      color: const Color(0xFFFFFFFF),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in worldBottomTagItems.indexed) ...[
                  WorldBottomTagContent(
                    item: entry.$2,
                    showUnreadDot:
                        eventsUnread &&
                            entry.$2.kind == WorldBottomSheetKind.events ||
                        showDetailUnreadDot &&
                            entry.$2.kind == WorldBottomSheetKind.detail,
                    onTap: () => onTap(entry.$2.kind),
                  ),
                  if (entry.$1 != worldBottomTagItems.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorldBottomTagContent extends StatelessWidget {
  const WorldBottomTagContent({
    required this.item,
    required this.onTap,
    this.showUnreadDot = false,
  });

  final WorldBottomTagItem item;
  final VoidCallback onTap;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: worldBottomTagHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEBEFF2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.asset != null)
                  SvgPicture.asset(
                    item.asset!,
                    width: 17,
                    height: 17,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF666666),
                      BlendMode.srcIn,
                    ),
                  )
                else
                  Icon(item.icon, size: 17, color: const Color(0xFF666666)),
                const SizedBox(width: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (showUnreadDot)
            Positioned(
              key: item.kind == WorldBottomSheetKind.events
                  ? const ValueKey('world-events-unread-dot')
                  : null,
              top: 2,
              right: 2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2442),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WorldSingleSectionBottomSheet extends StatefulWidget {
  const WorldSingleSectionBottomSheet({
    required this.selectionListenable,
    required this.services,
    required this.initialWorld,
    required this.worldListenable,
    required this.newUserJoinNoticesListenable,
    required this.eventsCache,
    required this.currentUid,
    required this.locationPoints,
    required this.locationNodes,
    required this.recentChatLocationIds,
    required this.onLocationTap,
    this.onDeleteWorld,
  });

  final ValueNotifier<WorldBottomSheetSelection> selectionListenable;
  final AppServices services;
  final WorldDetail initialWorld;
  final ValueListenable<WorldDetail?> worldListenable;
  final ValueListenable<List<WorldNewUserJoinNotice>>
  newUserJoinNoticesListenable;
  final WorldSectionsEventsCache eventsCache;
  final String currentUid;
  final List<WorldPoint> locationPoints;
  final List<WorldMapLocationNode> locationNodes;
  final Set<String> recentChatLocationIds;
  final ValueChanged<WorldPoint> onLocationTap;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;

  @override
  State<WorldSingleSectionBottomSheet> createState() =>
      WorldSingleSectionBottomSheetState();
}

class WorldSingleSectionBottomSheetState
    extends State<WorldSingleSectionBottomSheet> {
  static const int _eventsPageSize = 20;
  static const double _sheetHeightFactor = 0.85;
  static const double _contentDismissDragDistance = 48;
  static const double _contentDismissDragVelocity = 650;

  late final PageController _pageController;
  var _changingPageFromSelection = false;
  var _contentAtTop = true;
  var _contentDragDx = 0.0;
  var _contentDragDy = 0.0;
  VelocityTracker? _contentVelocityTracker;

  WorldDetail get _currentWorld =>
      widget.worldListenable.value ?? widget.initialWorld;

  WorldBottomSheetSelection get _selection => widget.selectionListenable.value;

  WorldSectionsEventsCache get _eventsCache => widget.eventsCache;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _pageForKind(_selection.kind),
    );
    widget.worldListenable.addListener(_handleWorldDetailChanged);
    widget.selectionListenable.addListener(_handleSelectionChanged);
    widget.newUserJoinNoticesListenable.addListener(
      _handleNewUserJoinNoticesChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
  }

  @override
  void didUpdateWidget(covariant WorldSingleSectionBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldListenable != widget.worldListenable) {
      oldWidget.worldListenable.removeListener(_handleWorldDetailChanged);
      widget.worldListenable.addListener(_handleWorldDetailChanged);
    }
    if (oldWidget.selectionListenable != widget.selectionListenable) {
      oldWidget.selectionListenable.removeListener(_handleSelectionChanged);
      widget.selectionListenable.addListener(_handleSelectionChanged);
    }
    if (oldWidget.newUserJoinNoticesListenable !=
        widget.newUserJoinNoticesListenable) {
      oldWidget.newUserJoinNoticesListenable.removeListener(
        _handleNewUserJoinNoticesChanged,
      );
      widget.newUserJoinNoticesListenable.addListener(
        _handleNewUserJoinNoticesChanged,
      );
    }
    if (_isEventsSheet &&
        (oldWidget.eventsCache != widget.eventsCache ||
            oldWidget.selectionListenable.value.kind != _selection.kind)) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
  }

  @override
  void dispose() {
    widget.worldListenable.removeListener(_handleWorldDetailChanged);
    widget.selectionListenable.removeListener(_handleSelectionChanged);
    widget.newUserJoinNoticesListenable.removeListener(
      _handleNewUserJoinNoticesChanged,
    );
    _pageController.dispose();
    super.dispose();
  }

  bool get _isEventsSheet => _selection.kind == WorldBottomSheetKind.events;

  void _handleWorldDetailChanged() {
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld();
    }
    if (mounted) setState(() {});
  }

  void _handleNewUserJoinNoticesChanged() {
    if (_selection.kind != WorldBottomSheetKind.detail) return;
    if (mounted) setState(() {});
  }

  void _handleSelectionChanged() {
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
    _contentAtTop = true;
    _resetContentDrag();
    _animateToSelectionPage();
    if (mounted) setState(() {});
  }

  int _pageForKind(WorldBottomSheetKind kind) {
    final index = worldBottomTagItems.indexWhere((item) => item.kind == kind);
    return index < 0 ? 0 : index;
  }

  WorldBottomSheetKind _kindForPage(int page) {
    if (page < 0 || page >= worldBottomTagItems.length) {
      return WorldBottomSheetKind.detail;
    }
    return worldBottomTagItems[page].kind;
  }

  void _animateToSelectionPage() {
    if (!_pageController.hasClients) return;
    final targetPage = _pageForKind(_selection.kind);
    final currentPage =
        _pageController.page?.round() ?? _pageController.initialPage;
    if (currentPage == targetPage) return;
    _changingPageFromSelection = true;
    unawaited(
      _pageController
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _changingPageFromSelection = false),
    );
  }

  void _handleSheetPageChanged(int page) {
    if (_changingPageFromSelection) return;
    final kind = _kindForPage(page);
    if (_selection.kind == kind) return;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: worldBottomSheetPageName(kind),
      object1: _currentWorld.worldId,
    );
    widget.selectionListenable.value = WorldBottomSheetSelection(
      kind: kind,
      eventsLatestRevision: _selection.eventsLatestRevision,
    );
  }

  void _ensureEventsForCurrentWorld({bool forceFirstPageRefresh = false}) {
    final worldId = _currentWorld.worldId;
    if (_eventsCache.worldId != worldId) {
      _eventsCache.reset(worldId);
      unawaited(_loadEventsPage(1));
      return;
    }
    if (forceFirstPageRefresh) {
      unawaited(_loadEventsPage(1, force: true));
      return;
    }
    if (_eventsCache.ticks.isEmpty) {
      unawaited(_loadEventsPage(1));
    }
  }

  void _mutateEventsCache(VoidCallback update) {
    if (!mounted) {
      update();
      return;
    }
    setState(update);
  }

  bool get _eventsHasMore {
    if (_eventsCache.total <= 0) return false;
    if (_eventsCache.ticks.length >= _eventsCache.total) return false;
    if (_eventsCache.page <= 0) return true;
    return _eventsCache.page * _eventsPageSize < _eventsCache.total;
  }

  void _loadNextEventsPage() {
    if (!_eventsHasMore ||
        _eventsCache.loadingMore ||
        _eventsCache.initialLoading) {
      return;
    }
    unawaited(_loadEventsPage(_eventsCache.page + 1));
  }

  Future<void> _loadEventsPage(int page, {bool force = false}) async {
    if (page <= 0) return;
    if (page == 1) {
      if (_eventsCache.initialLoading && !force) return;
      _mutateEventsCache(() {
        _eventsCache.initialLoading = true;
        _eventsCache.error = null;
      });
    } else {
      if (_eventsCache.loadingMore || !_eventsHasMore) return;
      _mutateEventsCache(() => _eventsCache.loadingMore = true);
    }

    final worldId = _currentWorld.worldId;
    try {
      final response = await widget.services.api.getWorldTicks(
        wid: worldId,
        limit: _eventsPageSize,
        offset: (page - 1) * _eventsPageSize,
      );
      if (worldId != _eventsCache.worldId) return;
      if (mounted && worldId != _currentWorld.worldId) return;
      final loadedTicks = worldEventTicksAscending(response.data);
      _mutateEventsCache(() {
        _eventsCache.ticks = worldMergeEventTicksAscending(
          _eventsCache.ticks,
          loadedTicks,
        );
        _eventsCache.total = response.total;
        _eventsCache.page = math.max(_eventsCache.page, page);
        _eventsCache.error = null;
      });
    } catch (e) {
      if (worldId != _eventsCache.worldId) return;
      if (mounted && worldId != _currentWorld.worldId) return;
      _mutateEventsCache(() => _eventsCache.error = e);
    } finally {
      if (worldId == _eventsCache.worldId &&
          (!mounted || worldId == _currentWorld.worldId)) {
        _mutateEventsCache(() {
          if (page == 1) {
            _eventsCache.initialLoading = false;
          } else {
            _eventsCache.loadingMore = false;
          }
        });
      }
    }
  }

  Widget _buildEventsSectionPage() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: WorldEventsSection(
        key: const PageStorageKey<String>('world-events-section-bottom-sheet'),
        world: _currentWorld,
        ticks: _eventsCache.ticks,
        initialLoading: _eventsCache.initialLoading,
        loadingMore: _eventsCache.loadingMore,
        hasMore: _eventsHasMore,
        error: _eventsCache.error,
        latestRevision: _selection.eventsLatestRevision,
        targetTickNumber: _selection.eventsTargetTickNumber,
        contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
        onLoadMore: _loadNextEventsPage,
      ),
    );
  }

  Widget _buildStatusSectionPage() {
    return WorldSectionListView(
      storageKey: 'world-status-section-bottom-sheet',
      child: WorldStatusSection(
        world: _currentWorld,
        currentUid: widget.currentUid,
      ),
    );
  }

  Widget _buildCastSectionPage() {
    return WorldSectionListView(
      storageKey: 'world-cast-section-bottom-sheet',
      child: WorldCharactersSection(
        world: _currentWorld,
        currentUid: widget.currentUid,
      ),
    );
  }

  Widget _buildLocationsSectionPage() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: WorldLocationList(
        points: widget.locationPoints,
        locationNodes: widget.locationNodes,
        recentChatLocationIds: widget.recentChatLocationIds,
        enableOuterScrollHandoff: false,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
        onPointTap: (point) {
          final locationId = point.sceneId.trim().isNotEmpty
              ? point.sceneId.trim()
              : (point.pointId.trim().isNotEmpty
                    ? point.pointId.trim()
                    : point.id.trim());
          GenesisTelemetry.collectLog(
            actionType: 'event',
            action: 'world_locations_click',
            object1: _currentWorld.worldId,
            object2: locationId,
          );
          Navigator.of(context).pop();
          widget.onLocationTap(point);
        },
      ),
    );
  }

  Widget _buildDetailSectionPage() {
    final latestDetailJoinNotice = worldLatestPlayerJoinNotice(
      _currentWorld.characters,
    );
    final newUserJoinNotice = _detailNewUserJoinNotice(
      latestDetailJoinNotice,
      widget.newUserJoinNoticesListenable.value,
    );
    return WorldSectionListView(
      storageKey: 'world-detail-section-bottom-sheet',
      child: WorldDetailSection(
        world: _currentWorld,
        currentUid: widget.currentUid,
        newUserJoinNotice: newUserJoinNotice,
        onDeleteWorld: widget.onDeleteWorld,
      ),
    );
  }

  WorldNewUserJoinNotice? _detailNewUserJoinNotice(
    WorldNewUserJoinNotice? latestDetailJoinNotice,
    List<WorldNewUserJoinNotice> socketNotices,
  ) {
    if (socketNotices.isNotEmpty) return socketNotices.last;
    return latestDetailJoinNotice;
  }

  Widget _buildSheetPage(WorldBottomSheetKind kind) {
    return switch (kind) {
      WorldBottomSheetKind.detail => _buildDetailSectionPage(),
      WorldBottomSheetKind.locations => _buildLocationsSectionPage(),
      WorldBottomSheetKind.events => _buildEventsSectionPage(),
      WorldBottomSheetKind.status => _buildStatusSectionPage(),
      WorldBottomSheetKind.cast => _buildCastSectionPage(),
    };
  }

  WorldBottomTagItem get _headerItem {
    return worldBottomTagItems.firstWhere(
      (item) => item.kind == _selection.kind,
    );
  }

  void _handleContentPointerDown(PointerDownEvent event) {
    _contentDragDx = 0;
    _contentDragDy = 0;
    _contentVelocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
  }

  void _handleContentPointerMove(PointerMoveEvent event) {
    _contentVelocityTracker?.addPosition(event.timeStamp, event.localPosition);
    _contentDragDx += event.delta.dx;
    final dragDelta = event.delta.dy;
    if (!_contentAtTop || dragDelta <= 0) {
      if (dragDelta < 0) _contentDragDy = 0;
      return;
    }
    _contentDragDy += dragDelta;
  }

  void _handleContentPointerUp(PointerUpEvent event) {
    _contentVelocityTracker?.addPosition(event.timeStamp, event.localPosition);
    final velocity =
        _contentVelocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    final isVerticalPull = _contentDragDy.abs() >= _contentDragDx.abs() * 1.2;
    final shouldClose =
        _contentAtTop &&
        isVerticalPull &&
        (_contentDragDy >= _contentDismissDragDistance ||
            velocity >= _contentDismissDragVelocity);
    _resetContentDrag();
    if (shouldClose) Navigator.of(context).pop();
  }

  void _handleContentPointerCancel(PointerCancelEvent event) {
    _resetContentDrag();
  }

  void _resetContentDrag() {
    _contentDragDx = 0;
    _contentDragDy = 0;
    _contentVelocityTracker = null;
  }

  bool _handleContentScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final atTop = notification.metrics.extentBefore <= 0.5;
    if (_contentAtTop != atTop) _contentAtTop = atTop;
    if (!atTop) _contentDragDy = 0;
    return false;
  }

  Widget _buildDismissibleSheetContent() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleContentPointerDown,
      onPointerMove: _handleContentPointerMove,
      onPointerUp: _handleContentPointerUp,
      onPointerCancel: _handleContentPointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleContentScrollNotification,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: PageView.builder(
            controller: _pageController,
            itemCount: worldBottomTagItems.length,
            onPageChanged: _handleSheetPageChanged,
            itemBuilder: (context, index) {
              return _buildSheetPage(_kindForPage(index));
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GenesisEdgeSwipeBack(
      onBack: () => Navigator.of(context).pop(),
      child: FractionallySizedBox(
        heightFactor: _sheetHeightFactor,
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: GenesisRadii.sheet,
          ),
          child: Column(
            children: [
              WorldSingleSectionSheetHeader(
                item: _headerItem,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _buildDismissibleSheetContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class WorldSingleSectionSheetHeader extends StatefulWidget {
  const WorldSingleSectionSheetHeader({
    required this.item,
    required this.onClose,
  });

  final WorldBottomTagItem item;
  final VoidCallback onClose;

  @override
  State<WorldSingleSectionSheetHeader> createState() =>
      WorldSingleSectionSheetHeaderState();
}

class WorldSingleSectionSheetHeaderState
    extends State<WorldSingleSectionSheetHeader> {
  static const double _dismissDragDistance = 48;
  static const double _dismissDragVelocity = 650;

  var _dragDy = 0.0;

  void _handleVerticalDragStart(DragStartDetails details) {
    _dragDy = 0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _dragDy += details.delta.dy;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final downwardVelocity = details.primaryVelocity ?? 0;
    if (_dragDy >= _dismissDragDistance ||
        downwardVelocity >= _dismissDragVelocity) {
      widget.onClose();
    }
    _dragDy = 0;
  }

  void _handleVerticalDragCancel() {
    _dragDy = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _handleVerticalDragStart,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      onVerticalDragCancel: _handleVerticalDragCancel,
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 64,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2D2D2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: 15,
              child: SizedBox(
                height: 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    WorldSheetHeaderIcon(item: widget.item),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 16,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: TextButton(
                        onPressed: widget.onClose,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: const Color(0xFFF3F3F5),
                          foregroundColor: const Color(0xFF111111),
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.close_rounded, size: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorldSheetHeaderIcon extends StatelessWidget {
  const WorldSheetHeaderIcon({required this.item});

  final WorldBottomTagItem item;

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;
    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(Color(0xFF111111), BlendMode.srcIn),
      );
    }
    return Icon(item.icon, size: 20, color: const Color(0xFF111111));
  }
}

class WorldSectionsEventsCache {
  var worldId = '';
  var ticks = const <Map<String, dynamic>>[];
  var total = 0;
  var page = 0;
  var initialLoading = false;
  var loadingMore = false;
  Object? error;

  void reset(String nextWorldId) {
    worldId = nextWorldId;
    ticks = const <Map<String, dynamic>>[];
    total = 0;
    page = 0;
    initialLoading = false;
    loadingMore = false;
    error = null;
  }

  void clear() {
    reset('');
  }
}
