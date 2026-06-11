import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/icons/my_flutter_app_icons.dart';

import '../../components/common/copyable_id_label.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_map_stage.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/secend_tabs.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../chat/location_chat_page.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';

const String _connectIconAsset = 'assets/custom-icons/png/connect.png';

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
  WorldChatroomService? _worldChatroom;
  StreamSubscription<WorldChatroomState>? _worldChatroomSub;
  StreamSubscription? _worldChatroomFailureSub;
  Map<String, _LocationChatPanelDescriptor> _locationChatDescriptors =
      <String, _LocationChatPanelDescriptor>{};
  final Set<String> _cachedLocationChatIds = <String>{};
  final Set<String> _readyLocationChatIds = <String>{};
  String _activeChatLocationId = '';
  bool _pollInFlight = false;
  bool _worldActionRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_fetchWorld(isInitial: true));
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(_fetchWorld());
  }

  @override
  void dispose() {
    unawaited(_worldChatroomSub?.cancel());
    unawaited(_worldChatroomFailureSub?.cancel());
    final chatroom = _worldChatroom;
    _worldChatroom = null;
    if (chatroom != null) {
      unawaited(_disposeWorldChatroom(chatroom));
    }
    _tabController.dispose();
    super.dispose();
  }

  void _startWorldChatroom() {
    if (_worldChatroom != null) return;
    final services = AppServicesScope.read(context);
    final service = WorldChatroomService(
      api: services.api,
      client: services.chatroom,
      messageStorage: services.chatroomMessages,
      refreshInitialSnapshotOnConnect: false,
    );
    _worldChatroom = service;
    _worldChatroomSub = service.states.listen(_handleWorldChatroomState);
    _worldChatroomFailureSub = bindChatroomFailureToast(
      context,
      service.failures,
      shouldShow: (failure) => failure.code != 'snapshot_failed',
    );
    final world = _world;
    if (world != null) {
      service.applyWorldSnapshot(world);
    }
    unawaited(_connectWorldChatroom(service, services));
  }

  void _handleWorldChatroomState(WorldChatroomState state) {
    if (!mounted) return;
    final world = state.world;
    var shouldSyncRelationStatus = false;
    setState(() {
      if (world != null && !identical(_world, world)) {
        _world = world;
        _syncLocationChatDescriptors(world);
        shouldSyncRelationStatus = true;
      }
    });
    if (shouldSyncRelationStatus) {
      _syncWorldChatroomForRelationStatus(world!.relationStatus);
    }
  }

  void _syncWorldChatroomForRelationStatus(String relationStatus) {
    if (_shouldConnectWorldChatroom(relationStatus)) {
      _startWorldChatroom();
      return;
    }
    _stopWorldChatroom();
  }

  void _stopWorldChatroom() {
    final chatroom = _worldChatroom;
    if (chatroom == null) return;
    unawaited(_worldChatroomSub?.cancel());
    unawaited(_worldChatroomFailureSub?.cancel());
    _worldChatroomSub = null;
    _worldChatroomFailureSub = null;
    _worldChatroom = null;
    if (mounted) {
      setState(() {
        _activeChatLocationId = '';
        _cachedLocationChatIds.clear();
        _readyLocationChatIds.clear();
      });
    }
    unawaited(_disposeWorldChatroom(chatroom));
  }

  Future<void> _connectWorldChatroom(
    WorldChatroomService service,
    AppServices services,
  ) async {
    try {
      final identity = await _chatroomIdentity(services);
      if (!mounted || !identical(_worldChatroom, service)) return;
      await service.connect(worldId: widget.wid, identity: identity);
    } catch (_) {
      // The service emits failures and keeps reconnecting while desired.
    }
  }

  Future<ChatroomConnectionIdentity> _chatroomIdentity(
    AppServices services,
  ) async {
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await services.sessionStore.readUserInfo();
    final cachedUid = userInfo == null
        ? ''
        : _mapString(userInfo, const ['uid']);
    final profile = services.identityAuth.currentProfile();
    final senderId = _firstNonEmpty([
      uid,
      cachedUid,
      profile?.uid,
      'local-user',
    ]);
    final senderName = _firstNonEmpty([
      profile?.displayName,
      profile?.email,
      formatUidForDisplay(uid),
      'Me',
    ]);
    return ChatroomConnectionIdentity(
      userId: senderId,
      senderId: senderId,
      senderName: senderName,
    );
  }

  Future<void> _disposeWorldChatroom(WorldChatroomService service) async {
    try {
      await service.disconnect();
    } catch (_) {
      // Leaving the page should not be blocked by socket shutdown errors.
    }
    await service.dispose();
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
        _syncLocationChatDescriptors(world);
      });
      _syncWorldChatroomForRelationStatus(world.relationStatus);
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
    final chatroom = _worldChatroom;
    if (!_canOpenLocationChat(chatroom)) {
      if (mounted) {
        showGenesisToast(context, _chatroomStatusLabel(chatroom?.state));
      }
      return;
    }
    final pointId = point.pointId.trim().isNotEmpty
        ? point.pointId.trim()
        : point.id.trim();
    final locationId = point.sceneId.trim().isNotEmpty
        ? point.sceneId.trim()
        : pointId;
    if (locationId.isEmpty) return;

    final descriptor = _LocationChatPanelDescriptor(
      locationId: locationId,
      locationName: point.name,
      isLeafLocation: point.isLeafLocation,
      localMessageLocationIds: _orderedNonEmptyStrings([
        pointId,
        locationId,
        point.id,
      ]),
    );
    unawaited(_updateUserPositionForLocation(locationId));
    await _showCachedLocationChat(descriptor);
  }

  Future<void> _updateUserPositionForLocation(String locationId) async {
    try {
      await AppServicesScope.of(
        context,
      ).api.updateUserPosition(wid: widget.wid, locationId: locationId);
    } catch (_) {
      // Position updates are opportunistic and must not delay opening chat.
    }
  }

  Future<void> _showCachedLocationChat(
    _LocationChatPanelDescriptor descriptor,
  ) async {
    final locationId = descriptor.locationId;
    if (locationId.isEmpty) return;
    final wasCached = _cachedLocationChatIds.contains(locationId);
    final stopwatch = _locationChatMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final previousActiveId = _activeChatLocationId;
    _logLocationChatMetric(
      'open start location=$locationId cached=$wasCached '
      'previous=${previousActiveId.isEmpty ? 'none' : previousActiveId} '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    if (previousActiveId.isNotEmpty && previousActiveId != locationId) {
      if (!descriptor.isLeafLocation) {
        unawaited(_leaveCachedLocationChat(previousActiveId));
      }
    }
    setState(() {
      _locationChatDescriptors[locationId] = descriptor;
      if (wasCached) {
        _cachedLocationChatIds.add(locationId);
      } else {
        _readyLocationChatIds.remove(locationId);
      }
      _activeChatLocationId = locationId;
    });
    unawaited(_hydrateActiveLocationChatMessages(descriptor));
    await WidgetsBinding.instance.endOfFrame;
    if (!wasCached && mounted && _activeChatLocationId == locationId) {
      _logLocationChatMetric(
        'build panel after first frame location=$locationId',
      );
      setState(() {
        _cachedLocationChatIds.add(locationId);
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    _logLocationChatMetric(
      'open location=$locationId cached=$wasCached '
      'previous=${previousActiveId.isEmpty ? 'none' : previousActiveId} '
      'active=$_activeChatLocationId elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
  }

  Future<void> _hydrateActiveLocationChatMessages(
    _LocationChatPanelDescriptor descriptor,
  ) async {
    final stopwatch = _locationChatMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final chatroom = _worldChatroom;
    final identity = chatroom?.identity;
    if (chatroom == null || identity == null) {
      _logLocationChatMetric(
        'active hydrate skipped location=${descriptor.locationId} '
        'hasChatroom=${chatroom != null} hasIdentity=${identity != null}',
      );
      return;
    }
    final ownerUid = _firstNonEmpty([identity.userId, identity.senderId]);
    if (ownerUid.isEmpty) {
      _logLocationChatMetric(
        'active hydrate skipped location=${descriptor.locationId} noOwner',
      );
      return;
    }
    _logLocationChatMetric(
      'active hydrate start location=${descriptor.locationId} '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    await chatroom.hydrateLocalMessages(
      worldId: widget.wid,
      locationId: descriptor.locationId,
      ownerUid: ownerUid,
      locationAliases: descriptor.localMessageLocationIds,
    );
    _logLocationChatMetric(
      'active hydrate done location=${descriptor.locationId} '
      'stateCount=${chatroom.state.messagesByLocation[descriptor.locationId]?.length ?? 0} '
      'elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
  }

  void _closeCachedLocationChat() {
    final locationId = _activeChatLocationId;
    if (locationId.isEmpty) return;
    unawaited(_leaveCachedLocationChat(locationId));
    setState(() {
      _activeChatLocationId = '';
    });
  }

  void _handleWorldPopBlocked() {
    if (_activeChatLocationId.isEmpty) return;
    _closeCachedLocationChat();
  }

  Future<void> _leaveCachedLocationChat(String locationId) async {
    final descriptor = _locationChatDescriptors[locationId];
    final chatroom = _worldChatroom;
    if (descriptor?.isLeafLocation != true || chatroom == null) return;
    if (chatroom.state.joinedLocationId != locationId) return;
    try {
      await chatroom.leave();
    } catch (_) {
      // Closing or switching cached panels should not surface leave failures.
    }
  }

  void _syncLocationChatDescriptors(WorldDetail world) {
    final descriptors = _locationChatDescriptorsForWorld(world);
    _locationChatDescriptors = descriptors;
    _cachedLocationChatIds.removeWhere(
      (locationId) => !descriptors.containsKey(locationId),
    );
    _readyLocationChatIds.removeWhere(
      (locationId) => !descriptors.containsKey(locationId),
    );
    if (!_locationChatDescriptors.containsKey(_activeChatLocationId)) {
      _activeChatLocationId = '';
    }
    _scheduleLocationChatPrecache(descriptors.keys.toList(growable: false));
  }

  Map<String, _LocationChatPanelDescriptor> _locationChatDescriptorsForWorld(
    WorldDetail world,
  ) {
    final nodes = world.processedLocationTree.flattened;
    if (nodes.isNotEmpty) {
      return {
        for (final node in nodes)
          if (node.id.trim().isNotEmpty)
            node.id.trim(): _LocationChatPanelDescriptor.fromNode(node),
      };
    }

    final parentIds = world.locations
        .map((location) => _mapString(location, const ['location_pid']))
        .where((locationId) => locationId.isNotEmpty)
        .toSet();
    return {
      for (final location in world.locations)
        if (_mapString(location, const ['location_id', 'id']).isNotEmpty)
          _mapString(location, const [
            'location_id',
            'id',
          ]): _LocationChatPanelDescriptor.fromLocation(
            location,
            isLeafLocation: !parentIds.contains(
              _mapString(location, const ['location_id', 'id']),
            ),
          ),
    };
  }

  void _scheduleLocationChatPrecache(List<String> locationIds) {
    _logLocationChatMetric(
      'panel precache skipped count=${locationIds.length} '
      'cached=${_cachedLocationChatIds.length}',
    );
  }

  bool get _locationChatMetricsEnabled => kDebugMode || kProfileMode;

  void _logLocationChatMetric(String message) {
    if (!_locationChatMetricsEnabled) return;
    debugPrint('[World][LocationChatCache] $message');
  }

  Widget? _buildLocationChatOverlay() {
    final chatroom = _worldChatroom;
    final activeLocationId = _activeChatLocationId;
    final activeDescriptor = _locationChatDescriptors[activeLocationId];
    final showSkeleton =
        activeLocationId.isNotEmpty &&
        activeDescriptor != null &&
        !_readyLocationChatIds.contains(activeLocationId);
    if (chatroom == null && !showSkeleton) return null;
    final cachedIds = _cachedLocationChatIds
        .where(_locationChatDescriptors.containsKey)
        .toList(growable: false);
    if (cachedIds.isEmpty && !showSkeleton) return null;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: activeLocationId.isEmpty,
        child: Stack(
          children: [
            if (chatroom != null)
              for (final locationId in cachedIds)
                _buildCachedLocationChatPanel(
                  _locationChatDescriptors[locationId]!,
                  chatroom,
                ),
            if (showSkeleton)
              Positioned.fill(
                child: _LocationChatPanelSkeleton(
                  title: activeDescriptor.locationName,
                  onBack: _closeCachedLocationChat,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedLocationChatPanel(
    _LocationChatPanelDescriptor descriptor,
    WorldChatroomService chatroom,
  ) {
    final active = descriptor.locationId == _activeChatLocationId;
    final visible =
        active && _readyLocationChatIds.contains(descriptor.locationId);
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: Opacity(
          opacity: visible ? 1 : 0,
          child: TickerMode(
            enabled: active,
            child: SizedBox.expand(
              child: LocationChatPanel(
                key: ValueKey('world-location-chat-${descriptor.locationId}'),
                worldId: widget.wid,
                locationId: descriptor.locationId,
                locationName: descriptor.locationName,
                isLeafLocation: descriptor.isLeafLocation,
                localMessageLocationIds: descriptor.localMessageLocationIds,
                service: chatroom,
                active: active,
                leaveOnInactive: false,
                onBack: _closeCachedLocationChat,
                onInitialContentReady: () =>
                    _markLocationChatPanelReady(descriptor.locationId),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _markLocationChatPanelReady(String locationId) {
    if (!mounted || !_locationChatDescriptors.containsKey(locationId)) return;
    if (!_readyLocationChatIds.add(locationId)) return;
    _logLocationChatMetric('panel ready location=$locationId');
    setState(() {});
  }

  bool _canOpenLocationChat(WorldChatroomService? service) {
    return service != null;
  }

  String _chatroomStatusLabel(WorldChatroomState? state) {
    if (state == null) return 'Disconnect';
    if (state.reconnecting) return 'Reconnecting';
    if (state.connected) return 'Connected';
    return 'Connecting';
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
      return WorldDetailsPageScaffold(
        panelTopGap: 50,
        panelCollapsedHeightOffset: 100,
        persistentTopOverlay: _buildPersistentMapTabs(0, topPadding + 8),
        map: WorldMapStage(
          controller: _tabController,
          pointsCount: 0,
          top: topPadding + 8,
          showTopOverlay: false,
          mapBuilder: (context, pointMode) => WorldMap(
            points: const <WorldPoint>[],
            listPoints: const <WorldPoint>[],
            locationNodes: const <WorldMapLocationNode>[],
            fallbackOnEmptyMapUrl: false,
            dimmed: pointMode,
            showPointsList: pointMode,
            overlayTop: topPadding + 8 + 48,
            drillExitTop: topPadding + 68,
          ),
        ),
        slivers: const [_WorldDetailsLoadingContent()],
      );
    }

    final avatarsByLocation = _avatarsByLocationFromCharacterPositions(
      world.characterPositions,
    );
    final processedLocationTree = world.processedLocationTree;
    final rootLocationNodes = processedLocationTree.mapRoots;
    final rootMapImageUrl = _rootWorldMapImageUrl(rootLocationNodes);
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
    return PopScope(
      canPop: _activeChatLocationId.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWorldPopBlocked();
      },
      child: WorldDetailsPageScaffold(
        panelTopGap: 50,
        panelCollapsedHeightOffset: 100,
        topOverlay: _buildLocationChatOverlay(),
        persistentTopOverlay: _buildPersistentMapTabs(
          listPoints.length,
          topPadding + 8,
        ),
        map: WorldMapStage(
          controller: _tabController,
          pointsCount: listPoints.length,
          top: topPadding + 8,
          showTopOverlay: false,
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
            onPointTap: _openChatForPoint,
          ),
        ),
        slivers: [
          _WorldFeedContent(
            world: world,
            worldActionRunning: _worldActionRunning,
            onWorldAction: _runWorldAction,
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentMapTabs(int pointsCount, double top) {
    return Positioned(
      left: 12,
      right: 12,
      top: top,
      child: WorldTopOverlayBar(
        pointsCount: pointsCount,
        controller: _tabController,
      ),
    );
  }
}

class _LocationChatPanelDescriptor {
  const _LocationChatPanelDescriptor({
    required this.locationId,
    required this.locationName,
    required this.isLeafLocation,
    this.localMessageLocationIds = const <String>[],
  });

  factory _LocationChatPanelDescriptor.fromNode(
    LocationTreeNode<Map<String, dynamic>> node,
  ) {
    final value = node.value;
    final locationId = node.id.trim();
    final valueLocationId = _mapString(value, const ['location_id', 'id']);
    final pointId = _mapString(value, const ['point_id']);
    return _LocationChatPanelDescriptor(
      locationId: locationId,
      locationName: _mapString(value, const [
        'location_name',
        'name',
      ], fallback: locationId),
      isLeafLocation: node.children.isEmpty,
      localMessageLocationIds: _orderedNonEmptyStrings([
        pointId,
        locationId,
        valueLocationId,
      ]),
    );
  }

  factory _LocationChatPanelDescriptor.fromLocation(
    Map<String, dynamic> location, {
    required bool isLeafLocation,
  }) {
    final locationId = _mapString(location, const ['location_id', 'id']);
    final pointId = _mapString(location, const ['point_id']);
    return _LocationChatPanelDescriptor(
      locationId: locationId,
      locationName: _mapString(location, const [
        'location_name',
        'name',
      ], fallback: locationId),
      isLeafLocation: isLeafLocation,
      localMessageLocationIds: _orderedNonEmptyStrings([pointId, locationId]),
    );
  }

  final String locationId;
  final String locationName;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
}

class _LocationChatPanelSkeleton extends StatelessWidget {
  const _LocationChatPanelSkeleton({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final style = ChatUiStyleConfig.standard;
    return ColoredBox(
      color: style.conversationBackgroundColor,
      child: Column(
        children: [
          ChatHeader(
            title: '$title (1)',
            subtitle: 'Loading',
            connected: false,
            connecting: true,
            onBack: onBack,
            showMoreButton: true,
          ),
          Expanded(child: _LocationChatMessageSkeletonList(style: style)),
          _LocationChatComposerSkeleton(style: style),
        ],
      ),
    );
  }
}

class _LocationChatMessageSkeletonList extends StatelessWidget {
  const _LocationChatMessageSkeletonList({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: style.messageListPadding,
      child: Column(
        children: [
          const Spacer(),
          _LocationChatDateSkeleton(style: style),
          _LocationChatOtherMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.62,
            lineWidths: const [0.74, 0.46],
          ),
          _LocationChatSelfMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.50,
            lineWidths: const [0.68],
          ),
          _LocationChatOtherMessageSkeleton(
            style: style,
            bubbleWidthFactor: 0.70,
            lineWidths: const [0.86, 0.58],
            showAiBadge: true,
          ),
          SizedBox(height: style.topTitleEmptyHeight),
        ],
      ),
    );
  }
}

class _LocationChatDateSkeleton extends StatelessWidget {
  const _LocationChatDateSkeleton({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.dateDividerBottomPadding),
      child: const Center(
        child: _LocationChatSkeletonBone(
          width: 72,
          height: 10,
          radius: 5,
          color: Color(0x33777777),
        ),
      ),
    );
  }
}

class _LocationChatOtherMessageSkeleton extends StatelessWidget {
  const _LocationChatOtherMessageSkeleton({
    required this.style,
    required this.bubbleWidthFactor,
    required this.lineWidths,
    this.showAiBadge = false,
  });

  final ChatUiStyleConfig style;
  final double bubbleWidthFactor;
  final List<double> lineWidths;
  final bool showAiBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ChatAvatar(
                label: '',
                colors: style.otherAvatarColors,
                style: style,
              ),
              if (showAiBadge)
                Positioned(
                  right: -8,
                  top: -9,
                  child: ChatAiBadge(style: style),
                ),
            ],
          ),
          SizedBox(width: style.avatarBubbleGap),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (style.showSenderNameAboveOtherBubble) ...[
                  const _LocationChatSkeletonBone(
                    width: 76,
                    height: 12,
                    radius: 6,
                    color: Color(0x33222222),
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                ],
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: bubbleWidthFactor,
                  child: _LocationChatBubbleSkeleton(
                    style: style,
                    color: style.otherBubbleColor,
                    lineColor: const Color(0xFFE5E8EC),
                    lineWidths: lineWidths,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: style.avatarSize + style.avatarBubbleGap),
        ],
      ),
    );
  }
}

class _LocationChatSelfMessageSkeleton extends StatelessWidget {
  const _LocationChatSelfMessageSkeleton({
    required this.style,
    required this.bubbleWidthFactor,
    required this.lineWidths,
  });

  final ChatUiStyleConfig style;
  final double bubbleWidthFactor;
  final List<double> lineWidths;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: style.avatarSize + style.avatarBubbleGap),
          Flexible(
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: bubbleWidthFactor,
              child: _LocationChatBubbleSkeleton(
                style: style,
                color: style.selfBubbleColor,
                lineColor: const Color(0x661A6B28),
                lineWidths: lineWidths,
              ),
            ),
          ),
          SizedBox(width: style.avatarBubbleGap),
          ChatAvatar(label: '', colors: style.selfAvatarColors, style: style),
        ],
      ),
    );
  }
}

class _LocationChatBubbleSkeleton extends StatelessWidget {
  const _LocationChatBubbleSkeleton({
    required this.style,
    required this.color,
    required this.lineColor,
    required this.lineWidths,
  });

  final ChatUiStyleConfig style;
  final Color color;
  final Color lineColor;
  final List<double> lineWidths;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(style.bubbleBorderRadius),
      ),
      child: Padding(
        padding: style.bubblePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lineWidths.length; i += 1) ...[
              _LocationChatSkeletonBone(
                widthFactor: lineWidths[i],
                height: 12,
                radius: 6,
                color: lineColor,
              ),
              if (i != lineWidths.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationChatComposerSkeleton extends StatelessWidget {
  const _LocationChatComposerSkeleton({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: style.composerPadding.copyWith(
        bottom: style.composerPadding.bottom + bottomInset,
      ),
      color: style.composerBackgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: style.inputMinHeight,
                maxHeight: style.inputMaxHeight,
              ),
              decoration: BoxDecoration(
                color: style.inputBackgroundColor,
                borderRadius: BorderRadius.circular(style.inputBorderRadius),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: style.inputHorizontalPadding,
                  vertical: style.inputVerticalPadding,
                ),
                child: const _LocationChatSkeletonBone(
                  widthFactor: 0.34,
                  height: 14,
                  radius: 7,
                  color: Color(0xFFE5E8EC),
                ),
              ),
            ),
          ),
          SizedBox(width: style.composerActionGap),
          DecoratedBox(
            decoration: BoxDecoration(
              color: style.composerSendButtonDisabledColor,
              borderRadius: BorderRadius.circular(
                style.composerSendButtonBorderRadius,
              ),
            ),
            child: SizedBox(
              width: style.composerSendButtonWidth,
              height: style.composerSendButtonHeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChatSkeletonBone extends StatelessWidget {
  const _LocationChatSkeletonBone({
    this.width,
    this.widthFactor,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: child,
    );
  }
}

class _WorldDetailsLoadingContent extends StatelessWidget {
  const _WorldDetailsLoadingContent();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _WorldHeaderLoadingSkeleton(),
        SizedBox(height: 4),
        _WorldTabsLoadingSkeleton(),
        SizedBox(height: 8),
        _WorldEventLoadingSkeleton(),
      ],
    );
  }
}

class _WorldHeaderLoadingSkeleton extends StatelessWidget {
  const _WorldHeaderLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 38),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: _WorldLoadingBone(width: 168, height: 18),
              ),
            ),
            SizedBox(width: 38),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _WorldLoadingBone(width: 128, height: 12)),
            SizedBox(width: 18),
            _WorldLoadingBone(width: 112, height: 12),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WorldLoadingBone(width: 42, height: 12),
                  _WorldLoadingBone(width: 46, height: 12),
                  _WorldLoadingBone(width: 40, height: 12),
                  _WorldLoadingBone(width: 44, height: 12),
                ],
              ),
            ),
            SizedBox(width: 14),
            _WorldLoadingBone(width: 120, height: 28, radius: 8),
          ],
        ),
      ],
    );
  }
}

class _WorldTabsLoadingSkeleton extends StatelessWidget {
  const _WorldTabsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _WorldLoadingBone(height: 32, radius: 16)),
        SizedBox(width: 8),
        Expanded(child: _WorldLoadingBone(height: 32, radius: 16)),
        SizedBox(width: 8),
        Expanded(child: _WorldLoadingBone(height: 32, radius: 16)),
      ],
    );
  }
}

class _WorldEventLoadingSkeleton extends StatelessWidget {
  const _WorldEventLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorldLoadingBone(width: 96, height: 14),
        SizedBox(height: 14),
        _WorldLoadingBone(widthFactor: 0.92, height: 12),
        SizedBox(height: 8),
        _WorldLoadingBone(widthFactor: 0.78, height: 12),
        SizedBox(height: 8),
        _WorldLoadingBone(widthFactor: 0.86, height: 12),
        SizedBox(height: 18),
        _WorldLoadingBone(widthFactor: 0.48, height: 12),
        SizedBox(height: 14),
        _WorldLoadingBone(widthFactor: 0.96, height: 92, radius: 6),
      ],
    );
  }
}

class _WorldLoadingBone extends StatelessWidget {
  const _WorldLoadingBone({
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: child,
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
  static const int _eventsPageSize = 20;
  static const double _eventsLoadMoreExtent = 160;

  late final TabController _sectionController;
  ScrollController? _panelScrollController;
  var _currentUid = '';
  var _currentUidRequested = false;
  var _eventsWorldId = '';
  var _eventTicks = const <Map<String, dynamic>>[];
  var _eventsTotal = 0;
  var _eventsPage = 0;
  var _eventsInitialLoading = false;
  var _eventsLoadingMore = false;
  Object? _eventsError;

  @override
  void initState() {
    super.initState();
    _sectionController = TabController(length: 3, vsync: this);
    _sectionController.addListener(_handleSectionTabChanged);
  }

  @override
  void dispose() {
    _panelScrollController?.removeListener(_handlePanelScroll);
    _sectionController.removeListener(_handleSectionTabChanged);
    _sectionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentUidRequested) return;
    _currentUidRequested = true;
    unawaited(_loadCurrentUid());
    _bindPanelScrollPosition();
    if (_eventsWorldId != widget.world.worldId) {
      _resetEvents(widget.world.worldId);
      unawaited(_loadEventsPage(1));
    }
  }

  @override
  void didUpdateWidget(covariant _WorldFeedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.world.worldId != widget.world.worldId) {
      _resetEvents(widget.world.worldId);
      unawaited(_loadEventsPage(1));
      return;
    }
    if (oldWidget.world.tickCount != widget.world.tickCount) {
      unawaited(_loadEventsPage(1));
    }
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  void _resetEvents(String worldId) {
    setState(() {
      _eventsWorldId = worldId;
      _eventTicks = const <Map<String, dynamic>>[];
      _eventsTotal = 0;
      _eventsPage = 0;
      _eventsInitialLoading = false;
      _eventsLoadingMore = false;
      _eventsError = null;
    });
  }

  void _bindPanelScrollPosition() {
    final controller = WorldDetailsPanelScrollControllerScope.maybeOf(context);
    if (controller == null || identical(controller, _panelScrollController)) {
      return;
    }
    _panelScrollController?.removeListener(_handlePanelScroll);
    _panelScrollController = controller;
    controller.addListener(_handlePanelScroll);
  }

  void _handleSectionTabChanged() {
    if (_sectionController.index == 0) _handlePanelScroll();
  }

  void _handlePanelScroll() {
    if (_sectionController.index != 0) return;
    final controller = _panelScrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter > _eventsLoadMoreExtent) return;
    _loadNextEventsPage();
  }

  bool get _eventsHasMore {
    return _eventsTotal > 0 && _eventTicks.length < _eventsTotal;
  }

  void _loadNextEventsPage() {
    if (!_eventsHasMore || _eventsLoadingMore || _eventsInitialLoading) return;
    unawaited(_loadEventsPage(_eventsPage + 1));
  }

  Future<void> _loadEventsPage(int page) async {
    if (page <= 0) return;
    if (page == 1) {
      if (_eventsInitialLoading) return;
      setState(() {
        _eventsInitialLoading = true;
        _eventsError = null;
      });
    } else {
      if (_eventsLoadingMore || !_eventsHasMore) return;
      setState(() => _eventsLoadingMore = true);
    }

    final worldId = widget.world.worldId;
    try {
      final response = await AppServicesScope.of(context).api.getWorldTicks(
        wid: worldId,
        limit: _eventsPageSize,
        offset: (page - 1) * _eventsPageSize,
      );
      if (!mounted || worldId != widget.world.worldId) return;
      setState(() {
        _eventTicks = page == 1
            ? response.data
            : [..._eventTicks, ...response.data];
        _eventsTotal = response.total;
        _eventsPage = page;
        _eventsError = null;
      });
    } catch (e) {
      if (!mounted || worldId != widget.world.worldId) return;
      setState(() => _eventsError = e);
    } finally {
      if (mounted && worldId == widget.world.worldId) {
        setState(() {
          if (page == 1) {
            _eventsInitialLoading = false;
          } else {
            _eventsLoadingMore = false;
          }
        });
      }
    }
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
              _WorldEventsSection(
                world: widget.world,
                ticks: _eventTicks,
                initialLoading: _eventsInitialLoading,
                loadingMore: _eventsLoadingMore,
                error: _eventsError,
              ),
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
    final title = world.name.trim().isEmpty ? world.worldId : world.name.trim();
    final wid = world.worldId;
    final owner = world.origin.originator.trim().isNotEmpty
        ? world.origin.originator.trim()
        : formatUidForDisplay(world.ownerUid);
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
                title,
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
              child: CopyableIdLabel(label: 'WID', value: wid),
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
                      iconAsset: _counterIconAsset(
                        data['icon'] as String? ?? '',
                      ),
                      preserveIconAssetColor: _counterIconAssetPreservesColor(
                        data['icon'] as String? ?? '',
                      ),
                      iconSize: 14,
                      iconColor: Colors.black,
                      text: formatStatCount(
                        data['value'] is num ? data['value'] as num : 0,
                      ),
                      gap: 4,
                      textStyle: const TextStyle(
                        fontSize: 14,
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
              height: 32,
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
                  padding: const EdgeInsets.symmetric(horizontal: 35),
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

bool _shouldConnectWorldChatroom(String relationStatus) {
  switch (relationStatus.trim().toLowerCase()) {
    case 'owner':
    case 'joined':
      return true;
    default:
      return false;
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
                'Owner: ${formatUidForDisplay(owner)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w400,
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

IconData? _counterIcon(String key) {
  switch (key) {
    case 'tick':
      return MyFlutterApp.pregress;
    case 'connect':
      return null;
    case 'character':
      return null;
    case 'player':
      return MyFlutterApp.user;
    default:
      return Icons.circle_outlined;
  }
}

String? _counterIconAsset(String key) {
  return switch (key) {
    'connect' => _connectIconAsset,
    'character' => aiCharacterIconAsset,
    _ => null,
  };
}

bool _counterIconAssetPreservesColor(String key) {
  return key == 'character';
}

class _WorldEventsSection extends StatelessWidget {
  const _WorldEventsSection({
    required this.world,
    required this.ticks,
    required this.initialLoading,
    required this.loadingMore,
    required this.error,
  });

  final WorldDetail world;
  final List<Map<String, dynamic>> ticks;
  final bool initialLoading;
  final bool loadingMore;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (ticks.isEmpty && initialLoading) {
      return const _WorldEventLoadingSkeleton();
    }
    if (ticks.isEmpty) {
      return _EmptySection(
        text: error == null ? 'No events yet.' : 'Load events failed.',
      );
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
            dateLabel: _tickParagraphTimestamp(ticks[index]),
            isLast: index == ticks.length - 1 && !loadingMore,
          ),
        if (loadingMore) const _WorldEventsLoadingMoreIndicator(),
      ],
    );
  }
}

String? _tickParagraphTimestamp(Map<String, dynamic> tick) {
  final result = tick['tick_result'];
  if (result is! Map) return null;
  final paragraphs = result['paragraphs'];
  if (paragraphs is! List) return null;
  for (final paragraph in paragraphs) {
    if (paragraph is! Map) continue;
    final timestamp = '${paragraph['timestamp'] ?? ''}'.trim();
    if (timestamp.isNotEmpty) return timestamp;
  }
  return null;
}

class _WorldEventsLoadingMoreIndicator extends StatelessWidget {
  const _WorldEventsLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
      subtitleBuilder: (character) =>
          _metricStatusText(world.metric, character),
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
    final hasCharacterRole = characters.any(_isCharacterRole);
    final sortedCharacters = _sortedCharacters(characters, currentUid);

    return Padding(
      padding: EdgeInsets.only(top: hasCharacterRole ? 5 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sortedCharacters.length; i++) ...[
            _CharacterRow(
              character: sortedCharacters[i],
              currentUid: currentUid,
              subtitle: subtitleBuilder(sortedCharacters[i]),
            ),
            if (i != sortedCharacters.length - 1) const SizedBox(height: 22),
          ],
        ],
      ),
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
    final username = _mapString(character, const ['player_username']);
    final suffix = _characterNameSuffix(
      currentUid: currentUid,
      playerUid: playerUid,
      username: username,
    );
    final isCharacterRole = _isCharacterRole(character);
    final roleLabel = isCharacterRole ? 'Character' : 'Player';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: isCharacterRole ? 6 : 0),
          child: GenesisCharacterAvatar(
            url: _mapString(character, const ['avatar']),
            name: name,
            showStar: isCharacterRole,
          ),
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
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          children: [
                            if (suffix.isNotEmpty)
                              TextSpan(
                                text: ' $suffix',
                                style: const TextStyle(
                                  color: Color(0xFF888888),
                                ),
                              ),
                          ],
                        ),
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

List<Map<String, dynamic>> _sortedCharacters(
  List<Map<String, dynamic>> characters,
  String currentUid,
) {
  final indexed = characters.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final rankCompare = _characterSortRank(
      a.$2,
      currentUid,
    ).compareTo(_characterSortRank(b.$2, currentUid));
    if (rankCompare != 0) return rankCompare;
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

int _characterSortRank(Map<String, dynamic> character, String currentUid) {
  if (_isCurrentUserCharacter(character, currentUid)) return 0;
  return _isCharacterRole(character) ? 2 : 1;
}

bool _isCurrentUserCharacter(
  Map<String, dynamic> character,
  String currentUid,
) {
  final playerUid = _mapString(character, const ['player_uid']);
  return currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid;
}

bool _isCharacterRole(Map<String, dynamic> character) {
  return _mapString(character, const ['player_uid']).isEmpty;
}

String _characterNameSuffix({
  required String currentUid,
  required String playerUid,
  required String username,
}) {
  if (currentUid.isNotEmpty &&
      playerUid.isNotEmpty &&
      playerUid == currentUid) {
    return '(Me)';
  }
  if (playerUid.isNotEmpty && username.isNotEmpty) return '($username)';
  return '';
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
  ], fallback: 'No character details yet.');
}

String _metricStatusText(
  Map<String, dynamic> metric,
  Map<String, dynamic> character,
) {
  final label = _mapString(metric, const ['label']);
  final unit = _mapString(metric, const ['unit']);
  final value = _resolvedMetricValueText(
    character['metric_value'],
    metric['default'],
  );
  return '$label: $value$unit';
}

String _resolvedMetricValueText(Object? metricValue, Object? defaultValue) {
  final parsedMetricValue = _metricNumber(metricValue);
  final resolved = parsedMetricValue == null || parsedMetricValue == 0
      ? defaultValue
      : metricValue;
  return _metricDisplayValue(resolved);
}

num? _metricNumber(Object? value) {
  if (value is num) return value;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return num.tryParse(text);
}

String _metricDisplayValue(Object? value) {
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return '0';
  return text;
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
  final playerUid = _mapString(character, const ['player_uid']);
  return playerUid.isEmpty;
}

String _rootWorldMapImageUrl(
  List<LocationTreeNode<Map<String, dynamic>>> rootLocationNodes,
) {
  for (final node in rootLocationNodes) {
    final url = _locationMapImageUrl(node.value);
    if (url.isNotEmpty) return url;
  }
  return '';
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
  return initialsForAvatarName(name);
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

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

List<String> _orderedNonEmptyStrings(Iterable<String?> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) continue;
    result.add(trimmed);
  }
  return result;
}
