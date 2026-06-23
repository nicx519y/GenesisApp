import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common/copyable_id_label.dart';
import '../../components/ai_content_disclaimer.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_map.dart';
import '../../components/world_map_stage.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
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
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
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
const double _worldMapTabsHeight = 38;
const double _worldTimePillTopGap = 12;
const double _worldTimePillHeight = 22;
const double _worldTimePillMinWidth = 96;
const double _worldSecondaryMapControlWidth = 160;
const double _worldTimePillHorizontalPadding = 12;
const double _worldMapContentTopOffset =
    _worldMapTabsHeight + _worldTimePillTopGap + _worldTimePillHeight + 8;
const int _worldSectionEventsIndex = 0;
const double _worldCharacterAvatarLogicalSize = 48;

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
  static const int _mapMessageBubbleQueueLimit = 60;
  static const int _mapMessageBubbleHistoryLimit = 20;
  static const int _mapMessageBubbleCacheLimit = 60;

  late final TabController _tabController;
  late final TabController _sectionController;
  WorldDetail? _world;
  Object? _initialLoadError;
  WorldChatroomService? _worldChatroom;
  StreamSubscription<WorldChatroomState>? _worldChatroomSub;
  StreamSubscription? _worldChatroomFailureSub;
  StreamSubscription<List<WorldChatroomMessage>>? _worldChatroomLatestSub;
  Map<String, _LocationChatPanelDescriptor> _locationChatDescriptors =
      <String, _LocationChatPanelDescriptor>{};
  final Set<String> _cachedLocationChatIds = <String>{};
  final Set<String> _readyLocationChatIds = <String>{};
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
  final Set<String> _shownMapMessageBubbleKeys = <String>{};
  String _mapMessageBubblePrimeKey = '';
  Future<void>? _mapMessageBubblePrimeFuture;
  String _activeChatLocationId = '';
  Set<String> _visibleMapLocationIds = <String>{};
  String _visibleMapLocationIdsSignature = '';
  bool _isInSecondaryMap = false;
  int _mapModeTargetIndex = 0;
  bool _pollInFlight = false;
  bool _worldActionRunning = false;
  bool _tick1WaitDialogStarted = false;
  var _currentUid = '';
  var _currentUidRequested = false;
  late final ValueNotifier<WorldDetail?> _sectionsWorldNotifier =
      ValueNotifier<WorldDetail?>(_world);
  final _sectionsEventsCache = _WorldSectionsEventsCache();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sectionController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleMapModeTabChanged);
    _handleMapModeTabChanged();
    final initialWorld = widget.initialWorldDetail;
    if (initialWorld != null) {
      _world = initialWorld;
      _sectionsWorldNotifier.value = initialWorld;
      _syncLocationChatDescriptors(initialWorld);
      _syncWorldChatroomForRelationStatus(initialWorld.relationStatus);
      _maybeShowTick1WaitDialog();
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
    _tabController.removeListener(_handleMapModeTabChanged);
    WorldDetailsStatusBarOverride.clearStyle();
    GenesisSystemUiChrome.applyDefault();
    unawaited(_worldChatroomSub?.cancel());
    unawaited(_worldChatroomFailureSub?.cancel());
    unawaited(_worldChatroomLatestSub?.cancel());
    _clearMapMessageBubbleState(updateUi: false);
    final chatroom = _worldChatroom;
    _worldChatroom = null;
    if (chatroom != null) {
      unawaited(_disposeWorldChatroom(chatroom));
    }
    _tabController.dispose();
    _sectionController.dispose();
    _sectionsEventsCache.clear();
    _sectionsWorldNotifier.dispose();
    super.dispose();
  }

  void _handleMapModeTabChanged() {
    if (_activeChatLocationId.isNotEmpty) {
      WorldDetailsStatusBarOverride.setStyle(
        kChatDarkHeaderSystemUiOverlayStyle,
      );
      return;
    }
    if (_tabController.index == 1) {
      WorldDetailsStatusBarOverride.setStyle(
        kGenesisDefaultSystemUiOverlayStyle,
      );
      return;
    }
    WorldDetailsStatusBarOverride.clearStyle();
  }

  void _handleMapModeTabTap(int index) {
    if (_mapModeTargetIndex != index) {
      setState(() => _mapModeTargetIndex = index);
    }
    if (_activeChatLocationId.isNotEmpty) {
      WorldDetailsStatusBarOverride.setStyle(
        kChatDarkHeaderSystemUiOverlayStyle,
      );
      return;
    }
    if (index == 1) {
      WorldDetailsStatusBarOverride.setStyle(
        kGenesisDefaultSystemUiOverlayStyle,
      );
      return;
    }
    WorldDetailsStatusBarOverride.clearStyle();
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
      final key = _mapMessageKey(candidate);
      if (key.isEmpty || !_shownMapMessageBubbleKeys.add(key)) continue;
      final queueLocationId = _mapBubbleQueueLocationId(candidate.locationId);
      byLocation
          .putIfAbsent(queueLocationId, () => <WorldChatroomMessage>[])
          .add(candidate);
    }
    if (byLocation.isEmpty) return false;
    for (final entry in byLocation.entries) {
      final locationId = entry.key;
      final locationMessages = _interleaveMapBubbleMessagesBySender(
        entry.value,
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
    }
    if (startCarousel) {
      _ensureMapMessageBubbleCarousel();
    }
    return true;
  }

  void _registerMapMessageBubbleLocation(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty || _mapMessageBubbleLocationOrder.contains(id)) return;
    _mapMessageBubbleLocationOrder.add(id);
  }

  String _mapBubbleQueueLocationId(String locationId) {
    final id = locationId.trim();
    if (id.isEmpty) return '';
    final locationKeys = _mapBubbleLocationKeys(id);
    for (final key in locationKeys) {
      if (_visibleMapLocationIds.contains(key)) return key;
    }
    return id;
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
      if (_showMapMessageBubble(locationId, nextMessage)) {
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

  bool _showMapMessageBubble(
    String queueLocationId,
    WorldChatroomMessage message,
  ) {
    final content = _mapBubbleDisplayContent(message.content);
    if (content.isEmpty) {
      return false;
    }
    final locationId = message.locationId.trim().isNotEmpty
        ? message.locationId.trim()
        : queueLocationId;
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
    setState(() {
      _removeActiveMapMessageBubble();
      _activeMapMessageBubblesByLocation[queueLocationId] = bubble;
      _mapMessageBubbleKeysByLocation[queueLocationId] = locationKeys;
      for (final locationId in locationKeys) {
        _mapMessageBubbles[locationId] = bubble;
      }
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
    if (!_isInSecondaryMap) return;
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
    if (isInSecondaryMap) {
      _visibleMapLocationIds = <String>{};
      _visibleMapLocationIdsSignature = '';
      _clearMapMessageBubbleState();
      return;
    }
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
    if (!_isInSecondaryMap) return;
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
        _cachedLocationChatIds.clear();
        _readyLocationChatIds.clear();
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
    setState(() {
      _world = world;
      _sectionsWorldNotifier.value = world;
      if (clearInitialLoadError) _initialLoadError = null;
      _syncLocationChatDescriptors(world);
    });
    _syncWorldChatroomForRelationStatus(world.relationStatus);
    _maybePrimeMapMessageBubbles();
  }

  String _rootMapImageUrlForWorld(WorldDetail world) {
    final rootLocationMapUrl = _rootWorldMapImageUrl(
      world.processedLocationTree.collapsedMapRoots,
    ).trim();
    if (rootLocationMapUrl.isNotEmpty) return rootLocationMapUrl;
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
      if (!mounted) return;
      if (action == _WorldHeaderActionKind.progress) {
        _openWorldSectionSheet(
          _worldSectionEventsIndex,
          scrollEventsToLatest: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, '${_worldHeaderActionLabel(action)} failed');
    } finally {
      if (mounted) setState(() => _worldActionRunning = false);
    }
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
    final chatroom = _worldChatroom;
    if (chatroom == null) {
      if (_world?.relationStatus.trim().toLowerCase() == 'approved') {
        await _runWorldAction(_WorldHeaderActionKind.launch);
        return;
      }
      if (mounted) {
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

  // ignore: unused_element
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
    WorldDetailsStatusBarOverride.setStyle(kChatDarkHeaderSystemUiOverlayStyle);
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
    _handleMapModeTabChanged();
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
      _handleMapModeTabChanged();
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
        child: Offstage(
          offstage: !active,
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
                  backgroundImageUrl: descriptor.backgroundImageUrl,
                  backgroundPreviewImageUrl:
                      descriptor.backgroundPreviewImageUrl,
                  isLeafLocation: descriptor.isLeafLocation,
                  localMessageLocationIds: descriptor.localMessageLocationIds,
                  service: chatroom,
                  active: active,
                  leaveOnInactive: false,
                  systemUiOverlayStyle: kChatDarkHeaderSystemUiOverlayStyle,
                  style: kLocationChatStyle,
                  onBack: _closeCachedLocationChat,
                  onInitialContentReady: () =>
                      _markLocationChatPanelReady(descriptor.locationId),
                ),
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

  void _showMapTab() {
    if (_tabController.index == 0) return;
    if (_mapModeTargetIndex != 0) {
      setState(() => _mapModeTargetIndex = 0);
    }
    _tabController.animateTo(
      0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
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
    final rootLocationNodes = processedLocationTree.collapsedMapRoots;
    final rootMapImageUrl = _rootMapImageUrlForWorld(world);
    final renderLocationNodes = processedLocationTree.collapsedMapRenderRoots;
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
    final thirdLevelLocationCount = allLocationNodes
        .where((node) => node.depth == 2)
        .length;
    final title = world.name.trim().isEmpty ? world.worldId : world.name.trim();
    final collapsedPanelHeight = _worldCollapsedPanelHeightFor(context, title);
    return PopScope(
      canPop: _activeChatLocationId.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWorldPopBlocked();
      },
      child: WorldDetailsPageScaffold(
        panelTopGap: 50,
        panelCollapsedHeightOffset: 120,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        topOverlay: _buildLocationChatOverlay(),
        persistentTopOverlay: _buildPersistentMapOverlay(
          thirdLevelLocationCount,
          topPadding + 8,
          worldTime: world.currentTime,
          tickIndex: world.tickCount,
        ),
        map: WorldMapStage(
          controller: _tabController,
          pointsCount: thirdLevelLocationCount,
          top: topPadding + 8,
          showTopOverlay: false,
          mapBuilder: (context, pointMode) => WorldMap(
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
                (pointMode
                    ? _worldMapTabsHeight + 8
                    : _worldMapContentTopOffset),
            drillExitTop:
                topPadding + 8 + _worldMapTabsHeight + _worldTimePillTopGap,
            drillExitMaxWidth: _worldSecondaryMapControlWidth,
            onDrillIntoLocation: _showMapTab,
            onSecondaryMapChanged: _handleSecondaryMapChanged,
            onVisibleLocationIdsChanged: _handleVisibleMapLocationIdsChanged,
            onPointTap: _openChatForPoint,
            messageBubbles: _mapMessageBubbles,
          ),
        ),
        fixedCollapsedPanelHeight: collapsedPanelHeight,
        fixedCollapsedPanelHeightIncludesBottomSafeArea: true,
        contentBottomPaddingOverride: 0,
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

  Widget _buildInitialLoadingScaffold(double topPadding) {
    return WorldDetailsPageScaffold(
      panelTopGap: 50,
      panelCollapsedHeightOffset: 120,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      persistentTopOverlay: _buildPersistentMapOverlay(0, topPadding + 8),
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
          pointsListOuterScrollHandoff: false,
          overlayTop: topPadding + 8 + _worldMapContentTopOffset,
          drillExitTop: topPadding + 8 + _worldMapContentTopOffset + 12,
        ),
      ),
      slivers: const [_WorldDetailsLoadingContent()],
    );
  }

  Widget _buildPersistentMapOverlay(
    int pointsCount,
    double top, {
    String worldTime = '',
    int tickIndex = -1,
  }) {
    final worldTimeLabel = _worldTimeLabel(
      tickIndex: tickIndex,
      worldTime: worldTime,
    );
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: top,
            child: WorldTopOverlayBar(
              pointsCount: pointsCount,
              controller: _tabController,
              onTabTap: _handleMapModeTabTap,
            ),
          ),
          if (worldTimeLabel.isNotEmpty)
            Positioned(
              right: 12,
              top: top + _worldMapTabsHeight + _worldTimePillTopGap,
              child: AnimatedBuilder(
                animation: _tabController.animation ?? _tabController,
                builder: (context, _) {
                  if (_mapModeTargetIndex != 0) {
                    return const SizedBox.shrink();
                  }
                  return _WorldTimePill(
                    text: worldTimeLabel,
                    width: _worldSecondaryMapControlWidth,
                  );
                },
              ),
            ),
          _WorldSectionFloatingTabs(
            controller: _sectionController,
            onTap: _openWorldSectionSheet,
          ),
        ],
      ),
    );
  }

  void _openWorldSectionSheet(int index, {bool scrollEventsToLatest = false}) {
    final world = _world;
    if (world == null) return;
    _sectionController.animateTo(index);
    _sectionsWorldNotifier.value = world;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (context) => _WorldSectionsBottomSheet(
        initialWorld: world,
        worldListenable: _sectionsWorldNotifier,
        eventsCache: _sectionsEventsCache,
        initialIndex: index,
        scrollEventsToLatest: scrollEventsToLatest,
      ),
    );
    unawaited(_fetchWorld());
  }
}

class _WorldTimePill extends StatelessWidget {
  const _WorldTimePill({required this.text, this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _worldTimePillHeight,
      constraints: const BoxConstraints(minWidth: _worldTimePillMinWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: _worldTimePillHorizontalPadding,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
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

class _WorldSectionFloatingTabs extends StatelessWidget {
  const _WorldSectionFloatingTabs({
    required this.controller,
    required this.onTap,
  });

  final TabController controller;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight =
              WorldDetailsPanelScrollControllerScope.maybeMapHeightOf(
                context,
              ) ??
              constraints.maxHeight * 0.69;
          final top = (mapHeight * 0.5)
              .clamp(
                safePadding.top + 72,
                constraints.maxHeight - safePadding.bottom - _height - 16,
              )
              .toDouble();
          return Stack(
            children: [
              Positioned(
                right: _edgePadding,
                top: top,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => SizedBox(
                    width: _width,
                    height: _height,
                    child: _buildTabs(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            for (final entry in _items.indexed) ...[
              Expanded(
                child: _WorldSectionFloatingTabButton(
                  item: entry.$2,
                  selected: controller.index == entry.$1,
                  onTap: () => onTap(entry.$1),
                ),
              ),
              if (entry.$1 != _items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFECECEC),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static const double _width = 48;
  static const double _height = 175;
  static const double _edgePadding = 8;

  static const _items = <_WorldSectionFloatingTabItem>[
    _WorldSectionFloatingTabItem(
      label: 'Events',
      asset: _worldSectionEventsIconAsset,
    ),
    _WorldSectionFloatingTabItem(
      label: 'Status',
      asset: _worldSectionStatusIconAsset,
    ),
    _WorldSectionFloatingTabItem(
      label: 'Cast',
      asset: _worldSectionCastIconAsset,
    ),
  ];
}

class _WorldSectionFloatingTabButton extends StatelessWidget {
  const _WorldSectionFloatingTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _WorldSectionFloatingTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            item.asset,
            width: 19,
            height: 19,
            colorFilter: const ColorFilter.mode(
              Color(0xFF111111),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF666666),
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldSectionFloatingTabItem {
  const _WorldSectionFloatingTabItem({
    required this.label,
    required this.asset,
  });

  final String label;
  final String asset;
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
    required this.onWorldAction,
  });

  final WorldDetail world;
  final bool worldActionRunning;
  final Future<void> Function(_WorldHeaderActionKind action) onWorldAction;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _WorldInfoHeader(
                world: world,
                worldActionRunning: worldActionRunning,
                onWorldAction: onWorldAction,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorldSectionsBottomSheet extends StatefulWidget {
  const _WorldSectionsBottomSheet({
    required this.initialWorld,
    required this.worldListenable,
    required this.eventsCache,
    required this.initialIndex,
    this.scrollEventsToLatest = false,
  });

  final WorldDetail initialWorld;
  final ValueListenable<WorldDetail?> worldListenable;
  final _WorldSectionsEventsCache eventsCache;
  final int initialIndex;
  final bool scrollEventsToLatest;

  @override
  State<_WorldSectionsBottomSheet> createState() =>
      _WorldSectionsBottomSheetState();
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

class _WorldSectionsBottomSheetState extends State<_WorldSectionsBottomSheet>
    with SingleTickerProviderStateMixin {
  static const int _eventsPageSize = 20;
  static const double _eventsLoadMoreExtent = 160;
  static const double _sheetHeightFactor = 0.85;

  late final TabController _controller;
  late final ScrollController _eventsScrollController = ScrollController();
  var _currentUid = '';
  var _currentUidRequested = false;
  var _scrollEventsToLatestAfterLoad = false;

  WorldDetail get _currentWorld =>
      widget.worldListenable.value ?? widget.initialWorld;

  _WorldSectionsEventsCache get _eventsCache => widget.eventsCache;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 2),
    );
    _controller.addListener(_handleTabChanged);
    widget.worldListenable.addListener(_handleWorldDetailChanged);
    _scrollEventsToLatestAfterLoad = widget.scrollEventsToLatest;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_currentUidRequested) {
      _currentUidRequested = true;
      unawaited(_loadCurrentUid());
    }
    _ensureEventsForCurrentWorld();
  }

  @override
  void didUpdateWidget(covariant _WorldSectionsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldListenable != widget.worldListenable) {
      oldWidget.worldListenable.removeListener(_handleWorldDetailChanged);
      widget.worldListenable.addListener(_handleWorldDetailChanged);
    }
    if (oldWidget.eventsCache != widget.eventsCache) {
      _ensureEventsForCurrentWorld(forceFirstPageRefresh: true);
    }
  }

  @override
  void dispose() {
    widget.worldListenable.removeListener(_handleWorldDetailChanged);
    _controller.removeListener(_handleTabChanged);
    _controller.dispose();
    _eventsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  void _handleTabChanged() {
    if (mounted) setState(() {});
    if (_controller.index == 0 && _eventsCache.ticks.isEmpty) {
      unawaited(_loadEventsPage(1));
    }
  }

  void _handleWorldDetailChanged() {
    _ensureEventsForCurrentWorld();
    if (mounted) setState(() {});
  }

  void _ensureEventsForCurrentWorld({bool forceFirstPageRefresh = false}) {
    final worldId = _currentWorld.worldId;
    if (_eventsCache.worldId != worldId) {
      _eventsCache.reset(worldId);
      unawaited(_loadEventsPage(1));
      return;
    }
    if (_eventsCache.ticks.isEmpty ||
        forceFirstPageRefresh ||
        _scrollEventsToLatestAfterLoad) {
      unawaited(_loadEventsPage(1));
    }
    if (_scrollEventsToLatestAfterLoad && _eventsCache.ticks.isNotEmpty) {
      _scheduleScrollEventsToLatest();
    }
  }

  void _mutateEventsCache(VoidCallback update) {
    setState(() {
      update();
    });
  }

  bool get _eventsHasMore {
    return _eventsCache.total > 0 &&
        _eventsCache.ticks.length < _eventsCache.total;
  }

  void _loadNextEventsPage() {
    if (!_eventsHasMore ||
        _eventsCache.loadingMore ||
        _eventsCache.initialLoading) {
      return;
    }
    unawaited(_loadEventsPage(_eventsCache.page + 1));
  }

  Future<void> _loadEventsPage(int page) async {
    if (page <= 0) return;
    if (page == 1) {
      if (_eventsCache.initialLoading) return;
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
      final response = await AppServicesScope.of(context).api.getWorldTicks(
        wid: worldId,
        limit: _eventsPageSize,
        offset: (page - 1) * _eventsPageSize,
      );
      if (!mounted || worldId != _currentWorld.worldId) return;
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
      if (page == 1 && _scrollEventsToLatestAfterLoad) {
        _scrollEventsToLatestAfterLoad = false;
        _scheduleScrollEventsToLatest();
      }
    } catch (e) {
      if (!mounted || worldId != _currentWorld.worldId) return;
      _mutateEventsCache(() => _eventsCache.error = e);
    } finally {
      if (mounted && worldId == _currentWorld.worldId) {
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

  bool _handleEventsScrollNotification(ScrollNotification notification) {
    if (notification.metrics.extentBefore <= _eventsLoadMoreExtent) {
      _loadNextEventsPage();
    }
    return false;
  }

  void _scheduleScrollEventsToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_eventsScrollController.hasClients) return;
      final maxScrollExtent = _eventsScrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) return;
      unawaited(
        _eventsScrollController.animateTo(
          maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  Widget _buildEventsSectionPage() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleEventsScrollNotification,
      child: _WorldSectionListView(
        storageKey: 'world-events-section',
        controller: _eventsScrollController,
        child: _WorldEventsSection(
          world: _currentWorld,
          ticks: _eventsCache.ticks,
          initialLoading: _eventsCache.initialLoading,
          loadingMore: _eventsCache.loadingMore,
          error: _eventsCache.error,
        ),
      ),
    );
  }

  Widget _buildStatusSectionPage() {
    return _WorldSectionListView(
      storageKey: 'world-status-section',
      child: _WorldStatusSection(world: _currentWorld, currentUid: _currentUid),
    );
  }

  Widget _buildSectionsStack() {
    return IndexedStack(
      index: _controller.index,
      children: [
        _buildEventsSectionPage(),
        _buildStatusSectionPage(),
        _WorldSectionListView(
          storageKey: 'world-cast-section',
          child: _WorldCharactersSection(
            world: _currentWorld,
            currentUid: _currentUid,
          ),
        ),
      ],
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
            SizedBox(
              height: 50,
              child: Stack(
                children: [
                  Positioned(
                    top: 16,
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
                    top: 10,
                    right: 24,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(34, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: const Color(0xFFF3F3F5),
                          foregroundColor: const Color(0xFF111111),
                          shape: const CircleBorder(),
                        ),
                        child: const Text(
                          '×',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 21,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _WorldSectionsSheetTabs(controller: _controller),
            ),
            const SizedBox(height: 6),
            Expanded(child: _buildSectionsStack()),
          ],
        ),
      ),
    );
  }
}

class _WorldSectionListView extends StatelessWidget {
  const _WorldSectionListView({
    required this.storageKey,
    this.controller,
    required this.child,
  });

  final String storageKey;
  final ScrollController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: PageStorageKey<String>(storageKey),
      controller: controller,
      primary: false,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      children: [child],
    );
  }
}

class _WorldSectionsSheetTabs extends StatelessWidget {
  const _WorldSectionsSheetTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0x1F767680),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final entry in _WorldSectionFloatingTabs._items.indexed)
                Expanded(
                  child: _WorldSectionsSheetTabButton(
                    label: entry.$2.label,
                    selected: controller.index == entry.$1,
                    onTap: () {
                      if (controller.index == entry.$1) return;
                      controller.index = entry.$1;
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WorldSectionsSheetTabButton extends StatelessWidget {
  const _WorldSectionsSheetTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: const Color(0xFFE8E8EA), width: 1)
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF111111) : const Color(0xFF727276),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
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
    final owner = world.ownerDeleted
        ? deletedEntityDisplayText
        : world.origin.originator.trim().isNotEmpty
        ? world.origin.originator.trim()
        : formatUidForDisplay(world.ownerUid);
    final ownerUid = world.ownerUid.trim();
    final action = _worldHeaderActionFor(world.relationStatus);
    final actionEnabled =
        !world.deleted && !worldActionRunning && action.isClickable;
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
                style: _worldTitleTextStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 38,
              child: GenesisMoreActionMenuButton(
                buttonSize: 18 * 1.25,
                items: [
                  GenesisActionMenuItem(
                    label: 'Report',
                    onSelected: () {
                      showGenesisReportDialog(
                        context: context,
                        targetType: 'world',
                        targetId: wid,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GenesisPairedMetaRow(
          leftLabel: 'WID',
          leftValue: wid,
          leftDisplayValue: world.deleted ? deletedEntityDisplayText : null,
          leftCopyEnabled: !world.deleted,
          leftStyle: _worldHeaderMetaTextStyle,
          leftIconColor: _worldHeaderMetaColor,
          rightText:
              'Owner: ${owner == deletedEntityDisplayText ? owner : formatUidForDisplay(owner)}',
          rightOnTap: ownerUid.isEmpty || world.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
          rightStyle: _worldHeaderMetaTextStyle,
          rightIconColor: _worldHeaderMetaColor,
        ),
        const SizedBox(height: 0),
        SizedBox(
          height: 56,
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
                isLoading: worldActionRunning,
                loadingSize: 18,
                loadingStrokeWidth: 2,
              ),
            ],
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
const TextStyle _worldTitleTextStyle = TextStyle(
  fontSize: 18,
  height: 1.25,
  fontWeight: FontWeight.w600,
  color: Color(0xFF4B6192),
);
const double _worldMetaRowHeight = 16 + 3 * 2;
double _worldCollapsedPanelHeightFor(BuildContext context, String title) {
  final availableTitleWidth =
      MediaQuery.sizeOf(context).width -
      WorldDetailsPageScaffold.contentHorizontalPadding * 2 -
      38 * 2;
  final textPainter =
      TextPainter(
        text: TextSpan(text: title, style: _worldTitleTextStyle),
        maxLines: 2,
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth: availableTitleWidth.clamp(0.0, double.infinity).toDouble(),
      );
  final bottomSafeArea = _worldBottomSafeAreaOf(context);
  final collapsedPanelHeight =
      WorldDetailsPageScaffold.inlineContentTopPadding +
      textPainter.height +
      4 +
      _worldMetaRowHeight +
      56 +
      bottomSafeArea;
  return collapsedPanelHeight;
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
        if (loadingMore) const _WorldEventsLoadingMoreIndicator(),
        const AiContentDisclaimer(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
          textAlign: TextAlign.left,
        ),
        for (int index = 0; index < ticks.length; index++)
          WorldTickEventItem(
            tick: ticks[index],
            tickNumber: worldTickEventNumber(ticks[index], fallback: index + 1),
            fallbackBody: fallbackBody,
            locationsById: locationsById,
            dateLabel: _tickParagraphTimestamp(ticks[index]),
            stackedContent: true,
            contentLabelStyle: _worldEventContentLabelStyle,
            contentTextStyle: _worldEventContentTextStyle,
            contentTimestampStyle: _worldEventContentTimestampStyle,
            isLast: index == ticks.length - 1 && !loadingMore,
          ),
      ],
    );
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
