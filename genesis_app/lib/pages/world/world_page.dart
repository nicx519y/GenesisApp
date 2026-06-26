import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common/copyable_id_label.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/ai_content_disclaimer.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/shared/location_chat_overlay_transition.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../network/models/world.dart';
import '../../platform/auth/auth_session.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../chat/location_chat_page.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';

const String _worldSectionEventsIconAsset =
    'assets/custom-icons/svg/world_tab_events.svg';
const String _worldSectionStatusIconAsset =
    'assets/custom-icons/svg/world_tab_status.svg';
const String _worldSectionCastIconAsset =
    'assets/custom-icons/svg/world_tab_cast.svg';
const String _worldDetailIconAsset =
    'assets/custom-icons/svg/worlddetail-icon.svg';
const double _worldMapTabsHeight = 38;
const double _worldMapBackButtonLeft = 9.5;
const double _worldMapIdentityHorizontalGap = 12;
const double _worldMainTabsHeight = 53;
const double _worldBottomTagHeight = 34;
const double _worldBottomTagToStatsGap = 10;
const double _worldStatsTopSpacerHeight =
    (_worldMainTabsHeight + _worldBottomTagHeight) / 2 -
    WorldDetailsPageScaffold.inlineContentTopPadding +
    _worldBottomTagToStatsGap;
const double _worldInfoHeaderHeight = 56;
const double _worldInfoHeaderContentHeight = 35;
const double _worldTimePillTopGap = 12;
const double _worldTimePillHeight = 22;
const double _worldTimePillMinWidth = 96;
const double _worldSecondaryMapControlWidth = 160;
const double _worldTimePillHorizontalPadding = 12;
const double _worldMapContentTopOffset =
    _worldMapTabsHeight + _worldTimePillTopGap + _worldTimePillHeight + 8;
const double _worldCharacterAvatarLogicalSize = 48;
const int _worldMainPageCount = 1;

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
  static const Duration _mapMessageBubbleInterval = Duration(seconds: 4);
  static const Duration _mapMessageBubbleHiddenInterval = Duration(
    milliseconds: 500,
  );
  static const Duration _worldInfoPollInterval = Duration(seconds: 5);
  static const int _mapMessageBubbleQueueLimit = 60;
  static const int _mapMessageBubbleHistoryLimit = 20;
  static const int _mapMessageBubbleCacheLimit = 60;
  static const double _worldMainSwipeSystemGestureEdgeWidth = 24;
  static const double _worldMainSwipeMinDistance = 48;
  static const double _worldMainSwipeDirectionRatio = 1.25;
  late final TabController _mainTabController;
  WorldDetail? _world;
  Object? _initialLoadError;
  WorldChatroomService? _worldChatroom;
  StreamSubscription<WorldChatroomState>? _worldChatroomSub;
  StreamSubscription? _worldChatroomFailureSub;
  StreamSubscription<List<WorldChatroomMessage>>? _worldChatroomLatestSub;
  Map<String, _LocationChatPanelDescriptor> _locationChatDescriptors =
      <String, _LocationChatPanelDescriptor>{};
  final _locationChatPageCache = _WorldLocationChatPageCache();
  final Map<String, WorldMapMessageBubble> _mapMessageBubbles =
      <String, WorldMapMessageBubble>{};
  final Map<String, Queue<WorldChatroomMessage>>
  _mapMessageBubbleQueuesByLocation = <String, Queue<WorldChatroomMessage>>{};
  final Map<String, Queue<WorldChatroomMessage>>
  _priorityMapMessageBubbleQueuesByLocation =
      <String, Queue<WorldChatroomMessage>>{};
  final List<String> _mapMessageBubbleLocationOrder = <String>[];
  int _mapMessageBubbleLocationCursor = 0;
  Timer? _mapMessageBubbleTimer;
  final Map<String, List<String>> _mapMessageBubbleKeysByLocation =
      <String, List<String>>{};
  final Map<String, WorldMapMessageBubble> _activeMapMessageBubblesByLocation =
      <String, WorldMapMessageBubble>{};
  final Map<String, String> _mapMessageBubbleRoundByLocation =
      <String, String>{};
  final Set<String> _shownMapMessageBubbleKeys = <String>{};
  String _mapMessageBubblePrimeKey = '';
  Future<void>? _mapMessageBubblePrimeFuture;
  String _activeChatLocationId = '';
  Set<String> _visibleMapLocationIds = <String>{};
  String _visibleMapLocationIdsSignature = '';
  bool _isInSecondaryMap = false;
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
  int _eventsLatestRevision = 0;
  int? _eventsTargetTickNumber;
  bool _tick1WaitDialogStarted = false;
  Timer? _worldInfoPollTimer;
  Future<void>? _worldInfoPollFuture;
  int? _pendingProgressTickCount;
  var _currentUid = '';
  var _currentUidRequested = false;
  late final ValueNotifier<WorldDetail?> _sectionsWorldNotifier =
      ValueNotifier<WorldDetail?>(_world);
  late final ValueNotifier<_WorldBottomSheetSelection>
  _worldBottomSheetSelection = ValueNotifier<_WorldBottomSheetSelection>(
    const _WorldBottomSheetSelection(
      kind: _WorldBottomSheetKind.detail,
      eventsLatestRevision: 0,
    ),
  );
  final _sectionsEventsCache = _WorldSectionsEventsCache();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(
      length: _worldMainPageCount,
      vsync: this,
    );
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
    unawaited(_worldChatroomLatestSub?.cancel());
    _stopWorldInfoPolling();
    _clearMapMessageBubbleState(updateUi: false);
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
        .clamp(0, _worldMainPageCount - 1)
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
    final nextIndex = index.clamp(0, _worldMainPageCount - 1).toInt();
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
    if (nextIndex < 0 || nextIndex >= _worldMainPageCount) return;
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
    _worldChatroomLatestSub = service.latestFetchedMessages.listen(
      _handleLatestFetchedChatroomMessages,
    );
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
    final tickDoneFromPush = _worldTickInProgress && !state.inputBlocked;
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
    if (tickDoneFromPush) {
      unawaited(_handleWorldTickDone());
    }
    _maybePrimeMapMessageBubbles();
  }

  void _handleLatestFetchedChatroomMessages(
    List<WorldChatroomMessage> messages,
  ) {
    _enqueueMapMessageBubbles(messages, priority: true);
  }

  bool _enqueueMapMessageBubbles(
    Iterable<WorldChatroomMessage> messages, {
    required bool priority,
    bool startCarousel = true,
  }) {
    final byLocation = <String, List<WorldChatroomMessage>>{};
    for (final message in messages) {
      final candidate = _mapBubbleCandidate(message);
      if (candidate == null) continue;
      final queueLocationId = _mapBubbleQueueLocationId(candidate.locationId);
      if (queueLocationId.isEmpty) continue;
      byLocation
          .putIfAbsent(queueLocationId, () => <WorldChatroomMessage>[])
          .add(candidate);
    }
    if (byLocation.isEmpty) return false;
    var queuedAny = false;
    for (final entry in byLocation.entries) {
      final locationId = entry.key;
      final latestRoundMessages = _latestMapBubbleConversationMessages(
        entry.value,
      );
      if (latestRoundMessages.isEmpty) continue;
      final roundId = latestRoundMessages.first.conversationRoundId.trim();
      _resetMapBubbleLocationQueueForNewRound(locationId, roundId);
      final dedupedMessages = <WorldChatroomMessage>[];
      for (final message in latestRoundMessages) {
        final key = _mapMessageKey(message);
        if (key.isEmpty || !_shownMapMessageBubbleKeys.add(key)) continue;
        dedupedMessages.add(message);
      }
      if (dedupedMessages.isEmpty) continue;
      final locationMessages = _interleaveMapBubbleMessagesBySender(
        dedupedMessages,
      );
      _registerMapMessageBubbleLocation(locationId);
      final queueMap = priority
          ? _priorityMapMessageBubbleQueuesByLocation
          : _mapMessageBubbleQueuesByLocation;
      final queue = queueMap.putIfAbsent(
        locationId,
        () => Queue<WorldChatroomMessage>(),
      );
      queue.addAll(locationMessages);
      _trimMapMessageBubbleQueues(locationId);
      queuedAny = true;
    }
    if (queuedAny && startCarousel) {
      _ensureMapMessageBubbleCarousel();
    }
    return queuedAny;
  }

  List<WorldChatroomMessage> _latestMapBubbleConversationMessages(
    List<WorldChatroomMessage> messages,
  ) {
    if (messages.isEmpty) {
      return const <WorldChatroomMessage>[];
    }

    var latestTickNo = -1;
    for (final message in messages) {
      if (message.tickNo > latestTickNo) latestTickNo = message.tickNo;
    }
    if (latestTickNo < 0) return const <WorldChatroomMessage>[];

    final latestTickMessages = messages
        .where((message) => message.tickNo == latestTickNo)
        .toList(growable: false);
    if (latestTickMessages.isEmpty) return const <WorldChatroomMessage>[];

    var latestRound = -1;
    for (final message in latestTickMessages) {
      final round = message.conversationRoundNumber;
      if (round > latestRound) latestRound = round;
    }
    if (latestRound < 0) return const <WorldChatroomMessage>[];

    return latestTickMessages
        .where((message) => message.conversationRoundNumber == latestRound)
        .toList(growable: false)
      ..sort(_compareMapBubbleMessages);
  }

  void _resetMapBubbleLocationQueueForNewRound(
    String locationId,
    String roundId,
  ) {
    if (roundId.isEmpty) return;
    final previousRoundId = _mapMessageBubbleRoundByLocation[locationId];
    if (previousRoundId == roundId) return;
    _mapMessageBubbleRoundByLocation[locationId] = roundId;
    _mapMessageBubbleQueuesByLocation.remove(locationId);
    _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
    if (_activeMapMessageBubblesByLocation.containsKey(locationId)) {
      _removeActiveMapMessageBubble();
    }
  }

  void _registerMapMessageBubbleLocation(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty || _mapMessageBubbleLocationOrder.contains(id)) return;
    _mapMessageBubbleLocationOrder.add(id);
  }

  String _mapBubbleQueueLocationId(String locationId) {
    return _visibleMapBubbleLocationId(locationId);
  }

  String _visibleMapBubbleLocationId(String locationId) {
    final locationKeys = _mapBubbleLocationKeys(locationId);
    for (final key in locationKeys) {
      if (_visibleMapLocationIds.contains(key)) return key;
    }
    return '';
  }

  WorldChatroomMessage? _mapBubbleCandidate(WorldChatroomMessage message) {
    final locationId = message.locationId.trim();
    final content = message.content.trim();
    if (locationId.isEmpty || content.isEmpty || message.streaming) return null;
    final senderType = message.senderType.trim().toLowerCase();
    if (senderType != 'character') return null;
    if (content == message.content && locationId == message.locationId) {
      return message;
    }
    return message.copyWith(locationId: locationId, content: content);
  }

  void _trimMapMessageBubbleQueues(String locationId) {
    final normal = _mapMessageBubbleQueuesByLocation[locationId];
    final priority = _priorityMapMessageBubbleQueuesByLocation[locationId];
    var total = (normal?.length ?? 0) + (priority?.length ?? 0);
    while (total > _mapMessageBubbleQueueLimit) {
      if (normal?.isNotEmpty == true) {
        final removed = _removeLeastFairMapBubbleMessage(normal!);
        if (!removed) break;
      } else if (priority?.isNotEmpty == true) {
        final removed = _removeLeastFairMapBubbleMessage(priority!);
        if (!removed) break;
      } else {
        break;
      }
      total -= 1;
    }
    if (normal?.isEmpty == true) {
      _mapMessageBubbleQueuesByLocation.remove(locationId);
    }
    if (priority?.isEmpty == true) {
      _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
    }
  }

  void _ensureMapMessageBubbleCarousel() {
    if (_mapMessageBubbleTimer != null) return;
    _advanceMapMessageBubbleCarousel();
  }

  void _advanceMapMessageBubbleCarousel() {
    if (!mounted) return;
    if (!_showNextMapMessageBubble()) {
      _mapMessageBubbleTimer?.cancel();
      _mapMessageBubbleTimer = null;
      _clearActiveMapMessageBubble();
      return;
    }

    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = Timer(
      _mapMessageBubbleInterval,
      _hideMapMessageBubbleBeforeNext,
    );
  }

  void _hideMapMessageBubbleBeforeNext() {
    if (!mounted) return;
    _clearActiveMapMessageBubble();
    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = Timer(
      _mapMessageBubbleHiddenInterval,
      _advanceMapMessageBubbleCarousel,
    );
  }

  bool _showNextMapMessageBubble() {
    final triedLocationIds = <String>{};
    while (true) {
      final locationId = _nextPlayableMapBubbleLocationId(triedLocationIds);
      if (locationId == null) return false;
      triedLocationIds.add(locationId);
      final nextMessage = _nextMapMessageBubble(locationId);
      if (nextMessage == null) continue;
      if (_showMapMessageBubble(nextMessage)) {
        return true;
      }
    }
  }

  String? _nextPlayableMapBubbleLocationId(Set<String> excludedLocationIds) {
    for (final locationId in _priorityMapMessageBubbleQueuesByLocation.keys) {
      _registerMapMessageBubbleLocation(locationId);
    }
    for (final locationId in _mapMessageBubbleQueuesByLocation.keys) {
      _registerMapMessageBubbleLocation(locationId);
    }
    final total = _mapMessageBubbleLocationOrder.length;
    if (total == 0) return null;
    var cursor = _mapMessageBubbleLocationCursor % total;
    for (var offset = 0; offset < total; offset += 1) {
      final index = (cursor + offset) % total;
      final locationId = _mapMessageBubbleLocationOrder[index];
      if (excludedLocationIds.contains(locationId)) continue;
      if (!_hasPlayableMapBubbleQueue(locationId)) continue;
      _mapMessageBubbleLocationCursor = (index + 1) % total;
      return locationId;
    }
    _mapMessageBubbleLocationCursor = cursor;
    return null;
  }

  bool _hasPlayableMapBubbleQueue(String locationId) {
    return (_priorityMapMessageBubbleQueuesByLocation[locationId]?.isNotEmpty ??
            false) ||
        (_mapMessageBubbleQueuesByLocation[locationId]?.isNotEmpty ?? false);
  }

  WorldChatroomMessage? _nextMapMessageBubble(String locationId) {
    final priority = _priorityMapMessageBubbleQueuesByLocation[locationId];
    while (priority != null && priority.isNotEmpty) {
      final message = priority.removeFirst();
      if (priority.isEmpty) {
        _priorityMapMessageBubbleQueuesByLocation.remove(locationId);
      }
      if (!_hasMapBubbleDisplayContent(message)) {
        _trimMapMessageBubbleQueues(locationId);
        continue;
      }
      _mapMessageBubbleQueuesByLocation
          .putIfAbsent(locationId, () => Queue<WorldChatroomMessage>())
          .addLast(message);
      _trimMapMessageBubbleQueues(locationId);
      return message;
    }
    final normal = _mapMessageBubbleQueuesByLocation[locationId];
    if (normal != null && normal.isNotEmpty) {
      final attempts = normal.length;
      for (var index = 0; index < attempts; index += 1) {
        final message = normal.removeFirst();
        if (!_hasMapBubbleDisplayContent(message)) continue;
        normal.addLast(message);
        return message;
      }
      if (normal.isEmpty) {
        _mapMessageBubbleQueuesByLocation.remove(locationId);
      }
    }
    return null;
  }

  bool _removeLeastFairMapBubbleMessage(Queue<WorldChatroomMessage> queue) {
    if (queue.isEmpty) return false;
    if (queue.length == 1) {
      queue.removeFirst();
      return true;
    }
    final countsBySender = <String, int>{};
    for (final message in queue) {
      final sender = _mapBubbleSenderStableId(message);
      countsBySender[sender] = (countsBySender[sender] ?? 0) + 1;
    }
    var maxCount = 0;
    for (final count in countsBySender.values) {
      if (count > maxCount) maxCount = count;
    }
    final next = Queue<WorldChatroomMessage>();
    var removed = false;
    for (final message in queue) {
      final sender = _mapBubbleSenderStableId(message);
      if (!removed && (countsBySender[sender] ?? 0) == maxCount) {
        removed = true;
        continue;
      }
      next.addLast(message);
    }
    if (!removed) {
      queue.removeFirst();
      return true;
    }
    queue
      ..clear()
      ..addAll(next);
    return true;
  }

  bool _hasMapBubbleDisplayContent(WorldChatroomMessage message) {
    return _mapBubbleDisplayContent(message.content).isNotEmpty;
  }

  bool _showMapMessageBubble(WorldChatroomMessage message) {
    final content = _mapBubbleDisplayContent(message.content);
    if (content.isEmpty) {
      return false;
    }
    final locationId = message.locationId.trim();
    if (locationId.isEmpty) {
      return false;
    }
    final bubble = WorldMapMessageBubble(
      locationId: locationId,
      senderId: _firstNonEmpty([message.senderId, message.userId]),
      senderName: message.senderName,
      senderAvatarUrl: _mapBubbleSenderAvatarUrl(message),
      content: content,
      createdAt: DateTime.now(),
    );
    final locationKeys = _mapBubbleLocationKeys(locationId);
    if (locationKeys.isEmpty) {
      return false;
    }
    final displayLocationId = _visibleMapBubbleLocationId(locationId);
    if (displayLocationId.isEmpty) {
      return false;
    }
    setState(() {
      _removeActiveMapMessageBubble();
      _activeMapMessageBubblesByLocation[displayLocationId] = bubble;
      _mapMessageBubbleKeysByLocation[displayLocationId] = locationKeys;
      _mapMessageBubbles[displayLocationId] = bubble;
    });
    return true;
  }

  String _mapBubbleDisplayContent(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(
      RegExp(r'(^|\n)[ \t]*(`{3,}|~{3,})[\s\S]*?(\n[ \t]*\2[ \t]*(?=\n|$)|$)'),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
    text = text
        .split('\n')
        .where((line) => !_isMapBubbleMarkdownLine(line))
        .join('\n');
    text = _removeMapBubbleInlineMarkdown(text);
    text = text.replaceAllMapped(
      RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>])'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'[「」]'), '');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n+ *'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'\s+([,.!?;:])'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'([([{])\s+'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'\\r\\n|\\n|\\r'), ' ');
    return text.trim();
  }

  bool _isMapBubbleMarkdownLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^#{1,6}\s+').hasMatch(trimmed) ||
        RegExp(r'^>\s*').hasMatch(trimmed) ||
        RegExp(r'^[-*+]\s+').hasMatch(trimmed) ||
        RegExp(r'^\d+[.)]\s+').hasMatch(trimmed) ||
        RegExp(r'^[-*_]{3,}$').hasMatch(trimmed) ||
        RegExp(r'^\[[^\]]+\]:\s*\S+').hasMatch(trimmed) ||
        RegExp(r'^\|.*\|$').hasMatch(trimmed) ||
        RegExp(
          r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$',
        ).hasMatch(trimmed);
  }

  String _removeMapBubbleInlineMarkdown(String input) {
    var text = input;
    final patterns = <RegExp>[
      RegExp(r'!\[[^\]\n]*\]\([^)\n]*\)'),
      RegExp(r'!\[[^\]\n]*\]\[[^\]\n]*\]'),
      RegExp(r'\[[^\]\n]+\]\([^)\n]*\)'),
      RegExp(r'\[[^\]\n]+\]\[[^\]\n]*\]'),
      RegExp(r'`+[^`\n]+`+'),
      RegExp(r'\*\*[^*\n]+\*\*'),
      RegExp(r'__[^_\n]+__'),
      RegExp(r'~~[^~\n]+~~'),
      RegExp(r'\*[^*\n]+\*'),
      RegExp(r'_[^_\n]+_'),
      RegExp(r'<https?://[^>\s]+>'),
      RegExp(r'\[[^\]\n]+\]'),
    ];
    var changed = true;
    while (changed) {
      changed = false;
      for (final pattern in patterns) {
        final next = text.replaceAll(pattern, ' ');
        if (next != text) {
          changed = true;
          text = next;
        }
      }
    }
    return text;
  }

  void _clearActiveMapMessageBubble() {
    if (!mounted) {
      _removeActiveMapMessageBubble();
      return;
    }
    setState(() {
      _removeActiveMapMessageBubble();
    });
  }

  void _removeActiveMapMessageBubble() {
    _activeMapMessageBubblesByLocation.clear();
    _mapMessageBubbleKeysByLocation.clear();
    _mapMessageBubbles.clear();
  }

  void _clearMapMessageBubbleState({bool updateUi = true}) {
    _mapMessageBubbleTimer?.cancel();
    _mapMessageBubbleTimer = null;
    void clearState() {
      _mapMessageBubbleQueuesByLocation.clear();
      _priorityMapMessageBubbleQueuesByLocation.clear();
      _mapMessageBubbleLocationOrder.clear();
      _mapMessageBubbleLocationCursor = 0;
      _mapMessageBubbleKeysByLocation.clear();
      _activeMapMessageBubblesByLocation.clear();
      _mapMessageBubbleRoundByLocation.clear();
      _shownMapMessageBubbleKeys.clear();
      _mapMessageBubblePrimeKey = '';
      _mapMessageBubblePrimeFuture = null;
      _mapMessageBubbles.clear();
    }

    if (updateUi && mounted) {
      setState(clearState);
    } else {
      clearState();
    }
  }

  void _maybePrimeMapMessageBubbles() {
    final service = _worldChatroom;
    final world = _world;
    final identity = service?.identity;
    if (service == null || world == null || identity == null) return;
    if (!_shouldConnectWorldChatroom(world.relationStatus)) return;
    final ownerUid = _firstNonEmpty([identity.userId, identity.senderId]);
    if (ownerUid.isEmpty) return;
    final descriptors = _leafLocationChatDescriptors();
    if (descriptors.isEmpty) return;
    if (_visibleMapLocationIds.isEmpty) return;
    final primeKey = [
      widget.wid,
      ownerUid,
      for (final locationId in (_visibleMapLocationIds.toList()..sort()))
        locationId,
      for (final descriptor in descriptors) descriptor.locationId,
    ].join('\u001F');
    if (_mapMessageBubblePrimeKey == primeKey) return;
    _mapMessageBubblePrimeKey = primeKey;
    final future = _primeMapMessageBubbles(
      service: service,
      descriptors: descriptors,
      primeKey: primeKey,
    );
    _mapMessageBubblePrimeFuture = future;
    unawaited(
      future
          .catchError((Object error) {
            debugPrint('[WorldPage] map bubble prime failed: $error');
            if (_mapMessageBubblePrimeKey == primeKey) {
              _mapMessageBubblePrimeKey = '';
            }
          })
          .whenComplete(() {
            if (identical(_mapMessageBubblePrimeFuture, future)) {
              _mapMessageBubblePrimeFuture = null;
            }
          }),
    );
  }

  Future<void> _primeMapMessageBubbles({
    required WorldChatroomService service,
    required List<_LocationChatPanelDescriptor> descriptors,
    required String primeKey,
  }) async {
    try {
      await service.refreshUserLocations();
    } catch (error) {
      debugPrint('[WorldPage] map bubble location refresh failed: $error');
    }
    if (!_isCurrentMapBubblePrime(service, primeKey)) return;
    var queuedAny = false;
    for (final descriptor in descriptors) {
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      var cachedMessages = await service.loadCachedMessages(
        worldId: widget.wid,
        locationId: descriptor.locationId,
        locationAliases: descriptor.localMessageLocationIds,
        limit: _mapMessageBubbleCacheLimit,
      );
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      if (cachedMessages.isEmpty) {
        await service.refreshLatestMessages(
          locationId: descriptor.locationId,
          limit: _mapMessageBubbleHistoryLimit,
          emitLatestFetched: false,
        );
        if (!_isCurrentMapBubblePrime(service, primeKey)) return;
        cachedMessages = await service.loadCachedMessages(
          worldId: widget.wid,
          locationId: descriptor.locationId,
          locationAliases: descriptor.localMessageLocationIds,
          limit: _mapMessageBubbleCacheLimit,
        );
      }
      if (!_isCurrentMapBubblePrime(service, primeKey)) return;
      queuedAny =
          _enqueueMapMessageBubbles(
            cachedMessages,
            priority: false,
            startCarousel: false,
          ) ||
          queuedAny;
    }
    if (_isCurrentMapBubblePrime(service, primeKey) && queuedAny) {
      _ensureMapMessageBubbleCarousel();
    }
  }

  bool _isCurrentMapBubblePrime(WorldChatroomService service, String primeKey) {
    return mounted &&
        identical(_worldChatroom, service) &&
        _mapMessageBubblePrimeKey == primeKey;
  }

  List<_LocationChatPanelDescriptor> _leafLocationChatDescriptors() {
    final descriptors =
        _locationChatDescriptors.values
            .where(
              (descriptor) =>
                  descriptor.isLeafLocation &&
                  descriptor.locationId.trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.locationId.compareTo(b.locationId));
    return descriptors;
  }

  void _handleSecondaryMapChanged(bool isInSecondaryMap) {
    if (_isInSecondaryMap == isInSecondaryMap) return;
    _isInSecondaryMap = isInSecondaryMap;
    _visibleMapLocationIds = <String>{};
    _visibleMapLocationIdsSignature = '';
    _clearMapMessageBubbleState();
  }

  void _handleVisibleMapLocationIdsChanged(List<String> locationIds) {
    final ids = locationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final signature = (ids.toList()..sort()).join('\u001F');
    if (signature == _visibleMapLocationIdsSignature) return;
    _visibleMapLocationIds = ids;
    _visibleMapLocationIdsSignature = signature;
    _clearMapMessageBubbleState();
    _maybePrimeMapMessageBubbles();
  }

  List<String> _mapBubbleLocationKeys(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty) return const <String>[];
    final world = _world;
    final result = <String>[id];
    final tree = world?.processedLocationTree;
    if (tree == null) return result;
    var node = tree.nodeById(id);
    while (node != null && node.parentId.trim().isNotEmpty) {
      final parentId = node.parentId.trim();
      if (!result.contains(parentId)) result.add(parentId);
      node = tree.nodeById(parentId);
    }
    return result;
  }

  String _mapMessageKey(WorldChatroomMessage message) {
    if (message.messageId > 0) return 'm:${message.messageId}';
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isNotEmpty) return 'c:$clientMsgId';
    return [
      message.locationId,
      message.conversationRoundId,
      message.roundOrder,
      message.senderId,
      message.content,
    ].join('|');
  }

  String _mapBubbleSenderStableId(WorldChatroomMessage message) {
    final senderId = _firstNonEmpty([message.senderId, message.userId]).trim();
    if (senderId.isNotEmpty) return senderId;
    final senderName = message.senderName.trim().toLowerCase();
    if (senderName.isNotEmpty) return 'bubble-sender-name:$senderName';
    return 'bubble-sender-location:${message.locationId.trim()}';
  }

  List<WorldChatroomMessage> _interleaveMapBubbleMessagesBySender(
    List<WorldChatroomMessage> messages,
  ) {
    if (messages.length < 3) {
      return messages..sort(_compareMapBubbleMessages);
    }
    final sorted = [...messages]..sort(_compareMapBubbleMessages);
    final bySender = <String, Queue<WorldChatroomMessage>>{};
    final senderOrder = <String>[];
    for (final message in sorted) {
      final sender = _mapBubbleSenderStableId(message);
      if (!bySender.containsKey(sender)) {
        senderOrder.add(sender);
        bySender[sender] = Queue<WorldChatroomMessage>();
      }
      bySender[sender]!.addLast(message);
    }
    if (senderOrder.length < 2) return sorted;
    final out = <WorldChatroomMessage>[];
    var senderIndex = 0;
    while (out.length < sorted.length) {
      var advanced = false;
      for (var offset = 0; offset < senderOrder.length; offset += 1) {
        final index = (senderIndex + offset) % senderOrder.length;
        final queue = bySender[senderOrder[index]];
        if (queue == null || queue.isEmpty) continue;
        out.add(queue.removeFirst());
        senderIndex = (index + 1) % senderOrder.length;
        advanced = true;
        break;
      }
      if (!advanced) break;
    }
    return out;
  }

  int _compareMapBubbleMessages(
    WorldChatroomMessage a,
    WorldChatroomMessage b,
  ) {
    if (a.messageId > 0 && b.messageId > 0) {
      return a.messageId.compareTo(b.messageId);
    }
    final createdAtA = a.createdAt;
    final createdAtB = b.createdAt;
    if (createdAtA != null && createdAtB != null) {
      return createdAtA.compareTo(createdAtB);
    }
    final round = a.conversationRoundNumber.compareTo(
      b.conversationRoundNumber,
    );
    if (round != 0) return round;
    return a.roundOrder.compareTo(b.roundOrder);
  }

  String _mapBubbleSenderAvatarUrl(WorldChatroomMessage message) {
    final senderId = _firstNonEmpty([message.senderId, message.userId]).trim();
    final senderKey = senderId.toLowerCase();
    final senderNameKey = message.senderName.trim().toLowerCase();
    final world = _world;
    if (world == null) return '';
    for (final character in world.characters) {
      final characterId = _mapString(character, const [
        'character_id',
        'char_id',
        'id',
        'uid',
        'player_uid',
      ]).trim();
      final characterName = _mapString(character, const ['name']).trim();
      final matchesId =
          senderKey.isNotEmpty && characterId.toLowerCase() == senderKey;
      final matchesName =
          senderNameKey.isNotEmpty &&
          characterName.toLowerCase() == senderNameKey;
      if (!matchesId && !matchesName) continue;
      return _resolveAssetUrl(
        _mapString(character, const ['avatar', 'avatar_url']),
      );
    }
    return '';
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
    unawaited(_worldChatroomLatestSub?.cancel());
    _worldChatroomSub = null;
    _worldChatroomFailureSub = null;
    _worldChatroomLatestSub = null;
    _worldChatroom = null;
    if (mounted) {
      setState(() {
        _activeChatLocationId = '';
        _locationChatPageCache.clear();
        _isInSecondaryMap = false;
      });
    }
    _clearMapMessageBubbleState();
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
      _maybePrimeMapMessageBubbles();
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
    });
    _syncWorldChatroomForRelationStatus(world.relationStatus);
    if (shouldStartPolling) {
      _startWorldTickPolling();
    } else if (_worldTickInProgress) {
      _markWorldTickIdle();
    }
    _maybePrimeMapMessageBubbles();
  }

  String _rootMapImageUrlForWorld(WorldDetail world) {
    final displayRootMapUrl = _rootWorldMapImageUrl(
      world.processedLocationTree.initialMapDisplayRoots,
    ).trim();
    if (displayRootMapUrl.isNotEmpty) return displayRootMapUrl;
    final worldMapUrl = world.mapImageUrl.trim();
    if (worldMapUrl.isNotEmpty) return worldMapUrl;
    return world.origin.worldMap.trim();
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
          barrierDismissible: false,
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

  Future<void> _runWorldAction(_WorldHeaderActionKind action) async {
    if (_worldActionRunning) return;
    if (action == _WorldHeaderActionKind.request) {
      final confirmed = await _confirmWorldRequest();
      if (!mounted || !confirmed) return;
    }
    if (action == _WorldHeaderActionKind.launch) {
      final world = _world;
      if (world == null) return;
      await _showLaunchRoleSheet(world);
      return;
    }
    setState(() => _worldActionRunning = true);
    if (action == _WorldHeaderActionKind.progress) {
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
      if (action == _WorldHeaderActionKind.request) {
        message = await api.requestWorld(widget.wid);
        GenesisTelemetry.collectLog(
          actionType: 'event',
          action: 'request_submit',
          object1: widget.wid,
        );
      } else if (action == _WorldHeaderActionKind.progress) {
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
      if (message.trim().isNotEmpty) {
        showGenesisToast(context, message);
      }
      if (action == _WorldHeaderActionKind.progress) {
        _startWorldTickPolling(openEventsAfterDone: true);
      } else {
        await _fetchWorld();
      }
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      if (action == _WorldHeaderActionKind.progress) {
        _openEventsAfterTickDone = false;
        _pendingProgressTickCount = null;
        _stopWorldInfoPolling();
        _markWorldTickIdle();
      }
      showGenesisToast(context, '${_worldHeaderActionLabel(action)} failed');
    } finally {
      if (mounted && action != _WorldHeaderActionKind.progress) {
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
        _worldBottomSheetSelection.value.kind != _WorldBottomSheetKind.events) {
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
      _WorldBottomSheetKind.events,
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
      avatarUrl: _resolvedProfileAvatar(cachedUser, profileAvatar),
      name: cachedName.isNotEmpty ? cachedName : profileName,
      identity: _mapString(cachedUser, const ['identity']),
      bio: _mapString(cachedUser, const ['bio', 'description']),
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
    if (!_shouldConnectWorldChatroom(relationStatus)) {
      if (relationStatus == 'approved') {
        await _runWorldAction(_WorldHeaderActionKind.launch);
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

    final descriptor = _LocationChatPanelDescriptor(
      locationId: locationId,
      locationName: point.name,
      backgroundImageUrl: point.iconUrl.trim().isNotEmpty
          ? point.iconUrl
          : point.mapImageUrl,
      backgroundPreviewImageUrl: '',
      isLeafLocation: point.isLeafLocation,
      localMessageLocationIds: _orderedNonEmptyStrings([
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
    _LocationChatPanelDescriptor descriptor,
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
      'panel precache scheduled count=${locationIds.length} '
      'cached=${_locationChatPageCache.cachedPanelCount}',
    );
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

  void _openWorldBottomSheet(
    _WorldBottomSheetKind kind, {
    List<WorldPoint> locationPoints = const <WorldPoint>[],
    List<WorldMapLocationNode> locationNodes = const <WorldMapLocationNode>[],
    bool scrollEventsToLatest = false,
    int? eventsTargetTickNumber,
  }) {
    final world = _world;
    if (world == null) return;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: _worldBottomSheetPageName(kind),
      object1: widget.wid,
    );
    if (scrollEventsToLatest) {
      _eventsLatestRevision += 1;
    }
    _eventsTargetTickNumber = eventsTargetTickNumber;
    _sectionsWorldNotifier.value = world;
    final services = AppServicesScope.read(context);
    _worldBottomSheetSelection.value = _WorldBottomSheetSelection(
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
          return _WorldSingleSectionBottomSheet(
            selectionListenable: _worldBottomSheetSelection,
            services: services,
            initialWorld: world,
            worldListenable: _sectionsWorldNotifier,
            eventsCache: _sectionsEventsCache,
            currentUid: _currentUid,
            locationPoints: locationPoints,
            locationNodes: locationNodes,
            onLocationTap: _openChatForPoint,
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
            _WorldBottomSheetKind.events,
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

    final avatarsByLocation = _avatarsByLocationFromCharacterPositions(
      world.characterPositions,
      currentUid: _currentUid,
    );
    final processedLocationTree = world.processedLocationTree;
    final rootLocationNodes = processedLocationTree.initialMapDisplayRoots;
    final rootMapImageUrl = _rootMapImageUrlForWorld(world);
    final renderLocationNodes = processedLocationTree.initialMapRenderRoots;
    final allLocationNodes = processedLocationTree.flattened;
    final locationNodes = _worldMapLocationNodes(
      rootLocationNodes,
      avatarsByLocation,
      processedLocationTree,
    );
    final listLocationNodes = _worldMapLocationNodes(
      processedLocationTree.mapRoots,
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
    final collapsedPanelHeight = _worldCollapsedPanelHeightFor(context);
    Widget buildWorldMapPage(int tabIndex, {required bool pointMode}) {
      return _WorldKeepAlivePage(
        child: WorldMap(
          key: PageStorageKey<String>('world-map-tab-$tabIndex'),
          points: points,
          listPoints: listPoints,
          locationNodes: locationNodes,
          listLocationNodes: listLocationNodes,
          mapImageUrl: rootMapImageUrl,
          dimmed: pointMode,
          showPointsList: pointMode,
          pointsListOuterScrollHandoff: false,
          overlayTop:
              topPadding +
              8 +
              (pointMode ? _worldMapTabsHeight + 8 : _worldMapContentTopOffset),
          drillExitTop:
              topPadding + 8 + _worldMapTabsHeight + _worldTimePillTopGap,
          drillExitMaxWidth: _worldSecondaryMapControlWidth,
          onDrillIntoLocation: _showMapTab,
          onSecondaryMapChanged: (isInSecondaryMap) {
            if (_worldMainTabIndex == tabIndex) {
              _handleSecondaryMapChanged(isInSecondaryMap);
            }
          },
          onVisibleLocationIdsChanged: (locationIds) {
            if (_worldMainTabIndex == tabIndex) {
              _handleVisibleMapLocationIdsChanged(locationIds);
            }
          },
          onHorizontalPanStateChanged: tabIndex == 0
              ? _handleWorldMapHorizontalPanStateChanged
              : null,
          onPointTap: _openChatForPoint,
          messageBubbles: pointMode
              ? const <String, WorldMapMessageBubble>{}
              : _mapMessageBubbles,
        ),
      );
    }

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
                  _openWorldBottomSheet(_WorldBottomSheetKind.events),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: _worldStatsTopSpacerHeight),
                ),
                _WorldFeedContent(
                  world: world,
                  worldActionRunning: _worldActionRunning,
                  worldTickInProgress: _worldTickInProgress,
                  onWorldAction: _runWorldAction,
                  onPullUp: () =>
                      _openWorldBottomSheet(_WorldBottomSheetKind.events),
                ),
              ],
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
                child: _WorldMapBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: collapsedPanelHeight - _worldMainTabsHeight,
              height: _worldMainTabsHeight,
              child: _WorldBottomTags(
                onTap: (kind) => _openWorldBottomSheet(
                  kind,
                  locationPoints: listPoints,
                  locationNodes: listLocationNodes,
                ),
              ),
            ),
            Positioned.fill(
              child: _WorldLocationChatRouterHost(
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
        overlayTop: topPadding + 8 + _worldMapContentTopOffset,
        drillExitTop: topPadding + 8 + _worldMapContentTopOffset + 12,
      ),
      slivers: const [_WorldDetailsLoadingContent()],
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
    final worldTimeLabel = _worldTimeLabel(
      tickIndex: tickIndex,
      worldTime: worldTime,
    );
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideReservedWidth =
              _worldMapBackButtonLeft +
              _worldMapTabsHeight +
              _worldMapIdentityHorizontalGap;
          final maxIdentityWidth =
              (constraints.maxWidth - sideReservedWidth * 2)
                  .clamp(_worldTimePillMinWidth, constraints.maxWidth)
                  .toDouble();
          return Stack(
            children: [
              if (_worldMainTabIndex == 0)
                Positioned(
                  left: _worldMapBackButtonLeft,
                  top: top + 6,
                  child: _WorldMapBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (world != null &&
                  (title.isNotEmpty || worldTimeLabel.isNotEmpty))
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
                        child: _WorldMapIdentityPill(
                          title: title,
                          timeText: worldTimeLabel,
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

class _WorldMapBackButton extends StatelessWidget {
  const _WorldMapBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _worldMapTabsHeight,
      height: _worldMapTabsHeight,
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        iconSize: 18,
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _WorldMapIdentityPill extends StatelessWidget {
  const _WorldMapIdentityPill({
    required this.title,
    required this.timeText,
    required this.maxWidth,
  });

  final String title;
  final String timeText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: _worldTimePillMinWidth,
        maxWidth: maxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _worldTimePillHorizontalPadding,
            title.isEmpty ? 0 : 7,
            _worldTimePillHorizontalPadding,
            7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4B6192),
                    fontSize: 16,
                    height: 1.1,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (title.isNotEmpty && timeText.isNotEmpty)
                const SizedBox(height: 3),
              if (timeText.isNotEmpty)
                Text(
                  timeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    height: 1,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w400,
                  ),
                  strutStyle: const StrutStyle(
                    fontSize: 12,
                    height: 1,
                    forceStrutHeight: true,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _worldTimeLabel({required int tickIndex, required String worldTime}) {
  final parts = <String>[];
  if (tickIndex >= 0) {
    parts.add('Tick $tickIndex');
  }
  final resolvedWorldTime = worldTime.trim();
  if (resolvedWorldTime.isNotEmpty) {
    parts.add(resolvedWorldTime);
  }
  return parts.join(' · ');
}

enum _WorldBottomSheetKind { detail, locations, events, status, cast }

String _worldBottomSheetPageName(_WorldBottomSheetKind kind) {
  return switch (kind) {
    _WorldBottomSheetKind.detail => 'world_detail',
    _WorldBottomSheetKind.locations => 'world_locations',
    _WorldBottomSheetKind.events => 'world_events',
    _WorldBottomSheetKind.status => 'world_status',
    _WorldBottomSheetKind.cast => 'world_cast',
  };
}

class _WorldBottomSheetSelection {
  const _WorldBottomSheetSelection({
    required this.kind,
    required this.eventsLatestRevision,
    this.eventsTargetTickNumber,
  });

  final _WorldBottomSheetKind kind;
  final int eventsLatestRevision;
  final int? eventsTargetTickNumber;
}

class _WorldBottomTagItem {
  const _WorldBottomTagItem({
    required this.label,
    required this.kind,
    this.asset,
    this.icon,
  });

  final String label;
  final _WorldBottomSheetKind kind;
  final String? asset;
  final IconData? icon;
}

const _worldBottomTagItems = <_WorldBottomTagItem>[
  _WorldBottomTagItem(
    label: 'Detail',
    kind: _WorldBottomSheetKind.detail,
    asset: _worldDetailIconAsset,
  ),
  _WorldBottomTagItem(
    label: 'Locations',
    kind: _WorldBottomSheetKind.locations,
    icon: Icons.place_outlined,
  ),
  _WorldBottomTagItem(
    label: 'Events',
    kind: _WorldBottomSheetKind.events,
    asset: _worldSectionEventsIconAsset,
  ),
  _WorldBottomTagItem(
    label: 'Status',
    kind: _WorldBottomSheetKind.status,
    asset: _worldSectionStatusIconAsset,
  ),
  _WorldBottomTagItem(
    label: 'Cast',
    kind: _WorldBottomSheetKind.cast,
    asset: _worldSectionCastIconAsset,
  ),
];

class _WorldBottomTags extends StatelessWidget {
  const _WorldBottomTags({required this.onTap});

  final ValueChanged<_WorldBottomSheetKind> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _worldMainTabsHeight,
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
                for (final entry in _worldBottomTagItems.indexed) ...[
                  _WorldBottomTagContent(
                    item: entry.$2,
                    onTap: () => onTap(entry.$2.kind),
                  ),
                  if (entry.$1 != _worldBottomTagItems.length - 1)
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

class _WorldBottomTagContent extends StatelessWidget {
  const _WorldBottomTagContent({required this.item, required this.onTap});

  final _WorldBottomTagItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: _worldBottomTagHeight,
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
    );
  }
}

class _LocationChatPanelDescriptor {
  const _LocationChatPanelDescriptor({
    required this.locationId,
    required this.locationName,
    required this.backgroundImageUrl,
    required this.backgroundPreviewImageUrl,
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
      backgroundImageUrl: _locationChatImageUrl(value, preferredKey: 'xl_url'),
      backgroundPreviewImageUrl: '',
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
      backgroundImageUrl: _locationChatImageUrl(
        location,
        preferredKey: 'xl_url',
      ),
      backgroundPreviewImageUrl: '',
      isLeafLocation: isLeafLocation,
      localMessageLocationIds: _orderedNonEmptyStrings([pointId, locationId]),
    );
  }

  final String locationId;
  final String locationName;
  final String backgroundImageUrl;
  final String backgroundPreviewImageUrl;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;

  _LocationChatPanelDescriptor copyWith({
    String? locationId,
    String? locationName,
    String? backgroundImageUrl,
    String? backgroundPreviewImageUrl,
    bool? isLeafLocation,
    List<String>? localMessageLocationIds,
  }) {
    return _LocationChatPanelDescriptor(
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      backgroundPreviewImageUrl:
          backgroundPreviewImageUrl ?? this.backgroundPreviewImageUrl,
      isLeafLocation: isLeafLocation ?? this.isLeafLocation,
      localMessageLocationIds:
          localMessageLocationIds ?? this.localMessageLocationIds,
    );
  }
}

class _WorldLocationChatPageCache {
  final Map<String, _LocationChatPanelDescriptor> _descriptors =
      <String, _LocationChatPanelDescriptor>{};
  final Set<String> _cachedLocationIds = <String>{};
  final Set<String> _readyLocationIds = <String>{};
  final Map<String, double> _scrollOffsetsByLocation = <String, double>{};
  final Map<String, String> _draftTextByLocation = <String, String>{};

  String activeLocationId = '';

  int get cachedPanelCount => _cachedLocationIds.length;

  Iterable<String> get cachedLocationIds =>
      _cachedLocationIds.where(_descriptors.containsKey);

  _LocationChatPanelDescriptor? get activeDescriptor =>
      _descriptors[activeLocationId];

  bool hasPanel(String locationId) => _cachedLocationIds.contains(locationId);

  bool isReady(String locationId) => _readyLocationIds.contains(locationId);

  void syncDescriptors(Map<String, _LocationChatPanelDescriptor> descriptors) {
    _descriptors
      ..clear()
      ..addAll(descriptors);
    _cachedLocationIds.addAll(
      descriptors.values
          .where((descriptor) => descriptor.isLeafLocation)
          .map((descriptor) => descriptor.locationId),
    );
    _cachedLocationIds.removeWhere((locationId) {
      return !descriptors.containsKey(locationId);
    });
    _readyLocationIds.removeWhere((locationId) {
      return !descriptors.containsKey(locationId);
    });
    _scrollOffsetsByLocation.removeWhere((locationId, _) {
      return !descriptors.containsKey(locationId);
    });
    _draftTextByLocation.removeWhere((locationId, _) {
      return !descriptors.containsKey(locationId);
    });
    if (!_descriptors.containsKey(activeLocationId)) {
      activeLocationId = '';
    }
  }

  void activate(_LocationChatPanelDescriptor descriptor) {
    _descriptors[descriptor.locationId] = descriptor;
    _cachedLocationIds.add(descriptor.locationId);
    activeLocationId = descriptor.locationId;
  }

  void deactivate() {
    activeLocationId = '';
  }

  _LocationChatPanelDescriptor? descriptorFor(String locationId) {
    return _descriptors[locationId];
  }

  void markReady(String locationId) {
    _readyLocationIds.add(locationId);
  }

  double? scrollOffsetFor(String locationId) {
    return _scrollOffsetsByLocation[locationId];
  }

  String draftTextFor(String locationId) {
    return _draftTextByLocation[locationId] ?? '';
  }

  void updateScrollOffset(String locationId, double offset) {
    if (locationId.isEmpty) return;
    _scrollOffsetsByLocation[locationId] = offset;
  }

  void updateDraftText(String locationId, String text) {
    if (locationId.isEmpty) return;
    if (text.isEmpty) {
      _draftTextByLocation.remove(locationId);
      return;
    }
    _draftTextByLocation[locationId] = text;
  }

  void clear() {
    _descriptors.clear();
    _cachedLocationIds.clear();
    _readyLocationIds.clear();
    _scrollOffsetsByLocation.clear();
    _draftTextByLocation.clear();
    activeLocationId = '';
  }

  void dispose() {
    clear();
  }
}

class _WorldLocationChatRouterHost extends StatefulWidget {
  const _WorldLocationChatRouterHost({
    required this.worldId,
    required this.chatroom,
    required this.cache,
    required this.onBack,
    required this.onPanelReady,
  });

  final String worldId;
  final WorldChatroomService? chatroom;
  final _WorldLocationChatPageCache cache;
  final VoidCallback onBack;
  final ValueChanged<String> onPanelReady;

  @override
  State<_WorldLocationChatRouterHost> createState() =>
      _WorldLocationChatRouterHostState();
}

class _WorldLocationChatRouterHostState
    extends State<_WorldLocationChatRouterHost> {
  String _displayLocationId = '';

  @override
  void initState() {
    super.initState();
    _syncDisplayLocationId();
  }

  @override
  void didUpdateWidget(_WorldLocationChatRouterHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDisplayLocationId();
  }

  void _syncDisplayLocationId() {
    final activeLocationId = widget.cache.activeLocationId;
    if (activeLocationId.isNotEmpty) {
      _displayLocationId = activeLocationId;
    }
  }

  void _handleDismissed() {
    if (_displayLocationId.isEmpty) return;
    setState(() => _displayLocationId = '');
  }

  @override
  Widget build(BuildContext context) {
    final activeLocationId = widget.cache.activeLocationId;
    final activeDescriptor = widget.cache.activeDescriptor;
    final displayLocationId = activeLocationId.isNotEmpty
        ? activeLocationId
        : _displayLocationId;
    final cachedIds = widget.cache.cachedLocationIds.toList(growable: false);
    final showSkeleton =
        activeLocationId.isNotEmpty &&
        activeDescriptor != null &&
        !widget.cache.isReady(activeLocationId);
    final active = activeLocationId.isNotEmpty;

    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: LocationChatOverlayTransition(
          active: active,
          onDismissed: _handleDismissed,
          child: Stack(
            children: [
              for (final descriptor
                  in cachedIds
                      .map(widget.cache.descriptorFor)
                      .whereType<_LocationChatPanelDescriptor>())
                _buildCachedPage(
                  descriptor,
                  displayLocationId: displayLocationId,
                  activeLocationId: activeLocationId,
                ),
              if (showSkeleton)
                Positioned.fill(
                  child: _LocationChatPanelSkeleton(
                    title: activeDescriptor.locationName,
                    onBack: widget.onBack,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCachedPage(
    _LocationChatPanelDescriptor descriptor, {
    required String displayLocationId,
    required String activeLocationId,
  }) {
    final active = descriptor.locationId == activeLocationId;
    final visible = descriptor.locationId == displayLocationId;
    final ready = widget.cache.isReady(descriptor.locationId);
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: Offstage(
          offstage: !visible,
          child: Opacity(
            opacity: visible && ready ? 1 : 0,
            child: TickerMode(
              enabled: visible,
              child: SizedBox.expand(
                child: _WorldLocationChatNestedRouterPage(
                  key: ValueKey(
                    'world-location-chat-router-${descriptor.locationId}',
                  ),
                  worldId: widget.worldId,
                  chatroom: widget.chatroom,
                  descriptor: descriptor,
                  active: active,
                  onBack: widget.onBack,
                  onInitialContentReady: () =>
                      widget.onPanelReady(descriptor.locationId),
                  initialDraftText: widget.cache.draftTextFor(
                    descriptor.locationId,
                  ),
                  initialScrollOffset: widget.cache.scrollOffsetFor(
                    descriptor.locationId,
                  ),
                  onDraftTextChanged: (text) {
                    widget.cache.updateDraftText(descriptor.locationId, text);
                  },
                  onScrollOffsetChanged: (offset) {
                    if (!active) return;
                    widget.cache.updateScrollOffset(
                      descriptor.locationId,
                      offset,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldLocationChatNestedRouterPage extends StatelessWidget {
  const _WorldLocationChatNestedRouterPage({
    super.key,
    required this.worldId,
    required this.chatroom,
    required this.descriptor,
    required this.active,
    required this.onBack,
    required this.onInitialContentReady,
    required this.initialDraftText,
    required this.initialScrollOffset,
    required this.onDraftTextChanged,
    required this.onScrollOffsetChanged,
  });

  final String worldId;
  final WorldChatroomService? chatroom;
  final _LocationChatPanelDescriptor descriptor;
  final bool active;
  final VoidCallback onBack;
  final VoidCallback onInitialContentReady;
  final String initialDraftText;
  final double? initialScrollOffset;
  final ValueChanged<String> onDraftTextChanged;
  final ValueChanged<double> onScrollOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final routeName = 'world_location_chat/$worldId/${descriptor.locationId}';
    return Navigator(
      pages: [
        MaterialPage<void>(
          key: ValueKey(routeName),
          name: routeName,
          child: LocationChatPanel(
            key: ValueKey('world-location-chat-${descriptor.locationId}'),
            worldId: worldId,
            locationId: descriptor.locationId,
            locationName: descriptor.locationName,
            backgroundImageUrl: descriptor.backgroundImageUrl,
            backgroundPreviewImageUrl: descriptor.backgroundPreviewImageUrl,
            isLeafLocation: descriptor.isLeafLocation,
            localMessageLocationIds: descriptor.localMessageLocationIds,
            service: chatroom,
            active: active,
            leaveOnInactive: false,
            systemUiOverlayStyle: kChatDarkHeaderSystemUiOverlayStyle,
            style: kLocationChatStyle,
            onBack: onBack,
            onInitialContentReady: onInitialContentReady,
            initialDraftText: initialDraftText,
            initialScrollOffset: initialScrollOffset,
            onDraftTextChanged: onDraftTextChanged,
            onScrollOffsetChanged: onScrollOffsetChanged,
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

class _LocationChatPanelSkeleton extends StatelessWidget {
  const _LocationChatPanelSkeleton({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle;
    return GenesisBottomSystemBarStyleScope(
      style: GenesisBottomSystemBarStyle(color: style.composerBackgroundColor),
      child: ColoredBox(
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
              style: style,
            ),
            Expanded(child: _LocationChatMessageSkeletonList(style: style)),
            _LocationChatComposerSkeleton(style: style),
          ],
        ),
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
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
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
                spacing: 20,
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

class _WorldFeedContent extends StatelessWidget {
  const _WorldFeedContent({
    required this.world,
    required this.worldActionRunning,
    required this.worldTickInProgress,
    required this.onWorldAction,
    required this.onPullUp,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final bool worldTickInProgress;
  final Future<void> Function(_WorldHeaderActionKind action) onWorldAction;
  final VoidCallback onPullUp;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _WorldSectionSheetPullGesture(
            onPullUp: onPullUp,
            child: Column(
              children: [
                _WorldInfoHeader(
                  world: world,
                  worldActionRunning: worldActionRunning,
                  worldTickInProgress: worldTickInProgress,
                  onWorldAction: onWorldAction,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorldSectionSheetPullGesture extends StatefulWidget {
  const _WorldSectionSheetPullGesture({
    required this.child,
    required this.onPullUp,
  });

  final Widget child;
  final VoidCallback onPullUp;

  @override
  State<_WorldSectionSheetPullGesture> createState() =>
      _WorldSectionSheetPullGestureState();
}

class _WorldSectionSheetPullGestureState
    extends State<_WorldSectionSheetPullGesture> {
  static const double _triggerDistance = 56;
  static const double _triggerVelocity = 520;

  var _dragDy = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {
        _dragDy = 0;
      },
      onVerticalDragUpdate: (details) {
        _dragDy += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        final upwardVelocity = -(details.primaryVelocity ?? 0);
        if (_dragDy <= -_triggerDistance ||
            upwardVelocity >= _triggerVelocity) {
          widget.onPullUp();
        }
        _dragDy = 0;
      },
      onVerticalDragCancel: () {
        _dragDy = 0;
      },
      child: widget.child,
    );
  }
}

class _WorldKeepAlivePage extends StatefulWidget {
  const _WorldKeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_WorldKeepAlivePage> createState() => _WorldKeepAlivePageState();
}

class _WorldKeepAlivePageState extends State<_WorldKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _WorldSingleSectionBottomSheet extends StatefulWidget {
  const _WorldSingleSectionBottomSheet({
    required this.selectionListenable,
    required this.services,
    required this.initialWorld,
    required this.worldListenable,
    required this.eventsCache,
    required this.currentUid,
    required this.locationPoints,
    required this.locationNodes,
    required this.onLocationTap,
  });

  final ValueListenable<_WorldBottomSheetSelection> selectionListenable;
  final AppServices services;
  final WorldDetail initialWorld;
  final ValueListenable<WorldDetail?> worldListenable;
  final _WorldSectionsEventsCache eventsCache;
  final String currentUid;
  final List<WorldPoint> locationPoints;
  final List<WorldMapLocationNode> locationNodes;
  final ValueChanged<WorldPoint> onLocationTap;

  @override
  State<_WorldSingleSectionBottomSheet> createState() =>
      _WorldSingleSectionBottomSheetState();
}

class _WorldSingleSectionBottomSheetState
    extends State<_WorldSingleSectionBottomSheet> {
  static const int _eventsPageSize = 20;
  static const double _sheetHeightFactor = 0.85;

  WorldDetail get _currentWorld =>
      widget.worldListenable.value ?? widget.initialWorld;

  _WorldBottomSheetSelection get _selection => widget.selectionListenable.value;

  _WorldSectionsEventsCache get _eventsCache => widget.eventsCache;

  @override
  void initState() {
    super.initState();
    widget.worldListenable.addListener(_handleWorldDetailChanged);
    widget.selectionListenable.addListener(_handleSelectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
  }

  @override
  void didUpdateWidget(covariant _WorldSingleSectionBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldListenable != widget.worldListenable) {
      oldWidget.worldListenable.removeListener(_handleWorldDetailChanged);
      widget.worldListenable.addListener(_handleWorldDetailChanged);
    }
    if (oldWidget.selectionListenable != widget.selectionListenable) {
      oldWidget.selectionListenable.removeListener(_handleSelectionChanged);
      widget.selectionListenable.addListener(_handleSelectionChanged);
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
    super.dispose();
  }

  bool get _isEventsSheet => _selection.kind == _WorldBottomSheetKind.events;

  void _handleWorldDetailChanged() {
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld();
    }
    if (mounted) setState(() {});
  }

  void _handleSelectionChanged() {
    if (_isEventsSheet) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
    if (mounted) setState(() {});
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
      final loadedTicks = _eventTicksAscending(response.data);
      _mutateEventsCache(() {
        _eventsCache.ticks = _mergeEventTicksAscending(
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
      child: _WorldEventsSection(
        key: const PageStorageKey<String>('world-events-section-bottom-sheet'),
        world: _currentWorld,
        ticks: _eventsCache.ticks,
        initialLoading: _eventsCache.initialLoading,
        loadingMore: _eventsCache.loadingMore,
        hasMore: _eventsHasMore,
        error: _eventsCache.error,
        latestRevision: _selection.eventsLatestRevision,
        targetTickNumber: _selection.eventsTargetTickNumber,
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        onLoadMore: _loadNextEventsPage,
      ),
    );
  }

  Widget _buildStatusSectionPage() {
    return _WorldSectionListView(
      storageKey: 'world-status-section-bottom-sheet',
      child: _WorldStatusSection(
        world: _currentWorld,
        currentUid: widget.currentUid,
      ),
    );
  }

  Widget _buildCastSectionPage() {
    return _WorldSectionListView(
      storageKey: 'world-cast-section-bottom-sheet',
      child: _WorldCharactersSection(
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
        enableOuterScrollHandoff: false,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
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
    return _WorldSectionListView(
      storageKey: 'world-detail-section-bottom-sheet',
      child: _WorldDetailSection(world: _currentWorld),
    );
  }

  Widget _buildSheetContent() {
    return switch (_selection.kind) {
      _WorldBottomSheetKind.detail => _buildDetailSectionPage(),
      _WorldBottomSheetKind.locations => _buildLocationsSectionPage(),
      _WorldBottomSheetKind.events => _buildEventsSectionPage(),
      _WorldBottomSheetKind.status => _buildStatusSectionPage(),
      _WorldBottomSheetKind.cast => _buildCastSectionPage(),
    };
  }

  _WorldBottomTagItem get _headerItem {
    return _worldBottomTagItems.firstWhere(
      (item) => item.kind == _selection.kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: _sheetHeightFactor,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _WorldSingleSectionSheetHeader(
              item: _headerItem,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: _buildSheetContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldSingleSectionSheetHeader extends StatefulWidget {
  const _WorldSingleSectionSheetHeader({
    required this.item,
    required this.onClose,
  });

  final _WorldBottomTagItem item;
  final VoidCallback onClose;

  @override
  State<_WorldSingleSectionSheetHeader> createState() =>
      _WorldSingleSectionSheetHeaderState();
}

class _WorldSingleSectionSheetHeaderState
    extends State<_WorldSingleSectionSheetHeader> {
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
                    _WorldSheetHeaderIcon(item: widget.item),
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

class _WorldSheetHeaderIcon extends StatelessWidget {
  const _WorldSheetHeaderIcon({required this.item});

  final _WorldBottomTagItem item;

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

class _WorldSectionsEventsCache {
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

class _WorldDetailSection extends StatelessWidget {
  const _WorldDetailSection({required this.world});

  final WorldDetail world;

  @override
  Widget build(BuildContext context) {
    final title = world.name.trim().isEmpty ? world.worldId : world.name.trim();
    final owner = _worldOwnerDisplayName(world);
    final ownerUid = world.ownerUid.trim();
    final version = world.origin.versionNum <= 0 ? 1 : world.origin.versionNum;
    final sourceWorldoOid = world.origin.oid.trim();
    final sourceWorldoRouteId = sourceWorldoOid.isNotEmpty
        ? sourceWorldoOid
        : world.originId > 0
        ? '${world.originId}'
        : '';
    final sourceOid = sourceWorldoOid.isEmpty
        ? '${world.originId}'
        : sourceWorldoOid;
    final canOpenSourceWorldo = sourceWorldoRouteId.isNotEmpty;
    final brief = world.brief.trim().isEmpty ? '-' : world.brief.trim();
    final cover = _resolveAssetUrl(world.cover).trim();

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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B6192),
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: GenesisMoreActionMenuButton(
                buttonSize: 18 * 1.25,
                items: [
                  genesisReportMenuItem(
                    context: context,
                    targetType: 'world',
                    targetId: world.worldId,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GenesisPairedMetaRow(
          leftLabel: 'WID',
          leftValue: world.worldId,
          leftDisplayValue: world.deleted ? deletedEntityDisplayText : null,
          leftCopyEnabled: !world.deleted,
          leftStyle: _worldHeaderMetaTextStyle,
          leftIconColor: _worldHeaderMetaColor,
          rightText: 'Owner: $owner',
          rightOnTap: ownerUid.isEmpty || world.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
          rightStyle: _worldHeaderMetaTextStyle,
          rightIconColor: _worldHeaderMetaColor,
        ),
        const SizedBox(height: 0),
        GenesisInlineMetaLabel(
          text: 'Source Worldo: $sourceOid · V$version',
          onTap: !canOpenSourceWorldo
              ? null
              : () => Navigator.of(context).pushNamed(
                  RouteNames.originWorld,
                  arguments: {
                    'oid': sourceWorldoRouteId,
                    'originId': world.originId,
                  },
                ),
          style: CopyableIdLabel.textStyle,
          trailingIcon: canOpenSourceWorldo ? Icons.chevron_right : null,
          trailingIconColor: _worldHeaderMetaColor,
          trailingIconSize: 16,
        ),
        const SizedBox(height: 24),
        const _WorldDetailSectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFFF2442),
          title: 'World Brief',
        ),
        const SizedBox(height: 8),
        Text(brief, style: _worldDetailBodyTextStyle),
        const SizedBox(height: 8),
        _WorldDetailCoverImage(url: cover),
      ],
    );
  }
}

class _WorldDetailSectionTitle extends StatelessWidget {
  const _WorldDetailSectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  final IconData icon;
  final Color iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorldDetailCoverImage extends StatelessWidget {
  const _WorldDetailCoverImage({required this.url});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final width = maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final height = width / _aspectRatio;

        final preview = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: GenesisImageRadii.content,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageUrl = selectGenesisImageUrl(
                    url,
                    logicalWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : null,
                    logicalHeight: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    devicePixelRatio:
                        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
                  );
                  return imageUrl.isEmpty
                      ? fallback
                      : imageUrl.startsWith('assets/')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return fallback;
                          },
                        );
                },
              ),
            ),
          ),
        );
        if (viewerUrl.isEmpty) return preview;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showGenesisImageViewer(context, imageUrls: [viewerUrl]),
          child: preview,
        );
      },
    );
  }
}

class _WorldSectionListView extends StatelessWidget {
  const _WorldSectionListView({required this.storageKey, required this.child});

  final String storageKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey<String>(storageKey),
      primary: false,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [child],
    );
  }
}

class _WorldInfoHeader extends StatelessWidget {
  const _WorldInfoHeader({
    required this.world,
    required this.worldActionRunning,
    required this.worldTickInProgress,
    required this.onWorldAction,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final bool worldTickInProgress;
  final Future<void> Function(_WorldHeaderActionKind action) onWorldAction;

  @override
  Widget build(BuildContext context) {
    final action = _worldHeaderActionFor(world.relationStatus);
    final actionLoading =
        worldActionRunning ||
        (worldTickInProgress && action.kind == _WorldHeaderActionKind.progress);
    final actionEnabled =
        !world.deleted && !actionLoading && action.isClickable;
    final counters = <Map<String, dynamic>>[
      {'icon': 'tick', 'value': world.tickCount},
      {'icon': 'connect', 'value': world.connectCount},
      {'icon': 'character', 'value': world.characterCount},
      {'icon': 'player', 'value': world.playerCount},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _worldInfoHeaderHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _worldInfoHeaderContentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final data in counters)
                          StatItem(
                            icon: _counterIcon(data['icon'] as String? ?? ''),
                            iconAsset: _counterIconAsset(
                              data['icon'] as String? ?? '',
                            ),
                            preserveIconAssetColor:
                                _counterIconAssetPreservesColor(
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
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  GenesisPrimaryButton(
                    label: action.label,
                    onPressed: actionEnabled
                        ? () => onWorldAction(action.kind)
                        : null,
                    height: 35,
                    width: 140,
                    backgroundColor: const Color(0xFF2F9663),
                    disabledBackgroundColor: const Color(
                      0xFF2F9663,
                    ).withValues(alpha: 0.62),
                    foregroundColor: Colors.white,
                    fontSize: 16,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    isLoading: actionLoading,
                    loadingSize: 18,
                    loadingStrokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
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
    case 'reject':
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
        'Requested',
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
      return 'Requested';
    case _WorldHeaderActionKind.unavailable:
      return 'Unavailable';
  }
}

const Color _worldHeaderMetaColor = Color(0xFF666666);
double _worldCollapsedPanelHeightFor(BuildContext context) {
  final bottomSafeArea = _worldBottomSafeAreaOf(context);
  final collapsedPanelHeight =
      WorldDetailsPageScaffold.inlineContentTopPadding +
      _worldStatsTopSpacerHeight +
      _worldInfoHeaderHeight +
      bottomSafeArea;
  return collapsedPanelHeight;
}

String _worldOwnerDisplayName(WorldDetail world) {
  if (world.ownerDeleted) return deletedEntityDisplayText;
  final ownerName = world.ownerName.trim();
  if (ownerName.isNotEmpty) return ownerName;
  final originator = world.origin.originator.trim();
  if (originator.isNotEmpty) return originator;
  return formatUidForDisplay(world.ownerUid);
}

double _worldBottomSafeAreaOf(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final paddingBottom = mediaQuery.padding.bottom;
  final viewPaddingBottom = mediaQuery.viewPadding.bottom;
  return paddingBottom > viewPaddingBottom ? paddingBottom : viewPaddingBottom;
}

const TextStyle _worldHeaderMetaTextStyle = TextStyle(
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
  color: _worldHeaderMetaColor,
);
const TextStyle _worldDetailBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
);

IconData? _counterIcon(String key) {
  switch (key) {
    case 'tick':
      return null;
    case 'connect':
      return null;
    case 'character':
      return null;
    case 'player':
      return null;
    default:
      return Icons.circle_outlined;
  }
}

String? _counterIconAsset(String key) {
  return switch (key) {
    'tick' => tickStatIconAsset,
    'connect' => connectStatIconAsset,
    'character' => characterStatIconAsset,
    'player' => userStatIconAsset,
    _ => null,
  };
}

bool _counterIconAssetPreservesColor(String key) {
  return key == 'character';
}

List<Map<String, dynamic>> _eventTicksAscending(
  List<Map<String, dynamic>> ticks,
) {
  final indexedTicks = ticks.indexed.toList(growable: false);
  indexedTicks.sort((a, b) {
    final tickCompare = _eventTickNumber(
      a.$2,
    ).compareTo(_eventTickNumber(b.$2));
    if (tickCompare != 0) return tickCompare;
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexedTicks) entry.$2];
}

List<Map<String, dynamic>> _mergeEventTicksAscending(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  final keyedTicks = <String, Map<String, dynamic>>{};
  final unkeyedTicks = <Map<String, dynamic>>[];
  for (final tick in [...existing, ...incoming]) {
    final key = _eventTickIdentity(tick);
    if (key.isEmpty) {
      unkeyedTicks.add(tick);
      continue;
    }
    keyedTicks[key] = tick;
  }
  return _eventTicksAscending([...keyedTicks.values, ...unkeyedTicks]);
}

String _eventTickIdentity(Map<String, dynamic> tick) {
  final tickId = _mapString(tick, const ['tick_id', 'id']);
  if (tickId.isNotEmpty) return 'id:$tickId';
  final tickNo = _eventTickNumber(tick);
  if (tickNo > 0) return 'no:$tickNo';
  return '';
}

int _eventTickNumber(Map<String, dynamic> tick) {
  final tickNo = _mapString(tick, const ['tick_no', 'tick_number', 'no']);
  final parsed = int.tryParse(tickNo);
  if (parsed != null) return parsed;

  final id = _mapString(tick, const ['tick_id', 'id']);
  final suffix = RegExp(r'(\d+)$').firstMatch(id)?.group(1);
  return int.tryParse(suffix ?? '') ?? 0;
}

class _WorldEventsSection extends StatefulWidget {
  const _WorldEventsSection({
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
  State<_WorldEventsSection> createState() => _WorldEventsSectionState();
}

class _WorldEventsSectionState extends State<_WorldEventsSection> {
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
  void didUpdateWidget(covariant _WorldEventsSection oldWidget) {
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
        child: const _WorldEventLoadingSkeleton(),
      );
    }
    if (widget.ticks.isEmpty && !hasPendingTargetPage) {
      return Padding(
        padding: widget.contentPadding,
        child: _EmptySection(
          text: widget.error == null ? 'No events yet.' : 'Load events failed.',
        ),
      );
    }

    final locationsById = <String, Map<String, dynamic>>{
      for (final location in widget.world.locations)
        _mapString(location, const ['location_id', 'id']): location,
    }..remove('');
    final fallbackBody = _eventBody(widget.world);
    final metricUnit = _mapString(widget.world.metric, const ['unit']);
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
              return _WorldTickEventCardPage(
                key: ValueKey<String>('world-event-tick-pending-$tickNumber'),
                resetRevision:
                    _tickCardResetRevisions['pending_tick:$tickNumber'] ?? 0,
                hasTopEdgePage: index > 0,
                hasBottomEdgePage: index < _pageCount - 1,
                padding: widget.contentPadding,
                onTurnPage: _turnPage,
                child: _WorldTickPendingEventPage(tickNumber: tickNumber),
              );
            }
            final tickIndex = _tickIndexForPage(index);
            if (tickIndex == null) return const SizedBox.shrink();
            final tick = visibleTicks[tickIndex];
            final identity = _eventTickIdentity(tick);
            final tickNumber = worldTickEventNumber(
              tick,
              fallback: tickIndex + 1,
            );
            return _WorldTickEventCardPage(
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
                    dateLabel: _tickParagraphTimestamp(tick),
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
              child: _WorldEventsLoadingMoreIndicator(),
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
    return _eventTickIdentity(_visibleTicks[tickIndex]);
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

class _WorldTickPendingEventPage extends StatelessWidget {
  const _WorldTickPendingEventPage({required this.tickNumber});

  final int tickNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Tick $tickNumber',
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey<String>('world-event-pending-tombstone'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorldTickPendingSkeletonLine(widthFactor: 0.28, height: 10),
              SizedBox(height: 12),
              _WorldTickPendingSkeletonLine(widthFactor: 0.92),
              SizedBox(height: 8),
              _WorldTickPendingSkeletonLine(widthFactor: 0.76),
              SizedBox(height: 18),
              _WorldTickPendingSkeletonLine(widthFactor: 0.34, height: 10),
              SizedBox(height: 12),
              _WorldTickPendingSkeletonLine(widthFactor: 0.86),
              SizedBox(height: 8),
              _WorldTickPendingSkeletonLine(widthFactor: 0.58),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorldTickPendingSkeletonLine extends StatelessWidget {
  const _WorldTickPendingSkeletonLine({
    required this.widthFactor,
    this.height = 12,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE1E4EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _WorldTickEventCardPage extends StatefulWidget {
  const _WorldTickEventCardPage({
    super.key,
    required this.child,
    required this.resetRevision,
    required this.hasTopEdgePage,
    required this.hasBottomEdgePage,
    required this.padding,
    required this.onTurnPage,
  });

  final Widget child;
  final int resetRevision;
  final bool hasTopEdgePage;
  final bool hasBottomEdgePage;
  final EdgeInsetsGeometry padding;
  final ValueChanged<int> onTurnPage;

  @override
  State<_WorldTickEventCardPage> createState() =>
      _WorldTickEventCardPageState();
}

class _WorldTickEventCardPageState extends State<_WorldTickEventCardPage> {
  static const double _turnDragThreshold = 56;
  static const double _edgeArrowMinSize = 18;
  static const double _edgeArrowMaxSize = 24;

  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  var _dragDeltaY = 0.0;
  var _dragStartedAtTop = true;
  var _dragStartedAtBottom = true;
  var _topPullDistance = 0.0;
  var _bottomPullDistance = 0.0;

  @override
  void didUpdateWidget(covariant _WorldTickEventCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetRevision != widget.resetRevision) {
      _jumpScrollToTop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  bool get _atTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentBefore <= 0;
  }

  bool get _atBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter <= 0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dragDeltaY = 0;
    _dragStartedAtTop = _atTop;
    _dragStartedAtBottom = _atBottom;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _dragDeltaY += event.delta.dy;
    _setEdgePullDistance(
      top: _dragStartedAtTop && widget.hasTopEdgePage
          ? math.max(0, _dragDeltaY)
          : 0,
      bottom: _dragStartedAtBottom && widget.hasBottomEdgePage
          ? math.max(0, -_dragDeltaY)
          : 0,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    final dragDeltaY = _dragDeltaY;
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
    if (dragDeltaY <= -_turnDragThreshold && _dragStartedAtBottom) {
      widget.onTurnPage(1);
    } else if (dragDeltaY >= _turnDragThreshold && _dragStartedAtTop) {
      widget.onTurnPage(-1);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _dragDeltaY = 0;
    _setEdgePullDistance(top: 0, bottom: 0);
  }

  void _setEdgePullDistance({required double top, required double bottom}) {
    final nextTop = top.clamp(0, _turnDragThreshold).toDouble();
    final nextBottom = bottom.clamp(0, _turnDragThreshold).toDouble();
    if (nextTop == _topPullDistance && nextBottom == _bottomPullDistance) {
      return;
    }
    setState(() {
      _topPullDistance = nextTop;
      _bottomPullDistance = nextBottom;
    });
  }

  Widget _buildEdgeArrow({
    required bool top,
    required double pullDistance,
    required IconData icon,
    required Key key,
  }) {
    if (pullDistance <= 0) {
      return const SizedBox.shrink();
    }
    final progress = (pullDistance / _turnDragThreshold).clamp(0.0, 1.0);
    final iconSize =
        _edgeArrowMinSize +
        ((_edgeArrowMaxSize - _edgeArrowMinSize) * progress);
    final offset = 6 + (8 * progress);
    return Positioned(
      top: top ? offset : null,
      bottom: top ? null : offset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.3 + (0.7 * progress),
          child: Align(
            alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
            child: Icon(
              icon,
              key: key,
              size: iconSize,
              color: const Color(0xFF111111),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: widget.padding,
              physics: _WorldTickCardScrollPhysics(
                allowLeadingOverscroll: widget.hasTopEdgePage,
                allowTrailingOverscroll: widget.hasBottomEdgePage,
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: widget.child,
            ),
          ),
          _buildEdgeArrow(
            top: true,
            pullDistance: _topPullDistance,
            icon: Icons.keyboard_arrow_down_rounded,
            key: const ValueKey<String>('world-event-top-edge-arrow'),
          ),
          _buildEdgeArrow(
            top: false,
            pullDistance: _bottomPullDistance,
            icon: Icons.keyboard_arrow_up_rounded,
            key: const ValueKey<String>('world-event-bottom-edge-arrow'),
          ),
        ],
      ),
    );
  }
}

class _WorldTickCardScrollPhysics extends BouncingScrollPhysics {
  const _WorldTickCardScrollPhysics({
    required this.allowLeadingOverscroll,
    required this.allowTrailingOverscroll,
    super.parent,
  });

  final bool allowLeadingOverscroll;
  final bool allowTrailingOverscroll;

  @override
  _WorldTickCardScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _WorldTickCardScrollPhysics(
      allowLeadingOverscroll: allowLeadingOverscroll,
      allowTrailingOverscroll: allowTrailingOverscroll,
      parent: buildParent(ancestor),
    );
  }

  @override
  double frictionFactor(double overscrollFraction) {
    return super.frictionFactor(overscrollFraction) * 0.5;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!allowLeadingOverscroll &&
        value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (!allowTrailingOverscroll &&
        position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      return value - position.pixels;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

const TextStyle _worldEventContentLabelStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111111),
);

const TextStyle _worldEventContentTextStyle = TextStyle(
  fontSize: 13,
  height: 1.6,
  fontWeight: FontWeight.w400,
  color: Color(0xFF444444),
);

const TextStyle _worldEventContentTimestampStyle = TextStyle(
  fontSize: 13,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: Color(0xFF111111),
);

String? _tickParagraphTimestamp(Map<String, dynamic> tick) {
  final result = tick['tick_result'];
  if (result is! Map) return null;
  final paragraphs = result['paragraphs'];
  if (paragraphs is! List) return null;
  for (final paragraph in paragraphs) {
    if (paragraph is! Map) continue;
    final timestamp = '${paragraph['timestamp'] ?? ''}'.trim();
    if (timestamp.isNotEmpty) return formatGenesisTimestamp(timestamp);
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
      subtitleColor: const Color(0xFF666666),
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
      subtitleColor: const Color(0xFF666666),
    );
  }
}

class _CharacterList extends StatelessWidget {
  const _CharacterList({
    required this.characters,
    required this.currentUid,
    required this.emptyText,
    required this.subtitleBuilder,
    required this.subtitleColor,
  });

  final List<Map<String, dynamic>> characters;
  final String currentUid;
  final String emptyText;
  final String Function(Map<String, dynamic> character) subtitleBuilder;
  final Color subtitleColor;

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
              subtitleColor: subtitleColor,
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
    required this.subtitleColor,
  });

  final Map<String, dynamic> character;
  final String currentUid;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    final name = _mapString(character, const ['name'], fallback: 'Character');
    final avatarUrl = _resizedWorldCharacterAvatarUrl(context, character);
    final playerUid = _mapString(character, const ['player_uid']);
    final username = _mapString(character, const ['player_username']);
    final playerDeleted = entityDeleted(character['player_deleted']);
    final suffix = _characterNameSuffix(
      currentUid: currentUid,
      playerUid: playerUid,
      username: username,
      playerDeleted: playerDeleted,
    );
    final isCharacterRole = _isCharacterRole(character);
    final roleLabel = isCharacterRole ? 'Character' : 'Player';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: isCharacterRole ? 6 : 0),
          child: GenesisCharacterAvatar(
            url: avatarUrl,
            name: name,
            showStar: isCharacterRole,
            starSize: 20,
            showFallbackWhileLoading: false,
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
                  ).copyWith(color: subtitleColor),
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

String _resizedWorldCharacterAvatarUrl(
  BuildContext context,
  Map<String, dynamic> character,
) {
  final rawUrl = _mapString(character, const ['avatar']).trim();
  final resizedUrl = resizeGenesisImageUrl(
    rawUrl,
    logicalWidth: _worldCharacterAvatarLogicalSize,
    devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
  );
  return resizedUrl.isNotEmpty ? resizedUrl : rawUrl;
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
  required bool playerDeleted,
}) {
  if (playerUid.isNotEmpty && playerDeleted) {
    return '($deletedEntityDisplayText)';
  }
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
    'identity',
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

String _resolvedProfileAvatar(
  Map<String, dynamic> userInfo,
  String profileAvatar,
) {
  final resolved = asResolvedImageUrl(
    _mapValue(userInfo, const ['avatar']),
    resolveAssetUrl,
    fallback: _mapValue(userInfo, const [
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]),
  );
  if (resolved.isNotEmpty) return resolved;
  return asResolvedImageUrl(profileAvatar, resolveAssetUrl);
}

Object? _mapValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
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
  ProcessedLocationTree<Map<String, dynamic>> processedLocationTree, {
  bool markAsMapRoot = true,
}) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: markAsMapRoot && node.children.isNotEmpty,
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
            markAsMapRoot: false,
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

String _locationChatImageUrl(
  Map<String, dynamic> location, {
  required String preferredKey,
}) {
  final image = _mapValue(location, const ['image']);
  if (image is Map) {
    final imageMap = asJsonMap(image);
    final preferredUrl = _resolveAssetUrl(_mapString(imageMap, [preferredKey]));
    if (preferredUrl.isNotEmpty) return preferredUrl;

    final fallbackUrl = _resolveAssetUrl(
      _mapString(imageMap, const ['xl_url', 'sm_url', 'url', 'image_url']),
    );
    if (fallbackUrl.isNotEmpty) return fallbackUrl;
  }

  final iconUrl = _resolveAssetUrl(_mapString(location, const ['icon']));
  if (iconUrl.isNotEmpty) return iconUrl;

  return _locationMapImageUrl(location);
}

Map<String, List<UserAvatar>> _avatarsByLocationFromCharacterPositions(
  List<Map<String, dynamic>> characterPositions, {
  required String currentUid,
}) {
  final map = <String, List<UserAvatar>>{};
  for (final cp in characterPositions) {
    final rawLocationId = cp['location_id'] ?? cp['current_location_id'];
    final locationId = '$rawLocationId'.trim();
    if (locationId.isEmpty) continue;
    final character = cp['character'];
    if (character is! Map) continue;
    final c = character.map((key, value) => MapEntry('$key', value));
    if (_isCurrentUserCharacter(c, currentUid)) continue;
    final name = (c['name'] ?? '').toString();
    final avatar = _resolveAssetUrl((c['avatar'] ?? '').toString());
    final showStar = worldMapCharacterShouldShowStarForTesting(c);
    final isPlayerControlledRole = _mapString(c, const [
      'player_uid',
      'user_id',
      'uid',
    ]).isNotEmpty;
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
        showStar: showStar,
        isPlayerControlledRole: isPlayerControlledRole,
      ),
    );
  }
  return map;
}

@visibleForTesting
bool worldMapCharacterShouldShowStarForTesting(Map<String, dynamic> character) {
  final type = character['type'];
  final isAiRole = type is num
      ? type == 1
      : {'1', 'ai'}.contains('$type'.trim().toLowerCase());
  final playerUid = _mapString(character, const ['player_uid']);
  return isAiRole && playerUid.isEmpty;
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
