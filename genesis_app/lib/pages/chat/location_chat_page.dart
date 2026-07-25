import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/debug/location_chat_debug_slice.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/ai_content_disclaimer.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/gems/gem_balance_prompt.dart';
import '../../components/gems/memory_model_entry_button.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_ugc_text.dart';
import '../../utils/llm_stream_escape_decoder.dart';

const double _locationChatAvatarLogicalSize = 40;
const double _locationChatComposerBottomExtension = 60;
const double _locationChatEdgeSwipeWidth = 24;
const double _locationChatEdgeSwipeTriggerDistance = 64;
const double _locationChatEdgeSwipeTriggerVelocity = 450;
const int _locationChatMessageGapMaxAttempts = 3;
const String _locationChatDefaultBackgroundAsset =
    'assets/images/map_default/location_default.webp';

String selectedModelCodeFromUserInfo(Map<String, dynamic> userInfo) {
  final direct = asString(userInfo['selected_model_code']).trim();
  if (direct.isNotEmpty) return direct;
  final nestedUser = userInfo['user'];
  if (nestedUser is! Map) return '';
  return asString(nestedUser['selected_model_code']).trim();
}

@visibleForTesting
void preserveUnmatchedLocationChatLocalMessages({
  required List<ChatMessageVm> previous,
  required List<ChatMessageVm> reconciled,
  required Set<String> usedLocalIds,
}) {
  for (final message in previous) {
    if (usedLocalIds.contains(message.localId) ||
        !message.isMe ||
        message.clientMsgId.trim().isEmpty ||
        (message.status != 'sending' && message.status != 'failed')) {
      continue;
    }
    usedLocalIds.add(message.localId);
    reconciled.add(message);
  }
}

const Set<String> _locationChatDraftRecoverableFailureCodes = <String>{
  '1002',
  '1008',
  '10001',
  '2006',
  '2010',
  '3001',
  '5000',
};

const Set<String> _locationChatDraftRecoverableSendFailureCodes = <String>{
  'ack_timeout',
  'connect_failed',
  'send_message_send_failed',
  'socket_closed',
  'socket_error',
  'stream_missing',
};

String? recoverLocationChatDraftAfterRetriableAckFailure({
  required Object failure,
  required ChatMessageVm localMessage,
  required List<ChatMessageVm> messages,
  bool activeSendFailure = false,
}) {
  if (failure is! ChatroomFailureEvent ||
      !_shouldRecoverLocationChatDraftAfterFailure(
        failure,
        activeSendFailure: activeSendFailure,
      )) {
    return null;
  }
  messages.removeWhere((message) => identical(message, localMessage));
  return localMessage.text;
}

bool _shouldRecoverLocationChatDraftAfterFailure(
  ChatroomFailureEvent failure, {
  required bool activeSendFailure,
}) {
  final code = failure.code.trim();
  if (_locationChatDraftRecoverableFailureCodes.contains(code)) return true;
  if (!activeSendFailure && failure.requestType.trim() != 'send_message') {
    return false;
  }
  return _locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(
        failure.sourceType.trim(),
      );
}

String _locationChatDraftRestoreToastMessage(Object failure) {
  if (failure is! ChatroomFailureEvent) {
    return 'Something went wrong. Please try again later.';
  }
  final code = failure.code.trim();
  final sourceType = failure.sourceType.trim();
  if (_locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(sourceType)) {
    return 'Something went wrong. Please try again later.';
  }
  return chatroomFailureToastMessage(failure);
}

bool _shouldShowDraftRestoreToast(Object failure) {
  if (failure is! ChatroomFailureEvent) return true;
  final code = failure.code.trim();
  final sourceType = failure.sourceType.trim();
  return _locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(sourceType);
}

class LocationChatPage extends StatelessWidget {
  const LocationChatPage({
    super.key,
    required this.worldId,
    required this.locationId,
    this.isLeafLocation = true,
    this.localMessageLocationIds = const <String>[],
    this.recentChatLocationPathIds = const <String>[],
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
  final List<String> recentChatLocationPathIds;
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
      recentChatLocationPathIds: recentChatLocationPathIds,
      worldName: worldName,
      locationName: locationName,
      backgroundImageUrl: backgroundImageUrl,
      backgroundPreviewImageUrl: backgroundPreviewImageUrl,
      service: service,
      connection: connection,
      active: true,
      showMoreButton: false,
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
    this.recentChatLocationPathIds = const <String>[],
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
    this.showMoreButton = false,
    this.systemUiOverlayStyle = kChatDarkHeaderSystemUiOverlayStyle,
    this.style,
    this.initialDraftText = '',
    this.onDraftTextChanged,
    this.messageQueueInitializationCovered = false,
    this.unauthorizedHandledByOwner = false,
  });

  final String worldId;
  final String locationId;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
  final List<String> recentChatLocationPathIds;
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
  final bool showMoreButton;
  final SystemUiOverlayStyle systemUiOverlayStyle;
  final ChatUiStyleConfig? style;
  final String initialDraftText;
  final ValueChanged<String>? onDraftTextChanged;
  final bool messageQueueInitializationCovered;
  final bool unauthorizedHandledByOwner;

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
  StreamSubscription<GemBalanceAlert>? _balanceAlertSubscription;
  WorldChatroomState _chatroomState = const WorldChatroomState();
  final Set<String> _myUserIdKeys = <String>{};
  final Set<String> _mySenderIdKeys = <String>{};
  String _myUserId = '';
  String _mySenderId = '';
  String _mySenderName = '';
  String _myAvatarUrl = '';
  String _selectedModelCode = '';
  double _devicePixelRatio = 1;
  bool _ownsService = false;
  bool _joinedLocation = false;
  bool _sending = false;
  bool _handlingUnauthorizedFailure = false;
  bool _awaitingAiResponse = false;
  bool _hasDraftText = false;
  bool _loadingOlderMessages = false;
  int _loadingOlderBeforeLocationMessageId = 0;
  bool _hasMoreOlderMessages = true;
  bool _olderMessagesExhaustedByRemote = false;
  bool _olderMessagesExhaustedByCursorlessContent = false;
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
  final Set<String> _messageGapFillKeys = <String>{};
  final Set<int> _messageGapFillBeforeLocationMessageIds = <int>{};
  final Map<String, int> _messageGapFillAttempts = <String, int>{};
  final Set<String> _releasedMessageGapKeys = <String>{};
  bool _deferredVisibleMessageGapFill = false;
  String _scrollCenterLocalId = '';
  double _edgeSwipeBackDragDistance = 0;
  bool _edgeSwipeBackTriggered = false;
  bool _openingModelPage = false;
  int _serviceGeneration = 0;
  int _selectedModelLoadGeneration = 0;
  ValueListenable<int>? _userInfoRevisionListenable;

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
    unawaited(_loadSelectedModelCodeFromCache());
    _startInitialBottomScroll();
  }

  @override
  void dispose() {
    _selectedModelLoadGeneration++;
    _userInfoRevisionListenable?.removeListener(_handleCachedUserInfoChanged);
    WidgetsBinding.instance.removeObserver(this);
    _recordPanelDebug(action: 'dispose', activeOverride: false);
    final service = _service;
    if (_ownsService && service != null) {
      unawaited(service.disconnect().catchError((Object _) {}));
    }
    unawaited(_closeChatroom());
    widget.onDraftTextChanged?.call(_textController.text);
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
    if (oldWidget.worldId != widget.worldId ||
        (!oldWidget.active && widget.active)) {
      unawaited(_loadSelectedModelCodeFromCache());
    }
    final changedChatTarget =
        oldWidget.service != widget.service ||
        oldWidget.worldId != widget.worldId ||
        oldWidget.locationId != widget.locationId;
    if (changedChatTarget ||
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
          if (changedChatTarget) {
            _olderMessagesExhaustedByRemote = false;
            _olderMessagesExhaustedByCursorlessContent = false;
          }
          _loadingOlderMessages = false;
          _initialContentReadyNotified = false;
          _initialLatestMessagesRefresh = null;
          _messageGapFillKeys.clear();
          _messageGapFillBeforeLocationMessageIds.clear();
          _messageGapFillAttempts.clear();
          _releasedMessageGapKeys.clear();
          _deferredVisibleMessageGapFill = false;
          _scrollCenterLocalId = '';
          _prepareConnection();
          _startInitialBottomScroll();
        }),
      );
      return;
    }
    if (!oldWidget.active && widget.active) {
      _activateConnection();
      _startInitialBottomScroll();
    } else if (oldWidget.active && !widget.active) {
      unawaited(_deactivateConnection());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userInfoRevision = AppServicesScope.of(
      context,
    ).sessionStore.userInfoRevision;
    if (!identical(_userInfoRevisionListenable, userInfoRevision)) {
      _userInfoRevisionListenable?.removeListener(_handleCachedUserInfoChanged);
      _userInfoRevisionListenable = userInfoRevision;
      userInfoRevision.addListener(_handleCachedUserInfoChanged);
    }
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

  Future<void> _loadSelectedModelCodeFromCache() async {
    final generation = ++_selectedModelLoadGeneration;
    try {
      final userInfo =
          await AppServicesScope.read(context).sessionStore.readUserInfo() ??
          const <String, dynamic>{};
      final modelCode = selectedModelCodeFromUserInfo(userInfo);
      if (!mounted || generation != _selectedModelLoadGeneration) return;
      if (modelCode == _selectedModelCode) return;
      setState(() => _selectedModelCode = modelCode);
    } catch (error) {
      debugPrint(
        '[WorldChat][Model] load cached selected model failed: $error',
      );
    }
  }

  void _handleCachedUserInfoChanged() {
    unawaited(_loadSelectedModelCodeFromCache());
  }

  Future<void> _openMemoryModelPage() async {
    if (_openingModelPage) return;
    _openingModelPage = true;
    _selectedModelLoadGeneration++;
    try {
      final selectedModelCode = await Navigator.of(context, rootNavigator: true)
          .pushNamed<String>(
            RouteNames.memoryModel,
            arguments: {'world_id': widget.worldId},
          );
      if (!mounted) return;
      final normalized = selectedModelCode?.trim() ?? '';
      if (normalized.isEmpty) {
        await _loadSelectedModelCodeFromCache();
        return;
      }
      if (normalized != _selectedModelCode) {
        setState(() => _selectedModelCode = normalized);
      }
    } finally {
      _openingModelPage = false;
    }
  }

  void _prepareConnection() {
    final provided = widget.service;
    _logPanelMetric(
      'prepareConnection providedService=${provided != null} '
      'active=${widget.active} '
      'openingPreviewCount=${widget.openingPreviewMessages.length}',
    );
    _recordPanelDebug(
      action: 'prepareConnection',
      details: {
        'providedService': provided != null,
        'active': widget.active,
        'openingPreviewCount': widget.openingPreviewMessages.length,
      },
    );
    if (!widget.active && widget.openingPreviewMessages.isNotEmpty) {
      _showOpeningPreviewMessages();
      return;
    }
    if (provided != null) {
      _service = provided;
      _ownsService = false;
      _joinedLocation = provided.state.joinedLocationId == widget.locationId;
      _syncSenderIdentity(provided);
      final services = AppServicesScope.read(context);
      _startHydrateLocalMessages(provided, services);
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
    _recordPanelDebug(
      action: 'openingPreviewShown',
      details: {
        'count': widget.openingPreviewMessages.length,
        'changed': changedMessages,
      },
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
    final changedMessages = _reconcileMessages(widget.openingPreviewMessages);
    _syncHasMoreOlderMessagesForSource(widget.openingPreviewMessages);
    return changedMessages;
  }

  void _activateConnection() {
    final provided = widget.service;
    _logPanelMetric(
      'activateConnection providedService=${provided != null} '
      'joined=$_joinedLocation',
    );
    _recordPanelDebug(
      action: 'activateConnection',
      details: {'providedService': provided != null, 'joined': _joinedLocation},
    );
    if (provided != null) {
      _service = provided;
      _ownsService = false;
      _joinedLocation = provided.state.joinedLocationId == widget.locationId;
      _syncSenderIdentity(provided);
      final services = AppServicesScope.read(context);
      _startHydrateLocalMessages(provided, services);
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
    await _balanceAlertSubscription?.cancel();
    _stateSubscription = null;
    _failuresSubscription = null;
    _balanceAlertSubscription = null;
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
    _recordPanelDebug(
      action: 'deactivateConnection',
      details: {
        'wasJoinedLocation': wasJoinedLocation,
        'shouldLeave': shouldLeave,
      },
    );
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
      _myAvatarUrl = _resolvedProfileAvatar(
        userInfo ?? const <String, dynamic>{},
        '',
      );
      final senderId = firstNonEmpty([uid, cachedUid, 'local-user']);
      final senderName = firstNonEmpty([
        _mapString(userInfo, 'display_name'),
        _mapString(userInfo, 'nickname'),
        _mapString(userInfo, 'name'),
        formatUidForDisplay(uid),
        'Me',
      ]);
      _rememberMyUserId(uid);
      _rememberMyUserId(cachedUid);
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
      _recordPanelDebug(action: 'joinDone');
    } catch (e) {
      _joinedLocation = false;
      _recordPanelDebug(action: 'joinFailed', details: {'error': '$e'});
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageVm.system('Join failed: $e'));
      });
      _scrollToBottom();
    }
  }

  void _attachService(WorldChatroomService service) {
    if (_ownsService && _balanceAlertSubscription == null) {
      _balanceAlertSubscription = bindGemBalancePrompt(
        context,
        service.balanceAlerts,
      );
    }
    if (_stateSubscription != null || _failuresSubscription != null) {
      _syncFromServiceState(service);
      return;
    }
    _failuresSubscription = bindChatroomFailureToast(
      context,
      service.failures,
      shouldShow: (failure) {
        return !widget.unauthorizedHandledByOwner ||
            !isChatroomUnauthorizedFailure(failure);
      },
      onFailure: _handleFailure,
    );
    _stateSubscription = service.states.listen(_handleChatroomState);
    _syncFromServiceState(service);
  }

  void _startHydrateLocalMessages(
    WorldChatroomService service,
    AppServices services,
  ) {
    final generation = _serviceGeneration;
    unawaited(_hydrateLocalMessages(service, services, generation));
  }

  bool _isCurrentService(WorldChatroomService service, int generation) {
    return mounted &&
        generation == _serviceGeneration &&
        identical(_service, service) &&
        !service.isDisposed;
  }

  bool _isDisposedServiceError(
    WorldChatroomService service,
    ChatroomProtocolException error,
    int generation,
  ) {
    return service.isDisposed ||
        !_isCurrentService(service, generation) ||
        error.message == 'WorldChatroomService is disposed';
  }

  Future<void> _hydrateLocalMessages(
    WorldChatroomService service,
    AppServices services,
    int generation,
  ) async {
    final stopwatch = _panelMetricsEnabled ? (Stopwatch()..start()) : null;
    if (!_isCurrentService(service, generation)) return;
    try {
      final identity = service.identity;
      final serviceOwnerUid = firstNonEmpty([
        identity?.userId,
        identity?.senderId,
      ]);
      _logPanelMetric(
        'hydrateLocal start serviceOwner=${serviceOwnerUid.isNotEmpty} '
        'aliases=${widget.localMessageLocationIds.join(',')}',
      );
      _recordPanelDebug(
        action: 'hydrateLocalStart',
        details: {
          'serviceOwner': serviceOwnerUid.isNotEmpty,
          'aliases': widget.localMessageLocationIds,
        },
      );
      if (serviceOwnerUid.isNotEmpty) {
        if (!_isCurrentService(service, generation)) return;
        await service.hydrateLocalMessages(
          worldId: widget.worldId,
          locationId: widget.locationId,
          ownerUid: serviceOwnerUid,
          locationAliases: widget.localMessageLocationIds,
        );
        if (!_isCurrentService(service, generation)) return;
        _syncFromServiceState(service);
        _logPanelMetric(
          'hydrateLocal done owner=service '
          'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
          'vmCount=${_messages.length} '
          'elapsed=${stopwatch?.elapsedMilliseconds}ms',
        );
        _recordPanelDebug(
          action: 'hydrateLocalDone',
          details: {
            'ownerSource': 'service',
            'elapsedMs': stopwatch?.elapsedMilliseconds,
          },
        );
        _notifyReadyOrRefreshLatestMessages(service, generation);
        return;
      }
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      if (!_isCurrentService(service, generation)) return;
      final userInfo = await services.sessionStore.readUserInfo();
      if (!_isCurrentService(service, generation)) return;
      final cachedUid = _mapString(userInfo, 'uid');
      final ownerUid = firstNonEmpty([uid, cachedUid]);
      if (ownerUid.isEmpty) {
        _logPanelMetric(
          'hydrateLocal skipped noOwner elapsed=${stopwatch?.elapsedMilliseconds}ms',
        );
        _recordPanelDebug(
          action: 'hydrateLocalSkipped',
          details: {
            'reason': 'noOwner',
            'elapsedMs': stopwatch?.elapsedMilliseconds,
          },
        );
        if (_isCurrentService(service, generation)) {
          _notifyInitialContentReady();
        }
        return;
      }
      if (!_isCurrentService(service, generation)) return;
      await service.hydrateLocalMessages(
        worldId: widget.worldId,
        locationId: widget.locationId,
        ownerUid: ownerUid,
        locationAliases: widget.localMessageLocationIds,
      );
      if (!_isCurrentService(service, generation)) return;
      _syncFromServiceState(service);
      _logPanelMetric(
        'hydrateLocal done owner=session '
        'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
        'vmCount=${_messages.length} '
        'elapsed=${stopwatch?.elapsedMilliseconds}ms',
      );
      _recordPanelDebug(
        action: 'hydrateLocalDone',
        details: {
          'ownerSource': 'session',
          'elapsedMs': stopwatch?.elapsedMilliseconds,
        },
      );
      _notifyReadyOrRefreshLatestMessages(service, generation);
    } on ChatroomProtocolException catch (error) {
      if (_isDisposedServiceError(service, error, generation)) {
        _logPanelMetric(
          'hydrateLocal ignored stale service elapsed=${stopwatch?.elapsedMilliseconds}ms',
        );
        _recordPanelDebug(
          action: 'hydrateLocalStaleService',
          details: {'elapsedMs': stopwatch?.elapsedMilliseconds},
        );
        return;
      }
      rethrow;
    }
  }

  void _notifyReadyOrRefreshLatestMessages(
    WorldChatroomService service,
    int generation,
  ) {
    if (!_isCurrentService(service, generation)) return;
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
      refresh
          .then((_) {
            if (!_isCurrentService(service, generation)) return;
            _syncFromServiceState(service);
            _logPanelMetric(
              'initial history refresh done beforeReady '
              'reason=$refreshReason '
              'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
              'vmCount=${_messages.length}',
            );
            _notifyInitialContentReady();
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (error is ChatroomProtocolException &&
                _isDisposedServiceError(service, error, generation)) {
              return;
            }
            if (!_isCurrentService(service, generation)) return;
            Error.throwWithStackTrace(error, stackTrace);
          }),
    );
  }

  String _initialLatestMessagesRefreshReason() {
    if (widget.messageQueueInitializationCovered) return '';
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
    final changedHasMoreOlder = _syncHasMoreOlderMessagesForSource(nextSource);
    final olderLoadRendered = _olderLoadHasRenderedNewMessages();
    final nextAwaitingAiResponse =
        _awaitingAiResponse && !_hasCompletedAwaitedAiResponse(nextSource);
    final shouldRebuild =
        changedMessages ||
        changedHasMoreOlder ||
        olderLoadRendered ||
        _hasVisibleChatroomStateChange(_chatroomState, state) ||
        nextAwaitingAiResponse != _awaitingAiResponse;
    if (shouldRebuild) {
      setState(() {
        _chatroomState = state;
        if (olderLoadRendered) _finishOlderMessagesLoading();
        _awaitingAiResponse = nextAwaitingAiResponse;
        if (!nextAwaitingAiResponse) _awaitingAiResponseRoundId = '';
      });
    } else {
      _chatroomState = state;
      if (olderLoadRendered) _finishOlderMessagesLoading();
      _awaitingAiResponse = nextAwaitingAiResponse;
      if (!nextAwaitingAiResponse) _awaitingAiResponseRoundId = '';
    }
    if (olderLoadRendered) _runDeferredVisibleMessageGapFillIfNeeded();
    _logPanelMetric(
      'state received source ${previousSource.length}->${nextSource.length} '
      'vm $beforeVmCount->${_messages.length} changed=$changedMessages '
      'joined=${state.joinedLocationId == widget.locationId} '
      'joining=${state.joining} connected=${state.connected} '
      'rebuild=$shouldRebuild '
      'reconcile=${reconcileStopwatch?.elapsedMilliseconds}ms',
    );
    _recordPanelDebug(
      action: 'stateReceived',
      sourceMessages: nextSource,
      details: {
        'previousSourceCount': previousSource.length,
        'nextSourceCount': nextSource.length,
        'beforeVmCount': beforeVmCount,
        'afterVmCount': _messages.length,
        'changedMessages': changedMessages,
        'joined': state.joinedLocationId == widget.locationId,
        'joining': state.joining,
        'connected': state.connected,
        'rebuild': shouldRebuild,
        'reconcileMs': reconcileStopwatch?.elapsedMilliseconds,
        'unseenIncomingCount': _unseenIncomingCount,
      },
    );
    if (nextSource.isNotEmpty) _notifyInitialContentReady();
    if (changedMessages && _initialBottomScrollPending) {
      _scheduleInitialBottomScroll(complete: nextSource.isNotEmpty);
      return;
    }
    if (changedMessages && _composerFocusBottomPinActive) {
      _clearUnseenIncomingCount();
      if (!wasAtBottom) _scheduleComposerFocusBottomPin();
      return;
    }
    if (changedMessages && wasAtBottom) {
      _clearUnseenIncomingCount();
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
    _recordPanelDebug(action: 'initialContentReadyScheduled');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logPanelMetric('initialContentReady fired vmCount=${_messages.length}');
      _recordPanelDebug(action: 'initialContentReadyFired');
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

  void _recordPanelDebug({
    required String action,
    List<WorldChatroomMessage>? sourceMessages,
    Map<String, Object?> details = const <String, Object?>{},
    bool? activeOverride,
  }) {
    if (!LocationChatDebugSlice.enabled) return;
    final source =
        sourceMessages ??
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final hasClients = _scrollController.hasClients;
    LocationChatDebugSlice.recordPanel(
      action: action,
      worldId: widget.worldId,
      locationId: widget.locationId,
      locationName: widget.locationName ?? '',
      active: activeOverride ?? widget.active,
      isLeafLocation: widget.isLeafLocation,
      state: _chatroomState,
      sourceMessages: source,
      renderMessages: _messages,
      details: details,
      hasMoreOlderMessages: _hasMoreOlderMessages,
      loadingOlderMessages: _loadingOlderMessages,
      unseenIncomingCount: _unseenIncomingCount,
      awaitingAiResponse: _awaitingAiResponse,
      scroll: {
        'hasClients': hasClients,
        'pixels': hasClients ? _scrollController.position.pixels : 0,
        'extentBefore': hasClients
            ? _scrollController.position.extentBefore
            : 0,
        'maxScrollExtent': hasClients
            ? _scrollController.position.maxScrollExtent
            : 0,
        'scrollCenterLocalId': _scrollCenterLocalId,
        'isAtBottom': _isAtBottom(),
        'initialBottomScrollPending': _initialBottomScrollPending,
        'initialBottomScrollScheduled': _initialBottomScrollScheduled,
        'composerFocusBottomPinActive': _composerFocusBottomPinActive,
        'keepBottomAfterLayoutScheduled': _keepBottomAfterLayoutScheduled,
      },
    );
  }

  bool _reconcileMessages(
    List<WorldChatroomMessage> source, {
    WorldChatroomState? identityState,
  }) {
    final resolvedIdentityState = identityState ?? _chatroomState;
    final renderWindow = _visibleLocationChatMessages(
      source,
      renderedLocationMessageIds: _renderedLocationMessageIds(),
      releasedGapKeys: _releasedMessageGapKeys,
      locationId: widget.locationId,
    );
    _requestVisibleMessageGapFillIfNeeded(renderWindow.gaps, source);
    final visibleSource = renderWindow.messages;
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
      final text = _locationChatMessageDisplayText(message);
      final currentTime = _messageCurrentTime(message);
      final createdAt = message.createdAt ?? DateTime.now();
      if (existing != null) {
        if (usedLocalIds.contains(existing.localId)) {
          changed = true;
          continue;
        }
        usedLocalIds.add(existing.localId);
        if (existing.globalMessageId != message.globalMessageId ||
            existing.messageId != message.messageId ||
            existing.locationMessageId != message.locationMessageId ||
            existing.roundId != message.conversationRoundId ||
            existing.tickNo != message.tickNo ||
            existing.senderName != senderName ||
            existing.isPlayerControlledRole != isPlayerControlledRole ||
            existing.avatarUrl != avatarUrl ||
            existing.text != text ||
            existing.currentTime != currentTime ||
            existing.status != status ||
            existing.localId != localId) {
          changed = true;
        }
        existing.globalMessageId = message.globalMessageId;
        existing.messageId = message.messageId;
        existing.locationMessageId = message.locationMessageId;
        existing.roundId = message.conversationRoundId;
        existing.tickNo = message.tickNo;
        existing.senderName = senderName;
        existing.isPlayerControlledRole = isPlayerControlledRole;
        existing.avatarUrl = avatarUrl;
        existing.text = text;
        existing.currentTime = currentTime;
        existing.status = status;
        existing.error = null;
        next.add(existing);
      } else {
        changed = true;
        final nextMessage = ChatMessageVm(
          localId: localId,
          clientMsgId: message.clientMsgId,
          globalMessageId: message.globalMessageId,
          messageId: message.messageId,
          locationMessageId: message.locationMessageId,
          roundId: message.conversationRoundId,
          tickNo: message.tickNo,
          senderId: message.senderId,
          senderName: senderName,
          isPlayerControlledRole: isPlayerControlledRole,
          avatarUrl: avatarUrl,
          text: text,
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
    preserveUnmatchedLocationChatLocalMessages(
      previous: previous,
      reconciled: next,
      usedLocalIds: usedLocalIds,
    );
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
    _syncScrollCenterLocalId();
    return changed;
  }

  void _syncScrollCenterLocalId() {
    final nextCenterLocalId = _firstNonSystemMessageLocalId();
    if (nextCenterLocalId.isEmpty) {
      if (_scrollCenterLocalId.isNotEmpty) {
        final previousCenterLocalId = _scrollCenterLocalId;
        _scrollCenterLocalId = '';
        _recordPanelDebug(
          action: 'scrollCenterCleared',
          details: {'previousCenterLocalId': previousCenterLocalId},
        );
      }
      return;
    }
    if (_scrollCenterLocalId.isNotEmpty &&
        _messages.any((message) => message.localId == _scrollCenterLocalId)) {
      return;
    }
    final previousCenterLocalId = _scrollCenterLocalId;
    _scrollCenterLocalId = nextCenterLocalId;
    _recordPanelDebug(
      action: previousCenterLocalId.isEmpty
          ? 'scrollCenterInitialized'
          : 'scrollCenterReset',
      details: {
        'previousCenterLocalId': previousCenterLocalId,
        'centerLocalId': _scrollCenterLocalId,
      },
    );
  }

  String _firstNonSystemMessageLocalId() {
    for (final message in _messages) {
      if (!message.isSystem) return message.localId;
    }
    return '';
  }

  Set<int> _renderedLocationMessageIds() {
    return _messages
        .where((message) => !message.isSystem && message.locationMessageId > 0)
        .map((message) => message.locationMessageId)
        .toSet();
  }

  void _requestVisibleMessageGapFillIfNeeded(
    List<_LocationChatMessageGap> gaps,
    List<WorldChatroomMessage> source,
  ) {
    final service = _service;
    if (service == null || source.isEmpty || gaps.isEmpty) return;
    if (_loadingOlderMessages) {
      _deferredVisibleMessageGapFill = true;
      return;
    }
    for (final gap in gaps) {
      final key = _locationChatMessageGapKey(widget.locationId, gap);
      if (_releasedMessageGapKeys.contains(key)) continue;
      if (!_messageGapFillBeforeLocationMessageIds.add(
        gap.upperLocationMessageId,
      )) {
        continue;
      }
      if (!_messageGapFillKeys.add(key)) {
        _messageGapFillBeforeLocationMessageIds.remove(
          gap.upperLocationMessageId,
        );
        continue;
      }
      _logPanelMetric(
        'message gap fill requested location=${widget.locationId} '
        'lower=${gap.lowerLocationMessageId} '
        'upper=${gap.upperLocationMessageId}',
      );
      _recordPanelDebug(
        action: 'gapFillRequested',
        sourceMessages: source,
        details: {
          'lowerLocationMessageId': gap.lowerLocationMessageId,
          'upperLocationMessageId': gap.upperLocationMessageId,
          'missingCount': gap.missingCount,
        },
      );
      unawaited(_fillVisibleMessageGap(service: service, key: key, gap: gap));
    }
  }

  void _runDeferredVisibleMessageGapFillIfNeeded() {
    if (!_deferredVisibleMessageGapFill || _loadingOlderMessages) return;
    _deferredVisibleMessageGapFill = false;
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final renderWindow = _visibleLocationChatMessages(
      source,
      renderedLocationMessageIds: _renderedLocationMessageIds(),
      releasedGapKeys: _releasedMessageGapKeys,
      locationId: widget.locationId,
    );
    _requestVisibleMessageGapFillIfNeeded(renderWindow.gaps, source);
  }

  Future<void> _fillVisibleMessageGap({
    required WorldChatroomService service,
    required String key,
    required _LocationChatMessageGap gap,
  }) async {
    try {
      for (
        var attempt = 1;
        attempt <= _locationChatMessageGapMaxAttempts;
        attempt += 1
      ) {
        _messageGapFillAttempts[key] = attempt;
        try {
          if (_isLocationChatMessageGapFilled(
            service.state.messagesByLocation[widget.locationId] ??
                const <WorldChatroomMessage>[],
            gap,
          )) {
            _messageGapFillKeys.remove(key);
            _messageGapFillAttempts.remove(key);
            return;
          }
          await service.loadOlderMessages(
            locationId: widget.locationId,
            beforeMessageId: gap.upperLocationMessageId,
            limit: math.min(100, gap.missingCount + 1),
          );
          if (_isLocationChatMessageGapFilled(
            service.state.messagesByLocation[widget.locationId] ??
                const <WorldChatroomMessage>[],
            gap,
          )) {
            _messageGapFillKeys.remove(key);
            _messageGapFillAttempts.remove(key);
            return;
          }
        } catch (error) {
          _logPanelMetric(
            'message gap fill failed location=${widget.locationId} '
            'lower=${gap.lowerLocationMessageId} '
            'upper=${gap.upperLocationMessageId} '
            'attempt=$attempt error=$error',
          );
          _recordPanelDebug(
            action: 'gapFillFailed',
            details: {
              'lowerLocationMessageId': gap.lowerLocationMessageId,
              'upperLocationMessageId': gap.upperLocationMessageId,
              'attempt': attempt,
              'error': '$error',
            },
          );
        }
      }
    } finally {
      _messageGapFillBeforeLocationMessageIds.remove(
        gap.upperLocationMessageId,
      );
    }
    _releasedMessageGapKeys.add(key);
    _messageGapFillKeys.remove(key);
    _messageGapFillAttempts.remove(key);
    _recordPanelDebug(
      action: 'gapFillReleased',
      details: {
        'lowerLocationMessageId': gap.lowerLocationMessageId,
        'upperLocationMessageId': gap.upperLocationMessageId,
        'attempts': _locationChatMessageGapMaxAttempts,
      },
    );
    if (!mounted) return;
    final changed = _reconcileMessages(
      _chatroomState.messagesByLocation[widget.locationId] ??
          const <WorldChatroomMessage>[],
    );
    if (changed && mounted) {
      setState(() {});
    }
  }

  ChatMessageVm? _matchingPendingSelfMessage(
    List<ChatMessageVm> previous,
    WorldChatroomMessage message, {
    required Set<String> usedLocalIds,
  }) {
    final content = _locationChatMessageDisplayText(message).trim();
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
    return _locationChatMessageLocalId(message);
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
    final avatarUrl = _resolvedProfileAvatar(
      userInfo ?? const <String, dynamic>{},
      '',
    );
    final avatarChanged = avatarUrl != _myAvatarUrl;
    _myAvatarUrl = avatarUrl;
    final changed =
        _rememberMyUserId(uid) | _rememberMyUserId(cachedUid) | avatarChanged;
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
    if (!isChatroomUnauthorizedFailure(failure)) return;
    unawaited(_handleUnauthorizedFailure());
  }

  Future<void> _handleUnauthorizedFailure() async {
    if (_handlingUnauthorizedFailure || !mounted) return;
    _handlingUnauthorizedFailure = true;
    try {
      final services = AppServicesScope.read(context);
      final previousService = _service;
      final ownedPreviousService = _ownsService;
      await _closeChatroom();
      if (!ownedPreviousService && previousService != null) {
        try {
          await previousService.disconnect();
        } catch (_) {}
      }
      await services.sessionStore.clearUid();
      services.notifySessionChanged();
      try {
        await services.identityAuth.signOutIdentity();
      } catch (error) {
        debugPrint(
          '[Auth][ChatroomUnauthorized] identity sign out failed: $error',
        );
      }
      if (!mounted) return;
      final loggedIn = await ensureGenesisLogin(context);
      if (!mounted) return;
      if (!loggedIn) {
        final onBack = widget.onBack;
        if (onBack != null) {
          onBack();
        } else {
          await Navigator.of(context).maybePop();
        }
        return;
      }
      if (!ownedPreviousService && previousService != null) {
        _service = previousService;
        _ownsService = false;
        _attachService(previousService);
        await _connectFallbackAndJoin(previousService, services);
      } else {
        _prepareConnection();
      }
    } finally {
      _handlingUnauthorizedFailure = false;
    }
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
    final text = normalizeGenesisUgcTextForDisplay(_textController.text);
    if (isGenesisUgcTextBlank(text)) return;

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
    _recordPanelDebug(
      action: 'optimisticSend',
      details: {
        'clientMsgId': clientMsgId,
        'vm': LocationChatDebugSlice.debugRenderMessage(localMessage),
      },
    );
    _scrollToBottom();

    await _submitLocalMessage(
      service: service,
      localMessage: localMessage,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> _retryFailedMessage(ChatMessageVm message) async {
    final service = _service;
    if (!message.isMe ||
        message.status != 'failed' ||
        service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _awaitingAiResponse ||
        _sending) {
      return;
    }

    final clientMsgId = _nextClientMsgId();
    setState(() {
      message.clientMsgId = clientMsgId;
      message.status = 'sending';
      message.error = null;
      _sending = true;
      _awaitingAiResponse = true;
      _awaitingAiResponseRoundId = '';
    });
    _recordPanelDebug(
      action: 'retrySend',
      details: {'clientMsgId': clientMsgId, 'localId': message.localId},
    );

    await _submitLocalMessage(
      service: service,
      localMessage: message,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> _submitLocalMessage({
    required WorldChatroomService service,
    required ChatMessageVm localMessage,
    required String clientMsgId,
  }) async {
    try {
      final ack = await service.sendMessage(
        localMessage.text,
        clientMsgId: clientMsgId,
      );
      if (!mounted) return;
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'location_chat_send_message',
        object1: widget.worldId,
        object2: widget.locationId,
        object3: ack.messageId,
      );
      unawaited(_markRecentWorldChatLocation());
      setState(() {
        localMessage.globalMessageId = ack.globalMessageId;
        localMessage.messageId = ack.messageId;
        localMessage.locationMessageId = ack.locationMessageId;
        localMessage.roundId = ack.conversationRoundId;
        localMessage.status = 'sent';
        _awaitingAiResponseRoundId = ack.conversationRoundId.trim();
        _sending = false;
      });
      _recordPanelDebug(
        action: 'sendAck',
        details: {
          'clientMsgId': clientMsgId,
          'globalMessageId': ack.globalMessageId,
          'messageId': ack.messageId,
          'locationMessageId': ack.locationMessageId,
          'roundId': ack.conversationRoundId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
        failure: e,
        localMessage: localMessage,
        messages: _messages,
        activeSendFailure: true,
      );
      setState(() {
        if (restoredDraft != null) {
          _hasDraftText = restoredDraft.trim().isNotEmpty;
          _textController.value = TextEditingValue(
            text: restoredDraft,
            selection: TextSelection.collapsed(offset: restoredDraft.length),
          );
        } else {
          localMessage.status = 'failed';
          localMessage.error = e.toString();
        }
        _awaitingAiResponse = false;
        _awaitingAiResponseRoundId = '';
        _sending = false;
      });
      if (restoredDraft != null && _shouldShowDraftRestoreToast(e)) {
        showGenesisToast(
          context,
          _locationChatDraftRestoreToastMessage(e),
          duration: const Duration(seconds: 4),
        );
      }
      _recordPanelDebug(
        action: 'sendFailed',
        details: {'clientMsgId': clientMsgId, 'error': '$e'},
      );
    }
  }

  Future<void> _markRecentWorldChatLocation() async {
    final uid = await resolveRecentWorldChatUid(AppServicesScope.read(context));
    await recentWorldChatStore.markRecentChat(
      uid: uid,
      worldId: widget.worldId,
      locationId: widget.locationId,
      locationPathIds: widget.recentChatLocationPathIds,
    );
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

  bool _syncHasMoreOlderMessagesForSource(List<WorldChatroomMessage> source) {
    final hasOlderCursor = _oldestLocationMessageId(source) > 0;
    if (!hasOlderCursor && source.isNotEmpty) {
      _olderMessagesExhaustedByCursorlessContent = true;
    }
    final nextHasMoreOlder =
        hasOlderCursor &&
        !_olderMessagesExhaustedByRemote &&
        !_olderMessagesExhaustedByCursorlessContent;
    if (_hasMoreOlderMessages == nextHasMoreOlder) return false;
    _hasMoreOlderMessages = nextHasMoreOlder;
    return true;
  }

  void _handleMessageListScroll() {
    if (!_scrollController.hasClients) return;
    if (_initialBottomScrollPending &&
        _initialBottomScrollDidJump &&
        _messages.isNotEmpty &&
        !_isAtBottom()) {
      _initialBottomScrollPending = false;
      _initialBottomScrollShouldComplete = false;
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
    if (position.extentBefore > 180) return;
    unawaited(_loadOlderMessages());
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlderMessages) return;
    final service = _service;
    if (service == null) return;
    final beforeLocationMessageId = _earliestLoadedLocationMessageId();
    if (beforeLocationMessageId <= 0) {
      _hasMoreOlderMessages = false;
      return;
    }
    setState(() {
      _loadingOlderMessages = true;
      _loadingOlderBeforeLocationMessageId = beforeLocationMessageId;
    });
    _recordPanelDebug(
      action: 'loadOlderStart',
      details: {'beforeLocationMessageId': beforeLocationMessageId},
    );
    try {
      final page = await service.loadOlderMessages(
        locationId: widget.locationId,
        beforeMessageId: beforeLocationMessageId,
        limit: 20,
      );
      _olderMessagesExhaustedByRemote = !page.hasMore;
      _hasMoreOlderMessages = page.hasMore;
      if (page.loadedCount > 0 && mounted) {
        _syncFromServiceState(service);
      }
      if (page.loadedCount > 0 &&
          mounted &&
          _loadingOlderMessages &&
          !_olderLoadHasRenderedNewMessages()) {
        setState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      }
      _recordPanelDebug(
        action: 'loadOlderDone',
        details: {
          'beforeLocationMessageId': beforeLocationMessageId,
          'loadedCount': page.loadedCount,
          'hasMore': page.hasMore,
        },
      );
      if (page.loadedCount <= 0 && mounted) {
        setState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      } else if (page.loadedCount <= 0) {
        _finishOlderMessagesLoading();
      }
    } catch (error) {
      _recordPanelDebug(
        action: 'loadOlderFailed',
        details: {
          'beforeLocationMessageId': beforeLocationMessageId,
          'error': '$error',
        },
      );
      // Up-scroll history loading is opportunistic; connection failures are
      // surfaced by the chatroom service failure stream when appropriate.
      if (mounted) {
        setState(() {
          _finishOlderMessagesLoading();
        });
        _runDeferredVisibleMessageGapFillIfNeeded();
      } else {
        _finishOlderMessagesLoading();
      }
    }
  }

  bool _olderLoadHasRenderedNewMessages() {
    if (!_loadingOlderMessages || _loadingOlderBeforeLocationMessageId <= 0) {
      return false;
    }
    final oldestRenderedLocationMessageId = _oldestRenderedLocationMessageId();
    return oldestRenderedLocationMessageId > 0 &&
        oldestRenderedLocationMessageId < _loadingOlderBeforeLocationMessageId;
  }

  int _oldestRenderedLocationMessageId() {
    var oldest = 0;
    for (final message in _messages) {
      if (message.isSystem || message.locationMessageId <= 0) continue;
      if (oldest == 0 || message.locationMessageId < oldest) {
        oldest = message.locationMessageId;
      }
    }
    return oldest;
  }

  void _finishOlderMessagesLoading() {
    _loadingOlderMessages = false;
    _loadingOlderBeforeLocationMessageId = 0;
  }

  int _earliestLoadedLocationMessageId() {
    var earliest = 0;
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    for (final message in source) {
      final messageId = message.locationMessageId > 0
          ? message.locationMessageId
          : message.messageId;
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
    if (message.locationMessageId > 0) {
      return 'location:${message.locationId}:${message.locationMessageId}';
    }
    if (message.locationId.trim().isEmpty && message.messageId > 0) {
      return 'message:${message.messageId}';
    }
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
    _serviceGeneration++;
    _service = null;
    _sending = false;
    _joinedLocation = false;
    _awaitingAiResponse = false;
    _awaitingAiResponseRoundId = '';

    await _stateSubscription?.cancel();
    await _failuresSubscription?.cancel();
    await _balanceAlertSubscription?.cancel();
    _stateSubscription = null;
    _failuresSubscription = null;
    _balanceAlertSubscription = null;

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

  void _startInitialBottomScroll() {
    _initialBottomScrollPending = true;
    _initialBottomScrollShouldComplete = false;
    _initialBottomScrollDidJump = false;
    _recordPanelDebug(action: 'initialBottomScrollStart');
    _scheduleInitialBottomScroll(complete: _messages.isNotEmpty);
  }

  void _scheduleInitialBottomScroll({required bool complete}) {
    if (!_initialBottomScrollPending) return;
    _initialBottomScrollShouldComplete =
        _initialBottomScrollShouldComplete || complete;
    if (_initialBottomScrollScheduled) return;
    _initialBottomScrollScheduled = true;
    _recordPanelDebug(
      action: 'initialBottomScrollScheduled',
      details: {'complete': complete},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialBottomScrollScheduled = false;
      if (!mounted || !_initialBottomScrollPending) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_bottomScrollOffset());
      _initialBottomScrollDidJump = true;
      _recordPanelDebug(action: 'initialBottomScrollJump');
      final shouldComplete = _initialBottomScrollShouldComplete;
      _initialBottomScrollShouldComplete = false;
      if (!shouldComplete || _messages.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_initialBottomScrollPending) return;
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_bottomScrollOffset());
        _initialBottomScrollPending = false;
        _initialBottomScrollDidJump = false;
        _recordPanelDebug(action: 'initialBottomScrollComplete');
      });
    });
  }

  void _scrollToBottom({bool jump = false}) {
    _recordPanelDebug(
      action: 'scrollToBottomScheduled',
      details: {'jump': jump},
    );
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
    _recordPanelDebug(action: 'forceScrollToBottom');
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
    _recordPanelDebug(action: 'composerFocusBottomPinStart');
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_bottomScrollOffset());
    }
    _scheduleComposerFocusBottomPin();
  }

  void _deactivateComposerFocusBottomPin() {
    _composerFocusBottomPinActive = false;
    _recordPanelDebug(action: 'composerFocusBottomPinStop');
  }

  void _scheduleComposerFocusBottomPin() {
    if (!_composerFocusBottomPinActive) return;
    if (_composerFocusBottomScheduled) return;
    _composerFocusBottomScheduled = true;
    _recordPanelDebug(action: 'composerFocusBottomPinScheduled');
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
    _recordPanelDebug(action: 'keepBottomAfterLayoutScheduled');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepBottomAfterLayoutScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_bottomScrollOffset());
      _recordPanelDebug(action: 'keepBottomAfterLayoutJump');
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
    return locationChatMessageReportTargetIdForTesting(message);
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
      alignContentLeft: true,
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      showSubtitle: widget.showConnectionStatus && aiRoleNames.isNotEmpty,
      showMoreButton: widget.showMoreButton,
      trailing: widget.active
          ? MemoryModelEntryButton(
              modelLabel: _selectedModelCode.isEmpty
                  ? 'Model'
                  : _selectedModelCode,
              darkHeader: true,
              onTap: () => unawaited(_openMemoryModelPage()),
            )
          : null,
      style: style,
    );
    final headerHeight = _locationChatHeaderHeight(style);
    final composerHeight = _locationChatComposerHeight(style);
    final listStyle = style.copyWith(
      messageListPadding: _locationChatMessageListPadding(
        style,
        headerHeight: headerHeight,
        composerHeight: composerHeight,
      ),
    );
    final messageList = ChatAnchoredMessageList(
      key: const ValueKey<String>('location-chat-message-list'),
      controller: _scrollController,
      messages: _messages,
      centerLocalId: _scrollCenterLocalId,
      topTitle: '',
      oldestEdgeNotice: _shouldShowOldestEdgeNotice()
          ? kAiContentDisclaimerText
          : null,
      oldestEdgeLoading: _loadingOlderMessages,
      onMessageLongPressStart: _showMessageActionMenu,
      onFailedMessageTap: (message) => unawaited(_retryFailedMessage(message)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            bottom: composerHeight + 12,
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

  bool _shouldShowOldestEdgeNotice() {
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    return shouldShowLocationChatOldestEdgeNoticeForTesting(
      source,
      renderedLocationMessageIds: _renderedLocationMessageIds(),
      releasedGapKeys: _releasedMessageGapKeys,
      locationId: widget.locationId,
      hasMoreOlderMessages: _hasMoreOlderMessages,
      loadingOlderMessages: _loadingOlderMessages,
      hasPendingGapFill: _messageGapFillKeys.isNotEmpty,
    );
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

  EdgeInsets _locationChatMessageListPadding(
    ChatUiStyleConfig style, {
    required double headerHeight,
    required double composerHeight,
  }) {
    return style.messageListPadding.copyWith(
      top: style.messageListPadding.top + headerHeight,
      bottom: style.messageListPadding.bottom + composerHeight,
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
            final url = _resolveLocationChatBackgroundUrl(
              imageUrl,
              previewImageUrl: previewImageUrl,
              logicalWidth: constraints.maxWidth,
              logicalHeight: constraints.maxHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            return _LocationChatBackgroundImage(url: url);
          },
        ),
      ),
    );
  }
}

String _resolveLocationChatBackgroundUrl(
  Object? imageUrl, {
  Object? previewImageUrl,
  required double? logicalWidth,
  required double? logicalHeight,
  required double devicePixelRatio,
}) {
  final selected = selectGenesisImageUrl(
    imageUrl,
    fallback: previewImageUrl,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  );
  final resolved = resolveAssetUrl(selected);
  if (resolved.isNotEmpty) return resolved;
  return _locationChatDefaultBackgroundAsset;
}

class _LocationChatBackgroundImage extends StatelessWidget {
  const _LocationChatBackgroundImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = url.trim();
    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.expand();
        },
      );
    }
    return GenesisStaticNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (_) => const SizedBox.expand(),
      errorWidget: (_, _) => const SizedBox.expand(),
    );
  }
}

@visibleForTesting
String resolveLocationChatBackgroundUrlForTesting({
  Object? imageUrl,
  Object? previewImageUrl,
  double logicalWidth = 390,
  double logicalHeight = 844,
  double devicePixelRatio = 1,
}) {
  return _resolveLocationChatBackgroundUrl(
    imageUrl,
    previewImageUrl: previewImageUrl,
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  );
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
String locationChatMessageReportTargetIdForTesting(ChatMessageVm message) {
  final globalMessageId = message.globalMessageId;
  if (globalMessageId > 0) return '$globalMessageId';
  return '';
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

@visibleForTesting
String locationChatMessageLocalIdForTesting(WorldChatroomMessage message) {
  return _locationChatMessageLocalId(message);
}

String _locationChatMessageLocalId(WorldChatroomMessage message) {
  if (message.locationMessageId > 0) {
    return 'location-${message.locationId}-${message.locationMessageId}';
  }
  return 'stream-${message.locationId}-${message.conversationRoundId}-${message.senderId}';
}

String _locationChatMessageDisplayText(WorldChatroomMessage message) {
  if (message.isLlmStreamMessage) {
    return decodeLlmStreamTextForDisplay(
      message.content,
      isStreaming: message.streaming,
    );
  }
  final senderType = message.senderType.trim().toLowerCase();
  if (senderType.isEmpty || senderType == 'user') {
    return decodeGenesisUgcTextForDisplay(message.content);
  }
  return normalizeGenesisUgcTextForDisplay(message.content);
}

@visibleForTesting
String locationChatMessageDisplayTextForTesting(WorldChatroomMessage message) {
  return _locationChatMessageDisplayText(message);
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
  return _visibleLocationChatMessages(source).messages;
}

@visibleForTesting
List<WorldChatroomMessage> visibleLocationChatMessagesWithRenderedIdsForTesting(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = 'loc-1',
}) {
  return _visibleLocationChatMessages(
    source,
    renderedLocationMessageIds: renderedLocationMessageIds,
    releasedGapKeys: releasedGapKeys,
    locationId: locationId,
  ).messages;
}

@visibleForTesting
int locationChatMessageGapFillCursorForTesting(
  List<WorldChatroomMessage> source,
) {
  return _visibleLocationChatMessages(source).gapFillBeforeLocationMessageId;
}

@visibleForTesting
bool shouldShowLocationChatOldestEdgeNoticeForTesting(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = 'loc-1',
  bool hasMoreOlderMessages = false,
  bool loadingOlderMessages = false,
  bool hasPendingGapFill = false,
}) {
  if (hasMoreOlderMessages || loadingOlderMessages || hasPendingGapFill) {
    return false;
  }
  final renderWindow = _visibleLocationChatMessages(
    source,
    renderedLocationMessageIds: renderedLocationMessageIds,
    releasedGapKeys: releasedGapKeys,
    locationId: locationId,
  );
  if (renderWindow.gaps.isNotEmpty) return false;
  return _visibleWindowContainsOldestLocationMessage(
    source: source,
    visible: renderWindow.messages,
  );
}

_VisibleLocationChatMessages _visibleLocationChatMessages(
  List<WorldChatroomMessage> source, {
  Set<int> renderedLocationMessageIds = const <int>{},
  Set<String> releasedGapKeys = const <String>{},
  String locationId = '',
}) {
  if (source.length < 2) {
    return _VisibleLocationChatMessages(
      messages: source,
      gapFillBeforeLocationMessageId: 0,
      gaps: const <_LocationChatMessageGap>[],
    );
  }
  final sorted = source.toList(growable: false)
    ..sort(_compareLocationChatRenderMessages);
  final locationMessages = sorted
      .where(
        (message) =>
            !_isTickAdvanceMessage(message) && message.locationMessageId > 0,
      )
      .toList(growable: false);
  if (locationMessages.isEmpty) {
    return _VisibleLocationChatMessages(
      messages: _collapseConsecutiveTickMessages(sorted),
      gapFillBeforeLocationMessageId: 0,
      gaps: const <_LocationChatMessageGap>[],
    );
  }

  final locationIds =
      locationMessages
          .map((message) => message.locationMessageId)
          .toSet()
          .toList(growable: false)
        ..sort();
  final visibleLocationMessageIds = renderedLocationMessageIds
      .where(locationIds.contains)
      .toSet();
  final gaps = <_LocationChatMessageGap>[];

  if (visibleLocationMessageIds.isEmpty) {
    var expectedLocationMessageId = locationMessages.last.locationMessageId;
    for (final message in locationMessages.reversed) {
      final locationMessageId = message.locationMessageId;
      if (locationMessageId == expectedLocationMessageId) {
        visibleLocationMessageIds.add(locationMessageId);
        expectedLocationMessageId -= 1;
        continue;
      }
      if (locationMessageId < expectedLocationMessageId) {
        final gap = _LocationChatMessageGap(
          lowerLocationMessageId: locationMessageId,
          upperLocationMessageId: expectedLocationMessageId + 1,
        );
        if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
          visibleLocationMessageIds.add(locationMessageId);
          expectedLocationMessageId = locationMessageId - 1;
          continue;
        }
        gaps.add(gap);
        break;
      }
    }
  } else {
    _includeVisibleLocationIdsInsideRenderedSpan(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
    );
    _expandVisibleLocationIdsAcrossGaps(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
      gaps: gaps,
      releasedGapKeys: releasedGapKeys,
      locationId: locationId,
      forward: true,
    );
    _expandVisibleLocationIdsAcrossGaps(
      locationIds: locationIds,
      visibleLocationMessageIds: visibleLocationMessageIds,
      gaps: gaps,
      releasedGapKeys: releasedGapKeys,
      locationId: locationId,
      forward: false,
    );
  }

  final visibleLocationMessages = locationMessages
      .where(
        (message) =>
            visibleLocationMessageIds.contains(message.locationMessageId),
      )
      .toList(growable: false);
  if (visibleLocationMessages.isEmpty) {
    return const _VisibleLocationChatMessages(
      messages: <WorldChatroomMessage>[],
      gapFillBeforeLocationMessageId: 0,
      gaps: <_LocationChatMessageGap>[],
    );
  }
  final visible = _visibleLocationChatMessagesWithTicks(
    sorted: sorted,
    visibleLocationMessageIds: visibleLocationMessageIds,
  );
  return _VisibleLocationChatMessages(
    messages: visible,
    gapFillBeforeLocationMessageId: gaps.isEmpty
        ? 0
        : gaps.first.upperLocationMessageId,
    gaps: gaps,
  );
}

List<WorldChatroomMessage> _visibleLocationChatMessagesWithTicks({
  required List<WorldChatroomMessage> sorted,
  required Set<int> visibleLocationMessageIds,
}) {
  final visible = <WorldChatroomMessage>[];
  final leadingCursorlessMessages = <WorldChatroomMessage>[];
  var seenLocationMessage = false;
  var seenVisibleLocationMessage = false;
  var blockedByHiddenLocationAfterVisible = false;

  for (final message in sorted) {
    if (_isTickAdvanceMessage(message)) {
      if (seenVisibleLocationMessage && !blockedByHiddenLocationAfterVisible) {
        visible.add(message);
      } else if (!seenLocationMessage) {
        leadingCursorlessMessages.add(message);
      }
      continue;
    }

    if (message.locationMessageId <= 0) {
      if (!seenLocationMessage) {
        leadingCursorlessMessages.add(message);
      }
      continue;
    }

    final messageIsVisible = visibleLocationMessageIds.contains(
      message.locationMessageId,
    );
    if (messageIsVisible) {
      if (!seenVisibleLocationMessage && !seenLocationMessage) {
        visible.addAll(leadingCursorlessMessages);
      }
      visible.add(message);
      seenVisibleLocationMessage = true;
      blockedByHiddenLocationAfterVisible = false;
    } else {
      if (seenVisibleLocationMessage) {
        blockedByHiddenLocationAfterVisible = true;
      }
      leadingCursorlessMessages.clear();
    }
    seenLocationMessage = true;
  }

  return _collapseConsecutiveTickMessages(visible);
}

List<WorldChatroomMessage> _collapseConsecutiveTickMessages(
  List<WorldChatroomMessage> messages,
) {
  if (messages.length < 2) return messages;
  final collapsed = <WorldChatroomMessage>[];
  for (final message in messages) {
    if (_isTickAdvanceMessage(message) &&
        collapsed.isNotEmpty &&
        _isTickAdvanceMessage(collapsed.last)) {
      collapsed[collapsed.length - 1] = message;
      continue;
    }
    collapsed.add(message);
  }
  return collapsed;
}

bool _visibleWindowContainsOldestLocationMessage({
  required List<WorldChatroomMessage> source,
  required List<WorldChatroomMessage> visible,
}) {
  final oldestLocationMessageId = _oldestLocationMessageId(source);
  if (oldestLocationMessageId <= 0) return true;
  for (final message in visible) {
    if (message.locationMessageId == oldestLocationMessageId) return true;
  }
  return false;
}

int _oldestLocationMessageId(List<WorldChatroomMessage> messages) {
  var oldest = 0;
  for (final message in messages) {
    if (_isTickAdvanceMessage(message) || message.locationMessageId <= 0) {
      continue;
    }
    if (oldest == 0 || message.locationMessageId < oldest) {
      oldest = message.locationMessageId;
    }
  }
  return oldest;
}

void _includeVisibleLocationIdsInsideRenderedSpan({
  required List<int> locationIds,
  required Set<int> visibleLocationMessageIds,
}) {
  if (visibleLocationMessageIds.isEmpty) return;
  final minRendered = visibleLocationMessageIds.reduce(math.min);
  final maxRendered = visibleLocationMessageIds.reduce(math.max);
  for (final id in locationIds) {
    if (id < minRendered) continue;
    if (id > maxRendered) break;
    visibleLocationMessageIds.add(id);
  }
}

void _expandVisibleLocationIdsAcrossGaps({
  required List<int> locationIds,
  required Set<int> visibleLocationMessageIds,
  required List<_LocationChatMessageGap> gaps,
  required Set<String> releasedGapKeys,
  required String locationId,
  required bool forward,
}) {
  if (visibleLocationMessageIds.isEmpty) return;
  if (forward) {
    var expected = visibleLocationMessageIds.reduce(math.max) + 1;
    for (final id in locationIds.where((id) => id >= expected)) {
      if (id == expected) {
        visibleLocationMessageIds.add(id);
        expected += 1;
        continue;
      }
      final gap = _LocationChatMessageGap(
        lowerLocationMessageId: expected - 1,
        upperLocationMessageId: id,
      );
      if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
        visibleLocationMessageIds.add(id);
        expected = id + 1;
        continue;
      }
      gaps.add(gap);
      return;
    }
    return;
  }

  var expected = visibleLocationMessageIds.reduce(math.min) - 1;
  for (final id in locationIds.reversed.where((id) => id <= expected)) {
    if (id == expected) {
      visibleLocationMessageIds.add(id);
      expected -= 1;
      continue;
    }
    final gap = _LocationChatMessageGap(
      lowerLocationMessageId: id,
      upperLocationMessageId: expected + 1,
    );
    if (_locationChatGapIsReleased(locationId, gap, releasedGapKeys)) {
      visibleLocationMessageIds.add(id);
      expected = id - 1;
      continue;
    }
    gaps.add(gap);
    return;
  }
}

bool _locationChatGapIsReleased(
  String locationId,
  _LocationChatMessageGap gap,
  Set<String> releasedGapKeys,
) {
  return releasedGapKeys.contains(_locationChatMessageGapKey(locationId, gap));
}

bool _isLocationChatMessageGapFilled(
  List<WorldChatroomMessage> messages,
  _LocationChatMessageGap gap,
) {
  final ids = messages
      .where(
        (message) =>
            !_isTickAdvanceMessage(message) && message.locationMessageId > 0,
      )
      .map((message) => message.locationMessageId)
      .toSet();
  for (
    var id = gap.lowerLocationMessageId + 1;
    id < gap.upperLocationMessageId;
    id += 1
  ) {
    if (!ids.contains(id)) return false;
  }
  return true;
}

String _locationChatMessageGapKey(
  String locationId,
  _LocationChatMessageGap gap,
) {
  return '${locationId.trim()}\u001F${gap.lowerLocationMessageId}\u001F${gap.upperLocationMessageId}';
}

bool _isTickAdvanceMessage(WorldChatroomMessage message) {
  return message.senderType.trim().toLowerCase() == 'tick';
}

int _compareLocationChatRenderMessages(
  WorldChatroomMessage a,
  WorldChatroomMessage b,
) {
  final byMessageId = a.messageId.compareTo(b.messageId);
  if (byMessageId != 0) return byMessageId;
  final byLocationMessageId = a.locationMessageId.compareTo(
    b.locationMessageId,
  );
  if (byLocationMessageId != 0) return byLocationMessageId;
  final byRound = a.conversationRoundNumber.compareTo(
    b.conversationRoundNumber,
  );
  if (byRound != 0) return byRound;
  return a.roundOrder.compareTo(b.roundOrder);
}

class _VisibleLocationChatMessages {
  const _VisibleLocationChatMessages({
    required this.messages,
    required this.gapFillBeforeLocationMessageId,
    required this.gaps,
  });

  final List<WorldChatroomMessage> messages;
  final int gapFillBeforeLocationMessageId;
  final List<_LocationChatMessageGap> gaps;
}

class _LocationChatMessageGap {
  const _LocationChatMessageGap({
    required this.lowerLocationMessageId,
    required this.upperLocationMessageId,
  });

  final int lowerLocationMessageId;
  final int upperLocationMessageId;

  int get missingCount => upperLocationMessageId - lowerLocationMessageId - 1;
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
