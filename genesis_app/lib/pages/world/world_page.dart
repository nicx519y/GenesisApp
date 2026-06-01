import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/secend_tabs.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_map_stage.dart';
import '../../components/world_tick_event_item.dart';
import '../../network/genesis_api.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../utils/stat_count_formatter.dart';

class WorldPage extends StatefulWidget {
  const WorldPage({super.key, required this.wid});

  final String wid;

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  WorldDetail? _world;
  Object? _initialLoadError;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _worldActionRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_fetchWorld(isInitial: true));
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_fetchWorld());
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(_fetchWorld());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchWorld({bool isInitial = false}) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final world = await AppServicesScope.read(
        context,
      ).api.getWorld(widget.wid);
      if (!mounted) return;
      setState(() {
        _world = world;
        if (isInitial) _initialLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (isInitial) {
        setState(() {
          _initialLoadError = e;
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _runWorldAction(_WorldHeaderActionKind action) async {
    if (_worldActionRunning) return;
    if (action == _WorldHeaderActionKind.launch) {
      final world = _world;
      if (world == null) return;
      await _showLaunchRoleSheet(world);
      return;
    }
    setState(() => _worldActionRunning = true);
    try {
      final api = AppServicesScope.of(context).api;
      final message = switch (action) {
        _WorldHeaderActionKind.request => await api.requestWorld(widget.wid),
        _WorldHeaderActionKind.progress => await api.progressWorld(widget.wid),
        _ => '',
      };
      if (!mounted) return;
      if (message.trim().isNotEmpty) {
        showGenesisToast(context, message);
      }
      await _fetchWorld();
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, '${_worldHeaderActionLabel(action)} failed');
    } finally {
      if (mounted) setState(() => _worldActionRunning = false);
    }
  }

  Future<void> _showLaunchRoleSheet(WorldDetail world) async {
    if (_worldActionRunning) return;
    final selection = await showOriginRoleLaunchSheet(
      context: context,
      characters: _worldPresetRoleCharacters(world),
      resolveAvatarUrl: _resolveAssetUrl,
      onFillFromProfile: _customRoleFromProfile,
    );
    if (!mounted || selection == null) return;
    await _joinApprovedWorld(world, selection);
  }

  Future<void> _joinApprovedWorld(
    WorldDetail world,
    OriginRoleLaunchSelection roleSelection,
  ) async {
    if (_worldActionRunning) return;
    setState(() => _worldActionRunning = true);
    try {
      final message = await AppServicesScope.of(context).api.joinApprovedWorld(
        world.worldId,
        presetCharacterId: roleSelection.presetCharacterId,
        customRole: roleSelection.customRole?.toPayload(),
      );
      if (!mounted) return;
      if (message.trim().isNotEmpty) {
        showGenesisToast(context, message);
      }
      await _fetchWorld();
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Launch failed');
    } finally {
      if (mounted) setState(() => _worldActionRunning = false);
    }
  }

  Future<OriginCustomRoleDraft?> _customRoleFromProfile() async {
    final services = AppServicesScope.read(context);
    final userInfo = await services.sessionStore.readUserInfo();
    final profile = services.identityAuth.currentProfile();
    if ((userInfo == null || userInfo.isEmpty) && profile == null) {
      if (mounted) {
        showGenesisToast(context, 'No saved profile found');
      }
      return null;
    }
    final cachedUser = userInfo ?? const <String, dynamic>{};
    final cachedAvatar = _mapString(cachedUser, const [
      'avatar',
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]);
    final profileAvatar = profile?.photoUrl.trim() ?? '';
    final cachedName = _mapString(cachedUser, const [
      'name',
      'nickname',
      'user_name',
      'displayName',
      'display_name',
    ]);
    final profileName = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : (profile?.email.trim() ?? '');
    return OriginCustomRoleDraft(
      avatarUrl: _resolveAssetUrl(
        cachedAvatar.isNotEmpty ? cachedAvatar : profileAvatar,
      ),
      name: cachedName.isNotEmpty ? cachedName : profileName,
      identity: _mapString(cachedUser, const ['identity']),
      bio: _mapString(cachedUser, const ['bio', 'description']),
    );
  }

  Future<void> _openChatForPoint(WorldPoint point) async {
    final pointId = point.pointId.trim().isNotEmpty
        ? point.pointId.trim()
        : point.id.trim();
    if (pointId.isEmpty) {
      Navigator.of(context).pushNamed(
        RouteNames.locationChat,
        arguments: {'world_id': widget.wid, 'world_name': _world?.name ?? ''},
      );
      return;
    }

    try {
      await AppServicesScope.of(
        context,
      ).api.updateUserPosition(wid: widget.wid, locationId: point.sceneId);
    } catch (_) {}

    if (!mounted) return;
    final locationId = point.sceneId.trim().isNotEmpty
        ? point.sceneId.trim()
        : pointId;
    Navigator.of(context).pushNamed(
      RouteNames.locationChat,
      arguments: {
        'world_id': widget.wid,
        'world_name': _world?.name ?? '',
        'location_id': locationId,
        'pointId': pointId,
        'location_name': point.name,
      },
    );
  }

  void _showMapTab() {
    if (_tabController.index == 0) return;
    _tabController.animateTo(
      0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final world = _world;
    if (world == null) {
      if (_initialLoadError != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _fetchWorld(isInitial: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final rootMapImageUrl = _rootWorldMapImageUrl(world);
    final avatarsByLocation = _avatarsByLocationFromCharacterPositions(
      world.characterPositions,
    );
    final processedLocationTree = world.processedLocationTree;
    final rootLocationNodes = processedLocationTree.mapRoots;
    final renderLocationNodes = processedLocationTree.renderRoots;
    final allLocationNodes = processedLocationTree.flattened;
    final locationNodes = _worldMapLocationNodes(
      rootLocationNodes,
      avatarsByLocation,
      processedLocationTree,
    );
    final points = renderLocationNodes.isNotEmpty
        ? _pointsFromWorldLocationNodes(
            renderLocationNodes,
            avatarsByLocation,
            processedLocationTree,
          )
        : world.locations.isNotEmpty
        ? _pointsFromWorldLocations(
            _rootWorldLocations(world.locations),
            avatarsByLocation,
          )
        : _pointsFromLocationIds(
            world.characterPositions
                .map((e) => e['location_id'])
                .followedBy(world.userPositions.map((e) => e['location_id']))
                .toList(growable: false),
            avatarsByLocation,
          );
    final listPoints = allLocationNodes.isNotEmpty
        ? _pointsFromWorldLocationNodes(
            allLocationNodes,
            avatarsByLocation,
            processedLocationTree,
          )
        : world.locations.isNotEmpty
        ? _pointsFromWorldLocations(world.locations, avatarsByLocation)
        : points;
    return WorldDetailsPageScaffold(
      panelTopGap: 50,
      panelCollapsedHeightOffset: 100,
      map: WorldMapStage(
        controller: _tabController,
        pointsCount: listPoints.length,
        top: topPadding + 20,
        mapBuilder: (context, pointMode) => WorldMap(
          points: points,
          listPoints: listPoints,
          locationNodes: locationNodes,
          mapImageUrl: rootMapImageUrl,
          dimmed: pointMode,
          showPointsList: pointMode,
          overlayTop: topPadding + 8 + 48,
          drillExitTop: topPadding + 68,
          onDrillIntoLocation: _showMapTab,
          onPointTap: (point) => unawaited(_openChatForPoint(point)),
        ),
      ),
      slivers: [
        _WorldFeedContent(
          world: world,
          worldActionRunning: _worldActionRunning,
          onWorldAction: _runWorldAction,
        ),
      ],
    );
  }
}

class _WorldFeedContent extends StatefulWidget {
  const _WorldFeedContent({
    required this.world,
    required this.worldActionRunning,
    required this.onWorldAction,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final Future<void> Function(_WorldHeaderActionKind action) onWorldAction;

  @override
  State<_WorldFeedContent> createState() => _WorldFeedContentState();
}

class _WorldFeedContentState extends State<_WorldFeedContent>
    with SingleTickerProviderStateMixin {
  late final TabController _sectionController;
  var _currentUid = '';
  var _currentUidRequested = false;

  @override
  void initState() {
    super.initState();
    _sectionController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentUidRequested) return;
    _currentUidRequested = true;
    unawaited(_loadCurrentUid());
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _WorldInfoHeader(
                world: widget.world,
                worldActionRunning: widget.worldActionRunning,
                onWorldAction: widget.onWorldAction,
              ),
              const SizedBox(height: 4),
              SecendTabs(
                controller: _sectionController,
                labels: const ['Events', 'Status', 'Characters'],
                horizontalPadding: 0,
                labelPadding: EdgeInsets.zero,
                expanded: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _AutoSizedTabBarView(
            controller: _sectionController,
            children: [
              _WorldEventsSection(world: widget.world),
              _WorldStatusSection(world: widget.world, currentUid: _currentUid),
              _WorldCharactersSection(
                world: widget.world,
                currentUid: _currentUid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoSizedTabBarView extends StatefulWidget {
  const _AutoSizedTabBarView({
    required this.controller,
    required this.children,
  });

  final TabController controller;
  final List<Widget> children;

  @override
  State<_AutoSizedTabBarView> createState() => _AutoSizedTabBarViewState();
}

class _AutoSizedTabBarViewState extends State<_AutoSizedTabBarView> {
  static const double _tabPageGap = 14;

  final Map<int, double> _childHeights = <int, double>{};

  @override
  void initState() {
    super.initState();
    widget.controller.animation?.addListener(_handleTabAnimation);
  }

  @override
  void didUpdateWidget(covariant _AutoSizedTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.animation?.removeListener(_handleTabAnimation);
      widget.controller.animation?.addListener(_handleTabAnimation);
    }
  }

  @override
  void dispose() {
    widget.controller.animation?.removeListener(_handleTabAnimation);
    super.dispose();
  }

  void _handleTabAnimation() {
    if (mounted) setState(() {});
  }

  void _updateChildHeight(int index, Size size) {
    final height = size.height;
    if ((_childHeights[index] ?? -1) == height) return;
    setState(() => _childHeights[index] = height);
  }

  double? get _currentHeight {
    final animationValue =
        widget.controller.animation?.value ??
        widget.controller.index.toDouble();
    final lowerIndex = animationValue.floor().clamp(
      0,
      widget.children.length - 1,
    );
    final upperIndex = animationValue.ceil().clamp(
      0,
      widget.children.length - 1,
    );
    final lowerHeight = _childHeights[lowerIndex];
    final upperHeight = _childHeights[upperIndex] ?? lowerHeight;
    final selectedHeight = _childHeights[widget.controller.index];
    if (lowerHeight == null || upperHeight == null) {
      return selectedHeight ?? lowerHeight ?? upperHeight;
    }
    return lowerHeight + (upperHeight - lowerHeight) * animationValue.frac();
  }

  @override
  Widget build(BuildContext context) {
    final currentHeight = _currentHeight;
    final measuringChildren = [
      for (int index = 0; index < widget.children.length; index++)
        Offstage(
          offstage: true,
          child: _MeasureSize(
            onChange: (size) => _updateChildHeight(index, size),
            child: widget.children[index],
          ),
        ),
    ];

    if (currentHeight == null) {
      return Column(
        children: [
          ...measuringChildren,
          widget.children[widget.controller.index],
        ],
      );
    }

    return Column(
      children: [
        ...measuringChildren,
        ClipRect(
          child: SizedBox(
            height: currentHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final expandedWidth = constraints.maxWidth + _tabPageGap * 2;
                return OverflowBox(
                  minWidth: expandedWidth,
                  maxWidth: expandedWidth,
                  alignment: Alignment.center,
                  child: TabBarView(
                    controller: widget.controller,
                    children: [
                      for (
                        int index = 0;
                        index < widget.children.length;
                        index++
                      )
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _tabPageGap,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _UnboundedHeightTabPage(
                              child: KeyedSubtree(
                                key: PageStorageKey<String>(
                                  'world-section-$index',
                                ),
                                child: widget.children[index],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UnboundedHeightTabPage extends StatelessWidget {
  const _UnboundedHeightTabPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.child, required this.onChange});

  final Widget child;
  final ValueChanged<Size> onChange;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final size = renderObject.size;
      if (_oldSize == size) return;
      _oldSize = size;
      widget.onChange(size);
    });
    return widget.child;
  }
}

extension on double {
  double frac() {
    return this - floorToDouble();
  }
}

class _WorldInfoHeader extends StatelessWidget {
  const _WorldInfoHeader({
    required this.world,
    required this.worldActionRunning,
    required this.onWorldAction,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final Future<void> Function(_WorldHeaderActionKind action) onWorldAction;

  @override
  Widget build(BuildContext context) {
    final title = world.origin.name.isEmpty ? world.name : world.origin.name;
    final wid = world.worldId;
    final owner = world.origin.originator.trim().isNotEmpty
        ? world.origin.originator.trim()
        : world.ownerUid;
    final ownerUid = world.ownerUid.trim();
    final action = _worldHeaderActionFor(world.relationStatus);
    final actionEnabled = !worldActionRunning && action.isClickable;
    final counters = <Map<String, dynamic>>[
      {'icon': 'tick', 'value': world.tickCount},
      {'icon': 'connect', 'value': world.connectCount},
      {'icon': 'character', 'value': world.characterCount},
      {'icon': 'player', 'value': world.playerCount},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 38),
            Expanded(
              child: Text(
                '#$title',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B6192),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(
              width: 38,
              child: Icon(
                Icons.more_horiz_sharp,
                size: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _WidMetaText(
                wid: wid,
                onCopy: () => _copyWid(context, wid),
              ),
            ),
            _OwnerMetaLink(
              owner: owner,
              onTap: ownerUid.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      RouteNames.userInfo,
                      arguments: {'uid': ownerUid},
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final data in counters)
                    StatItem(
                      icon: _counterIcon(data['icon'] as String? ?? ''),
                      iconSize: 11,
                      iconColor: Colors.black,
                      text: formatStatCount(
                        data['value'] is num ? data['value'] as num : 0,
                      ),
                      gap: 4,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
            // const Spacer(),
            SizedBox(
              width: 120,
              height: 28,
              child: FilledButton(
                onPressed: actionEnabled
                    ? () => onWorldAction(action.kind)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F9663),
                  disabledBackgroundColor: const Color(
                    0xFF2F9663,
                  ).withValues(alpha: 0.62),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: worldActionRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Center(
                        child: Text(
                          action.label,
                          strutStyle: const StrutStyle(
                            fontSize: 14,
                            height: 1,
                            forceStrutHeight: true,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _WorldHeaderActionKind { request, pending, launch, progress, unavailable }

class _WorldHeaderAction {
  const _WorldHeaderAction(this.kind, this.label, this.isClickable);

  final _WorldHeaderActionKind kind;
  final String label;
  final bool isClickable;
}

_WorldHeaderAction _worldHeaderActionFor(String relationStatus) {
  switch (relationStatus.trim().toLowerCase()) {
    case 'anonymous':
    case 'rejected':
    case 'none':
      return const _WorldHeaderAction(
        _WorldHeaderActionKind.request,
        'Request',
        true,
      );
    case 'pending':
      return const _WorldHeaderAction(
        _WorldHeaderActionKind.pending,
        'pending',
        false,
      );
    case 'approved':
      return const _WorldHeaderAction(
        _WorldHeaderActionKind.launch,
        'Launch',
        true,
      );
    case 'owner':
    case 'joined':
      return const _WorldHeaderAction(
        _WorldHeaderActionKind.progress,
        'Progress',
        true,
      );
    default:
      return const _WorldHeaderAction(
        _WorldHeaderActionKind.unavailable,
        'Unavailable',
        false,
      );
  }
}

String _worldHeaderActionLabel(_WorldHeaderActionKind action) {
  switch (action) {
    case _WorldHeaderActionKind.request:
      return 'Request';
    case _WorldHeaderActionKind.launch:
      return 'Launch';
    case _WorldHeaderActionKind.progress:
      return 'Progress';
    case _WorldHeaderActionKind.pending:
      return 'pending';
    case _WorldHeaderActionKind.unavailable:
      return 'Unavailable';
  }
}

class _WidMetaText extends StatelessWidget {
  const _WidMetaText({required this.wid, required this.onCopy});

  final String wid;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'WID: $wid',
            style: const TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8A8A8A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        InkResponse(
          onTap: onCopy,
          radius: 18,
          child: const Icon(
            Icons.copy_outlined,
            size: 16,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ],
    );
  }
}

class _OwnerMetaLink extends StatelessWidget {
  const _OwnerMetaLink({required this.owner, required this.onTap});

  final String owner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                'Owner: $owner',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A8A8A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF8A8A8A)),
          ],
        ),
      ),
    );
  }
}

IconData _counterIcon(String key) {
  switch (key) {
    case 'tick':
      return MyFlutterApp.pregress;
    case 'connect':
      return MyFlutterApp.copy;
    case 'character':
      return MyFlutterApp.userStar;
    case 'player':
      return MyFlutterApp.user;
    default:
      return Icons.circle_outlined;
  }
}

Future<void> _copyWid(BuildContext context, String wid) async {
  await Clipboard.setData(ClipboardData(text: wid));
  if (!context.mounted) return;
  showGenesisToast(context, 'WID copied');
}

class _WorldEventsSection extends StatelessWidget {
  const _WorldEventsSection({required this.world});

  final WorldDetail world;

  @override
  Widget build(BuildContext context) {
    final ticks = world.ticks;
    if (ticks.isEmpty) {
      return const _EmptySection(text: 'No events yet.');
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in world.locations)
        _mapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final fallbackBody = _eventBody(world);

    return Column(
      children: [
        for (int index = 0; index < ticks.length; index++)
          WorldTickEventItem(
            tick: ticks[index],
            tickNumber: worldTickEventNumber(ticks[index], fallback: index + 1),
            fallbackBody: fallbackBody,
            locationsById: locationsById,
            isLast: index == ticks.length - 1,
          ),
      ],
    );
  }
}

class _WorldStatusSection extends StatelessWidget {
  const _WorldStatusSection({required this.world, required this.currentUid});

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return _CharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No character status yet.',
      subtitleBuilder: _metricPercentText,
    );
  }
}

class _WorldCharactersSection extends StatelessWidget {
  const _WorldCharactersSection({
    required this.world,
    required this.currentUid,
  });

  final WorldDetail world;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return _CharacterList(
      characters: world.characters,
      currentUid: currentUid,
      emptyText: 'No characters yet.',
      subtitleBuilder: _characterDescriptionText,
    );
  }
}

class _CharacterList extends StatelessWidget {
  const _CharacterList({
    required this.characters,
    required this.currentUid,
    required this.emptyText,
    required this.subtitleBuilder,
  });

  final List<Map<String, dynamic>> characters;
  final String currentUid;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) {
      return _EmptySection(text: emptyText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < characters.length; i++) ...[
          _CharacterRow(
            character: characters[i],
            currentUid: currentUid,
            subtitle: subtitleBuilder(characters[i]),
          ),
          if (i != characters.length - 1) const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({
    required this.character,
    required this.currentUid,
    required this.subtitle,
  });

  final Map<String, dynamic> character;
  final String currentUid;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final name = _mapString(character, const ['name'], fallback: 'Character');
    final playerUid = _mapString(character, const ['player_uid']);
    final displayName =
        currentUid.isNotEmpty && playerUid.isNotEmpty && playerUid == currentUid
        ? '$name (Me)'
        : name;
    final type = _mapString(character, const ['type']).toLowerCase();
    final isAi = type == 'ai';
    final roleLabel = isAi ? 'Character' : 'Player';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GenesisCharacterAvatar(
          url: _mapString(character, const ['avatar']),
          name: name,
          showStar: isAi,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      roleLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8F8F8F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6F6F6F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}

String _eventBody(WorldDetail world) {
  final candidates = [
    world.latestNarrator,
    world.origin.worldView,
    world.origin.description,
    world.name,
  ];
  for (final item in candidates) {
    final value = item.trim();
    if (value.isNotEmpty) return value;
  }
  return 'No world events yet.';
}

String _characterDescriptionText(Map<String, dynamic> character) {
  return _mapString(character, const [
    'brief',
    'description',
    'identity',
  ], fallback: 'No character details yet.');
}

String _metricPercentText(Map<String, dynamic> character) {
  final value = character['metric_value'];
  if (value is num) {
    final text = value % 1 == 0 ? value.toInt().toString() : value.toString();
    return '$text%';
  }

  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0%';
  return text.endsWith('%') ? text : '$text%';
}

String _mapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _resolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

List<OriginCharacter> _worldPresetRoleCharacters(WorldDetail world) {
  return world.characters
      .where(_isAvailablePresetWorldRole)
      .map((character) {
        final charId = _mapString(character, const [
          'char_id',
          'character_id',
          'id',
        ]);
        final locationId = _mapString(character, const [
          'location_id',
          'initial_location_id',
        ]);
        final locationInt = int.tryParse(locationId) ?? 0;
        return OriginCharacter(
          id: int.tryParse(charId) ?? 0,
          characterId: charId,
          originId: world.originId,
          name: _mapString(character, const ['name'], fallback: 'Character'),
          avatar: _mapString(character, const ['avatar']),
          tags: _mapString(character, const ['identity']),
          tagline: _mapString(character, const ['brief']),
          description: _mapString(character, const ['description', 'brief']),
          goal: _mapString(character, const ['goal']),
          currentLocationId: locationInt,
          initialLocationId: locationInt,
          createdAt: null,
          updatedAt: null,
        );
      })
      .toList(growable: false);
}

bool _isAvailablePresetWorldRole(Map<String, dynamic> character) {
  final charId = _mapString(character, const ['char_id', 'character_id', 'id']);
  if (charId.isEmpty) return false;
  final type = _mapString(character, const ['type']).toLowerCase();
  final playerUid = _mapString(character, const ['player_uid']);
  return playerUid.isEmpty && (type.isEmpty || type == 'ai');
}

String _rootWorldMapImageUrl(WorldDetail world) {
  return _resolveAssetUrl(
    world.origin.worldMap.isEmpty
        ? world.origin.mapImage
        : world.origin.worldMap,
  );
}

List<WorldPoint> _pointsFromWorldLocationNodes(
  List<LocationTreeNode<Map<String, dynamic>>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<Map<String, dynamic>> processedLocationTree,
) {
  return _pointsFromWorldLocations(
    nodes.map((node) => node.value).toList(growable: false),
    avatarsByLocation,
    depths: nodes.map((node) => node.depth).toList(growable: false),
    isLeafLocations: nodes
        .map((node) => node.children.isEmpty)
        .toList(growable: false),
    usersByIndex: nodes
        .map(
          (node) => processedLocationTree.aggregateValues<UserAvatar>(
            node.id,
            avatarsByLocation,
            idOf: _userAvatarStableId,
          ),
        )
        .toList(growable: false),
  );
}

List<WorldMapLocationNode> _worldMapLocationNodes(
  List<LocationTreeNode<Map<String, dynamic>>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<Map<String, dynamic>> processedLocationTree,
) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: node.id == processedLocationTree.root?.id,
          point: _pointsFromWorldLocationNodes(
            [node],
            avatarsByLocation,
            processedLocationTree,
          ).first,
          mapImageUrl: _locationMapImageUrl(node.value),
          children: _worldMapLocationNodes(
            node.children,
            avatarsByLocation,
            processedLocationTree,
          ),
        );
      })
      .toList(growable: false);
}

String _locationMapImageUrl(
  Map<String, dynamic> location, {
  String fallback = '',
}) {
  final url = _resolveAssetUrl(
    _mapString(location, const ['map_url', 'mapUrl']),
  );
  return url.isEmpty ? fallback : url;
}

Map<String, List<UserAvatar>> _avatarsByLocationFromCharacterPositions(
  List<Map<String, dynamic>> characterPositions,
) {
  final map = <String, List<UserAvatar>>{};
  for (final cp in characterPositions) {
    final rawLocationId = cp['location_id'] ?? cp['current_location_id'];
    final locationId = '$rawLocationId'.trim();
    if (locationId.isEmpty) continue;
    final character = cp['character'];
    if (character is! Map) continue;
    final c = character.map((key, value) => MapEntry('$key', value));
    final name = (c['name'] ?? '').toString();
    final avatar = _resolveAssetUrl((c['avatar'] ?? '').toString());
    final isAi = '${c['type'] ?? ''}'.trim().toLowerCase() == 'ai';
    final id = _mapString(c, const [
      'character_id',
      'char_id',
      'id',
      'uid',
      'player_uid',
    ]);
    (map[locationId] ??= <UserAvatar>[]).add(
      UserAvatar(
        _initials(name),
        id: id,
        name: name,
        avatarUrl: avatar,
        showStar: isAi,
      ),
    );
  }
  return map;
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return '?';
  final parts = cleaned
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}

List<Map<String, dynamic>> _rootWorldLocations(
  List<Map<String, dynamic>> locations,
) {
  return locations
      .where((location) => _mapString(location, const ['location_pid']).isEmpty)
      .toList(growable: false);
}

List<WorldPoint> _pointsFromWorldLocations(
  List<Map<String, dynamic>> locations,
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
  List<bool>? isLeafLocations,
  List<List<UserAvatar>>? usersByIndex,
}) {
  if (locations.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = '${l['location_id'] ?? ''}'.trim();
    final pointId = '${l['point_id'] ?? locationId}'.trim();
    final id = pointId.isNotEmpty
        ? pointId
        : (locationId.isNotEmpty ? locationId : '$i');
    final name = (l['location_name'] ?? '').toString();
    final locationSummary = _mapString(l, const ['location_summary']);
    final locationDescription = _mapString(l, const ['location_description']);
    final description = locationSummary.isNotEmpty ? locationSummary : '';
    final descriptionFallback = locationDescription;
    final icon = _resolveAssetUrl((l['icon'] ?? '').toString());

    final rawXP = l['x_percent'];
    final rawYP = l['y_percent'];
    final xPercent = rawXP is num
        ? rawXP.toDouble()
        : double.tryParse('$rawXP') ?? 0;
    final yPercent = rawYP is num
        ? rawYP.toDouble()
        : double.tryParse('$rawYP') ?? 0;

    double? dx;
    double? dy;
    if (xPercent > 0 && yPercent > 0) {
      dx = xPercent / 100;
      dy = yPercent / 100;
    } else {
      final posX = l['x'] ?? l['pos_x'] ?? l['position_x'];
      final posY = l['y'] ?? l['pos_y'] ?? l['position_y'];
      dx = posX is num ? posX.toDouble() : double.tryParse('$posX');
      dy = posY is num ? posY.toDouble() : double.tryParse('$posY');
    }

    if (dx == null || dy == null) {
      final positionRaw = l['position'];
      final position = positionRaw is int
          ? positionRaw
          : int.tryParse('$positionRaw');
      final index = (position == null || position <= 0) ? i : (position - 1);
      final col = index % 3;
      final row = index ~/ 3;
      dx = 0.18 + col * 0.30;
      dy = 0.22 + row * 0.22;
    }

    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: usersByIndex == null || i >= usersByIndex.length
          ? (avatarsByLocation[locationId] ?? const <UserAvatar>[])
          : usersByIndex[i],
      sceneId: locationId,
      pointId: pointId,
      iconUrl: icon,
      description: description,
      locationDescription: descriptionFallback,
      depth: depths == null || i >= depths.length ? 0 : depths[i],
      isLeafLocation: isLeafLocations == null || i >= isLeafLocations.length
          ? true
          : isLeafLocations[i],
    );
  });
}

String _userAvatarStableId(UserAvatar avatar) {
  final id = avatar.id.trim();
  if (id.isNotEmpty) return id;
  return '${avatar.name ?? ''}|${avatar.avatarUrl}|${avatar.initials}';
}

List<WorldPoint> _pointsFromLocationIds(
  List<dynamic> locationIds,
  Map<String, List<UserAvatar>> avatarsByLocation,
) {
  final ids =
      locationIds
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort((a, b) => a.compareTo(b));

  if (ids.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(ids.length, (i) {
    final id = ids[i];
    final col = i % 3;
    final row = i ~/ 3;
    final dx = 0.18 + col * 0.30;
    final dy = 0.22 + row * 0.22;
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };

    return WorldPoint(
      id: id,
      name: 'Location $id',
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: (avatarsByLocation[id] ?? const <UserAvatar>[]),
      sceneId: id,
      pointId: id,
      description: '',
    );
  });
}
