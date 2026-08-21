// ignore_for_file: use_key_in_widget_constructors

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
import 'package:genesis_flutter_android/components/genesis_feature_themes.dart';

import '../../app/bootstrap/service_registry.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/map_detail_sheet_surface.dart';
import '../../components/world_map.dart';
import '../../components/world/genesis_world_theme.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/world.dart';
import 'world_constants.dart';
import 'world_map_data.dart';
import 'world_models.dart';
import 'world_sections.dart';

const Duration worldBottomTabSelectionDuration = Duration(milliseconds: 180);
const Curve worldBottomTabSelectionCurve = Curves.easeOutCubic;

class WorldBottomTags extends StatefulWidget {
  const WorldBottomTags({
    super.key,
    required this.onTap,
    this.eventsUnread = false,
    this.showDetailUnreadDot = false,
    this.selectedKind,
    this.tabKeyPrefix = 'world-bottom-tab',
  });

  final ValueChanged<WorldBottomSheetKind> onTap;
  final bool eventsUnread;
  final bool showDetailUnreadDot;
  final WorldBottomSheetKind? selectedKind;
  final String tabKeyPrefix;

  @override
  State<WorldBottomTags> createState() => _WorldBottomTagsState();
}

class _WorldBottomTagsState extends State<WorldBottomTags>
    with SingleTickerProviderStateMixin {
  final GlobalKey _trackKey = GlobalKey();
  final Map<WorldBottomSheetKind, GlobalKey> _tabKeys = {
    for (final item in worldBottomTagItems) item.kind: GlobalKey(),
  };
  late final AnimationController _indicatorController = AnimationController(
    vsync: this,
    duration: worldBottomTabSelectionDuration,
  )..addStatusListener(_handleIndicatorStatus);

  Map<WorldBottomSheetKind, Rect> _tabRects = const {};
  Rect? _settledIndicatorRect;
  RectTween? _indicatorTween;
  bool _geometrySyncScheduled = false;
  bool _animateNextGeometrySync = false;

  @override
  void initState() {
    super.initState();
    _scheduleGeometrySync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleGeometrySync();
  }

  @override
  void didUpdateWidget(covariant WorldBottomTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleGeometrySync(
      animateSelection: oldWidget.selectedKind != widget.selectedKind,
    );
  }

  @override
  void dispose() {
    _indicatorController
      ..removeStatusListener(_handleIndicatorStatus)
      ..dispose();
    super.dispose();
  }

  void _handleIndicatorStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final end = _indicatorTween?.end;
    if (end == null) return;
    setState(() {
      _settledIndicatorRect = end;
      _indicatorTween = null;
    });
  }

  Rect? get _currentIndicatorRect {
    final tween = _indicatorTween;
    if (tween == null) return _settledIndicatorRect;
    return tween.lerp(
      worldBottomTabSelectionCurve.transform(_indicatorController.value),
    );
  }

  void _scheduleGeometrySync({bool animateSelection = false}) {
    _animateNextGeometrySync |= animateSelection;
    if (_geometrySyncScheduled) return;
    _geometrySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometrySyncScheduled = false;
      if (!mounted) return;
      final shouldAnimate = _animateNextGeometrySync;
      _animateNextGeometrySync = false;
      _syncGeometry(animateSelection: shouldAnimate);
    });
  }

  void _syncGeometry({required bool animateSelection}) {
    final trackBox = _trackKey.currentContext?.findRenderObject();
    if (trackBox is! RenderBox || !trackBox.hasSize) return;
    final nextRects = <WorldBottomSheetKind, Rect>{};
    for (final entry in _tabKeys.entries) {
      final tabBox = entry.value.currentContext?.findRenderObject();
      if (tabBox is! RenderBox || !tabBox.hasSize) continue;
      final offset = tabBox.localToGlobal(Offset.zero, ancestor: trackBox);
      nextRects[entry.key] = offset & tabBox.size;
    }
    final targetRect = widget.selectedKind == null
        ? null
        : nextRects[widget.selectedKind!];
    final currentRect = _currentIndicatorRect;

    if (targetRect == null) {
      _indicatorController.stop();
      setState(() {
        _tabRects = nextRects;
        _settledIndicatorRect = null;
        _indicatorTween = null;
      });
      return;
    }
    if (animateSelection && currentRect != null && currentRect != targetRect) {
      setState(() {
        _tabRects = nextRects;
        _settledIndicatorRect = currentRect;
        _indicatorTween = RectTween(begin: currentRect, end: targetRect);
      });
      _indicatorController.forward(from: 0);
      return;
    }
    _indicatorController.stop();
    setState(() {
      _tabRects = nextRects;
      _settledIndicatorRect = targetRect;
      _indicatorTween = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMeasuredGeometry = _tabRects.length == worldBottomTagItems.length;
    return Container(
      height: worldMainTabsHeight,
      color: context.genesisColors.pageBackground,
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: GenesisTypography.bodyStrong.copyWith(
          color: context.genesisColors.textPrimary,
          fontSize: 12,
          height: 1,
          decoration: TextDecoration.none,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Stack(
              key: _trackKey,
              children: [
                if (hasMeasuredGeometry)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _indicatorController,
                      builder: (context, _) => CustomPaint(
                        key: ValueKey<String>(
                          '${widget.tabKeyPrefix}-indicator',
                        ),
                        painter: _WorldBottomTabsIndicatorPainter(
                          tabRects: _tabRects.values.toList(growable: false),
                          indicatorRect: _currentIndicatorRect,
                          tabColor: context.genesisColors.surfaceTag,
                          indicatorColor:
                              context.genesisColors.foregroundStrong,
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in worldBottomTagItems.indexed) ...[
                      WorldBottomTagContent(
                        key: _tabKeys[entry.$2.kind],
                        item: entry.$2,
                        tabKeyPrefix: widget.tabKeyPrefix,
                        selected: entry.$2.kind == widget.selectedKind,
                        paintBackground: !hasMeasuredGeometry,
                        showUnreadDot:
                            widget.eventsUnread &&
                                entry.$2.kind == WorldBottomSheetKind.events ||
                            widget.showDetailUnreadDot &&
                                entry.$2.kind == WorldBottomSheetKind.detail,
                        onTap: () => widget.onTap(entry.$2.kind),
                      ),
                      if (entry.$1 != worldBottomTagItems.length - 1)
                        SizedBox(width: 7),
                    ],
                  ],
                ),
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
    super.key,
    required this.item,
    required this.onTap,
    required this.tabKeyPrefix,
    this.selected = false,
    this.showUnreadDot = false,
    this.paintBackground = true,
  });

  final WorldBottomTagItem item;
  final VoidCallback onTap;
  final String tabKeyPrefix;
  final bool selected;
  final bool showUnreadDot;
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        key: ValueKey<String>('$tabKeyPrefix-${item.kind}'),
        duration: worldBottomTabSelectionDuration,
        curve: worldBottomTabSelectionCurve,
        height: worldBottomTagHeight,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: !paintBackground
              ? Colors.transparent
              : selected
              ? context.genesisColors.foregroundStrong
              : context.genesisColors.surfaceTag,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: worldBottomTabSelectionDuration,
              curve: worldBottomTabSelectionCurve,
              style: GenesisTypography.withFallback(
                TextStyle(
                  color: selected
                      ? context.genesisColors.textInverse
                      : context.genesisColors.textSecondary,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showUnreadDot) ...[
              const SizedBox(width: 6),
              Container(
                key: item.kind == WorldBottomSheetKind.events
                    ? const ValueKey('world-events-unread-dot')
                    : null,
                constraints: const BoxConstraints(minWidth: 15),
                height: 15,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: context.genesisColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '1',
                  style: TextStyle(
                    color: context.genesisColors.onDanger,
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorldBottomTabsIndicatorPainter extends CustomPainter {
  const _WorldBottomTabsIndicatorPainter({
    required this.tabRects,
    required this.indicatorRect,
    required this.tabColor,
    required this.indicatorColor,
  });

  final List<Rect> tabRects;
  final Rect? indicatorRect;
  final Color tabColor;
  final Color indicatorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(11);
    final tabPaint = Paint()..color = tabColor;
    for (final rect in tabRects) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), tabPaint);
    }
    final indicatorRect = this.indicatorRect;
    if (indicatorRect == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(indicatorRect, radius),
      Paint()..color = indicatorColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WorldBottomTabsIndicatorPainter oldDelegate) {
    return !listEquals(oldDelegate.tabRects, tabRects) ||
        oldDelegate.indicatorRect != indicatorRect ||
        oldDelegate.tabColor != tabColor ||
        oldDelegate.indicatorColor != indicatorColor;
  }
}

class WorldSingleSectionBottomSheet extends StatefulWidget {
  const WorldSingleSectionBottomSheet({
    super.key,
    required this.selectionListenable,
    required this.services,
    required this.initialWorld,
    required this.worldListenable,
    required this.newUserJoinNoticesListenable,
    required this.eventsCache,
    required this.currentUid,
    required this.recentChatLocationIds,
    required this.onLocationTap,
    required this.onTabTap,
    required this.onCollapsed,
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
  final Set<String> recentChatLocationIds;
  final ValueChanged<WorldPoint> onLocationTap;
  final ValueChanged<WorldBottomSheetKind> onTabTap;
  final VoidCallback onCollapsed;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;

  @override
  State<WorldSingleSectionBottomSheet> createState() =>
      WorldSingleSectionBottomSheetState();
}

class WorldSingleSectionBottomSheetState
    extends State<WorldSingleSectionBottomSheet> {
  static const int _eventsPageSize = 20;
  static const double _sheetMinChildSize = 0.001;
  static const double _sheetAbsoluteMaxChildSize = 1;
  static const Duration _sheetSnapDuration = Duration(milliseconds: 260);

  late final PageController _pageController;
  late final DraggableScrollableController _sheetController;
  late final List<ScrollController> _pagePreviewScrollControllers;
  ScrollController? _sheetScrollController;
  var _sheetHostHeight = 1.0;
  var _changingPageFromSelection = false;
  var _isClosing = false;
  var _sheetHasOpened = false;
  var _sheetPointerActive = false;
  var _extentCommandGeneration = 0;
  WorldLocationListData? _cachedLocationListData;
  ProcessedLocationTree<Map<String, dynamic>>? _cachedProcessedLocationTree;
  List<Map<String, dynamic>>? _cachedLocations;
  List<Map<String, dynamic>>? _cachedCharacterPositions;
  List<Map<String, dynamic>>? _cachedUserPositions;
  String _cachedLocationListCurrentUid = '';

  WorldDetail get _currentWorld =>
      widget.worldListenable.value ?? widget.initialWorld;

  WorldBottomSheetSelection get _selection => widget.selectionListenable.value;

  WorldSectionsEventsCache get _eventsCache => widget.eventsCache;

  double get _sheetRestingChildSize {
    final expandedTop = mapDetailSheetExpandedTop(context);
    return ((_sheetHostHeight - expandedTop) / _sheetHostHeight)
        .clamp(_sheetMinChildSize, _sheetAbsoluteMaxChildSize)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _pageForKind(_selection.kind),
    );
    _sheetController = DraggableScrollableController();
    _pagePreviewScrollControllers = List<ScrollController>.generate(
      worldBottomTagItems.length,
      (_) => ScrollController(),
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
    _sheetController.dispose();
    _pageController.dispose();
    for (final controller in _pagePreviewScrollControllers) {
      controller.dispose();
    }
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
    _resetActivePageScroll();
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
    _resetActivePageScroll();
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

  void _resetActivePageScroll() {
    final controller = _sheetScrollController;
    if (controller != null && controller.hasClients && controller.offset != 0) {
      controller.jumpTo(0);
    }
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

  Widget _buildEventsSectionPage(ScrollController scrollController) {
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
        contentPadding: const EdgeInsets.fromLTRB(
          20,
          worldInfoHeaderHeight,
          20,
          32,
        ),
        onLoadMore: _loadNextEventsPage,
        scrollController: scrollController,
      ),
    );
  }

  Widget _buildStatusSectionPage(ScrollController scrollController) {
    final world = _currentWorld;
    return WorldCharacterListView(
      storageKey: 'world-status-section-bottom-sheet',
      characters: world.characters,
      currentUid: widget.currentUid,
      emptyText: 'No character status yet.',
      subtitleBuilder: (character) =>
          worldMetricStatusText(world.metric, character),
      subtitleColor: context.genesisColors.textMuted,
      showCharacterDetails: false,
      scrollController: scrollController,
      cardStyle: true,
      statusProgressStyle: true,
      metric: world.metric,
      locationNameBuilder: (character) =>
          worldCharacterLocationName(world, character),
      padding: const EdgeInsets.fromLTRB(20, worldInfoHeaderHeight, 20, 32),
    );
  }

  Widget _buildCastSectionPage(ScrollController scrollController) {
    final world = _currentWorld;
    return WorldCharacterListView(
      storageKey: 'world-cast-section-bottom-sheet',
      characters: world.characters,
      currentUid: widget.currentUid,
      emptyText: 'No characters yet.',
      subtitleBuilder: worldCharacterDescriptionText,
      subtitleColor: context.genesisColors.textMuted,
      showCharacterDetails: true,
      scrollController: scrollController,
      padding: const EdgeInsets.fromLTRB(20, worldInfoHeaderHeight, 20, 32),
    );
  }

  Widget _buildLocationsSectionPage(ScrollController scrollController) {
    final locationData = _locationListDataForCurrentWorld();
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: WorldLocationList(
        points: locationData.points,
        locationNodes: locationData.locationNodes,
        recentChatLocationIds: widget.recentChatLocationIds,
        enableOuterScrollHandoff: false,
        lazyBuildRows: true,
        padding: const EdgeInsets.fromLTRB(20, worldInfoHeaderHeight, 20, 32),
        compactSheetStyle: true,
        scrollController: scrollController,
        header: _WorldLocationsSummary(
          worldName: _currentWorld.name,
          zoneCount: locationData.locationNodes.length,
          placeCount: locationData.points
              .where((point) => point.isLeafLocation)
              .length,
        ),
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
          unawaited(
            _closeSheetToTabDivider(
              afterClose: () => widget.onLocationTap(point),
            ),
          );
        },
      ),
    );
  }

  WorldLocationListData _locationListDataForCurrentWorld() {
    final world = _currentWorld;
    final cached = _cachedLocationListData;
    if (cached != null &&
        identical(_cachedProcessedLocationTree, world.processedLocationTree) &&
        identical(_cachedLocations, world.locations) &&
        identical(_cachedCharacterPositions, world.characterPositions) &&
        identical(_cachedUserPositions, world.userPositions) &&
        _cachedLocationListCurrentUid == widget.currentUid) {
      return cached;
    }
    final locationData = worldLocationListDataFor(
      world,
      currentUid: widget.currentUid,
    );
    _cachedLocationListData = locationData;
    _cachedProcessedLocationTree = world.processedLocationTree;
    _cachedLocations = world.locations;
    _cachedCharacterPositions = world.characterPositions;
    _cachedUserPositions = world.userPositions;
    _cachedLocationListCurrentUid = widget.currentUid;
    return locationData;
  }

  Widget _buildDetailSectionPage(ScrollController scrollController) {
    final latestDetailJoinNotice = worldLatestPlayerJoinNotice(
      _currentWorld.characters,
    );
    final newUserJoinNotice = _detailNewUserJoinNotice(
      latestDetailJoinNotice,
      widget.newUserJoinNoticesListenable.value,
    );
    return WorldDetailSectionListView(
      storageKey: 'world-detail-section-bottom-sheet',
      world: _currentWorld,
      currentUid: widget.currentUid,
      scrollController: scrollController,
      newUserJoinNotice: newUserJoinNotice,
      onDeleteWorld: widget.onDeleteWorld,
      padding: const EdgeInsets.fromLTRB(20, worldInfoHeaderHeight, 20, 32),
    );
  }

  WorldNewUserJoinNotice? _detailNewUserJoinNotice(
    WorldNewUserJoinNotice? latestDetailJoinNotice,
    List<WorldNewUserJoinNotice> socketNotices,
  ) {
    if (socketNotices.isNotEmpty) return socketNotices.last;
    return latestDetailJoinNotice;
  }

  Widget _buildSheetPage(
    WorldBottomSheetKind kind,
    ScrollController scrollController,
  ) {
    return switch (kind) {
      WorldBottomSheetKind.detail => _buildDetailSectionPage(scrollController),
      WorldBottomSheetKind.locations => _buildLocationsSectionPage(
        scrollController,
      ),
      WorldBottomSheetKind.events => _buildEventsSectionPage(scrollController),
      WorldBottomSheetKind.status => _buildStatusSectionPage(scrollController),
      WorldBottomSheetKind.cast => _buildCastSectionPage(scrollController),
    };
  }

  WorldBottomTagItem get _headerItem {
    return worldBottomTagItems.firstWhere(
      (item) => item.kind == _selection.kind,
    );
  }

  void open() {
    if (!mounted) return;
    _isClosing = false;
    _sheetHasOpened = false;
    final commandGeneration = ++_extentCommandGeneration;
    _animateSheetFromTabDivider(commandGeneration);
  }

  Future<void> close() => _closeSheetToTabDivider();

  void _animateSheetFromTabDivider(int commandGeneration) {
    if (!mounted || commandGeneration != _extentCommandGeneration) return;
    if (!_sheetController.isAttached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateSheetFromTabDivider(commandGeneration);
      });
      return;
    }
    unawaited(
      _sheetController.animateTo(
        _sheetRestingChildSize,
        duration: _sheetSnapDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _animateSheetToTabDivider() async {
    if (!_sheetController.isAttached) return;
    try {
      await _sheetController.animateTo(
        _sheetMinChildSize,
        duration: _sheetSnapDuration,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  Future<void> _closeSheetToTabDivider({VoidCallback? afterClose}) async {
    if (_isClosing) return;
    _isClosing = true;
    final commandGeneration = ++_extentCommandGeneration;
    if (_sheetController.isAttached &&
        _sheetController.size > _sheetMinChildSize + 0.002) {
      await _animateSheetToTabDivider();
    }
    if (!mounted || commandGeneration != _extentCommandGeneration) return;
    _isClosing = false;
    _sheetHasOpened = false;
    widget.onCollapsed();
    afterClose?.call();
  }

  void _handleSheetPointerDown(PointerDownEvent event) {
    _sheetPointerActive = true;
  }

  void _handleSheetPointerEnd(PointerEvent event) {
    _sheetPointerActive = false;
    _closeSheetIfReleasedAtTabDivider();
  }

  void _closeSheetIfReleasedAtTabDivider() {
    if (_isClosing ||
        !_sheetHasOpened ||
        !_sheetController.isAttached ||
        _sheetController.size > _sheetMinChildSize + 0.002) {
      return;
    }
    unawaited(_closeSheetToTabDivider());
  }

  bool _handleSheetExtentNotification(
    DraggableScrollableNotification notification,
  ) {
    if (notification.extent > _sheetMinChildSize + 0.05) {
      _sheetHasOpened = true;
    } else if (_sheetHasOpened && !_isClosing && !_sheetPointerActive) {
      unawaited(_closeSheetToTabDivider());
    }
    return false;
  }

  Widget _buildSheetContent(ScrollController sheetScrollController) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: PageView.builder(
        controller: _pageController,
        itemCount: worldBottomTagItems.length,
        onPageChanged: _handleSheetPageChanged,
        itemBuilder: (context, index) {
          final scrollController = index == _pageForKind(_selection.kind)
              ? sheetScrollController
              : _pagePreviewScrollControllers[index];
          return _buildSheetPage(_kindForPage(index), scrollController);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = GenesisSafeAreaInsets.bottom(context, minimum: 24);
    final bottomTabsInset = worldMainTabsHeight + bottomSafeArea;
    return LayoutBuilder(
      builder: (context, constraints) {
        _sheetHostHeight = math
            .max(1, constraints.maxHeight - bottomTabsInset)
            .toDouble();
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleSheetPointerDown,
          onPointerUp: _handleSheetPointerEnd,
          onPointerCancel: _handleSheetPointerEnd,
          child: GenesisEdgeSwipeBack(
            onBack: () => unawaited(_closeSheetToTabDivider()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  bottom: bottomTabsInset,
                  child: GestureDetector(
                    key: const ValueKey<String>('world-detail-sheet-backdrop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_closeSheetToTabDivider()),
                    child: const SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: bottomTabsInset),
                  child: NotificationListener<DraggableScrollableNotification>(
                    onNotification: _handleSheetExtentNotification,
                    child: DraggableScrollableSheet(
                      key: const ValueKey<String>(
                        'world-detail-draggable-sheet',
                      ),
                      controller: _sheetController,
                      initialChildSize: _sheetMinChildSize,
                      minChildSize: _sheetMinChildSize,
                      maxChildSize: _sheetRestingChildSize,
                      shouldCloseOnMinExtent: false,
                      snap: true,
                      snapAnimationDuration: _sheetSnapDuration,
                      builder: (context, scrollController) {
                        _sheetScrollController = scrollController;
                        return MapDetailSheetSurface(
                          surfaceKey: const ValueKey<String>(
                            'world-detail-sheet-surface',
                          ),
                          connectsToBottom: true,
                          child: Material(
                            color: Colors.transparent,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildSheetContent(scrollController),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  height: worldInfoHeaderHeight,
                                  child: ColoredBox(
                                    color: context.genesisColors.pageBackground,
                                    child: WorldSingleSectionSheetHeader(
                                      item: _headerItem,
                                      pageController: _pageController,
                                      world: _currentWorld,
                                      currentUid: widget.currentUid,
                                      onDeleteWorld: widget.onDeleteWorld,
                                      sheetController: _sheetController,
                                      sheetHostHeight: _sheetHostHeight,
                                      restingChildSize: _sheetRestingChildSize,
                                      onClose: () =>
                                          unawaited(_closeSheetToTabDivider()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomSafeArea,
                  height: worldMainTabsHeight,
                  child: ExcludeSemantics(
                    child: Opacity(
                      key: const ValueKey<String>(
                        'world-detail-sheet-tab-hit-targets',
                      ),
                      opacity: 0,
                      child: WorldBottomTags(
                        tabKeyPrefix: 'world-detail-sheet-hit-tab',
                        onTap: widget.onTabTap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorldLocationsSummary extends StatelessWidget {
  const _WorldLocationsSummary({
    required this.worldName,
    required this.zoneCount,
    required this.placeCount,
  });

  final String worldName;
  final int zoneCount;
  final int placeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              worldName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.genesisColors.textPrimary,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '$zoneCount zones · $placeCount places',
            style: TextStyle(
              color: context.genesisColors.textSubtle,
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class WorldSingleSectionSheetHeader extends StatefulWidget {
  const WorldSingleSectionSheetHeader({
    required this.item,
    required this.pageController,
    required this.world,
    required this.currentUid,
    required this.onDeleteWorld,
    required this.sheetController,
    required this.sheetHostHeight,
    required this.restingChildSize,
    required this.onClose,
  });

  final WorldBottomTagItem item;
  final PageController pageController;
  final WorldDetail world;
  final String currentUid;
  final Future<void> Function(BuildContext context, WorldDetail world)?
  onDeleteWorld;
  final DraggableScrollableController sheetController;
  final double sheetHostHeight;
  final double restingChildSize;
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
    if (!widget.sheetController.isAttached || widget.sheetHostHeight <= 0) {
      return;
    }
    final nextSize =
        (widget.sheetController.size -
                details.delta.dy / widget.sheetHostHeight)
            .clamp(
              WorldSingleSectionBottomSheetState._sheetMinChildSize,
              widget.restingChildSize,
            )
            .toDouble();
    widget.sheetController.jumpTo(nextSize);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final downwardVelocity = details.primaryVelocity ?? 0;
    if (_dragDy >= _dismissDragDistance ||
        downwardVelocity >= _dismissDragVelocity) {
      widget.onClose();
    } else if (widget.sheetController.isAttached) {
      unawaited(
        widget.sheetController.animateTo(
          widget.restingChildSize,
          duration: WorldSingleSectionBottomSheetState._sheetSnapDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
    _dragDy = 0;
  }

  void _handleVerticalDragCancel() {
    _dragDy = 0;
    if (!widget.sheetController.isAttached) return;
    unawaited(
      widget.sheetController.animateTo(
        widget.restingChildSize,
        duration: WorldSingleSectionBottomSheetState._sheetSnapDuration,
        curve: Curves.easeOutCubic,
      ),
    );
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
        height: 67,
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: _WorldSheetPageIndicator(
                pageController: widget.pageController,
                fallbackPage: worldBottomTagItems.indexWhere(
                  (item) => item.kind == widget.item.kind,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 29,
              child: SizedBox(
                height: 26,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GenesisTypography.navigationTitle.copyWith(
                          color: context.genesisColors.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (widget.item.kind == WorldBottomSheetKind.detail) ...[
                      _WorldSheetCircularAction(
                        child: WorldDetailMoreMenuButton(
                          world: widget.world,
                          currentUid: widget.currentUid,
                          onDeleteWorld: widget.onDeleteWorld,
                          buttonSize: 26,
                          iconSize: 14,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: TextButton(
                        onPressed: widget.onClose,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(26, 26),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor:
                              context.genesisWorldColors.closeSurface,
                          foregroundColor: context.genesisColors.textPrimary,
                          shape: const CircleBorder(),
                        ),
                        child: GenesisCloseIcon(
                          size: 14,
                          color: context.genesisColors.textPrimary,
                        ),
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

class _WorldSheetCircularAction extends StatelessWidget {
  const _WorldSheetCircularAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.genesisWorldColors.closeSurface,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _WorldSheetPageIndicator extends StatelessWidget {
  const _WorldSheetPageIndicator({
    required this.pageController,
    required this.fallbackPage,
  });

  final PageController pageController;
  final int fallbackPage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        final page = pageController.hasClients
            ? pageController.page ?? fallbackPage.toDouble()
            : fallbackPage.toDouble();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final entry in worldBottomTagItems.indexed) ...[
              _WorldSheetPageIndicatorSegment(
                key: ValueKey<String>(
                  'world-sheet-page-indicator-${entry.$2.kind}',
                ),
                selectionProgress: 1 - (page - entry.$1).abs(),
              ),
              if (entry.$1 != worldBottomTagItems.length - 1)
                const SizedBox(width: 5),
            ],
          ],
        );
      },
    );
  }
}

class _WorldSheetPageIndicatorSegment extends StatelessWidget {
  const _WorldSheetPageIndicatorSegment({
    super.key,
    required this.selectionProgress,
  });

  final double selectionProgress;

  @override
  Widget build(BuildContext context) {
    final progress = selectionProgress.clamp(0.0, 1.0);
    final colors = context.genesisColors;
    return Container(
      width: 4 + 22 * progress,
      height: 4,
      decoration: BoxDecoration(
        color: Color.lerp(colors.dragHandle, colors.foregroundStrong, progress),
        borderRadius: BorderRadius.circular(2),
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
        colorFilter: ColorFilter.mode(
          context.genesisColors.textPrimary,
          BlendMode.srcIn,
        ),
      );
    }
    return Icon(item.icon, size: 20, color: context.genesisColors.textPrimary);
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
