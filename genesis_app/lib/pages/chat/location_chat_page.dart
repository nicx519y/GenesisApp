import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/ai_content_disclaimer.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/world.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';

const double _locationChatAvatarLogicalSize = 40;
const double _locationChatComposerBottomExtension = 60;
const double _locationChatEdgeSwipeWidth = 24;
const double _locationChatEdgeSwipeTriggerDistance = 64;
const double _locationChatEdgeSwipeTriggerVelocity = 450;

class LocationChatPage extends StatelessWidget {
  const LocationChatPage({
    super.key,
    required this.worldId,
    required this.locationId,
    this.isLeafLocation = true,
    this.localMessageLocationIds = const <String>[],
    this.worldName,
    this.locationName,
    this.backgroundImageUrl,
    this.backgroundPreviewImageUrl,
    this.service,
    this.connection,
  });

  final String worldId;
  final String locationId;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
  final String? worldName;
  final String? locationName;
  final String? backgroundImageUrl;
  final String? backgroundPreviewImageUrl;
  final WorldChatroomService? service;
  final ChatroomConnectionController? connection;

  @override
  Widget build(BuildContext context) {
    return LocationChatPanel(
      worldId: worldId,
      locationId: locationId,
      isLeafLocation: isLeafLocation,
      localMessageLocationIds: localMessageLocationIds,
      worldName: worldName,
      locationName: locationName,
      backgroundImageUrl: backgroundImageUrl,
      backgroundPreviewImageUrl: backgroundPreviewImageUrl,
      service: service,
      connection: connection,
      active: true,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }
}

class LocationChatPanel extends StatefulWidget {
  const LocationChatPanel({
    super.key,
    required this.worldId,
    required this.locationId,
    this.isLeafLocation = true,
    this.localMessageLocationIds = const <String>[],
    this.worldName,
    this.locationName,
    this.backgroundImageUrl,
    this.backgroundPreviewImageUrl,
    this.openingPreviewMessages = const <WorldChatroomMessage>[],
    this.openingPreviewEntities = const <WorldChatroomEntity>[],
    this.service,
    this.connection,
    this.active = true,
    this.leaveOnInactive = true,
    this.onBack,
    this.onInitialContentReady,
    this.composerReplacement,
    this.showConnectionStatus = true,
    this.systemUiOverlayStyle = kChatDarkHeaderSystemUiOverlayStyle,
    this.style,
    this.initialDraftText = '',
    this.initialScrollOffset,
    this.onDraftTextChanged,
    this.onScrollOffsetChanged,
  });

  final String worldId;
  final String locationId;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
  final String? worldName;
  final String? locationName;
  final String? backgroundImageUrl;
  final String? backgroundPreviewImageUrl;
  final List<WorldChatroomMessage> openingPreviewMessages;
  final List<WorldChatroomEntity> openingPreviewEntities;
  final WorldChatroomService? service;
  final ChatroomConnectionController? connection;
  final bool active;
  final bool leaveOnInactive;
  final VoidCallback? onBack;
  final VoidCallback? onInitialContentReady;
  final Widget? composerReplacement;
  final bool showConnectionStatus;
  final SystemUiOverlayStyle systemUiOverlayStyle;
  final ChatUiStyleConfig? style;
  final String initialDraftText;
  final double? initialScrollOffset;
  final ValueChanged<String>? onDraftTextChanged;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<LocationChatPanel> createState() => _LocationChatPanelState();
}

class _LocationChatPanelState extends State<LocationChatPanel>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final Stopwatch _panelStopwatch = Stopwatch()..start();
  final _messages = <ChatMessageVm>[];
  double _composerHeight = 0;

  WorldChatroomService? _service;
  StreamSubscription<WorldChatroomState>? _stateSubscription;
  StreamSubscription<ChatroomFailureEvent>? _failuresSubscription;
  WorldChatroomState _chatroomState = const WorldChatroomState();
  final Set<String> _myUserIdKeys = <String>{};
  final Set<String> _mySenderIdKeys = <String>{};
  String _myUserId = '';
  String _mySenderId = '';
  String _mySenderName = '';
  String _myAvatarUrl = '';
  double _devicePixelRatio = 1;
  bool _ownsService = false;
  bool _joinedLocation = false;
  bool _sending = false;
  bool _awaitingAiResponse = false;
  bool _hasDraftText = false;
  bool _loadingOlderMessages = false;
  bool _hasMoreOlderMessages = true;
  bool _initialContentReadyNotified = false;
  Future<void>? _initialLatestMessagesRefresh;
  int _unseenIncomingCount = 0;
  int _clientMsgCounter = 0;
  String _awaitingAiResponseRoundId = '';
  bool _keepBottomAfterLayoutScheduled = false;
  bool _initialBottomScrollPending = false;
  bool _initialBottomScrollScheduled = false;
  bool _initialBottomScrollShouldComplete = false;
  bool _initialBottomScrollDidJump = false;
  bool _composerFocusBottomPinActive = false;
  bool _composerFocusBottomScheduled = false;
  double _edgeSwipeBackDragDistance = 0;
  bool _edgeSwipeBackTriggered = false;

  @override
  void initState() {
    super.initState();
    final initialDraftText = widget.initialDraftText;
    if (initialDraftText.isNotEmpty) {
      _textController.text = initialDraftText;
      _textController.selection = TextSelection.collapsed(
        offset: initialDraftText.length,
      );
      _hasDraftText = initialDraftText.trim().isNotEmpty;
    }
    _logPanelMetric(
      'init active=${widget.active} leaf=${widget.isLeafLocation} '
      'aliases=${widget.localMessageLocationIds.join(',')}',
    );
    WidgetsBinding.instance.addObserver(this);
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    _textController.addListener(_handleDraftTextChanged);
    _scrollController.addListener(_handleMessageListScroll);
    _prepareConnection();
    if (!_restoreInitialScrollOffset()) {
      _startInitialBottomScroll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final service = _service;
    if (_ownsService && service != null) {
      unawaited(service.disconnect().catchError((Object _) {}));
    }
    unawaited(_closeChatroom());
    widget.onDraftTextChanged?.call(_textController.text);
    if (!_initialBottomScrollPending && _scrollController.hasClients) {
      widget.onScrollOffsetChanged?.call(_scrollController.position.pixels);
    }
    _scrollController.removeListener(_handleMessageListScroll);
    _scrollController.dispose();
    _composerFocusNode.removeListener(_handleComposerFocusChanged);
    _composerFocusNode.dispose();
    _textController.removeListener(_handleDraftTextChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.worldId != widget.worldId ||
        oldWidget.locationId != widget.locationId ||
        !listEquals(
          oldWidget.openingPreviewMessages,
          widget.openingPreviewMessages,
        ) ||
        !listEquals(
          oldWidget.openingPreviewEntities,
          widget.openingPreviewEntities,
        )) {
      unawaited(
        _closeChatroom().then((_) {
          if (!mounted) return;
          _hasMoreOlderMessages = true;
          _loadingOlderMessages = false;
          _initialContentReadyNotified = false;
          _initialLatestMessagesRefresh = null;
          _prepareConnection();
          if (!_restoreInitialScrollOffset()) {
            _startInitialBottomScroll();
          }
        }),
      );
      return;
    }
    if (!oldWidget.active && widget.active) {
      _activateConnection();
      if (!_restoreInitialScrollOffset()) {
        _startInitialBottomScroll();
      }
    } else if (oldWidget.active && !widget.active) {
      unawaited(_deactivateConnection());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previousDevicePixelRatio = _devicePixelRatio;
    _devicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? _devicePixelRatio;
    if ((previousDevicePixelRatio - _devicePixelRatio).abs() > 0.01 &&
        !widget.active &&
        widget.openingPreviewMessages.isNotEmpty) {
      final changedMessages = _syncOpeningPreviewMessages();
      _logPanelMetric(
        'opening preview dpr sync '
        '$previousDevicePixelRatio->$_devicePixelRatio '
        'changed=$changedMessages',
      );
    }
  }

  @override
  void didChangeMetrics() {
    if (_composerFocusBottomPinActive) {
      _scheduleComposerFocusBottomPin();
      return;
    }
    _keepBottomAfterLayoutIfNeeded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WorldChatroomService owns reconnect behavior; this page only joins/leaves
    // the current location.
  }

  void _prepareConnection() {
    final provided = widget.service;
    _logPanelMetric(
      'prepareConnection providedService=${provided != null} '
      'active=${widget.active} '
      'openingPreviewCount=${widget.openingPreviewMessages.length}',
    );
    if (!widget.active && widget.openingPreviewMessages.isNotEmpty) {
      _showOpeningPreviewMessages();
      return;
    }
    if (provided != null) {
      _service = provided;
      _ownsService = false;
      _syncSenderIdentity(provided);
      final services = AppServicesScope.read(context);
      unawaited(_hydrateLocalMessages(provided, services));
      unawaited(_syncLocalIdentity(services));
      _syncFromServiceState(provided);
      if (widget.active) _activateConnection();
      return;
    }

    if (!widget.active) {
      _notifyInitialContentReady();
      return;
    }
    _activateConnection();
  }

  void _showOpeningPreviewMessages() {
    final changedMessages = _syncOpeningPreviewMessages();
    _logPanelMetric(
      'opening preview shown count=${widget.openingPreviewMessages.length} '
      'changed=$changedMessages',
    );
    if (changedMessages && mounted) setState(() {});
    _notifyInitialContentReady();
  }

  bool _syncOpeningPreviewMessages() {
    final nextEntitiesById = <String, WorldChatroomEntity>{
      for (final entity in widget.openingPreviewEntities)
        if (entity.id.trim().isNotEmpty) entity.id.trim(): entity,
    };
    _chatroomState = _chatroomState.copyWith(
      entitiesById: nextEntitiesById,
      entitiesByLocation: <String, List<WorldChatroomEntity>>{
        widget.locationId: widget.openingPreviewEntities,
      },
    );
    return _reconcileMessages(widget.openingPreviewMessages);
  }

  void _activateConnection() {
    final provided = widget.service;
    _logPanelMetric(
      'activateConnection providedService=${provided != null} '
      'joined=$_joinedLocation',
    );
    if (provided != null) {
      _service = provided;
      _ownsService = false;
      _syncSenderIdentity(provided);
      final services = AppServicesScope.read(context);
      unawaited(_hydrateLocalMessages(provided, services));
      unawaited(_syncLocalIdentity(services));
      _attachService(provided);
      if (widget.isLeafLocation && !_joinedLocation) {
        unawaited(_joinLocation(provided));
      }
      return;
    }

    if (_service != null) {
      final service = _service!;
      _attachService(service);
      if (widget.isLeafLocation && !_joinedLocation) {
        unawaited(_joinLocation(service));
      }
      return;
    }

    final services = AppServicesScope.read(context);
    final service = WorldChatroomService(
      api: services.api,
      client: services.chatroom,
      messageStorage: services.chatroomMessages,
    );
    _service = service;
    _ownsService = true;
    _attachService(service);
    unawaited(_connectFallbackAndJoin(service, services));
  }

  Future<void> _deactivateConnection() async {
    _sending = false;
    _awaitingAiResponse = false;
    _awaitingAiResponseRoundId = '';
    final wasJoinedLocation = _joinedLocation;
    _joinedLocation = false;
    await _stateSubscription?.cancel();
    await _failuresSubscription?.cancel();
    _stateSubscription = null;
    _failuresSubscription = null;
    final service = _service;
    final shouldLeave =
        wasJoinedLocation ||
        (service?.state.joinedLocationId == widget.locationId &&
            widget.isLeafLocation);
    if (widget.leaveOnInactive && service != null && shouldLeave) {
      try {
        await service.leave();
      } catch (_) {
        // Hidden cached panels should not surface leave failures.
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _connectFallbackAndJoin(
    WorldChatroomService service,
    AppServices services,
  ) async {
    try {
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      final userInfo = await services.sessionStore.readUserInfo();
      final cachedUid = _mapString(userInfo, 'uid');
      final profile = services.identityAuth.currentProfile();
      _myAvatarUrl = _resolvedProfileAvatar(
        userInfo ?? const <String, dynamic>{},
        profile?.photoUrl ?? '',
      );
      final senderId = firstNonEmpty([
        uid,
        cachedUid,
        profile?.uid,
        'local-user',
      ]);
      final senderName = firstNonEmpty([
        profile?.displayName,
        profile?.email,
        formatUidForDisplay(uid),
        'Me',
      ]);
      _rememberMyUserId(uid);
      _rememberMyUserId(cachedUid);
      _rememberMyUserId(profile?.uid);
      _rememberMyUserId(senderId);
      _rememberMySenderId(senderId);
      _mySenderName = senderName;
      await service.connect(
        worldId: widget.worldId,
        identity: ChatroomConnectionIdentity(
          userId: senderId,
          senderId: senderId,
          senderName: senderName,
        ),
      );
      if (widget.isLeafLocation) {
        await _joinLocation(service);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageVm.system('WebSocket connection failed: $e'));
      });
      _scrollToBottom();
    }
  }

  Future<void> _joinLocation(WorldChatroomService service) async {
    try {
      if (_mySenderId.isEmpty || _mySenderName.isEmpty) {
        final senderId = firstNonEmpty([_mySenderId, 'local-user']);
        _rememberMySenderId(senderId);
        _mySenderName = firstNonEmpty([_mySenderName, 'Me']);
      }
      if (_myUserId.isEmpty) _rememberMyUserId(_mySenderId);
      await service.join(locationId: widget.locationId);
      _joinedLocation = true;
    } catch (e) {
      _joinedLocation = false;
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageVm.system('Join failed: $e'));
      });
      _scrollToBottom();
    }
  }

  void _attachService(WorldChatroomService service) {
    if (_stateSubscription != null || _failuresSubscription != null) {
      _syncFromServiceState(service);
      return;
    }
    _failuresSubscription = bindChatroomFailureToast(
      context,
      service.failures,
      onFailure: _handleFailure,
    );
    _stateSubscription = service.states.listen(_handleChatroomState);
    _syncFromServiceState(service);
  }

  Future<void> _hydrateLocalMessages(
    WorldChatroomService service,
    AppServices services,
  ) async {
    final stopwatch = _panelMetricsEnabled ? (Stopwatch()..start()) : null;
    final identity = service.identity;
    final serviceOwnerUid = firstNonEmpty([
      identity?.userId,
      identity?.senderId,
    ]);
    _logPanelMetric(
      'hydrateLocal start serviceOwner=${serviceOwnerUid.isNotEmpty} '
      'aliases=${widget.localMessageLocationIds.join(',')}',
    );
    if (serviceOwnerUid.isNotEmpty) {
      await service.hydrateLocalMessages(
        worldId: widget.worldId,
        locationId: widget.locationId,
        ownerUid: serviceOwnerUid,
        locationAliases: widget.localMessageLocationIds,
      );
      _syncFromServiceState(service);
      _logPanelMetric(
        'hydrateLocal done owner=service '
        'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
        'vmCount=${_messages.length} '
        'elapsed=${stopwatch?.elapsedMilliseconds}ms',
      );
      _notifyReadyOrRefreshLatestMessages(service);
      return;
    }
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await services.sessionStore.readUserInfo();
    final cachedUid = _mapString(userInfo, 'uid');
    final profile = services.identityAuth.currentProfile();
    final ownerUid = firstNonEmpty([uid, cachedUid, profile?.uid]);
    if (ownerUid.isEmpty) {
      _logPanelMetric(
        'hydrateLocal skipped noOwner elapsed=${stopwatch?.elapsedMilliseconds}ms',
      );
      _notifyInitialContentReady();
      return;
    }
    await service.hydrateLocalMessages(
      worldId: widget.worldId,
      locationId: widget.locationId,
      ownerUid: ownerUid,
      locationAliases: widget.localMessageLocationIds,
    );
    _syncFromServiceState(service);
    _logPanelMetric(
      'hydrateLocal done owner=session '
      'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
      'vmCount=${_messages.length} '
      'elapsed=${stopwatch?.elapsedMilliseconds}ms',
    );
    _notifyReadyOrRefreshLatestMessages(service);
  }

  void _notifyReadyOrRefreshLatestMessages(WorldChatroomService service) {
    final refreshReason = _initialLatestMessagesRefreshReason();
    if (refreshReason.isEmpty) {
      _notifyInitialContentReady();
      return;
    }
    if (!widget.active) {
      _notifyInitialContentReady();
      return;
    }
    final existingRefresh = _initialLatestMessagesRefresh;
    if (existingRefresh != null) return;
    _logPanelMetric('initial history refresh start beforeReady $refreshReason');
    final refresh = service.refreshLatestMessages(
      locationId: widget.locationId,
      limit: 20,
    );
    _initialLatestMessagesRefresh = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (!mounted) return;
        _syncFromServiceState(service);
        _logPanelMetric(
          'initial history refresh done beforeReady '
          'reason=$refreshReason '
          'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
          'vmCount=${_messages.length}',
        );
        _notifyInitialContentReady();
      }),
    );
  }

  String _initialLatestMessagesRefreshReason() {
    if (_messages.isEmpty) return 'empty';
    return _hasVisibleAiMessageMissingCurrentTime() ? 'missingCurrentTime' : '';
  }

  bool _hasVisibleAiMessageMissingCurrentTime() {
    for (final message in _messages) {
      if (!_messageShouldShowCurrentTime(message)) continue;
      if (message.currentTime.trim().isEmpty) return true;
    }
    return false;
  }

  bool _messageShouldShowCurrentTime(ChatMessageVm message) {
    final senderType = message.senderType.trim().toLowerCase();
    return senderType != 'user' &&
        senderType != 'tick' &&
        senderType != 'system';
  }

  void _syncFromServiceState(WorldChatroomService service) {
    _handleChatroomState(service.state);
  }

  void _handleChatroomState(WorldChatroomState state) {
    if (!mounted) return;
    final service = _service;
    if (service != null) _syncSenderIdentity(service);
    final wasAtBottom = _isAtBottom();
    final previousSource =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final previousLatestLocalId = _latestMessageLocalId();
    final nextSource =
        state.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final beforeVmCount = _messages.length;
    final reconcileStopwatch = _panelMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final changedMessages = _reconcileMessages(
      nextSource,
      identityState: state,
    );
    final nextAwaitingAiResponse =
        _awaitingAiResponse && !_hasCompletedAwaitedAiResponse(nextSource);
    final shouldRebuild =
        changedMessages ||
        _hasVisibleChatroomStateChange(_chatroomState, state) ||
        nextAwaitingAiResponse != _awaitingAiResponse;
    if (shouldRebuild) {
      setState(() {
        _chatroomState = state;
        _awaitingAiResponse = nextAwaitingAiResponse;
        if (!nextAwaitingAiResponse) _awaitingAiResponseRoundId = '';
      });
    } else {
      _chatroomState = state;
      _awaitingAiResponse = nextAwaitingAiResponse;
      if (!nextAwaitingAiResponse) _awaitingAiResponseRoundId = '';
    }
    _logPanelMetric(
      'state received source ${previousSource.length}->${nextSource.length} '
      'vm $beforeVmCount->${_messages.length} changed=$changedMessages '
      'joined=${state.joinedLocationId == widget.locationId} '
      'joining=${state.joining} connected=${state.connected} '
      'rebuild=$shouldRebuild '
      'reconcile=${reconcileStopwatch?.elapsedMilliseconds}ms',
    );
    if (nextSource.isNotEmpty) _notifyInitialContentReady();
    if (changedMessages && _initialBottomScrollPending) {
      _scheduleInitialBottomScroll(complete: nextSource.isNotEmpty);
      return;
    }
    if (changedMessages && _composerFocusBottomPinActive) {
      _clearUnseenIncomingCount();
      _scheduleComposerFocusBottomPin();
      return;
    }
    if (changedMessages && wasAtBottom) {
      _clearUnseenIncomingCount();
      _keepBottomAfterLayoutIfNeeded();
    } else if (changedMessages &&
        previousLatestLocalId.isNotEmpty &&
        _latestMessageLocalId() != previousLatestLocalId) {
      final newIncomingCount = _newIncomingTailMessageCount(
        previousSource,
        nextSource,
      );
      if (newIncomingCount > 0) {
        setState(() {
          _unseenIncomingCount += newIncomingCount;
        });
      }
    }
  }

  bool _hasVisibleChatroomStateChange(
    WorldChatroomState previous,
    WorldChatroomState next,
  ) {
    if (previous.joinedLocationId != next.joinedLocationId ||
        previous.joining != next.joining ||
        previous.connected != next.connected ||
        previous.reconnecting != next.reconnecting ||
        previous.inputBlocked != next.inputBlocked) {
      return true;
    }
    return !_sameCurrentLocationEntities(previous, next);
  }

  bool _sameCurrentLocationEntities(
    WorldChatroomState previous,
    WorldChatroomState next,
  ) {
    for (final locationId in _currentLocationIds()) {
      final previousEntities =
          previous.entitiesByLocation[locationId] ??
          const <WorldChatroomEntity>[];
      final nextEntities =
          next.entitiesByLocation[locationId] ?? const <WorldChatroomEntity>[];
      if (identical(previousEntities, nextEntities)) continue;
      if (previousEntities.length != nextEntities.length) return false;
      for (var i = 0; i < previousEntities.length; i += 1) {
        if (!_sameVisibleEntity(previousEntities[i], nextEntities[i])) {
          return false;
        }
      }
    }
    return true;
  }

  bool _sameVisibleEntity(
    WorldChatroomEntity previous,
    WorldChatroomEntity next,
  ) {
    return previous.id == next.id &&
        previous.name == next.name &&
        previous.avatarUrl == next.avatarUrl &&
        previous.type == next.type &&
        previous.locationId == next.locationId &&
        previous.isAi == next.isAi;
  }

  void _notifyInitialContentReady() {
    if (_initialContentReadyNotified || !mounted) return;
    _initialContentReadyNotified = true;
    _logPanelMetric(
      'initialContentReady scheduled vmCount=${_messages.length}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logPanelMetric('initialContentReady fired vmCount=${_messages.length}');
      widget.onInitialContentReady?.call();
    });
  }

  bool get _panelMetricsEnabled => kDebugMode || kProfileMode;

  void _logPanelMetric(String message) {
    if (!_panelMetricsEnabled) return;
    debugPrint(
      '[LocationChatPanel][${widget.locationId}] '
      '+${_panelStopwatch.elapsedMilliseconds}ms $message',
    );
  }

  bool _reconcileMessages(
    List<WorldChatroomMessage> source, {
    WorldChatroomState? identityState,
  }) {
    final resolvedIdentityState = identityState ?? _chatroomState;
    final visibleSource = visibleLocationChatMessagesForTesting(source);
    final previous = _messages.where((message) => !message.isSystem).toList();
    final existingByKey = {
      for (final message in previous) message.localId: message,
    };
    final existingByMessageId = <int, ChatMessageVm>{
      for (final message in previous)
        if ((message.messageId ?? 0) > 0) message.messageId!: message,
    };
    final existingByClientMsgId = <String, ChatMessageVm>{
      for (final message in previous)
        if (message.clientMsgId.trim().isNotEmpty)
          message.clientMsgId.trim(): message,
    };
    final next = <ChatMessageVm>[];
    final usedLocalIds = <String>{};
    var changed = previous.length != visibleSource.length;
    for (final message in visibleSource) {
      final localId = _messageLocalId(message);
      final status = message.streaming ? 'streaming' : 'sent';
      final isMe = _isMineMessage(message);
      final senderName = _messageSenderDisplayName(
        message,
        identityState: resolvedIdentityState,
      );
      final isPlayerControlledRole = _messageSenderIsPlayerControlledRole(
        message,
        identityState: resolvedIdentityState,
      );
      final clientMsgId = message.clientMsgId.trim();
      final existing =
          (clientMsgId.isEmpty ? null : existingByClientMsgId[clientMsgId]) ??
          existingByKey[localId] ??
          (message.messageId > 0
              ? existingByMessageId[message.messageId]
              : null) ??
          _matchingPendingSelfMessage(
            previous,
            message,
            usedLocalIds: usedLocalIds,
          );
      final avatarUrl = _messageAvatarUrl(
        message,
        isMe: isMe,
        fallback: existing?.avatarUrl ?? '',
      );
      final currentTime = _messageCurrentTime(message);
      final createdAt = message.createdAt ?? DateTime.now();
      if (existing != null) {
        if (usedLocalIds.contains(existing.localId)) {
          changed = true;
          continue;
        }
        usedLocalIds.add(existing.localId);
        if (existing.messageId != message.messageId ||
            existing.roundId != message.conversationRoundId ||
            existing.tickNo != message.tickNo ||
            existing.senderName != senderName ||
            existing.isPlayerControlledRole != isPlayerControlledRole ||
            existing.avatarUrl != avatarUrl ||
            existing.text != message.content ||
            existing.currentTime != currentTime ||
            existing.status != status ||
            existing.localId != localId) {
          changed = true;
        }
        existing.messageId = message.messageId;
        existing.roundId = message.conversationRoundId;
        existing.tickNo = message.tickNo;
        existing.senderName = senderName;
        existing.isPlayerControlledRole = isPlayerControlledRole;
        existing.avatarUrl = avatarUrl;
        existing.text = message.content;
        existing.currentTime = currentTime;
        existing.status = status;
        existing.error = null;
        next.add(existing);
      } else {
        changed = true;
        final nextMessage = ChatMessageVm(
          localId: localId,
          clientMsgId: message.clientMsgId,
          messageId: message.messageId,
          roundId: message.conversationRoundId,
          tickNo: message.tickNo,
          senderId: message.senderId,
          senderName: senderName,
          isPlayerControlledRole: isPlayerControlledRole,
          avatarUrl: avatarUrl,
          text: message.content,
          currentTime: currentTime,
          isMe: isMe,
          status: status,
          senderType: _messageSenderType(message),
          createdAt: createdAt,
        );
        usedLocalIds.add(nextMessage.localId);
        next.add(nextMessage);
      }
    }
    for (var i = 0; i < next.length && i < previous.length; i += 1) {
      if (next[i].localId != previous[i].localId) {
        changed = true;
        break;
      }
    }
    if (changed) {
      _messages
        ..clear()
        ..addAll(next);
    }
    return changed;
  }

  ChatMessageVm? _matchingPendingSelfMessage(
    List<ChatMessageVm> previous,
    WorldChatroomMessage message, {
    required Set<String> usedLocalIds,
  }) {
    final content = message.content.trim();
    if (content.isEmpty) return null;
    final now = DateTime.now();
    for (final candidate in previous.reversed) {
      if (usedLocalIds.contains(candidate.localId)) continue;
      if (!candidate.isMe) continue;
      if (candidate.status != 'sending' && candidate.status != 'sent') {
        continue;
      }
      final candidateMessageId = candidate.messageId ?? 0;
      if (candidateMessageId > 0 &&
          message.messageId > 0 &&
          candidateMessageId != message.messageId) {
        continue;
      }
      final age = now.difference(candidate.createdAt).abs();
      if (candidateMessageId <= 0 &&
          candidate.status != 'sending' &&
          age > const Duration(minutes: 1)) {
        continue;
      }
      if (candidate.text.trim() != content) continue;
      return candidate;
    }
    return null;
  }

  String _messageLocalId(WorldChatroomMessage message) {
    if (message.messageId > 0) return 'message-${message.messageId}';
    return 'stream-${message.locationId}-${message.conversationRoundId}-${message.senderId}';
  }

  String _messageSenderType(WorldChatroomMessage message) {
    final senderType = message.senderType.trim().toLowerCase();
    if (senderType == 'narrator') {
      return _senderIdIsNarrator(message.senderId) ? 'narrator' : 'character';
    }
    if (senderType == 'tick') return 'tick';
    if (senderType == 'ai') return 'character';
    return senderType.isEmpty ? 'user' : senderType;
  }

  String _messageCurrentTime(WorldChatroomMessage message) {
    final senderType = _messageSenderType(message);
    if (senderType == 'user' ||
        senderType == 'tick' ||
        senderType == 'system') {
      return '';
    }
    return message.currentTime.trim();
  }

  void _syncSenderIdentity(WorldChatroomService service) {
    final identity = service.identity;
    if (identity == null) return;
    final userId = identity.userId.trim();
    final senderId = identity.senderId.trim();
    final senderName = identity.senderName.trim();
    _rememberMyUserId(userId);
    _rememberMySenderId(senderId);
    if (senderName.isNotEmpty) _mySenderName = senderName;
  }

  Future<void> _syncLocalIdentity(AppServices services) async {
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await services.sessionStore.readUserInfo();
    final cachedUid = _mapString(userInfo, 'uid');
    final profile = services.identityAuth.currentProfile();
    final avatarUrl = _resolvedProfileAvatar(
      userInfo ?? const <String, dynamic>{},
      profile?.photoUrl ?? '',
    );
    final avatarChanged = avatarUrl != _myAvatarUrl;
    _myAvatarUrl = avatarUrl;
    final changed =
        _rememberMyUserId(uid) |
        _rememberMyUserId(cachedUid) |
        _rememberMyUserId(profile?.uid) |
        avatarChanged;
    if (!changed || !mounted) return;
    final changedMessages = _reconcileMessages(
      _chatroomState.messagesByLocation[widget.locationId] ??
          const <WorldChatroomMessage>[],
    );
    if (changedMessages && mounted) setState(() {});
  }

  bool _rememberMyUserId(String? userId) {
    final trimmed = userId?.trim() ?? '';
    final key = _chatroomIdentityKey(trimmed);
    if (key.isEmpty) return false;
    if (_myUserId.isEmpty) _myUserId = trimmed;
    return _myUserIdKeys.add(key);
  }

  bool _rememberMySenderId(String? senderId) {
    final trimmed = senderId?.trim() ?? '';
    final key = _chatroomIdentityKey(trimmed);
    if (key.isEmpty) return false;
    if (_mySenderId.isEmpty) _mySenderId = trimmed;
    return _mySenderIdKeys.add(key);
  }

  bool _isMineMessage(WorldChatroomMessage message) {
    final userIdKey = _chatroomIdentityKey(message.userId);
    if (userIdKey.isNotEmpty && _myUserIdKeys.contains(userIdKey)) return true;
    final senderIdKey = _chatroomIdentityKey(message.senderId);
    return senderIdKey.isNotEmpty && _mySenderIdKeys.contains(senderIdKey);
  }

  void _handleFailure(ChatroomFailureEvent failure) {
    // Toast binding already displays the failure. Keep the message list backed
    // by WorldChatroomState instead of appending synthetic rows.
  }

  bool _hasCompletedAwaitedAiResponse(List<WorldChatroomMessage> source) {
    final awaitedRoundId = _awaitingAiResponseRoundId.trim();
    if (!_awaitingAiResponse) return false;
    if (awaitedRoundId.isEmpty) return false;
    for (final message in source.reversed) {
      if (!_currentLocationIds().contains(message.locationId)) continue;
      if (message.conversationRoundId != awaitedRoundId) continue;
      if (_isMineMessage(message)) continue;
      if (_messageSenderType(message) == 'user') continue;
      return !message.streaming;
    }
    return false;
  }

  Future<void> _send() async {
    final service = _service;
    if (service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _awaitingAiResponse ||
        _sending) {
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final clientMsgId = _nextClientMsgId();
    final localMessage = ChatMessageVm(
      localId: 'local-$clientMsgId',
      clientMsgId: clientMsgId,
      senderId: _mySenderId,
      senderName: _localSelfDisplayName(),
      avatarUrl: _resizedLocationChatAvatarUrl(_localSelfAvatarUrl()),
      isPlayerControlledRole: _identityCandidatesArePlayerControlledRole([
        _myUserId,
        _mySenderId,
      ]),
      text: text,
      isMe: true,
      status: 'sending',
    );

    setState(() {
      _sending = true;
      _awaitingAiResponse = true;
      _awaitingAiResponseRoundId = '';
      _messages.add(localMessage);
      _hasDraftText = false;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final ack = await service.sendMessage(text, clientMsgId: clientMsgId);
      if (!mounted) return;
      setState(() {
        localMessage.messageId = ack.messageId;
        localMessage.roundId = ack.conversationRoundId;
        localMessage.status = 'sent';
        _awaitingAiResponseRoundId = ack.conversationRoundId.trim();
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        localMessage.status = 'failed';
        localMessage.error = e.toString();
        _awaitingAiResponse = false;
        _awaitingAiResponseRoundId = '';
        _sending = false;
      });
    }
  }

  String _nextClientMsgId() {
    _clientMsgCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_clientMsgCounter';
  }

  String _latestMessageLocalId() {
    final nonSystem = _messages.where((message) => !message.isSystem);
    if (nonSystem.isEmpty) return '';
    return nonSystem.last.localId;
  }

  void _handleMessageListScroll() {
    if (!_scrollController.hasClients) return;
    var publishedOffset = false;
    if (_initialBottomScrollPending &&
        _initialBottomScrollDidJump &&
        _messages.isNotEmpty &&
        !_isAtBottom()) {
      _initialBottomScrollPending = false;
      _initialBottomScrollShouldComplete = false;
      widget.onScrollOffsetChanged?.call(_scrollController.position.pixels);
      publishedOffset = true;
    }
    if (!_initialBottomScrollPending && !publishedOffset) {
      widget.onScrollOffsetChanged?.call(_scrollController.position.pixels);
    }
    if (_unseenIncomingCount > 0 && _isAtBottom()) {
      _clearUnseenIncomingCount();
    }
    if (!widget.active ||
        !widget.isLeafLocation ||
        _loadingOlderMessages ||
        !_hasMoreOlderMessages) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels - position.minScrollExtent > 180) return;
    unawaited(_loadOlderMessages());
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlderMessages) return;
    final service = _service;
    if (service == null) return;
    final beforeMessageId = _earliestLoadedMessageId();
    if (beforeMessageId <= 0) {
      _hasMoreOlderMessages = false;
      return;
    }
    _loadingOlderMessages = true;
    try {
      final page = await service.loadOlderMessages(
        locationId: widget.locationId,
        beforeMessageId: beforeMessageId,
        limit: 20,
      );
      _hasMoreOlderMessages = page.hasMore;
    } catch (_) {
      // Up-scroll history loading is opportunistic; connection failures are
      // surfaced by the chatroom service failure stream when appropriate.
    } finally {
      _loadingOlderMessages = false;
    }
  }

  int _earliestLoadedMessageId() {
    var earliest = 0;
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    for (final message in source) {
      final messageId = message.messageId;
      if (messageId <= 0) continue;
      if (earliest == 0 || messageId < earliest) earliest = messageId;
    }
    return earliest;
  }

  int _newIncomingTailMessageCount(
    List<WorldChatroomMessage> previous,
    List<WorldChatroomMessage> next,
  ) {
    final previousKeys = previous.map(_messageDedupKey).toSet();
    var count = 0;
    for (final message in next) {
      if (previousKeys.contains(_messageDedupKey(message))) continue;
      if (_isMineMessage(message)) continue;
      count += 1;
    }
    return count;
  }

  String _messageDedupKey(WorldChatroomMessage message) {
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isNotEmpty) return 'client:$clientMsgId';
    if (message.messageId > 0) return 'message:${message.messageId}';
    return [
      'round',
      message.locationId,
      message.conversationRoundId,
      message.senderId,
      message.roundOrder,
    ].join(':');
  }

  String _messageSenderDisplayName(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    final state = identityState ?? _chatroomState;
    return firstNonEmpty([
      _roleNameForIdentityCandidates([
        message.userId,
        message.senderId,
      ], identityState: state),
      _entityNameForIdentity(message.userId, identityState: state),
      _entityNameForIdentity(message.senderId, identityState: state),
      message.senderName,
    ]);
  }

  bool _messageSenderIsPlayerControlledRole(
    WorldChatroomMessage message, {
    WorldChatroomState? identityState,
  }) {
    return _identityCandidatesArePlayerControlledRole([
      message.userId,
      message.senderId,
    ], identityState: identityState);
  }

  String _messageAvatarUrl(
    WorldChatroomMessage message, {
    bool? isMe,
    String fallback = '',
  }) {
    final mine = isMe ?? _isMineMessage(message);
    final avatarUrl = resolveLocationChatMessageAvatarForTesting(
      entityUserAvatar: _entityAvatarForIdentity(message.userId),
      entitySenderAvatar: _entityAvatarForIdentity(message.senderId),
      roleAvatar: _roleAvatarForIdentityCandidates([
        message.userId,
        message.senderId,
      ]),
      isMine: mine,
      localSelfAvatar: mine ? _localSelfAvatarUrl() : '',
      fallback: fallback,
    );
    return _resizedLocationChatAvatarUrl(avatarUrl);
  }

  String _resizedLocationChatAvatarUrl(String rawUrl) {
    final url = rawUrl.trim();
    final resizedUrl = resizeGenesisImageUrl(
      url,
      logicalWidth: _locationChatAvatarLogicalSize,
      devicePixelRatio: _devicePixelRatio,
    );
    return resizedUrl.isNotEmpty ? resizedUrl : url;
  }

  String _localSelfDisplayName() {
    return firstNonEmpty([
      _roleNameForIdentityCandidates([_myUserId, _mySenderId]),
      _entityNameForIdentity(_myUserId),
      _entityNameForIdentity(_mySenderId),
      _mySenderName,
    ]);
  }

  String _localSelfAvatarUrl() {
    return firstNonEmpty([
      _entityAvatarForIdentity(_myUserId),
      _entityAvatarForIdentity(_mySenderId),
      _roleAvatarForIdentityCandidates([_myUserId, _mySenderId]),
      _myAvatarUrl,
    ]);
  }

  String _entityNameForIdentity(
    String value, {
    WorldChatroomState? identityState,
  }) {
    final key = _chatroomIdentityKey(value);
    if (key.isEmpty) return '';
    final state = identityState ?? _chatroomState;
    for (final entry in state.entitiesById.entries) {
      if (_chatroomIdentityKey(entry.key) != key) continue;
      return entry.value.name;
    }
    return '';
  }

  bool _identityCandidatesArePlayerControlledRole(
    List<String?> identities, {
    WorldChatroomState? identityState,
  }) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return false;
    final state = identityState ?? _chatroomState;
    for (final entry in state.entitiesById.entries) {
      if (!keys.contains(_chatroomIdentityKey(entry.key))) continue;
      if (entry.value.type == WorldChatroomEntityType.player) return true;
    }
    return _worldHasPlayerControlledRoleForIdentity(keys, state.world);
  }

  String _entityAvatarForIdentity(String value) {
    final key = _chatroomIdentityKey(value);
    if (key.isEmpty) return '';
    for (final entry in _chatroomState.entitiesById.entries) {
      if (_chatroomIdentityKey(entry.key) != key) continue;
      return entry.value.avatarUrl;
    }
    return '';
  }

  bool _worldHasPlayerControlledRoleForIdentity(
    Set<String> identityKeys,
    WorldDetail? world,
  ) {
    if (world == null) return false;
    for (final character in world.characterPositions) {
      if (_characterCandidateIsPlayerControlled(character, identityKeys)) {
        return true;
      }
    }
    for (final character in world.characters) {
      if (_characterCandidateIsPlayerControlled(character, identityKeys)) {
        return true;
      }
    }
    return false;
  }

  bool _characterCandidateIsPlayerControlled(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return false;
    return _firstMapString(character, const [
      'player_uid',
      'user_id',
      'uid',
    ]).isNotEmpty;
  }

  String _roleNameForIdentityCandidates(
    List<String?> identities, {
    WorldChatroomState? identityState,
  }) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return '';
    final world = (identityState ?? _chatroomState).world;
    if (world == null) return '';
    for (final character in world.characterPositions) {
      final candidate = _roleNameFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final character in world.characters) {
      final candidate = _roleNameFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final position in world.userPositions) {
      final candidate = _roleNameFromUserPosition(position, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _roleNameFromCharacterCandidate(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return '';
    return _firstMapString(character, const [
      'name',
      'role_nickname',
      'role_name',
      'character_name',
    ]);
  }

  String _roleAvatarForIdentityCandidates(List<String?> identities) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return '';
    final world = _chatroomState.world;
    if (world == null) return '';
    for (final character in world.characterPositions) {
      final candidate = _roleAvatarFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final character in world.characters) {
      final candidate = _roleAvatarFromCharacterCandidate(character, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    for (final position in world.userPositions) {
      final candidate = _roleAvatarFromUserPosition(position, keys);
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _roleAvatarFromCharacterCandidate(
    Map<String, dynamic> candidate,
    Set<String> identityKeys,
  ) {
    final rawCharacter = candidate['character'];
    final character = rawCharacter is Map
        ? _stringKeyMap(rawCharacter)
        : candidate;
    if (!_characterMatchesIdentity(character, identityKeys)) return '';
    return _firstMapImageUrl(character, const ['avatar', 'avatar_url']);
  }

  String _roleAvatarFromUserPosition(
    Map<String, dynamic> position,
    Set<String> identityKeys,
  ) {
    final rawUser = position['user'];
    final user = rawUser is Map ? _stringKeyMap(rawUser) : position;
    final userId = _firstMapString(user, const ['user_id', 'uid', 'id']);
    final userKey = _chatroomIdentityKey(userId);
    if (userKey.isEmpty || !identityKeys.contains(userKey)) return '';
    return _firstMapImageUrl(user, const ['avatar', 'avatar_url']);
  }

  bool _characterMatchesIdentity(
    Map<String, dynamic> character,
    Set<String> identityKeys,
  ) {
    for (final key in const [
      'player_uid',
      'user_id',
      'uid',
      'character_id',
      'char_id',
      'id',
    ]) {
      final value = _chatroomIdentityKey(_mapString(character, key));
      if (value.isNotEmpty && identityKeys.contains(value)) return true;
    }
    return false;
  }

  String _roleNameFromUserPosition(
    Map<String, dynamic> position,
    Set<String> identityKeys,
  ) {
    final rawUser = position['user'];
    final user = rawUser is Map ? _stringKeyMap(rawUser) : position;
    final userId = _firstMapString(user, const ['user_id', 'uid', 'id']);
    final userKey = _chatroomIdentityKey(userId);
    if (userKey.isEmpty || !identityKeys.contains(userKey)) return '';
    return _firstMapString(user, const [
      'role_nickname',
      'role_name',
      'character_name',
      'name',
    ]);
  }

  Future<void> _closeChatroom() async {
    final service = _service;
    final ownsService = _ownsService;
    _service = null;
    _sending = false;
    _awaitingAiResponse = false;
    _awaitingAiResponseRoundId = '';

    await _stateSubscription?.cancel();
    await _failuresSubscription?.cancel();
    _stateSubscription = null;
    _failuresSubscription = null;

    if (service != null) {
      final shouldLeave =
          _joinedLocation ||
          (service.state.joinedLocationId == widget.locationId &&
              widget.isLeafLocation);
      if (widget.leaveOnInactive && shouldLeave) {
        try {
          await service.leave();
        } catch (_) {
          // Route disposal must not wait on or surface leave failures.
        }
      }
      if (ownsService) {
        try {
          await service.disconnect();
        } catch (_) {}
        await service.dispose();
      }
    }
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 24;
  }

  double _bottomScrollOffset() {
    if (!_scrollController.hasClients) return 0;
    return _scrollController.position.maxScrollExtent;
  }

  bool _restoreInitialScrollOffset() {
    final initialOffset = widget.initialScrollOffset;
    if (initialOffset == null) return false;
    _initialBottomScrollPending = false;
    _initialBottomScrollShouldComplete = false;
    _initialBottomScrollDidJump = false;

    void restoreIfReady() {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = initialOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(target);
    }

    restoreIfReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreIfReady();
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreIfReady());
    });
    return true;
  }

  void _startInitialBottomScroll() {
    _initialBottomScrollPending = true;
    _initialBottomScrollShouldComplete = false;
    _initialBottomScrollDidJump = false;
    _scheduleInitialBottomScroll(complete: _messages.isNotEmpty);
  }

  void _scheduleInitialBottomScroll({required bool complete}) {
    if (!_initialBottomScrollPending) return;
    _initialBottomScrollShouldComplete =
        _initialBottomScrollShouldComplete || complete;
    if (_initialBottomScrollScheduled) return;
    _initialBottomScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialBottomScrollScheduled = false;
      if (!mounted || !_initialBottomScrollPending) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_bottomScrollOffset());
      _initialBottomScrollDidJump = true;
      final shouldComplete = _initialBottomScrollShouldComplete;
      _initialBottomScrollShouldComplete = false;
      if (!shouldComplete || _messages.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_initialBottomScrollPending) return;
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_bottomScrollOffset());
        _initialBottomScrollPending = false;
        _initialBottomScrollDidJump = false;
        widget.onScrollOffsetChanged?.call(_scrollController.position.pixels);
      });
    });
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final bottom = _bottomScrollOffset();
      if (jump) {
        _scrollController.jumpTo(bottom);
        return;
      }
      _scrollController.animateTo(
        bottom,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _forceScrollToBottom() {
    void jumpIfReady() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_bottomScrollOffset());
    }

    jumpIfReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpIfReady();
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpIfReady());
    });
  }

  void _scrollToBottomForComposerInput() {
    _activateComposerFocusBottomPin();
  }

  void _activateComposerFocusBottomPin() {
    _composerFocusBottomPinActive = true;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_bottomScrollOffset());
    }
    _scheduleComposerFocusBottomPin();
  }

  void _deactivateComposerFocusBottomPin() {
    _composerFocusBottomPinActive = false;
  }

  void _scheduleComposerFocusBottomPin() {
    if (!_composerFocusBottomPinActive) return;
    if (_composerFocusBottomScheduled) return;
    _composerFocusBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerFocusBottomScheduled = false;
      if (!mounted ||
          !_composerFocusNode.hasFocus ||
          !_composerFocusBottomPinActive) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_bottomScrollOffset());
      }
    });
  }

  bool _handleMessageListScrollNotification(ScrollNotification notification) {
    if (!_composerFocusBottomPinActive) return false;
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null) {
      return false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_composerFocusBottomPinActive) return;
      if (!_scrollController.hasClients || _isAtBottom()) return;
      _deactivateComposerFocusBottomPin();
    });
    return false;
  }

  void _keepBottomAfterLayoutIfNeeded() {
    if (!_isAtBottom()) return;
    if (_keepBottomAfterLayoutScheduled) return;
    _keepBottomAfterLayoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepBottomAfterLayoutScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_bottomScrollOffset());
    });
  }

  void _clearUnseenIncomingCount() {
    if (_unseenIncomingCount == 0 || !mounted) return;
    setState(() => _unseenIncomingCount = 0);
  }

  void _openUnseenIncomingMessages() {
    _clearUnseenIncomingCount();
    _forceScrollToBottom();
  }

  void _showMessageActionMenu(
    BuildContext menuContext,
    ChatMessageVm message,
    LongPressStartDetails details,
  ) {
    final items = <GenesisActionMenuItem>[
      GenesisActionMenuItem(
        label: 'Copy',
        iconData: Icons.copy_outlined,
        onSelected: () => _copyMessageText(message),
      ),
      if (!message.isMe)
        GenesisActionMenuItem(
          label: 'Report',
          iconAsset: genesisReportIconAsset,
          onSelected: () {
            showGenesisReportDialog(
              context: context,
              targetType: 'message',
              targetId: _messageReportTargetId(message),
            );
          },
        ),
    ];
    showGenesisActionMenuAt(
      context: menuContext,
      globalPosition: details.globalPosition,
      items: items,
      appearance: GenesisActionMenuAppearance.message,
    );
  }

  Future<void> _copyMessageText(ChatMessageVm message) async {
    final text = message.isTick ? _tickReportText(message) : message.text;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showGenesisToast(context, 'Copied');
  }

  String _messageReportTargetId(ChatMessageVm message) {
    final messageId = message.messageId ?? 0;
    if (messageId > 0) return '$messageId';
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isNotEmpty) return clientMsgId;
    return message.localId;
  }

  String _tickReportText(ChatMessageVm message) {
    final tick = message.tickNo > 0 ? 'Tick ${message.tickNo}' : 'Tick';
    final text = message.text.trim();
    return text.isEmpty ? tick : '$tick · $text';
  }

  List<WorldChatroomEntity> _realUsersForCurrentLocation(
    WorldChatroomState state,
  ) {
    final locationIds = _currentLocationIds();
    final users = <WorldChatroomEntity>[];
    final seen = <String>{};

    void addUser(WorldChatroomEntity entity) {
      if (!_isRealUserEntity(entity)) return;
      final key = _realUserDedupKey(entity);
      if (key.isEmpty || !seen.add(key)) return;
      users.add(entity);
    }

    for (final locationId in locationIds) {
      for (final entity
          in state.entitiesByLocation[locationId] ??
              const <WorldChatroomEntity>[]) {
        addUser(entity);
      }
    }

    if (state.joinedLocationId == widget.locationId) {
      final selfId = firstNonEmpty([_myUserId, _mySenderId]);
      final selfName = _localSelfDisplayName();
      if (selfId.isNotEmpty || selfName.isNotEmpty) {
        addUser(
          WorldChatroomEntity(
            id: selfId.isEmpty ? selfName : selfId,
            name: selfName,
            avatarUrl: _localSelfAvatarUrl(),
            type: WorldChatroomEntityType.player,
            locationId: widget.locationId,
            isAi: false,
          ),
        );
      }
    }

    return users;
  }

  List<String> _currentLocationIds() {
    final seen = <String>{};
    final ids = <String>[];
    void add(String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty || !seen.add(trimmed)) return;
      ids.add(trimmed);
    }

    add(widget.locationId);
    for (final locationId in widget.localMessageLocationIds) {
      add(locationId);
    }
    return ids;
  }

  bool _isRealUserEntity(WorldChatroomEntity entity) {
    return !entity.isAi;
  }

  String _realUserDedupKey(WorldChatroomEntity entity) {
    final idKey = _chatroomIdentityKey(entity.id);
    if (idKey.isNotEmpty) return 'id:$idKey';
    final nameKey = entity.name.trim().toLowerCase();
    return nameKey.isEmpty ? '' : 'name:$nameKey';
  }

  @override
  Widget build(BuildContext context) {
    final realUsers = _realUsersForCurrentLocation(_chatroomState);
    final aiRoleNames = resolveLocationChatAiRoleNamesForTesting(
      _chatroomState,
      _currentLocationIds(),
    );
    final title = firstNonEmpty([widget.locationName, widget.locationId]);
    final subtitle = aiRoleNames.join(', ');
    final joined = _chatroomState.joinedLocationId == widget.locationId;
    final connecting =
        _chatroomState.reconnecting ||
        _chatroomState.joining ||
        (_chatroomState.connected && !joined);
    final inputBlocked = _chatroomState.inputBlocked;
    final baseStyle = widget.style ?? kLocationChatStyle;
    final style = baseStyle.copyWith(
      headerSubtitleTextStyle: baseStyle.headerSubtitleTextStyle.copyWith(
        fontSize: 12,
      ),
      headerStatusIconSize: 12,
    );
    final replacementComposer = widget.composerReplacement;
    final composer = replacementComposer == null
        ? ChatComposer(
            controller: _textController,
            focusNode: _composerFocusNode,
            inputEnabled: widget.active,
            sendEnabled:
                widget.active &&
                joined &&
                _hasDraftText &&
                !_sending &&
                !_awaitingAiResponse &&
                !inputBlocked,
            sending: false,
            onSend: _send,
            sendLabel: 'Send',
            style: style,
            onHeightChanged: _handleComposerHeightChanged,
            onInputTap: _handleComposerInputTap,
          )
        : _LocationChatMeasuredComposer(
            onHeightChanged: _handleComposerHeightChanged,
            child: replacementComposer,
          );
    final header = ChatHeader(
      title: '$title (${realUsers.length})',
      subtitle: subtitle,
      connected: joined,
      connecting: connecting,
      subtitleIconAsset: locationChatCharacterIconAsset,
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      showSubtitle: widget.showConnectionStatus && aiRoleNames.isNotEmpty,
      style: style,
    );
    final listStyle = style.copyWith(
      messageListPadding: _locationChatMessageListPadding(style),
    );
    final messageList = ChatMessageList(
      key: const ValueKey<String>('location-chat-message-list'),
      controller: _scrollController,
      messages: _messages,
      topTitle: '',
      oldestEdgeNotice: kAiContentDisclaimerText,
      onMessageLongPressStart: _showMessageActionMenu,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      reverse: false,
      showDateDividers: false,
      style: listStyle,
    );

    return GenesisBottomSystemBarStyleScope(
      style: GenesisBottomSystemBarStyle(color: style.composerBackgroundColor),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: widget.systemUiOverlayStyle,
        child: Stack(
          children: [
            Positioned.fill(
              child: _LocationChatBackground(
                imageUrl: widget.backgroundImageUrl,
                previewImageUrl: widget.backgroundPreviewImageUrl,
                color: style.conversationBackgroundColor,
              ),
            ),
            Positioned.fill(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: _composerFocusNode.hasFocus,
                body: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Stack(
                      children: [
                        Positioned.fill(
                          child: NotificationListener<ScrollNotification>(
                            onNotification:
                                _handleMessageListScrollNotification,
                            child: messageList,
                          ),
                        ),
                        if (_unseenIncomingCount > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: _locationChatComposerHeight(style) + 12,
                            child: Center(
                              child: _LocationChatNewMessageNotice(
                                count: _unseenIncomingCount,
                                onTap: _openUnseenIncomingMessages,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Positioned(left: 0, right: 0, top: 0, child: header),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: RepaintBoundary(
                        child: _LocationChatComposerExtension(
                          style: style,
                          child: composer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_supportsEdgeSwipeBack)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: _edgeSwipeBackWidth(context),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _handleEdgeSwipeBackStart,
                  onHorizontalDragUpdate: _handleEdgeSwipeBackUpdate,
                  onHorizontalDragEnd: _handleEdgeSwipeBackEnd,
                  onHorizontalDragCancel: _resetEdgeSwipeBack,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _supportsEdgeSwipeBack {
    return widget.active &&
        widget.onBack != null &&
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  double _edgeSwipeBackWidth(BuildContext context) {
    final direction = Directionality.of(context);
    final padding = MediaQuery.paddingOf(context);
    final edgePadding = direction == TextDirection.rtl
        ? padding.right
        : padding.left;
    return math.max(_locationChatEdgeSwipeWidth, edgePadding);
  }

  void _handleEdgeSwipeBackStart(DragStartDetails details) {
    _edgeSwipeBackDragDistance = 0;
    _edgeSwipeBackTriggered = false;
  }

  void _handleEdgeSwipeBackUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final logicalDelta = Directionality.of(context) == TextDirection.rtl
        ? -delta
        : delta;
    _edgeSwipeBackDragDistance = math.max(
      0,
      _edgeSwipeBackDragDistance + logicalDelta,
    );
    if (_edgeSwipeBackDragDistance >= _locationChatEdgeSwipeTriggerDistance) {
      _triggerEdgeSwipeBack();
    }
  }

  void _handleEdgeSwipeBackEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final logicalVelocity = Directionality.of(context) == TextDirection.rtl
        ? -velocity
        : velocity;
    if (logicalVelocity >= _locationChatEdgeSwipeTriggerVelocity) {
      _triggerEdgeSwipeBack();
      return;
    }
    _resetEdgeSwipeBack();
  }

  void _triggerEdgeSwipeBack() {
    if (_edgeSwipeBackTriggered) return;
    _edgeSwipeBackTriggered = true;
    _composerFocusNode.unfocus();
    widget.onBack?.call();
  }

  void _resetEdgeSwipeBack() {
    _edgeSwipeBackDragDistance = 0;
    _edgeSwipeBackTriggered = false;
  }

  EdgeInsets _locationChatMessageListPadding(ChatUiStyleConfig style) {
    return style.messageListPadding.copyWith(
      top: style.messageListPadding.top + _locationChatHeaderHeight(style),
      bottom:
          style.messageListPadding.bottom + _locationChatComposerHeight(style),
    );
  }

  double _locationChatHeaderHeight(ChatUiStyleConfig style) {
    return GenesisSafeAreaInsets.top(context) + style.headerHeight;
  }

  double _locationChatComposerHeight(ChatUiStyleConfig style) {
    if (_composerHeight > 0) return _composerHeight;
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
    return style.composerPadding.vertical + style.inputMinHeight + bottomInset;
  }

  void _handleComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _scrollToBottomForComposerInput();
    } else {
      _deactivateComposerFocusBottomPin();
    }
    if (mounted) setState(() {});
  }

  void _handleComposerInputTap() {
    _scrollToBottomForComposerInput();
  }

  void _handleDraftTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    widget.onDraftTextChanged?.call(_textController.text);
    if (_hasDraftText == hasText) return;
    setState(() => _hasDraftText = hasText);
  }

  void _handleComposerHeightChanged(double height) {
    if ((_composerHeight - height).abs() > 0.5) {
      setState(() => _composerHeight = height);
    }
    if (_initialBottomScrollPending) {
      _scheduleInitialBottomScroll(complete: _messages.isNotEmpty);
      return;
    }
    if (_composerFocusBottomPinActive) {
      _scheduleComposerFocusBottomPin();
      return;
    }
    _keepBottomAfterLayoutIfNeeded();
  }
}

class _LocationChatBackground extends StatelessWidget {
  const _LocationChatBackground({
    required this.imageUrl,
    required this.previewImageUrl,
    required this.color,
  });

  final String? imageUrl;
  final String? previewImageUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: color,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final url = selectGenesisImageUrl(
              imageUrl,
              fallback: previewImageUrl,
              logicalWidth: constraints.maxWidth,
              logicalHeight: constraints.maxHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            if (url.isEmpty) return const SizedBox.expand();
            return Image(
              image: _locationChatBackgroundProvider(url),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.expand();
              },
            );
          },
        ),
      ),
    );
  }
}

ImageProvider _locationChatBackgroundProvider(String url) {
  final resolved = url.trim();
  return resolved.startsWith('assets/')
      ? AssetImage(resolved)
      : CachedNetworkImageProvider(resolved);
}

class _LocationChatComposerExtension extends StatelessWidget {
  const _LocationChatComposerExtension({
    required this.style,
    required this.child,
  });

  final ChatUiStyleConfig style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -_locationChatComposerBottomExtension,
          height: _locationChatComposerBottomExtension,
          child: DecoratedBox(
            decoration: BoxDecoration(color: _bottomExtensionColor(style)),
          ),
        ),
        child,
      ],
    );
  }

  Color _bottomExtensionColor(ChatUiStyleConfig style) {
    final gradient = style.composerBackgroundGradient;
    if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
      return gradient.colors.last;
    }
    return style.composerBackgroundColor;
  }
}

class _LocationChatMeasuredComposer extends StatefulWidget {
  const _LocationChatMeasuredComposer({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double> onHeightChanged;

  @override
  State<_LocationChatMeasuredComposer> createState() =>
      _LocationChatMeasuredComposerState();
}

class _LocationChatMeasuredComposerState
    extends State<_LocationChatMeasuredComposer> {
  final _key = GlobalKey();
  double _lastHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _LocationChatMeasuredComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final context = _key.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final height = renderObject.size.height;
    if ((_lastHeight - height).abs() <= 0.5) return;
    _lastHeight = height;
    widget.onHeightChanged(height);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: SizeChangedLayoutNotifier(key: _key, child: widget.child),
    );
  }
}

String _mapString(Map<String, dynamic>? map, String key) {
  if (map == null) return '';
  final value = map[key];
  if (value == null) return '';
  return '$value'.trim();
}

String _resolvedProfileAvatar(
  Map<dynamic, dynamic> userInfo,
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

@visibleForTesting
String resolveLocationChatMessageAvatarForTesting({
  String entityUserAvatar = '',
  String entitySenderAvatar = '',
  String roleAvatar = '',
  bool isMine = false,
  String localSelfAvatar = '',
  String fallback = '',
}) {
  return firstNonEmpty([
    entityUserAvatar,
    entitySenderAvatar,
    roleAvatar,
    if (isMine) localSelfAvatar,
    fallback,
  ]);
}

@visibleForTesting
List<String> resolveLocationChatAiRoleNamesForTesting(
  WorldChatroomState state,
  Iterable<String> locationIds,
) {
  final names = <String>[];
  final seen = <String>{};
  for (final locationId in locationIds) {
    final trimmedLocationId = locationId.trim();
    if (trimmedLocationId.isEmpty) continue;
    final entities =
        state.entitiesByLocation[trimmedLocationId] ??
        const <WorldChatroomEntity>[];
    for (final entity in entities) {
      if (!entity.isAi) continue;
      final name = entity.name.trim();
      if (name.isEmpty) continue;
      final key = _locationChatEntityDedupKey(entity);
      if (key.isEmpty || !seen.add(key)) continue;
      names.add(name);
    }
  }
  return names;
}

String _locationChatEntityDedupKey(WorldChatroomEntity entity) {
  final idKey = _chatroomIdentityKey(entity.id);
  if (idKey.isNotEmpty) return 'id:$idKey';
  final nameKey = entity.name.trim().toLowerCase();
  return nameKey.isEmpty ? '' : 'name:$nameKey';
}

Object? _mapValue(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return value;
  }
  return null;
}

bool _senderIdIsNarrator(String senderId) {
  return senderId.trim().toLowerCase() == 'nar';
}

@visibleForTesting
List<WorldChatroomMessage> visibleLocationChatMessagesForTesting(
  List<WorldChatroomMessage> source,
) {
  if (source.length < 2) return source;
  final next = <WorldChatroomMessage>[];
  WorldChatroomMessage? pendingTick;
  for (final message in source) {
    if (_isTickAdvanceMessage(message)) {
      pendingTick = message;
      continue;
    }
    if (pendingTick != null) {
      next.add(pendingTick);
      pendingTick = null;
    }
    next.add(message);
  }
  if (pendingTick != null) next.add(pendingTick);
  return next.length == source.length ? source : next;
}

bool _isTickAdvanceMessage(WorldChatroomMessage message) {
  return message.senderType.trim().toLowerCase() == 'tick';
}

class _LocationChatNewMessageNotice extends StatelessWidget {
  const _LocationChatNewMessageNotice({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1E1E24),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('location-chat-new-message-notice'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$count new message',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

String _firstMapString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _mapString(map, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _firstMapImageUrl(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (!map.containsKey(key)) continue;
    final resolved = asResolvedImageUrl(map[key], resolveAssetUrl);
    if (resolved.isNotEmpty) return resolved;
  }
  return '';
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> map) {
  return {
    for (final entry in map.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _chatroomIdentityKey(String? value) {
  return (value ?? '').trim().toLowerCase();
}
