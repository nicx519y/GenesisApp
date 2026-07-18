import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/daily_check_in_coordinator.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/debug/location_chat_debug_slice.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_generation_wait_overlay.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/gems/gem_balance_prompt.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/api_exception.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/world.dart';
import '../../platform/auth/auth_session.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../utils/api_error_message.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import 'world_bottom_sheet.dart';
import 'world_constants.dart';
import 'world_header.dart';
import 'world_location_chat_host.dart';
import 'world_map_bubble_candidates.dart';
import 'world_map_data.dart';
import 'world_models.dart';
import 'world_page_result.dart';
import 'world_recent_chat_location.dart';
import 'world_sections.dart';
import 'world_value_helpers.dart';

class WorldPage extends StatefulWidget {
  const WorldPage({
    super.key,
    required this.wid,
    this.waitForTick1 = false,
    this.initialWorldDetail,
  });

  final String wid;
  final bool waitForTick1;
  final WorldDetail? initialWorldDetail;

  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> with TickerProviderStateMixin {
  static const double _progressWaitAvatarSize = 88;
  static const String _progressWaitTitle = 'Progressing the World';
  static const String _progressWaitMessage =
      'Compressing recent memories\n'
      'Advancing the world timeline\n'
      'Generating the next story beat\n'
      'Updating character locations';
  static const double _worldMainSwipeSystemGestureEdgeWidth = 24;
  static const double _worldMainSwipeMinDistance = 48;
  static const double _worldMainSwipeDirectionRatio = 1.25;
  late final TabController _mainTabController;
  WorldDetail? _world;
  Object? _initialLoadError;
  WorldChatroomService? _worldChatroom;
  StreamSubscription<WorldChatroomState>? _worldChatroomSub;
  StreamSubscription? _worldChatroomFailureSub;
  StreamSubscription<GemBalanceAlert>? _worldChatroomBalanceSub;
  Future<void>? _worldChatroomAuthRecovery;
  Map<String, WorldLocationChatPanelDescriptor> _locationChatDescriptors =
      <String, WorldLocationChatPanelDescriptor>{};
  final _locationChatPageCache = WorldLocationChatPageCache();
  final Set<String> _preloadedLocationMessageIds = <String>{};
  final Map<String, Future<void>> _preloadingLocationMessageFutures =
      <String, Future<void>>{};
  String _activeChatLocationId = '';
  bool _pollInFlight = false;
  bool _worldActionRunning = false;
  bool _worldTickInProgress = false;
  bool _worldTickWaitOverlayRequested = false;
  bool _openEventsAfterTickDone = false;
  bool _eventsUnread = false;
  bool _worldBottomSheetOpen = false;
  bool _hasUnreadNewUserJoin = false;
  bool _openEventsAfterCurrentBottomSheetClosed = false;
  int? _eventsAfterCurrentBottomSheetClosedTargetTickNumber;
  BuildContext? _worldBottomSheetContext;
  int _worldMainTabIndex = 0;
  int? _worldMainSwipePointer;
  Offset? _worldMainSwipeStartPosition;
  bool _worldMainSwipeStartCanMapScrollLeft = false;
  bool _worldMainSwipeStartCanMapScrollRight = false;
  bool _worldMapCanScrollLeft = false;
  bool _worldMapCanScrollRight = false;
  bool _mapBubbleMessagesReady = false;
  int _eventsLatestRevision = 0;
  int? _eventsTargetTickNumber;
  int _lastAppliedNewUserJoinRevision = 0;
  WorldNewUserJoinNotice? _pendingNewUserJoinNotice;
  bool _tick1WaitDialogStarted = false;
  bool? _lastChatroomInputBlocked;
  bool _worldTickDoneHandling = false;
  bool _worldTickLockPollInFlight = false;
  int _worldTickLockPollingGeneration = 0;
  Timer? _worldTickLockPollingTimer;
  int _lastAppliedChatroomWorldProgressRevision = 0;
  List<WorldMapBubbleCandidate> _mapBubbleCandidates =
      const <WorldMapBubbleCandidate>[];
  int? _pendingProgressTickCount;
  var _currentUid = '';
  var _currentUidRequested = false;
  Set<String> _recentChatLocationIds = const <String>{};
  Set<String> _recentChatLocationPathIds = const <String>{};
  var _locationChatDescriptorSignature = '';
  late final ValueNotifier<WorldDetail?> _sectionsWorldNotifier =
      ValueNotifier<WorldDetail?>(_world);
  late final ValueNotifier<WorldBottomSheetSelection>
  _worldBottomSheetSelection = ValueNotifier<WorldBottomSheetSelection>(
    const WorldBottomSheetSelection(
      kind: WorldBottomSheetKind.detail,
      eventsLatestRevision: 0,
    ),
  );
  final ValueNotifier<List<WorldNewUserJoinNotice>>
  _newUserJoinNoticesNotifier = ValueNotifier<List<WorldNewUserJoinNotice>>(
    const <WorldNewUserJoinNotice>[],
  );
  final _sectionsEventsCache = WorldSectionsEventsCache();
  static const _worldTickLockPollInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: worldMainPageCount, vsync: this);
    _mainTabController.addListener(_handleWorldMainTabChanged);
    _worldBottomSheetSelection.addListener(
      _handleWorldBottomSheetSelectionChanged,
    );
    _syncWorldStatusBarForMainTab();
    final initialWorld = widget.initialWorldDetail;
    if (initialWorld != null) {
      _world = initialWorld;
      _sectionsWorldNotifier.value = initialWorld;
      _syncLocationChatDescriptors(initialWorld);
      _syncWorldChatroomForRelationStatus(initialWorld.relationStatus);
      _maybeShowTick1WaitDialog();
      if (initialWorld.isProgressing &&
          shouldConnectWorldChatroom(initialWorld.relationStatus)) {
        _startWorldTickTracking();
      }
    } else {
      unawaited(
        _fetchWorld(isInitial: true).then((_) {
          if (mounted) _maybeShowTick1WaitDialog();
        }),
      );
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(_fetchWorld());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_currentUidRequested) {
      _currentUidRequested = true;
      unawaited(_loadCurrentUid());
    }
  }

  @override
  void dispose() {
    _stopWorldTickLockPolling();
    _mainTabController.removeListener(_handleWorldMainTabChanged);
    _worldBottomSheetSelection.removeListener(
      _handleWorldBottomSheetSelectionChanged,
    );
    WorldDetailsStatusBarOverride.clearStyle();
    GenesisSystemUiChrome.applyDefault();
    unawaited(_worldChatroomSub?.cancel());
    unawaited(_worldChatroomFailureSub?.cancel());
    unawaited(_worldChatroomBalanceSub?.cancel());
    final chatroom = _worldChatroom;
    _worldChatroom = null;
    if (chatroom != null) {
      unawaited(_disposeWorldChatroom(chatroom));
    }
    _mainTabController.dispose();
    _sectionsEventsCache.clear();
    _locationChatPageCache.dispose();
    _sectionsWorldNotifier.dispose();
    _worldBottomSheetSelection.removeListener(
      _handleWorldBottomSheetSelectionChanged,
    );
    _worldBottomSheetSelection.dispose();
    _newUserJoinNoticesNotifier.dispose();
    super.dispose();
  }

  void _handleWorldMainTabChanged() {
    final nextIndex = _mainTabController.index
        .clamp(0, worldMainPageCount - 1)
        .toInt();
    if (nextIndex >= 2) {
      _sectionsWorldNotifier.value = _world;
    }
    _syncWorldStatusBarForMainTab(nextIndex);
    if (_worldMainTabIndex == nextIndex) return;
    setState(() => _worldMainTabIndex = nextIndex);
  }

  bool get _isDetailBottomSheetVisible {
    return _worldBottomSheetOpen &&
        _worldBottomSheetSelection.value.kind == WorldBottomSheetKind.detail;
  }

  void _handleWorldBottomSheetSelectionChanged() {
    if (_worldBottomSheetSelection.value.kind == WorldBottomSheetKind.events) {
      _clearEventsUnread();
    }
    if (!_isDetailBottomSheetVisible) return;
    if (!_hasUnreadNewUserJoin && _pendingNewUserJoinNotice == null) return;
    setState(_activateDetailNewUserJoinNotices);
  }

  void _syncWorldStatusBarForMainTab([int? index]) {
    if (_activeChatLocationId.isNotEmpty) {
      WorldDetailsStatusBarOverride.setStyle(
        kChatDarkHeaderSystemUiOverlayStyle,
      );
      return;
    }
    if ((index ?? _worldMainTabIndex) != 0) {
      WorldDetailsStatusBarOverride.setStyle(
        kGenesisDefaultSystemUiOverlayStyle,
      );
      return;
    }
    WorldDetailsStatusBarOverride.clearStyle();
  }

  void _selectWorldMainTab(
    int index, {
    bool scrollEventsToLatest = false,
    int? eventsTargetTickNumber,
  }) {
    final nextIndex = index.clamp(0, worldMainPageCount - 1).toInt();
    if (scrollEventsToLatest) {
      _eventsLatestRevision += 1;
    }
    _eventsTargetTickNumber = eventsTargetTickNumber;
    if (nextIndex >= 2) {
      _sectionsWorldNotifier.value = _world;
    }
    _syncWorldStatusBarForMainTab(nextIndex);
    if (_mainTabController.index != nextIndex) {
      _mainTabController.animateTo(
        nextIndex,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
    if (_worldMainTabIndex == nextIndex) {
      setState(() {});
      return;
    }
    setState(() => _worldMainTabIndex = nextIndex);
  }

  void _handleWorldMainSwipePointerDown(PointerDownEvent event) {
    if (_activeChatLocationId.isNotEmpty || _world == null) return;
    if (_worldMainTabIndex != 0) return;
    if (_worldMainSwipePointer != null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final localX = event.localPosition.dx;
    if (localX <= _worldMainSwipeSystemGestureEdgeWidth ||
        localX >= screenWidth - _worldMainSwipeSystemGestureEdgeWidth) {
      return;
    }

    _worldMainSwipePointer = event.pointer;
    _worldMainSwipeStartPosition = event.position;
    _worldMainSwipeStartCanMapScrollLeft = _worldMapCanScrollLeft;
    _worldMainSwipeStartCanMapScrollRight = _worldMapCanScrollRight;
  }

  void _handleWorldMainSwipePointerUp(PointerUpEvent event) {
    if (_worldMainSwipePointer != event.pointer) return;
    final startPosition = _worldMainSwipeStartPosition;
    if (startPosition != null && _worldMainTabIndex == 0) {
      _maybeSelectWorldMainTabBySwipe(event.position - startPosition);
    }
    _clearWorldMainSwipeTracking();
  }

  void _handleWorldMainSwipePointerCancel(PointerCancelEvent event) {
    if (_worldMainSwipePointer == event.pointer) {
      _clearWorldMainSwipeTracking();
    }
  }

  void _clearWorldMainSwipeTracking() {
    _worldMainSwipePointer = null;
    _worldMainSwipeStartPosition = null;
    _worldMainSwipeStartCanMapScrollLeft = false;
    _worldMainSwipeStartCanMapScrollRight = false;
  }

  void _maybeSelectWorldMainTabBySwipe(Offset delta) {
    final horizontalDistance = delta.dx.abs();
    final verticalDistance = delta.dy.abs();
    if (horizontalDistance < _worldMainSwipeMinDistance ||
        horizontalDistance < verticalDistance * _worldMainSwipeDirectionRatio) {
      return;
    }

    final nextIndex = delta.dx < 0
        ? _worldMainTabIndex + 1
        : _worldMainTabIndex - 1;
    if (nextIndex < 0 || nextIndex >= worldMainPageCount) return;
    if (!_canSelectWorldMainTabBySwipe(delta.dx)) return;
    _selectWorldMainTab(nextIndex);
  }

  bool _canSelectWorldMainTabBySwipe(double horizontalDelta) {
    if (_worldMainTabIndex != 0) return false;
    if (horizontalDelta < 0) {
      return !_worldMainSwipeStartCanMapScrollRight || !_worldMapCanScrollRight;
    }
    return !_worldMainSwipeStartCanMapScrollLeft || !_worldMapCanScrollLeft;
  }

  void _handleWorldMapHorizontalPanStateChanged(
    WorldMapHorizontalPanState state,
  ) {
    _worldMapCanScrollLeft = state.canScrollLeft;
    _worldMapCanScrollRight = state.canScrollRight;
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  List<String> _locationPathIdsForLocationId(
    String locationId,
    ProcessedLocationTree<Map<String, dynamic>> tree,
  ) {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return const <String>[];
    final nodesById = <String, LocationTreeNode<Map<String, dynamic>>>{
      for (final node in tree.flattened) node.id.trim(): node,
    };
    final path = <String>[];
    var current = nodesById[resolvedLocationId];
    while (current != null) {
      final id = current.id.trim();
      if (id.isNotEmpty && id != worldSyntheticRootLocationId) {
        path.add(id);
      }
      current = nodesById[current.parentId.trim()];
    }
    if (path.isEmpty) path.add(resolvedLocationId);
    return worldOrderedNonEmptyStrings(path.reversed);
  }

  void _startWorldChatroom() {
    if (_worldChatroom != null) return;
    final services = AppServicesScope.read(context);
    final service = _createWorldChatroom(services);
    _attachWorldChatroom(service);
    unawaited(_connectWorldChatroom(service, services));
  }

  WorldChatroomService _createWorldChatroom(AppServices services) {
    _lastAppliedNewUserJoinRevision = 0;
    final service = WorldChatroomService(
      api: services.api,
      client: services.chatroom,
      messageStorage: services.chatroomMessages,
      refreshInitialSnapshotOnConnect: false,
    );
    final world = _world;
    if (world != null) {
      service.applyWorldSnapshot(world);
    }
    return service;
  }

  void _attachWorldChatroom(WorldChatroomService service) {
    _worldChatroom = service;
    _worldChatroomSub = service.states.listen(_handleWorldChatroomState);
    _worldChatroomFailureSub = bindChatroomFailureToast(
      context,
      service.failures,
      shouldShow: (failure) => failure.code != 'snapshot_failed',
      onFailure: _handleWorldChatroomFailure,
    );
    _worldChatroomBalanceSub = bindGemBalancePrompt(
      context,
      service.balanceAlerts,
    );
  }

  void _handleWorldChatroomFailure(ChatroomFailureEvent failure) {
    if (!isChatroomUnauthorizedFailure(failure)) return;
    unawaited(_recoverWorldChatroomAuthentication());
  }

  Future<void> _recoverWorldChatroomAuthentication() {
    final existing = _worldChatroomAuthRecovery;
    if (existing != null) return existing;
    final recovery = _performWorldChatroomAuthenticationRecovery();
    _worldChatroomAuthRecovery = recovery;
    return recovery.whenComplete(() {
      if (identical(_worldChatroomAuthRecovery, recovery)) {
        _worldChatroomAuthRecovery = null;
      }
    });
  }

  Future<void> _performWorldChatroomAuthenticationRecovery() async {
    final oldService = _worldChatroom;
    try {
      await _detachWorldChatroomForAuthentication(oldService);
      if (!mounted) return;

      final services = AppServicesScope.read(context);
      await services.sessionStore.clearUid();
      services.notifySessionChanged();
      try {
        await services.identityAuth.signOutIdentity();
      } catch (error) {
        debugPrint(
          '[Auth][WorldChatroomUnauthorized] identity sign out failed: $error',
        );
      }
      if (!mounted) return;

      final loggedIn = await ensureGenesisLogin(context);
      if (!mounted) return;
      if (!loggedIn) {
        if (identical(_worldChatroom, oldService)) {
          _worldChatroom = null;
        }
        _exitWorldAfterAuthenticationCancelled();
        return;
      }

      await _loadCurrentUid();
      if (!mounted) return;
      final replacement = _createWorldChatroom(services);
      final identity = await _chatroomIdentity(services);
      try {
        await replacement.connect(worldId: widget.wid, identity: identity);
      } catch (error) {
        debugPrint(
          '[Auth][WorldChatroomUnauthorized] reconnect failed: $error',
        );
      }
      if (!mounted) {
        await replacement.dispose();
        return;
      }

      final activeLocationId = _activeChatLocationId.trim();
      final activeDescriptor = _locationChatDescriptors[activeLocationId];
      if (activeDescriptor?.isLeafLocation == true) {
        try {
          await replacement.join(locationId: activeLocationId);
        } catch (error) {
          debugPrint(
            '[Auth][WorldChatroomUnauthorized] location rejoin failed: $error',
          );
        }
      }
      if (!mounted) {
        await replacement.dispose();
        return;
      }
      _attachWorldChatroom(replacement);
      setState(() {
        _preloadedLocationMessageIds.clear();
        _preloadingLocationMessageFutures.clear();
        _mapBubbleMessagesReady = false;
        _recentChatLocationIds = const <String>{};
        _recentChatLocationPathIds = const <String>{};
        _replaceMapBubbleCandidates(const <WorldMapBubbleCandidate>[]);
      });
      _handleWorldChatroomState(replacement.state);
    } catch (error, stackTrace) {
      debugPrint(
        '[Auth][WorldChatroomUnauthorized] recovery failed: $error\n$stackTrace',
      );
      if (!mounted) return;
      if (identical(_worldChatroom, oldService)) {
        _worldChatroom = null;
      }
      _exitWorldAfterAuthenticationCancelled();
    }
  }

  Future<void> _detachWorldChatroomForAuthentication(
    WorldChatroomService? service,
  ) async {
    await _worldChatroomSub?.cancel();
    await _worldChatroomFailureSub?.cancel();
    await _worldChatroomBalanceSub?.cancel();
    _worldChatroomSub = null;
    _worldChatroomFailureSub = null;
    _worldChatroomBalanceSub = null;
    if (service != null) await service.dispose();
  }

  void _exitWorldAfterAuthenticationCancelled() {
    final navigator = Navigator.of(context);
    if (_activeChatLocationId.isEmpty) {
      unawaited(navigator.maybePop());
      return;
    }
    setState(() {
      _activeChatLocationId = '';
      _locationChatPageCache.deactivate();
    });
    _syncWorldStatusBarForMainTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(navigator.maybePop());
    });
  }

  void _handleWorldChatroomState(WorldChatroomState state) {
    if (!mounted) return;
    final world = state.world;
    final currentWorld = world ?? _world;
    final currentRelationStatus = currentWorld?.relationStatus ?? '';
    final canShowWorldTickProgress =
        _worldChatroom != null ||
        shouldConnectWorldChatroom(currentRelationStatus);
    final latestNewUserJoin = state.latestNewUserJoin;
    final hasNewUserJoin =
        latestNewUserJoin != null &&
        state.latestNewUserJoinRevision > _lastAppliedNewUserJoinRevision;
    final newUserJoinNotice = hasNewUserJoin
        ? _newUserJoinNoticeFromEvent(latestNewUserJoin)
        : null;
    var shouldSyncRelationStatus = false;
    final previousInputBlocked = _lastChatroomInputBlocked;
    _lastChatroomInputBlocked = state.inputBlocked;
    final tickDoneFromPush =
        _worldTickInProgress &&
        previousInputBlocked == true &&
        !state.inputBlocked &&
        !_worldTickDoneHandling;
    final tickStartedFromPush =
        canShowWorldTickProgress &&
        state.inputBlocked &&
        previousInputBlocked != true &&
        !_worldTickInProgress;
    final socketCurrentTime = state.latestSocketCurrentTime.trim();
    final socketTickNo = state.latestSocketTickNo;
    final shouldApplySocketWorldProgress =
        (socketCurrentTime.isNotEmpty || socketTickNo > 0) &&
        state.latestSocketCurrentTimeRevision >
            _lastAppliedChatroomWorldProgressRevision;
    setState(() {
      if (world != null && _shouldApplyChatroomWorldSnapshot(world)) {
        _world = world;
        _sectionsWorldNotifier.value = world;
        _syncLocationChatDescriptors(world);
        shouldSyncRelationStatus = true;
      }
      final currentWorldDetail = _world;
      if (shouldApplySocketWorldProgress && currentWorldDetail != null) {
        _world = currentWorldDetail.copyWith(
          tickCount: socketTickNo > 0 ? socketTickNo : null,
          currentTime: socketCurrentTime.isEmpty ? null : socketCurrentTime,
        );
        _sectionsWorldNotifier.value = _world;
        _lastAppliedChatroomWorldProgressRevision =
            state.latestSocketCurrentTimeRevision;
      }
      _replaceMapBubbleCandidates(
        _buildMapBubbleCandidates(state, currentWorld),
      );
      _applyRecentChatLocationSelection(state, _world ?? currentWorld);
      if (newUserJoinNotice != null) {
        _applyNewUserJoinNotice(
          newUserJoinNotice,
          state.latestNewUserJoinRevision,
        );
      }
    });
    if (shouldSyncRelationStatus) {
      _syncWorldChatroomForRelationStatus(world!.relationStatus);
    }
    if (tickStartedFromPush) {
      _setWorldTickInProgress(true);
      _startWorldTickTracking();
    }
    if (tickDoneFromPush) {
      unawaited(_handleWorldTickDone());
    }
  }

  void _applyRecentChatLocationSelection(
    WorldChatroomState state,
    WorldDetail? world,
  ) {
    final selection = _recentChatLocationSelectionForState(state, world);
    _recentChatLocationIds = selection == null
        ? const <String>{}
        : Set<String>.unmodifiable([selection.locationId]);
    _recentChatLocationPathIds = selection?.pathIds ?? const <String>{};
  }

  ({String locationId, Set<String> pathIds})?
  _recentChatLocationSelectionForState(
    WorldChatroomState state,
    WorldDetail? world,
  ) {
    if (world == null) return null;
    final leafDescriptors = <String, WorldLocationChatPanelDescriptor>{
      for (final descriptor in _locationChatDescriptors.values)
        if (descriptor.isLeafLocation &&
            descriptor.locationId.trim().isNotEmpty)
          descriptor.locationId.trim(): descriptor,
    };
    final fallbackLeafLocationIds = world.processedLocationTree.flattened
        .where((node) => node.children.isEmpty)
        .map((node) => node.id);
    final latestLocationId = latestChatLocationIdFromMessages(
      allLocationsLoaded: _mapBubbleMessagesReady,
      messagesByLocation: state.messagesByLocation,
      allowedLocationIds: leafDescriptors.isNotEmpty
          ? leafDescriptors.keys
          : fallbackLeafLocationIds,
    );
    if (latestLocationId.isEmpty) return null;
    final descriptorPath =
        leafDescriptors[latestLocationId]?.recentChatLocationPathIds ??
        const <String>[];
    if (descriptorPath.isNotEmpty) {
      return (
        locationId: latestLocationId,
        pathIds: Set<String>.unmodifiable(
          worldOrderedNonEmptyStrings([...descriptorPath, latestLocationId]),
        ),
      );
    }
    return (
      locationId: latestLocationId,
      pathIds: Set<String>.unmodifiable(
        _locationPathIdsForLocationId(
          latestLocationId,
          world.processedLocationTree,
        ),
      ),
    );
  }

  WorldNewUserJoinNotice _newUserJoinNoticeFromEvent(
    ChatroomNewUserJoinEvent event,
  ) {
    return WorldNewUserJoinNotice(
      characterId: event.characterId,
      characterType: event.characterType,
      characterName: event.characterName,
      playerUid: event.playerUid,
      playerUsername: event.playerUsername,
      ts: event.ts,
    );
  }

  void _applyNewUserJoinNotice(WorldNewUserJoinNotice notice, int revision) {
    _lastAppliedNewUserJoinRevision = revision;
    if (_isDetailBottomSheetVisible) {
      _pendingNewUserJoinNotice = null;
      _hasUnreadNewUserJoin = false;
      _newUserJoinNoticesNotifier.value = <WorldNewUserJoinNotice>[notice];
      return;
    }
    _pendingNewUserJoinNotice = notice;
    _hasUnreadNewUserJoin = true;
  }

  void _activateDetailNewUserJoinNotices() {
    final pending = _pendingNewUserJoinNotice;
    if (pending != null) {
      _newUserJoinNoticesNotifier.value = <WorldNewUserJoinNotice>[pending];
      _pendingNewUserJoinNotice = null;
    }
    _hasUnreadNewUserJoin = false;
  }

  void _syncWorldChatroomForRelationStatus(String relationStatus) {
    if (shouldConnectWorldChatroom(relationStatus)) {
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
    unawaited(_worldChatroomBalanceSub?.cancel());
    _worldChatroomSub = null;
    _worldChatroomFailureSub = null;
    _worldChatroomBalanceSub = null;
    _worldChatroom = null;
    _preloadedLocationMessageIds.clear();
    _preloadingLocationMessageFutures.clear();
    _mapBubbleMessagesReady = false;
    if (mounted) {
      setState(() {
        _activeChatLocationId = '';
        _recentChatLocationIds = const <String>{};
        _recentChatLocationPathIds = const <String>{};
        _locationChatPageCache.clear();
        _replaceMapBubbleCandidates(const <WorldMapBubbleCandidate>[]);
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
      if (!mounted || !identical(_worldChatroom, service)) return;
      _scheduleLocationChatPrecache();
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
        : worldMapString(userInfo, const ['uid']);
    final profile = services.identityAuth.currentProfile();
    final senderId = worldFirstNonEmpty([
      uid,
      cachedUid,
      profile?.uid,
      'local-user',
    ]);
    final senderName = worldFirstNonEmpty([
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
      _applyWorldDetail(world, clearInitialLoadError: isInitial);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[WorldPage] load failed wid="${widget.wid}": $e');
      if (isInitial) {
        setState(() {
          _initialLoadError = e;
        });
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _applyWorldDetail(
    WorldDetail world, {
    bool clearInitialLoadError = false,
  }) {
    final canTrackWorldProgress = shouldConnectWorldChatroom(
      world.relationStatus,
    );
    final shouldStartTracking = world.isProgressing && canTrackWorldProgress;
    _precacheProgressWaitAvatarImages(world);
    setState(() {
      _world = world;
      _sectionsWorldNotifier.value = world;
      if (clearInitialLoadError) _initialLoadError = null;
      _syncLocationChatDescriptors(world);
      _replaceMapBubbleCandidates(
        _buildMapBubbleCandidates(_worldChatroom?.state, world),
      );
    });
    _syncWorldChatroomForRelationStatus(world.relationStatus);
    if (shouldStartTracking) {
      _startWorldTickTracking();
    } else if (_worldTickInProgress) {
      _markWorldTickIdle();
    }
  }

  List<GenesisGenerationWaitAvatar> _progressWaitAvatarsFromWorld(
    WorldDetail? world,
  ) {
    if (world == null) return const <GenesisGenerationWaitAvatar>[];
    return world.characters
        .map((character) {
          return GenesisGenerationWaitAvatar(
            name: worldMapString(character, const [
              'name',
              'character_name',
              'player_username',
            ]).trim(),
            url: worldResolveAssetUrl(
              worldMapString(character, const [
                'avatar',
                'avatar_url',
                'role_avatar',
              ]),
            ).trim(),
          );
        })
        .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
        .toList(growable: false);
  }

  void _precacheProgressWaitAvatarImages(WorldDetail world) {
    if (!mounted) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1;
    for (final avatar in _progressWaitAvatarsFromWorld(world)) {
      final resolvedUrl = selectGenesisImageUrl(
        avatar.url,
        logicalWidth: _progressWaitAvatarSize,
        logicalHeight: _progressWaitAvatarSize,
        devicePixelRatio: devicePixelRatio,
      ).trim();
      if (resolvedUrl.isEmpty) continue;
      final ImageProvider provider = resolvedUrl.startsWith('assets/')
          ? AssetImage(resolvedUrl)
          : NetworkImage(resolvedUrl);
      unawaited(
        precacheImage(
          provider,
          context,
          onError: (exception, stackTrace) {
            debugPrint(
              '[WorldPage] progress avatar precache failed url="$resolvedUrl": '
              '$exception',
            );
          },
        ).catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            '[WorldPage] progress avatar precache future failed '
            'url="$resolvedUrl": $error',
          );
        }),
      );
    }
  }

  String _rootMapImageUrlForWorld(WorldDetail world) {
    final displayRootMapUrl = worldRootMapImageUrl(
      world.processedLocationTree.initialMapDisplayRoots,
    ).trim();
    if (displayRootMapUrl.isNotEmpty) return displayRootMapUrl;
    final worldMapUrl = world.mapImageUrl.trim();
    if (worldMapUrl.isNotEmpty) return worldMapUrl;
    return world.origin.worldMap.trim();
  }

  List<WorldMapBubbleCandidate> _buildMapBubbleCandidates(
    WorldChatroomState? state,
    WorldDetail? world,
  ) {
    if (state == null || world == null) {
      return const <WorldMapBubbleCandidate>[];
    }
    return worldMapBubbleCandidatesFor(
      currentTickNo: world.tickCount,
      characterPositions: world.characterPositions,
      messagesByLocation: state.messagesByLocation,
    );
  }

  void _replaceMapBubbleCandidates(List<WorldMapBubbleCandidate> candidates) {
    _mapBubbleCandidates = candidates;
  }

  List<WorldMapMessageBubble> get _mapMessageBubbles {
    return _mapBubbleCandidates
        .map(
          (candidate) => WorldMapMessageBubble(
            characterId: candidate.characterId,
            content: candidate.content,
          ),
        )
        .toList(growable: false);
  }

  void _maybeShowTick1WaitDialog() {
    if (!widget.waitForTick1 || _tick1WaitDialogStarted) return;
    final world = _world;
    if (world == null || worldHasTick1(world)) return;
    _tick1WaitDialogStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showGenesisDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => WorldTick1WaitDialog(
            loadWorld: _loadWorldForTick1Wait,
            onWorldReady: (world) =>
                _applyWorldDetail(world, clearInitialLoadError: true),
          ),
        ),
      );
    });
  }

  Future<WorldDetail> _loadWorldForTick1Wait() async {
    return AppServicesScope.read(context).api.getWorld(widget.wid);
  }

  Future<void> _runWorldAction(WorldHeaderActionKind action) async {
    if (action == WorldHeaderActionKind.progress && _worldTickInProgress) {
      _openEventsAfterTickDone = true;
      _startWorldTickTracking();
      _setWorldTickWaitOverlayRequested(true);
      return;
    }
    if (_worldActionRunning) return;
    if (action == WorldHeaderActionKind.request) {
      if (!await ensureGenesisLogin(context)) return;
      if (!mounted) return;
      final confirmed = await _confirmWorldRequest();
      if (!mounted || !confirmed) return;
    }
    if (action == WorldHeaderActionKind.launch) {
      final world = _world;
      if (world == null) return;
      await _showLaunchRoleSheet(world);
      return;
    }
    setState(() => _worldActionRunning = true);
    if (action == WorldHeaderActionKind.progress) {
      _openEventsAfterTickDone = true;
      _setWorldTickWaitOverlayRequested(true);
      _setWorldTickInProgress(true);
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'world_progress_submit_start',
        object1: widget.wid,
      );
    }
    try {
      final api = AppServicesScope.of(context).api;
      var message = '';
      if (action == WorldHeaderActionKind.request) {
        message = await api.requestWorld(widget.wid);
        GenesisTelemetry.collectLog(
          actionType: 'event',
          action: 'request_submit',
          object1: widget.wid,
        );
      } else if (action == WorldHeaderActionKind.progress) {
        final result = await api.progressWorldResult(widget.wid);
        message = result.message;
        _pendingProgressTickCount = result.tickCount > 0
            ? result.tickCount
            : null;
        if (result.tickCount > 1) {
          unawaited(_markLastTickActivityTag());
        }
        GenesisTelemetry.collectLog(
          actionType: 'event',
          action: 'world_progress_submit_success',
          object1: widget.wid,
          object2: _pendingProgressTickCount,
        );
      }
      if (!mounted) return;
      if (action != WorldHeaderActionKind.progress &&
          message.trim().isNotEmpty) {
        showGenesisToast(context, message);
      }
      if (action == WorldHeaderActionKind.progress) {
        _startWorldTickTracking(openEventsAfterDone: true);
      } else {
        await _fetchWorld();
      }
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      if (action == WorldHeaderActionKind.progress) {
        _openEventsAfterTickDone = false;
        _pendingProgressTickCount = null;
        _setWorldTickWaitOverlayRequested(false);
        _markWorldTickIdle();
        if (_isWorldProgressInsufficientGems(error)) {
          unawaited(
            showGemBalancePrompt(
              context,
              GemBalanceAlert(
                kind: GemBalanceAlertKind.insufficient,
                message: error is ApiException ? error.message : '',
              ),
            ),
          );
          return;
        }
      }
      showGenesisToast(context, '${worldHeaderActionLabel(action)} failed');
    } finally {
      if (mounted && action != WorldHeaderActionKind.progress) {
        setState(() => _worldActionRunning = false);
      }
    }
  }

  Future<void> _markLastTickActivityTag() async {
    final uid = await resolveRecentWorldChatUid(AppServicesScope.read(context));
    await worldActivityTagStore.markLastTick(uid: uid, worldId: widget.wid);
  }

  bool _isWorldProgressInsufficientGems(Object error) {
    return error is ApiException && error.code == 21001;
  }

  void _startWorldTickTracking({bool openEventsAfterDone = false}) {
    if (openEventsAfterDone) _openEventsAfterTickDone = true;
    _startWorldTickLockPolling();
    _setWorldTickInProgress(true);
    if (!_worldActionRunning) {
      if (mounted) {
        setState(() => _worldActionRunning = true);
      } else {
        _worldActionRunning = true;
      }
    }
  }

  void _setWorldTickInProgress(bool inProgress) {
    if (!inProgress) {
      _stopWorldTickLockPolling();
    }
    final changed = _worldTickInProgress != inProgress;
    if (changed) {
      if (mounted) {
        setState(() => _worldTickInProgress = inProgress);
      } else {
        _worldTickInProgress = inProgress;
      }
    }
    final chatroom = _worldChatroom;
    if (chatroom != null) {
      try {
        chatroom.setInputBlocked(inProgress);
      } catch (_) {
        // Socket state is best-effort; page state still gates the visible button.
      }
    }
  }

  void _setWorldTickWaitOverlayRequested(bool requested) {
    if (_worldTickWaitOverlayRequested == requested) return;
    if (mounted) {
      setState(() => _worldTickWaitOverlayRequested = requested);
    } else {
      _worldTickWaitOverlayRequested = requested;
    }
  }

  void _startWorldTickLockPolling() {
    if (_worldTickLockPollingTimer?.isActive == true) return;
    _worldTickLockPollingTimer = Timer.periodic(_worldTickLockPollInterval, (
      _,
    ) {
      unawaited(_pollWorldTickLockStatus(_worldTickLockPollingGeneration));
    });
  }

  void _stopWorldTickLockPolling() {
    _worldTickLockPollingTimer?.cancel();
    _worldTickLockPollingTimer = null;
    _worldTickLockPollInFlight = false;
    _worldTickLockPollingGeneration += 1;
  }

  Future<void> _pollWorldTickLockStatus(int generation) async {
    if (!mounted ||
        !_worldTickInProgress ||
        _worldTickDoneHandling ||
        _worldTickLockPollInFlight ||
        generation != _worldTickLockPollingGeneration) {
      return;
    }
    _worldTickLockPollInFlight = true;
    try {
      final status = await AppServicesScope.read(
        context,
      ).api.chatroomHttp.tickLockStatus(worldId: widget.wid);
      if (!mounted ||
          !_worldTickInProgress ||
          _worldTickDoneHandling ||
          generation != _worldTickLockPollingGeneration) {
        return;
      }
      if (!status.isLocked) {
        unawaited(_handleWorldTickDone());
      }
    } catch (_) {
      // Polling is a fallback; keep waiting for tick_done or the next poll.
    } finally {
      if (generation == _worldTickLockPollingGeneration) {
        _worldTickLockPollInFlight = false;
      }
    }
  }

  Future<void> _handleWorldTickDone() async {
    if (_worldTickDoneHandling) return;
    _worldTickDoneHandling = true;
    _markWorldTickIdle();
    try {
      await _fetchWorld();
      if (!mounted) return;
      _markEventsUnread();
      final completedTickCount = _world?.tickCount ?? _pendingProgressTickCount;
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'world_progress_async_complete',
        object1: widget.wid,
        object2: completedTickCount,
      );
      _pendingProgressTickCount = null;
      if (_openEventsAfterTickDone) {
        _openEventsAfterTickDone = false;
        if (!_shouldSuppressAutoEventsAfterTick) {
          _showOrSelectEventsAfterTick();
        }
      }
    } finally {
      _worldTickDoneHandling = false;
    }
  }

  bool get _shouldSuppressAutoEventsAfterTick {
    if (_activeChatLocationId.isNotEmpty) {
      return true;
    }
    if (_locationChatPageCache.activeLocationId.isNotEmpty) {
      return true;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return true;
    }
    return false;
  }

  void _showOrSelectEventsAfterTick() {
    if (_worldBottomSheetOpen &&
        _worldBottomSheetSelection.value.kind != WorldBottomSheetKind.events) {
      final sheetContext = _worldBottomSheetContext;
      if (sheetContext != null) {
        _openEventsAfterCurrentBottomSheetClosed = true;
        _eventsAfterCurrentBottomSheetClosedTargetTickNumber =
            _world?.tickCount;
        unawaited(Navigator.of(sheetContext).maybePop());
        return;
      }
    }
    _openWorldBottomSheet(
      WorldBottomSheetKind.events,
      scrollEventsToLatest: true,
      eventsTargetTickNumber: _world?.tickCount,
    );
  }

  void _markWorldTickIdle() {
    _setWorldTickInProgress(false);
    _setWorldTickWaitOverlayRequested(false);
    if (!mounted) {
      _worldActionRunning = false;
      return;
    }
    setState(() => _worldActionRunning = false);
  }

  void _markEventsUnread() {
    if (_eventsUnread) return;
    setState(() => _eventsUnread = true);
  }

  void _clearEventsUnread() {
    if (!_eventsUnread) return;
    setState(() => _eventsUnread = false);
  }

  Future<bool> _confirmWorldRequest() async {
    final result = await showGenesisActionBox<bool>(
      context: context,
      title: 'Request to join this World?',
      actions: const [
        GenesisActionBoxAction<bool>(
          label: 'Request',
          value: true,
          color: Color(0xFF2F9663),
        ),
      ],
    );
    return result ?? false;
  }

  Future<void> _showLaunchRoleSheet(WorldDetail world) async {
    if (_worldActionRunning) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    final selection = await showOriginRoleLaunchSheet(
      context: context,
      characters: worldPresetRoleCharacters(world),
      resolveAvatarUrl: worldResolveAssetUrl,
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
    if (!await _ensureProfileFillLogin()) return null;
    if (!mounted) return null;
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
    final profileAvatar = profile?.photoUrl.trim() ?? '';
    final cachedName = worldMapString(cachedUser, const [
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
      avatarUrl: worldResolvedProfileAvatar(cachedUser, profileAvatar),
      name: cachedName.isNotEmpty ? cachedName : profileName,
      identity: worldMapString(cachedUser, const ['identity']),
      bio: worldMapString(cachedUser, const ['bio', 'description']),
    );
  }

  Future<bool> _ensureProfileFillLogin() async {
    if (await _hasLocalLoginSession()) return true;
    if (!mounted) return false;
    final loggedIn = await showLoginSheet(
      context: context,
      onLogin: _loginWithProvider,
    );
    if (!mounted || !loggedIn) return false;
    await showDailyCheckInAfterLogin(context);
    if (!mounted) return false;
    return _hasLocalLoginSession();
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
  }

  Future<bool> _loginWithProvider(IdentityProvider provider) async {
    final services = AppServicesScope.read(context);
    final session = await services.identityAuth.signIn(provider);
    final user = await services.backendAuth.loginWithIdentity(session);
    if (user.uid.trim().isNotEmpty) {
      await services.sessionStore.saveUid(user.uid);
    }
    final cachedUserInfo = await services.sessionStore.readUserInfo();
    final loginUserInfo = <String, dynamic>{
      if (cachedUserInfo != null) ...cachedUserInfo,
      'uid': user.uid,
      'login_provider': provider.name,
    };
    if (user.nickname.trim().isNotEmpty) {
      loginUserInfo['name'] = user.nickname;
    }
    if (user.avatar.trim().isNotEmpty) {
      loginUserInfo['avatar'] = user.avatar;
    }
    await services.sessionStore.saveUserInfo(loginUserInfo);
    services.notifySessionChanged();
    return true;
  }

  Future<void> _openChatForPoint(WorldPoint point) async {
    final relationStatus = _world?.relationStatus.trim().toLowerCase() ?? '';
    if (!shouldConnectWorldChatroom(relationStatus)) {
      if (relationStatus == 'approved') {
        await _runWorldAction(WorldHeaderActionKind.launch);
      } else if (mounted) {
        showGenesisToast(context, 'Request approval to launch');
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
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'world_map',
      object1: widget.wid,
      object2: locationId,
    );
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'world_location_chat',
      object1: widget.wid,
      object2: locationId,
    );

    final locationPathIds = _world == null
        ? <String>[locationId]
        : _locationPathIdsForLocationId(
            locationId,
            _world!.processedLocationTree,
          );
    final descriptor = WorldLocationChatPanelDescriptor(
      locationId: locationId,
      locationName: point.name,
      backgroundImageUrl: point.iconUrl.trim().isNotEmpty
          ? point.iconUrl
          : point.mapImageUrl,
      backgroundPreviewImageUrl: '',
      isLeafLocation: point.isLeafLocation,
      localMessageLocationIds: worldOrderedNonEmptyStrings([
        pointId,
        locationId,
        point.id,
      ]),
      recentChatLocationPathIds: locationPathIds,
    );
    final syncedDescriptor =
        _locationChatDescriptors[locationId] ??
        _locationChatDescriptors[pointId] ??
        _locationChatDescriptors[point.id.trim()];
    unawaited(_updateUserPositionForLocation(locationId));
    await _showCachedLocationChat(
      syncedDescriptor?.copyWith(
            locationId: locationId,
            locationName: point.name,
            backgroundImageUrl:
                syncedDescriptor.backgroundImageUrl.trim().isNotEmpty
                ? syncedDescriptor.backgroundImageUrl
                : descriptor.backgroundImageUrl,
            backgroundPreviewImageUrl:
                syncedDescriptor.backgroundPreviewImageUrl.trim().isNotEmpty
                ? syncedDescriptor.backgroundPreviewImageUrl
                : descriptor.backgroundPreviewImageUrl,
            isLeafLocation: point.isLeafLocation,
            localMessageLocationIds: descriptor.localMessageLocationIds,
            recentChatLocationPathIds: descriptor.recentChatLocationPathIds,
          ) ??
          descriptor,
    );
  }

  void _recordWorldMapClick() {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'world_map_click',
      object1: widget.wid,
    );
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
    WorldLocationChatPanelDescriptor descriptor,
  ) async {
    final chatroom = _worldChatroom;
    final locationId = descriptor.locationId;
    if (locationId.isEmpty || chatroom == null || !mounted) return;
    final wasCached = _locationChatPageCache.hasPanel(locationId);
    final stopwatch = _locationChatMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final previousActiveId = _activeChatLocationId;
    _logLocationChatMetric(
      'open start location=$locationId cached=$wasCached '
      'previous=${previousActiveId.isEmpty ? 'none' : previousActiveId} '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    _recordWorldLocationChatDebug(
      action: 'openStart',
      locationId: locationId,
      details: {
        'cached': wasCached,
        'previousActiveId': previousActiveId,
        'descriptor': _debugDescriptor(descriptor),
      },
    );
    if (previousActiveId.isNotEmpty && previousActiveId != locationId) {
      if (!descriptor.isLeafLocation) {
        unawaited(_leaveCachedLocationChat(previousActiveId));
      }
    }
    setState(() {
      _locationChatDescriptors[locationId] = descriptor;
      _locationChatPageCache.activate(descriptor);
      _activeChatLocationId = locationId;
    });
    WorldDetailsStatusBarOverride.setStyle(kChatDarkHeaderSystemUiOverlayStyle);
    unawaited(_hydrateActiveLocationChatMessages(descriptor));
    _logLocationChatMetric(
      'open location=$locationId cached=$wasCached '
      'previous=${previousActiveId.isEmpty ? 'none' : previousActiveId} '
      'active=$_activeChatLocationId elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
    _recordWorldLocationChatDebug(
      action: 'openDone',
      locationId: locationId,
      details: {
        'cached': wasCached,
        'previousActiveId': previousActiveId,
        'elapsedMs': stopwatch?.elapsedMilliseconds,
      },
    );
  }

  Future<void> _hydrateActiveLocationChatMessages(
    WorldLocationChatPanelDescriptor descriptor,
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
      _recordWorldLocationChatDebug(
        action: 'activeHydrateSkipped',
        locationId: descriptor.locationId,
        details: {
          'hasChatroom': chatroom != null,
          'hasIdentity': identity != null,
        },
      );
      return;
    }
    final ownerUid = worldFirstNonEmpty([identity.userId, identity.senderId]);
    if (ownerUid.isEmpty) {
      _logLocationChatMetric(
        'active hydrate skipped location=${descriptor.locationId} noOwner',
      );
      _recordWorldLocationChatDebug(
        action: 'activeHydrateSkipped',
        locationId: descriptor.locationId,
        details: {'reason': 'noOwner'},
      );
      return;
    }
    _logLocationChatMetric(
      'active hydrate start location=${descriptor.locationId} '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    unawaited(_preloadLocationChatMessages(descriptor));
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
    _recordWorldLocationChatDebug(
      action: 'activeHydrateDone',
      locationId: descriptor.locationId,
      details: {
        'aliases': descriptor.localMessageLocationIds,
        'stateCount':
            chatroom.state.messagesByLocation[descriptor.locationId]?.length ??
            0,
        'elapsedMs': stopwatch?.elapsedMilliseconds,
      },
    );
  }

  void _closeCachedLocationChat() {
    final locationId = _activeChatLocationId;
    if (locationId.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_leaveCachedLocationChat(locationId));
    setState(() {
      _activeChatLocationId = '';
      _locationChatPageCache.deactivate();
    });
    _recordWorldLocationChatDebug(
      action: 'close',
      locationId: locationId,
      details: {'cachedPanelCount': _locationChatPageCache.cachedPanelCount},
    );
    _syncWorldStatusBarForMainTab();
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
    final signature = _locationChatDescriptorsSignature(descriptors);
    if (signature == _locationChatDescriptorSignature) return;
    _locationChatDescriptorSignature = signature;
    _locationChatDescriptors = descriptors;
    _locationChatPageCache.syncDescriptors(descriptors);
    _recordWorldLocationChatDebug(
      action: 'syncDescriptors',
      details: {
        'count': descriptors.length,
        'leafCount': descriptors.values
            .where((descriptor) => descriptor.isLeafLocation)
            .length,
        'descriptors': descriptors.values
            .map(_debugDescriptor)
            .toList(growable: false),
      },
    );
    if (!_locationChatDescriptors.containsKey(_activeChatLocationId)) {
      _activeChatLocationId = '';
      _locationChatPageCache.deactivate();
      _syncWorldStatusBarForMainTab();
    }
    _preloadedLocationMessageIds.removeWhere(
      (locationId) => !descriptors.containsKey(locationId),
    );
    _preloadingLocationMessageFutures.removeWhere(
      (locationId, _) => !descriptors.containsKey(locationId),
    );
    _mapBubbleMessagesReady = false;
    _recentChatLocationIds = const <String>{};
    _recentChatLocationPathIds = const <String>{};
    _scheduleLocationChatPrecache();
  }

  bool _shouldApplyChatroomWorldSnapshot(WorldDetail nextWorld) {
    final currentWorld = _world;
    if (currentWorld == null) return true;
    if (currentWorld.worldId != nextWorld.worldId) return true;
    if (currentWorld.relationStatus != nextWorld.relationStatus) return true;
    if (currentWorld.tickCount != nextWorld.tickCount) return true;
    if (currentWorld.currentTime != nextWorld.currentTime) return true;
    if (currentWorld.isProgressing != nextWorld.isProgressing) return true;
    final nextSignature = _locationChatDescriptorsSignature(
      _locationChatDescriptorsForWorld(nextWorld),
    );
    return nextSignature != _locationChatDescriptorSignature;
  }

  String _locationChatDescriptorsSignature(
    Map<String, WorldLocationChatPanelDescriptor> descriptors,
  ) {
    final parts =
        descriptors.values
            .map((descriptor) {
              return [
                descriptor.locationId,
                descriptor.locationName,
                descriptor.backgroundImageUrl,
                descriptor.backgroundPreviewImageUrl,
                descriptor.isLeafLocation ? '1' : '0',
                descriptor.localMessageLocationIds.join(','),
                descriptor.recentChatLocationPathIds.join(','),
              ].join('\u001f');
            })
            .toList(growable: false)
          ..sort();
    return parts.join('\u001e');
  }

  Map<String, WorldLocationChatPanelDescriptor>
  _locationChatDescriptorsForWorld(WorldDetail world) {
    final nodes = world.processedLocationTree.flattened;
    if (nodes.isNotEmpty) {
      return {
        for (final node in nodes)
          if (node.id.trim().isNotEmpty)
            node.id.trim(): WorldLocationChatPanelDescriptor.fromNode(node)
                .copyWith(
                  recentChatLocationPathIds: _locationPathIdsForLocationId(
                    node.id,
                    world.processedLocationTree,
                  ),
                ),
      };
    }

    final locationIdsById = <String, Map<String, dynamic>>{
      for (final location in world.locations)
        if (worldMapString(location, const ['location_id', 'id']).isNotEmpty)
          worldMapString(location, const ['location_id', 'id']): location,
    };
    final parentIds = world.locations
        .map((location) => worldMapString(location, const ['location_pid']))
        .where((locationId) => locationId.isNotEmpty)
        .toSet();
    return {
      for (final location in world.locations)
        if (worldMapString(location, const ['location_id', 'id']).isNotEmpty)
          worldMapString(location, const ['location_id', 'id']):
              WorldLocationChatPanelDescriptor.fromLocation(
                location,
                isLeafLocation: !parentIds.contains(
                  worldMapString(location, const ['location_id', 'id']),
                ),
              ).copyWith(
                recentChatLocationPathIds: _locationPathIdsFromLocations(
                  worldMapString(location, const ['location_id', 'id']),
                  locationIdsById,
                ),
              ),
    };
  }

  List<String> _locationPathIdsFromLocations(
    String locationId,
    Map<String, Map<String, dynamic>> locationsById,
  ) {
    final resolvedLocationId = locationId.trim();
    if (resolvedLocationId.isEmpty) return const <String>[];
    final path = <String>[];
    var currentId = resolvedLocationId;
    final seen = <String>{};
    while (currentId.isNotEmpty && seen.add(currentId)) {
      path.add(currentId);
      final current = locationsById[currentId];
      if (current == null) break;
      currentId = worldMapString(current, const ['location_pid']);
    }
    return worldOrderedNonEmptyStrings(path.reversed);
  }

  void _scheduleLocationChatPrecache() {
    final descriptors = _locationChatDescriptors.values
        .where((descriptor) => descriptor.isLeafLocation)
        .where((descriptor) => descriptor.locationId.trim().isNotEmpty)
        .toList(growable: false);
    _logLocationChatMetric(
      'panel precache scheduled count=${descriptors.length} '
      'cached=${_locationChatPageCache.cachedPanelCount} '
      'preloaded=${_preloadedLocationMessageIds.length}',
    );
    _recordWorldLocationChatDebug(
      action: 'precacheScheduled',
      details: {
        'count': descriptors.length,
        'cachedPanelCount': _locationChatPageCache.cachedPanelCount,
        'preloadedCount': _preloadedLocationMessageIds.length,
      },
    );
    if (descriptors.isEmpty) return;
    final chatroom = _worldChatroom;
    if (chatroom == null || chatroom.identity == null) return;
    final pendingDescriptors = descriptors
        .where(
          (descriptor) =>
              !_preloadedLocationMessageIds.contains(descriptor.locationId) &&
              !_preloadingLocationMessageFutures.containsKey(
                descriptor.locationId,
              ),
        )
        .toList(growable: false);
    if (pendingDescriptors.isEmpty) {
      final expectedIds = descriptors
          .map((descriptor) => descriptor.locationId.trim())
          .where((locationId) => locationId.isNotEmpty)
          .toSet();
      if (expectedIds.every(_preloadedLocationMessageIds.contains)) {
        _mapBubbleMessagesReady = true;
        _replaceMapBubbleCandidates(
          _buildMapBubbleCandidates(chatroom.state, _world),
        );
        _applyRecentChatLocationSelection(chatroom.state, _world);
      }
      return;
    }
    final pendingIds = pendingDescriptors
        .map((descriptor) => descriptor.locationId.trim())
        .where((locationId) => locationId.isNotEmpty)
        .toList(growable: false);
    final preloadFuture = chatroom
        .initializeLeafLocationQueues(locationIds: pendingIds)
        .then((_) {
          if (!identical(_worldChatroom, chatroom)) return;
          _preloadedLocationMessageIds.addAll(pendingIds);
        })
        .catchError((Object error) {
          _logLocationChatMetric('message preload failed error=$error');
          _recordWorldLocationChatDebug(
            action: 'preloadFailed',
            details: {'error': '$error'},
          );
        })
        .whenComplete(() {
          for (final locationId in pendingIds) {
            _preloadingLocationMessageFutures.remove(locationId);
          }
        });
    for (final locationId in pendingIds) {
      _preloadingLocationMessageFutures[locationId] = preloadFuture;
    }
    unawaited(
      preloadFuture.then((_) {
        if (!mounted || !identical(_worldChatroom, chatroom)) return;
        final expectedIds = descriptors
            .map((descriptor) => descriptor.locationId.trim())
            .where((locationId) => locationId.isNotEmpty)
            .toSet();
        if (!expectedIds.every(_preloadedLocationMessageIds.contains)) return;
        setState(() {
          _mapBubbleMessagesReady = true;
          _replaceMapBubbleCandidates(
            _buildMapBubbleCandidates(chatroom.state, _world),
          );
          _applyRecentChatLocationSelection(chatroom.state, _world);
        });
        _logLocationChatMetric(
          'map bubble messages ready locations=${expectedIds.length}',
        );
        _recordWorldLocationChatDebug(
          action: 'mapBubbleMessagesReady',
          details: {
            'locations': expectedIds.toList(growable: false),
            'candidateCount': _mapBubbleCandidates.length,
          },
        );
      }),
    );
  }

  Future<void> _preloadLocationChatMessages(
    WorldLocationChatPanelDescriptor descriptor,
  ) {
    final locationId = descriptor.locationId.trim();
    if (locationId.isEmpty || !descriptor.isLeafLocation) {
      return Future<void>.value();
    }
    final chatroom = _worldChatroom;
    if (chatroom == null || chatroom.identity == null) {
      return Future<void>.value();
    }
    if (_preloadedLocationMessageIds.contains(locationId)) {
      return Future<void>.value();
    }
    final existing = _preloadingLocationMessageFutures[locationId];
    if (existing != null) return existing;
    _logLocationChatMetric(
      'message preload start location=$locationId '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    _recordWorldLocationChatDebug(
      action: 'preloadStart',
      locationId: locationId,
      details: {'aliases': descriptor.localMessageLocationIds},
    );
    final future = chatroom
        .initializeLeafLocationQueues(locationIds: [locationId])
        .then((messages) {
          if (!identical(_worldChatroom, chatroom) ||
              !_locationChatDescriptors.containsKey(locationId)) {
            return;
          }
          _preloadedLocationMessageIds.add(locationId);
          _logLocationChatMetric(
            'message preload done location=$locationId '
            'stateCount=${chatroom.state.messagesByLocation[locationId]?.length ?? 0}',
          );
          _recordWorldLocationChatDebug(
            action: 'preloadDone',
            locationId: locationId,
            details: {
              'stateCount':
                  chatroom.state.messagesByLocation[locationId]?.length ?? 0,
            },
          );
        })
        .catchError((Object error) {
          _logLocationChatMetric(
            'message preload failed location=$locationId error=$error',
          );
          _recordWorldLocationChatDebug(
            action: 'preloadFailed',
            locationId: locationId,
            details: {'error': '$error'},
          );
        })
        .whenComplete(() {
          _preloadingLocationMessageFutures.remove(locationId);
        });
    _preloadingLocationMessageFutures[locationId] = future;
    return future;
  }

  bool get _locationChatMetricsEnabled => kDebugMode || kProfileMode;

  void _logLocationChatMetric(String message) {
    if (!_locationChatMetricsEnabled) return;
    debugPrint('[World][LocationChatCache] $message');
  }

  void _recordWorldLocationChatDebug({
    required String action,
    String locationId = '',
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!LocationChatDebugSlice.enabled) return;
    final activeLocationId = _activeChatLocationId.trim();
    LocationChatDebugSlice.recordEvent(
      source: 'world',
      action: action,
      worldId: widget.wid,
      locationId: locationId,
      details: <String, Object?>{
        ...details,
        'activeLocationId': activeLocationId,
        'cacheActiveLocationId': _locationChatPageCache.activeLocationId,
        'cachedPanelCount': _locationChatPageCache.cachedPanelCount,
        'preloadedLocationIds': _preloadedLocationMessageIds.toList(
          growable: false,
        ),
        'preloadingLocationIds': _preloadingLocationMessageFutures.keys.toList(
          growable: false,
        ),
        'mapBubbleMessagesReady': _mapBubbleMessagesReady,
      },
      snapshotKey: widget.wid,
      snapshot: <String, Object?>{
        'worldId': widget.wid,
        'activeLocationId': activeLocationId,
        'cacheActiveLocationId': _locationChatPageCache.activeLocationId,
        'cachedPanelCount': _locationChatPageCache.cachedPanelCount,
        'preloadedLocationIds': _preloadedLocationMessageIds.toList(
          growable: false,
        ),
        'preloadingLocationIds': _preloadingLocationMessageFutures.keys.toList(
          growable: false,
        ),
        'mapBubbleMessagesReady': _mapBubbleMessagesReady,
        'descriptorCount': _locationChatDescriptors.length,
        'descriptors': _locationChatDescriptors.values
            .map(_debugDescriptor)
            .toList(growable: false),
      },
    );
  }

  Map<String, Object?> _debugDescriptor(
    WorldLocationChatPanelDescriptor descriptor,
  ) {
    return <String, Object?>{
      'locationId': descriptor.locationId,
      'locationName': descriptor.locationName,
      'isLeafLocation': descriptor.isLeafLocation,
      'localMessageLocationIds': descriptor.localMessageLocationIds,
      'hasBackgroundImage': descriptor.backgroundImageUrl.trim().isNotEmpty,
      'ready': _locationChatPageCache.isReady(descriptor.locationId),
      'cached': _locationChatPageCache.hasPanel(descriptor.locationId),
    };
  }

  void _showMapTab() {
    if (_worldMainTabIndex == 0) return;
    _selectWorldMainTab(0);
  }

  void _handleBottomSheetLocationTap(WorldPoint point) {
    unawaited(_openChatForPoint(point));
  }

  void _openWorldBottomSheet(
    WorldBottomSheetKind kind, {
    List<WorldPoint> locationPoints = const <WorldPoint>[],
    List<WorldMapLocationNode> locationNodes = const <WorldMapLocationNode>[],
    bool scrollEventsToLatest = false,
    int? eventsTargetTickNumber,
  }) {
    final world = _world;
    if (world == null) return;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: worldBottomSheetPageName(kind),
      object1: widget.wid,
    );
    if (kind == WorldBottomSheetKind.events) {
      _clearEventsUnread();
    }
    if (kind == WorldBottomSheetKind.detail &&
        (_hasUnreadNewUserJoin || _pendingNewUserJoinNotice != null)) {
      setState(_activateDetailNewUserJoinNotices);
    }
    if (scrollEventsToLatest) {
      _eventsLatestRevision += 1;
    }
    _eventsTargetTickNumber = eventsTargetTickNumber;
    _sectionsWorldNotifier.value = world;
    final services = AppServicesScope.read(context);
    _worldBottomSheetSelection.value = WorldBottomSheetSelection(
      kind: kind,
      eventsLatestRevision: _eventsLatestRevision,
      eventsTargetTickNumber: _eventsTargetTickNumber,
    );
    if (_worldBottomSheetOpen) return;
    _worldBottomSheetOpen = true;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.18),
        builder: (context) {
          _worldBottomSheetContext = context;
          return WorldSingleSectionBottomSheet(
            selectionListenable: _worldBottomSheetSelection,
            services: services,
            initialWorld: world,
            worldListenable: _sectionsWorldNotifier,
            newUserJoinNoticesListenable: _newUserJoinNoticesNotifier,
            eventsCache: _sectionsEventsCache,
            currentUid: _currentUid,
            locationPoints: locationPoints,
            locationNodes: locationNodes,
            recentChatLocationIds: _recentChatLocationIds,
            onLocationTap: _handleBottomSheetLocationTap,
            onDeleteWorld: _confirmAndDeleteWorldFromDetail,
          );
        },
      ).whenComplete(() {
        _worldBottomSheetOpen = false;
        _worldBottomSheetContext = null;
        final openEvents = _openEventsAfterCurrentBottomSheetClosed;
        final targetTickNumber =
            _eventsAfterCurrentBottomSheetClosedTargetTickNumber;
        _openEventsAfterCurrentBottomSheetClosed = false;
        _eventsAfterCurrentBottomSheetClosedTargetTickNumber = null;
        if (openEvents && mounted && !_shouldSuppressAutoEventsAfterTick) {
          _openWorldBottomSheet(
            WorldBottomSheetKind.events,
            scrollEventsToLatest: true,
            eventsTargetTickNumber: targetTickNumber,
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = GenesisSafeAreaInsets.top(context);
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
      return _buildInitialLoadingScaffold(topPadding);
    }

    final avatarsByLocation = worldAvatarsByLocationFromCharacterPositions(
      world.characterPositions,
      currentUid: _currentUid,
    );
    final processedLocationTree = world.processedLocationTree;
    final rootLocationNodes = processedLocationTree.initialMapDisplayRoots;
    final rootMapImageUrl = _rootMapImageUrlForWorld(world);
    final renderLocationNodes = processedLocationTree.initialMapRenderRoots;
    final allLocationNodes = processedLocationTree.flattened;
    final locationNodes = worldMapLocationNodes(
      rootLocationNodes,
      avatarsByLocation,
      processedLocationTree,
    );
    final listLocationNodes = worldMapLocationNodes(
      processedLocationTree.mapRoots,
      avatarsByLocation,
      processedLocationTree,
    );
    final points = renderLocationNodes.isNotEmpty
        ? worldPointsFromLocationNodes(
            renderLocationNodes,
            avatarsByLocation,
            processedLocationTree,
          )
        : world.locations.isNotEmpty
        ? worldPointsFromLocations(
            worldRootWorldLocations(world.locations),
            avatarsByLocation,
          )
        : worldPointsFromLocationIds(
            world.characterPositions
                .map((e) => e['location_id'])
                .followedBy(world.userPositions.map((e) => e['location_id']))
                .toList(growable: false),
            avatarsByLocation,
          );
    final listPoints = allLocationNodes.isNotEmpty
        ? worldPointsFromLocationNodes(
            allLocationNodes,
            avatarsByLocation,
            processedLocationTree,
          )
        : world.locations.isNotEmpty
        ? worldPointsFromLocations(world.locations, avatarsByLocation)
        : points;
    final recentMapLocationIds = _recentChatLocationPathIds;
    final collapsedPanelHeight = worldCollapsedPanelHeightFor(context);
    Widget buildWorldMapPage(int tabIndex, {required bool pointMode}) {
      final map = WorldMap(
        key: PageStorageKey<String>('world-map-tab-$tabIndex'),
        points: points,
        listPoints: listPoints,
        locationNodes: locationNodes,
        listLocationNodes: listLocationNodes,
        messageBubbles: _activeChatLocationId.isEmpty && _mapBubbleMessagesReady
            ? _mapMessageBubbles
            : const <WorldMapMessageBubble>[],
        messageBubblePlaybackPaused: _activeChatLocationId.isNotEmpty,
        mapImageUrl: rootMapImageUrl,
        dimmed: pointMode,
        showPointsList: pointMode,
        recentChatLocationIds: _recentChatLocationIds,
        recentChatMapLocationIds: recentMapLocationIds,
        initialZoomScale: pointMode ? 1 : 1.2,
        pointsListOuterScrollHandoff: false,
        overlayTop:
            topPadding +
            8 +
            (pointMode ? worldMapTabsHeight + 8 : worldMapContentTopOffset),
        drillExitTop: topPadding + 8 + worldMapTabsHeight + worldTimePillTopGap,
        drillExitMaxWidth: worldSecondaryMapControlWidth,
        onDrillIntoLocation: _showMapTab,
        onHorizontalPanStateChanged: tabIndex == 0
            ? _handleWorldMapHorizontalPanStateChanged
            : null,
        onMapTap: _recordWorldMapClick,
        onPointTap: _openChatForPoint,
      );
      return WorldKeepAlivePage(child: map);
    }

    final canShowWorldTickProgress =
        _worldChatroom != null ||
        shouldConnectWorldChatroom(world.relationStatus);
    final mountedSlivers = <Widget>[
      const SliverToBoxAdapter(
        child: SizedBox(height: worldStatsTopSpacerHeight),
      ),
      WorldFeedContent(
        world: world,
        worldActionRunning: _worldActionRunning,
        onWorldAction: _runWorldAction,
        onPullUp: () => _openWorldBottomSheet(WorldBottomSheetKind.events),
      ),
    ];

    return PopScope(
      canPop: _activeChatLocationId.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWorldPopBlocked();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handleWorldMainSwipePointerDown,
        onPointerUp: _handleWorldMainSwipePointerUp,
        onPointerCancel: _handleWorldMainSwipePointerCancel,
        child: Stack(
          children: [
            WorldDetailsPageScaffold(
              panelTopGap: 50,
              panelCollapsedHeightOffset: 120,
              scrollPhysics: const NeverScrollableScrollPhysics(),
              persistentTopOverlay: _buildPersistentMapOverlay(
                topPadding,
                world: world,
                worldTime: world.currentTime,
                tickIndex: world.tickCount,
              ),
              map: buildWorldMapPage(0, pointMode: false),
              fixedCollapsedPanelHeight: collapsedPanelHeight,
              fixedCollapsedPanelHeightIncludesBottomSafeArea: true,
              contentBottomPaddingOverride: 0,
              onPanelTopPullUp: () =>
                  _openWorldBottomSheet(WorldBottomSheetKind.events),
              slivers: mountedSlivers,
            ),
            if (_worldMainTabIndex != 0)
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: topPadding,
                child: const ColoredBox(color: Colors.white),
              ),
            if (_worldMainTabIndex != 0)
              Positioned(
                left: 9.5,
                top: topPadding + 6,
                child: WorldMapBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: collapsedPanelHeight - worldMainTabsHeight,
              height: worldMainTabsHeight,
              child: WorldBottomTags(
                eventsUnread: _eventsUnread,
                showDetailUnreadDot: _hasUnreadNewUserJoin,
                onTap: (kind) => _openWorldBottomSheet(
                  kind,
                  locationPoints: listPoints,
                  locationNodes: listLocationNodes,
                ),
              ),
            ),
            Positioned.fill(
              child: WorldLocationChatRouterHost(
                worldId: widget.wid,
                chatroom: _worldChatroom,
                cache: _locationChatPageCache,
                onBack: _closeCachedLocationChat,
                isMessageQueueInitializationCovered: (locationId) {
                  final resolvedLocationId = locationId.trim();
                  return _preloadedLocationMessageIds.contains(
                        resolvedLocationId,
                      ) ||
                      _preloadingLocationMessageFutures.containsKey(
                        resolvedLocationId,
                      );
                },
                onPanelReady: (locationId) {
                  final becameReady = _locationChatPageCache.markReady(
                    locationId,
                  );
                  _recordWorldLocationChatDebug(
                    action: 'panelReady',
                    locationId: locationId,
                  );
                  if (mounted && becameReady) setState(() {});
                },
              ),
            ),
            if (canShowWorldTickProgress &&
                _worldTickInProgress &&
                (_worldTickWaitOverlayRequested ||
                    _activeChatLocationId.isNotEmpty ||
                    _locationChatPageCache.activeLocationId.isNotEmpty))
              Positioned.fill(
                child: GenesisGenerationWaitOverlay(
                  title: _progressWaitTitle,
                  message: _progressWaitMessage,
                  characterAvatars: _progressWaitAvatarsFromWorld(_world),
                  onBackPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialLoadingScaffold(double topPadding) {
    return WorldDetailsPageScaffold(
      panelTopGap: 50,
      panelCollapsedHeightOffset: 120,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      persistentTopOverlay: _buildPersistentMapOverlay(topPadding),
      map: WorldMap(
        points: const <WorldPoint>[],
        listPoints: const <WorldPoint>[],
        locationNodes: const <WorldMapLocationNode>[],
        fallbackOnEmptyMapUrl: false,
        dimmed: false,
        showPointsList: false,
        recentChatLocationIds: _recentChatLocationIds,
        pointsListOuterScrollHandoff: false,
        overlayTop: topPadding + 8 + worldMapContentTopOffset,
        drillExitTop: topPadding + 8 + worldMapContentTopOffset + 12,
      ),
      slivers: const [WorldDetailsLoadingContent()],
    );
  }

  Widget _buildPersistentMapOverlay(
    double top, {
    WorldDetail? world,
    String worldTime = '',
    int tickIndex = -1,
  }) {
    final title = world == null
        ? ''
        : (world.name.trim().isEmpty ? world.worldId : world.name.trim());
    final resolvedWorldTimeLabel = worldTimeLabel(
      tickIndex: tickIndex,
      worldTime: worldTime,
    );
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideReservedWidth =
              worldMapBackButtonLeft +
              worldMapTabsHeight +
              worldMapIdentityHorizontalGap;
          final maxIdentityWidth =
              (constraints.maxWidth - sideReservedWidth * 2)
                  .clamp(worldTimePillMinWidth, constraints.maxWidth)
                  .toDouble();
          return Stack(
            children: [
              if (_worldMainTabIndex == 0)
                Positioned(
                  left: worldMapBackButtonLeft,
                  top: top + 6,
                  child: WorldMapBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (world != null &&
                  (title.isNotEmpty || resolvedWorldTimeLabel.isNotEmpty))
                Positioned(
                  left: sideReservedWidth,
                  right: sideReservedWidth,
                  top: top + 2,
                  child: AnimatedBuilder(
                    animation:
                        _mainTabController.animation ?? _mainTabController,
                    builder: (context, _) {
                      if (_worldMainTabIndex != 0) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.topCenter,
                        child: WorldMapIdentityPill(
                          title: title,
                          timeText: resolvedWorldTimeLabel,
                          maxWidth: maxIdentityWidth,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteWorldFromDetail(
    BuildContext actionContext,
    WorldDetail world,
  ) async {
    final worldId = world.worldId.trim();
    if (worldId.isEmpty ||
        !worldCanDeleteLaunchedOnlyBySelf(world, _currentUid)) {
      showGenesisToast(
        actionContext,
        'Only worlds launched by you alone can be deleted.',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final confirmed = await showGenesisActionBox<bool>(
      context: actionContext,
      title: '',
      titleWidget: _DeleteWorldConfirmationTitle(name: world.name.trim()),
      titleHeight: 104,
      actions: const [
        GenesisActionBoxAction<bool>(
          label: 'Delete',
          value: true,
          color: Color(0xFFFF2442),
        ),
      ],
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !mounted || !actionContext.mounted) return;
    final api = AppServicesScope.read(actionContext).api;

    try {
      await api.v1.world.deleteLaunched(worldId: worldId);
      if (!mounted) return;
      final bottomSheetContext = _worldBottomSheetContext;
      if (bottomSheetContext != null && bottomSheetContext.mounted) {
        await Navigator.of(bottomSheetContext).maybePop();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(WorldPageResult.deleted(deletedWorldId: worldId));
    } catch (error) {
      if (!actionContext.mounted) return;
      showGenesisToast(actionContext, apiErrorMessage(error));
    }
  }
}

class _DeleteWorldConfirmationTitle extends StatelessWidget {
  const _DeleteWorldConfirmationTitle({required this.name});

  static const _baseStyle = TextStyle(
    color: Color(0xFF111111),
    fontSize: 15,
    height: 1.16,
    fontWeight: FontWeight.w600,
  );
  static const _nameStyle = TextStyle(color: Color(0xFF4B6192));

  final String name;

  @override
  Widget build(BuildContext context) {
    final resolvedName = name.trim().isEmpty ? 'this World' : name.trim();
    return Center(
      child: Text.rich(
        TextSpan(
          style: _baseStyle,
          children: [
            const TextSpan(text: 'Delete world '),
            TextSpan(text: resolvedName, style: _nameStyle),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
