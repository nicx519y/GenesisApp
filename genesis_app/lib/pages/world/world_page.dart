import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/models/world.dart';
import '../../platform/auth/auth_session.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../utils/display_name_formatter.dart';
import 'world_bottom_sheet.dart';
import 'world_constants.dart';
import 'world_header.dart';
import 'world_location_chat_host.dart';
import 'world_map_bubble_candidates.dart';
import 'world_map_data.dart';
import 'world_models.dart';
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
  static const Duration _worldInfoPollInterval = Duration(seconds: 5);
  static const double _worldMainSwipeSystemGestureEdgeWidth = 24;
  static const double _worldMainSwipeMinDistance = 48;
  static const double _worldMainSwipeDirectionRatio = 1.25;
  late final TabController _mainTabController;
  WorldDetail? _world;
  Object? _initialLoadError;
  WorldChatroomService? _worldChatroom;
  StreamSubscription<WorldChatroomState>? _worldChatroomSub;
  StreamSubscription? _worldChatroomFailureSub;
  Map<String, WorldLocationChatPanelDescriptor> _locationChatDescriptors =
      <String, WorldLocationChatPanelDescriptor>{};
  final _locationChatPageCache = WorldLocationChatPageCache();
  final Set<String> _preloadedLocationMessageIds = <String>{};
  final Map<String, Future<void>> _preloadingLocationMessageFutures =
      <String, Future<void>>{};
  Future<void>? _preloadMessageCacheResetFuture;
  String _activeChatLocationId = '';
  bool _pollInFlight = false;
  bool _worldActionRunning = false;
  bool _worldTickInProgress = false;
  bool _openEventsAfterTickDone = false;
  bool _worldBottomSheetOpen = false;
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
  bool _tick1WaitDialogStarted = false;
  Timer? _worldInfoPollTimer;
  Future<void>? _worldInfoPollFuture;
  int _lastAppliedChatroomWorldProgressRevision = 0;
  List<WorldMapBubbleCandidate> _mapBubbleCandidates =
      const <WorldMapBubbleCandidate>[];
  int? _pendingProgressTickCount;
  var _currentUid = '';
  var _currentUidRequested = false;
  late final ValueNotifier<WorldDetail?> _sectionsWorldNotifier =
      ValueNotifier<WorldDetail?>(_world);
  late final ValueNotifier<WorldBottomSheetSelection>
  _worldBottomSheetSelection = ValueNotifier<WorldBottomSheetSelection>(
    const WorldBottomSheetSelection(
      kind: WorldBottomSheetKind.detail,
      eventsLatestRevision: 0,
    ),
  );
  final _sectionsEventsCache = WorldSectionsEventsCache();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: worldMainPageCount, vsync: this);
    _mainTabController.addListener(_handleWorldMainTabChanged);
    _syncWorldStatusBarForMainTab();
    final initialWorld = widget.initialWorldDetail;
    if (initialWorld != null) {
      _world = initialWorld;
      _sectionsWorldNotifier.value = initialWorld;
      _syncLocationChatDescriptors(initialWorld);
      _syncWorldChatroomForRelationStatus(initialWorld.relationStatus);
      _maybeShowTick1WaitDialog();
      if (initialWorld.isProgressing) {
        _startWorldTickPolling();
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
    _mainTabController.removeListener(_handleWorldMainTabChanged);
    WorldDetailsStatusBarOverride.clearStyle();
    GenesisSystemUiChrome.applyDefault();
    unawaited(_worldChatroomSub?.cancel());
    unawaited(_worldChatroomFailureSub?.cancel());
    _stopWorldInfoPolling();
    final chatroom = _worldChatroom;
    _worldChatroom = null;
    if (chatroom != null) {
      unawaited(_disposeWorldChatroom(chatroom));
    }
    _mainTabController.dispose();
    _sectionsEventsCache.clear();
    _locationChatPageCache.dispose();
    _sectionsWorldNotifier.dispose();
    _worldBottomSheetSelection.dispose();
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
    final currentWorld = world ?? _world;
    var shouldSyncRelationStatus = false;
    final tickDoneFromPush = _worldTickInProgress && !state.inputBlocked;
    final socketCurrentTime = state.latestSocketCurrentTime.trim();
    final socketTickNo = state.latestSocketTickNo;
    final shouldApplySocketWorldProgress =
        (socketCurrentTime.isNotEmpty || socketTickNo > 0) &&
        state.latestSocketCurrentTimeRevision >
            _lastAppliedChatroomWorldProgressRevision;
    setState(() {
      if (world != null && !identical(_world, world)) {
        _world = world;
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
    });
    if (shouldSyncRelationStatus) {
      _syncWorldChatroomForRelationStatus(world!.relationStatus);
    }
    if (tickDoneFromPush) {
      unawaited(_handleWorldTickDone());
    }
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
    _worldChatroomSub = null;
    _worldChatroomFailureSub = null;
    _worldChatroom = null;
    _preloadedLocationMessageIds.clear();
    _preloadingLocationMessageFutures.clear();
    _preloadMessageCacheResetFuture = null;
    _mapBubbleMessagesReady = false;
    if (mounted) {
      setState(() {
        _activeChatLocationId = '';
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
    final shouldStartPolling = world.isProgressing;
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
    if (shouldStartPolling) {
      _startWorldTickPolling();
    } else if (_worldTickInProgress) {
      _markWorldTickIdle();
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
    if (_worldActionRunning) return;
    if (action == WorldHeaderActionKind.request) {
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
        _startWorldTickPolling(openEventsAfterDone: true);
      } else {
        await _fetchWorld();
      }
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      if (action == WorldHeaderActionKind.progress) {
        _openEventsAfterTickDone = false;
        _pendingProgressTickCount = null;
        _stopWorldInfoPolling();
        _markWorldTickIdle();
      }
      showGenesisToast(context, '${worldHeaderActionLabel(action)} failed');
    } finally {
      if (mounted && action != WorldHeaderActionKind.progress) {
        setState(() => _worldActionRunning = false);
      }
    }
  }

  void _startWorldTickPolling({bool openEventsAfterDone = false}) {
    if (openEventsAfterDone) _openEventsAfterTickDone = true;
    _setWorldTickInProgress(true);
    if (_worldInfoPollTimer != null) return;
    _worldInfoPollTimer = Timer.periodic(
      _worldInfoPollInterval,
      (_) => _pollWorldInfoUntilTickDone(),
    );
    unawaited(_pollWorldInfoUntilTickDone());
  }

  void _setWorldTickInProgress(bool inProgress) {
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

  Future<void> _pollWorldInfoUntilTickDone() {
    final existing = _worldInfoPollFuture;
    if (existing != null) return existing;
    final future = _pollWorldInfoOnce();
    _worldInfoPollFuture = future;
    return future.whenComplete(() {
      if (identical(_worldInfoPollFuture, future)) {
        _worldInfoPollFuture = null;
      }
    });
  }

  Future<void> _pollWorldInfoOnce() async {
    try {
      final world = await AppServicesScope.read(
        context,
      ).api.getWorldInfo(widget.wid);
      if (!mounted || world.isProgressing) return;
      await _handleWorldTickDone();
    } catch (error) {
      debugPrint(
        '[WorldPage] world/info poll failed wid="${widget.wid}": $error',
      );
    }
  }

  Future<void> _handleWorldTickDone() async {
    _stopWorldInfoPolling();
    _markWorldTickIdle();
    await _fetchWorld();
    if (!mounted) return;
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
      _showOrSelectEventsAfterTick();
    }
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
    if (!mounted) {
      _worldActionRunning = false;
      return;
    }
    setState(() => _worldActionRunning = false);
  }

  void _stopWorldInfoPolling() {
    _worldInfoPollTimer?.cancel();
    _worldInfoPollTimer = null;
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
      actionType: 'event',
      action: 'world_map_click',
      object1: widget.wid,
      object2: locationId,
    );
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
          ) ??
          descriptor,
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
      return;
    }
    final ownerUid = worldFirstNonEmpty([identity.userId, identity.senderId]);
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
    _locationChatDescriptors = descriptors;
    _locationChatPageCache.syncDescriptors(descriptors);
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
    _scheduleLocationChatPrecache();
  }

  Map<String, WorldLocationChatPanelDescriptor>
  _locationChatDescriptorsForWorld(WorldDetail world) {
    final nodes = world.processedLocationTree.flattened;
    if (nodes.isNotEmpty) {
      return {
        for (final node in nodes)
          if (node.id.trim().isNotEmpty)
            node.id.trim(): WorldLocationChatPanelDescriptor.fromNode(node),
      };
    }

    final parentIds = world.locations
        .map((location) => worldMapString(location, const ['location_pid']))
        .where((locationId) => locationId.isNotEmpty)
        .toSet();
    return {
      for (final location in world.locations)
        if (worldMapString(location, const ['location_id', 'id']).isNotEmpty)
          worldMapString(location, const [
            'location_id',
            'id',
          ]): WorldLocationChatPanelDescriptor.fromLocation(
            location,
            isLeafLocation: !parentIds.contains(
              worldMapString(location, const ['location_id', 'id']),
            ),
          ),
    };
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
    if (descriptors.isEmpty) return;
    final chatroom = _worldChatroom;
    if (chatroom == null || chatroom.identity == null) return;
    final resetFuture = _ensureLocationMessagePreloadReset(chatroom);
    final preloadFuture = Future.wait<void>(
      descriptors.map(
        (descriptor) =>
            _preloadLocationChatMessages(descriptor, resetFuture: resetFuture),
      ),
    );
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
        });
        _logLocationChatMetric(
          'map bubble messages ready locations=${expectedIds.length}',
        );
      }),
    );
  }

  Future<void> _ensureLocationMessagePreloadReset(
    WorldChatroomService chatroom,
  ) {
    final existing = _preloadMessageCacheResetFuture;
    if (existing != null) return existing;
    _logLocationChatMetric('message preload cache reset start');
    final future = chatroom
        .clearCachedMessages()
        .then((_) {
          if (!identical(_worldChatroom, chatroom)) return;
          _preloadedLocationMessageIds.clear();
          _logLocationChatMetric('message preload cache reset done');
        })
        .catchError((Object error) {
          _logLocationChatMetric(
            'message preload cache reset failed error=$error',
          );
          throw error;
        });
    _preloadMessageCacheResetFuture = future;
    return future;
  }

  Future<void> _preloadLocationChatMessages(
    WorldLocationChatPanelDescriptor descriptor, {
    Future<void>? resetFuture,
  }) {
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
    final resolvedResetFuture =
        resetFuture ?? _ensureLocationMessagePreloadReset(chatroom);
    _logLocationChatMetric(
      'message preload start location=$locationId '
      'aliases=${descriptor.localMessageLocationIds.join(',')}',
    );
    final future = resolvedResetFuture
        .then(
          (_) => chatroom.refreshLatestMessages(
            locationId: locationId,
            limit: 20,
            emitLatestFetched: false,
          ),
        )
        .then((messages) {
          if (!identical(_worldChatroom, chatroom) ||
              !_locationChatDescriptors.containsKey(locationId)) {
            return;
          }
          _preloadedLocationMessageIds.add(locationId);
          _logLocationChatMetric(
            'message preload done location=$locationId '
            'loaded=${messages.length} '
            'stateCount=${chatroom.state.messagesByLocation[locationId]?.length ?? 0}',
          );
        })
        .catchError((Object error) {
          _logLocationChatMetric(
            'message preload failed location=$locationId error=$error',
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
            eventsCache: _sectionsEventsCache,
            currentUid: _currentUid,
            locationPoints: locationPoints,
            locationNodes: locationNodes,
            onLocationTap: _handleBottomSheetLocationTap,
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
        if (openEvents && mounted) {
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
        onPointTap: _openChatForPoint,
      );
      return WorldKeepAlivePage(child: map);
    }

    final canShowWorldTickProgress = shouldConnectWorldChatroom(
      world.relationStatus,
    );
    final mountedSlivers = <Widget>[
      const SliverToBoxAdapter(
        child: SizedBox(height: worldStatsTopSpacerHeight),
      ),
      WorldFeedContent(
        world: world,
        worldActionRunning:
            _worldActionRunning ||
            (canShowWorldTickProgress && _worldTickInProgress),
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
                onPanelReady: (locationId) {
                  _locationChatPageCache.markReady(locationId);
                  if (mounted) setState(() {});
                },
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
}
