import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../utils/display_name_formatter.dart';

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
  final WorldChatroomService? service;
  final ChatroomConnectionController? connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatUiStyleConfig.standard.conversationBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: LocationChatPanel(
        worldId: worldId,
        locationId: locationId,
        isLeafLocation: isLeafLocation,
        localMessageLocationIds: localMessageLocationIds,
        worldName: worldName,
        locationName: locationName,
        backgroundImageUrl: backgroundImageUrl,
        service: service,
        connection: connection,
        active: true,
        onBack: () => Navigator.of(context).maybePop(),
      ),
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
    this.service,
    this.connection,
    this.active = true,
    this.leaveOnInactive = true,
    this.onBack,
    this.onInitialContentReady,
    this.composerReplacement,
    this.showConnectionStatus = true,
    this.systemUiOverlayStyle = kGenesisDefaultSystemUiOverlayStyle,
    this.style,
  });

  final String worldId;
  final String locationId;
  final bool isLeafLocation;
  final List<String> localMessageLocationIds;
  final String? worldName;
  final String? locationName;
  final String? backgroundImageUrl;
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

  @override
  State<LocationChatPanel> createState() => _LocationChatPanelState();
}

class _LocationChatPanelState extends State<LocationChatPanel>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final Stopwatch _panelStopwatch = Stopwatch()..start();
  final _messages = <ChatMessageVm>[];

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
  late String _backgroundImageUrl;
  bool _ownsService = false;
  bool _joinedLocation = false;
  bool _sending = false;
  bool _loadingOlderMessages = false;
  bool _hasMoreOlderMessages = true;
  bool _initialContentReadyNotified = false;
  Future<void>? _initialLatestMessagesRefresh;
  int _unseenIncomingCount = 0;
  int _clientMsgCounter = 0;

  @override
  void initState() {
    super.initState();
    _backgroundImageUrl = widget.backgroundImageUrl?.trim() ?? '';
    _logPanelMetric(
      'init active=${widget.active} leaf=${widget.isLeafLocation} '
      'aliases=${widget.localMessageLocationIds.join(',')}',
    );
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleMessageListScroll);
    _prepareConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final service = _service;
    if (_ownsService && service != null) {
      unawaited(service.disconnect().catchError((Object _) {}));
    }
    unawaited(_closeChatroom());
    _scrollController.removeListener(_handleMessageListScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBackgroundImageUrl = widget.backgroundImageUrl?.trim() ?? '';
    if (nextBackgroundImageUrl.isNotEmpty &&
        nextBackgroundImageUrl != _backgroundImageUrl) {
      _backgroundImageUrl = nextBackgroundImageUrl;
    }
    if (oldWidget.service != widget.service ||
        oldWidget.worldId != widget.worldId ||
        oldWidget.locationId != widget.locationId) {
      unawaited(
        _closeChatroom().then((_) {
          if (!mounted) return;
          _hasMoreOlderMessages = true;
          _loadingOlderMessages = false;
          _initialContentReadyNotified = false;
          _initialLatestMessagesRefresh = null;
          _prepareConnection();
        }),
      );
      return;
    }
    if (!oldWidget.active && widget.active) {
      _activateConnection();
    } else if (oldWidget.active && !widget.active) {
      unawaited(_deactivateConnection());
    }
  }

  @override
  void didChangeMetrics() {
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
      'active=${widget.active}',
    );
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

    if (!widget.active) return;
    _activateConnection();
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
    if (_messages.isNotEmpty) {
      _notifyInitialContentReady();
      return;
    }
    final existingRefresh = _initialLatestMessagesRefresh;
    if (existingRefresh != null) return;
    _logPanelMetric('initial history refresh start beforeReady');
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
          'sourceCount=${_chatroomState.messagesByLocation[widget.locationId]?.length ?? 0} '
          'vmCount=${_messages.length}',
        );
        _notifyInitialContentReady();
      }),
    );
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
    final changedMessages = _reconcileMessages(nextSource);
    setState(() {
      _chatroomState = state;
    });
    _logPanelMetric(
      'state received source ${previousSource.length}->${nextSource.length} '
      'vm $beforeVmCount->${_messages.length} changed=$changedMessages '
      'joined=${state.joinedLocationId == widget.locationId} '
      'joining=${state.joining} connected=${state.connected} '
      'reconcile=${reconcileStopwatch?.elapsedMilliseconds}ms',
    );
    if (nextSource.isNotEmpty) _notifyInitialContentReady();
    if (changedMessages &&
        previousLatestLocalId.isNotEmpty &&
        _latestMessageLocalId() != previousLatestLocalId) {
      if (wasAtBottom) {
        _clearUnseenIncomingCount();
        _scrollToBottom(jump: true);
      } else {
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

  bool _reconcileMessages(List<WorldChatroomMessage> source) {
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
      final senderName = _messageSenderDisplayName(message);
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
            existing.avatarUrl != avatarUrl ||
            existing.text != message.content ||
            existing.status != status ||
            existing.localId != localId) {
          changed = true;
        }
        existing.messageId = message.messageId;
        existing.roundId = message.conversationRoundId;
        existing.tickNo = message.tickNo;
        existing.senderName = senderName;
        existing.avatarUrl = avatarUrl;
        existing.text = message.content;
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
          avatarUrl: avatarUrl,
          text: message.content,
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

  Future<void> _send() async {
    final service = _service;
    if (service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
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
      avatarUrl: _localSelfAvatarUrl(),
      text: text,
      isMe: true,
      status: 'sending',
    );

    setState(() {
      _sending = true;
      _messages.add(localMessage);
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
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        localMessage.status = 'failed';
        localMessage.error = e.toString();
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
    if (position.maxScrollExtent - position.pixels > 180) return;
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

  String _messageSenderDisplayName(WorldChatroomMessage message) {
    return firstNonEmpty([
      _roleNameForIdentityCandidates([message.userId, message.senderId]),
      _entityNameForIdentity(message.userId),
      _entityNameForIdentity(message.senderId),
      message.senderName,
    ]);
  }

  String _messageAvatarUrl(
    WorldChatroomMessage message, {
    bool? isMe,
    String fallback = '',
  }) {
    final mine = isMe ?? _isMineMessage(message);
    return resolveLocationChatMessageAvatarForTesting(
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

  String _entityNameForIdentity(String value) {
    final key = _chatroomIdentityKey(value);
    if (key.isEmpty) return '';
    for (final entry in _chatroomState.entitiesById.entries) {
      if (_chatroomIdentityKey(entry.key) != key) continue;
      return entry.value.name;
    }
    return '';
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

  String _roleNameForIdentityCandidates(List<String?> identities) {
    final keys = identities
        .map(_chatroomIdentityKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return '';
    final world = _chatroomState.world;
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
    return _scrollController.position.pixels <= 24;
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(0);
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _keepBottomAfterLayoutIfNeeded() {
    if (!_isAtBottom()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_isAtBottom()) return;
      _scrollToBottom(jump: true);
    });
  }

  void _clearUnseenIncomingCount() {
    if (_unseenIncomingCount == 0 || !mounted) return;
    setState(() => _unseenIncomingCount = 0);
  }

  void _openUnseenIncomingMessages() {
    _clearUnseenIncomingCount();
    _scrollToBottom(jump: true);
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

  String _realUserDisplayName(WorldChatroomEntity entity) {
    return firstNonEmpty([entity.name, formatUidForDisplay(entity.id)]);
  }

  @override
  Widget build(BuildContext context) {
    final realUsers = _realUsersForCurrentLocation(_chatroomState);
    final realUserNames = realUsers
        .map(_realUserDisplayName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final title = firstNonEmpty([widget.locationName, widget.locationId]);
    final subtitle = realUserNames.join(', ');
    final joined = _chatroomState.joinedLocationId == widget.locationId;
    final connecting =
        _chatroomState.reconnecting ||
        _chatroomState.joining ||
        (_chatroomState.connected && !joined);
    final inputBlocked = _chatroomState.inputBlocked;
    final baseStyle = widget.style ?? kChatWhiteHeaderStyle;
    final style = baseStyle.copyWith(
      headerSubtitleTextStyle: baseStyle.headerSubtitleTextStyle.copyWith(
        fontSize: 12,
      ),
      headerStatusIconSize: 12,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.systemUiOverlayStyle,
      child: ColoredBox(
        color: style.conversationBackgroundColor,
        child: Column(
          children: [
            ChatHeader(
              title: '$title (${realUsers.length})',
              subtitle: subtitle,
              connected: realUsers.isNotEmpty,
              connecting: connecting && realUsers.isEmpty,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              showSubtitle:
                  widget.showConnectionStatus && realUserNames.isNotEmpty,
              style: style,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _LocationChatBackgroundImage(
                      imageUrl: _backgroundImageUrl,
                    ),
                  ),
                  Positioned.fill(
                    child: ChatMessageList(
                      controller: _scrollController,
                      messages: _messages,
                      topTitle: '',
                    ),
                  ),
                  if (_unseenIncomingCount > 0)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: _LocationChatNewMessageNotice(
                        count: _unseenIncomingCount,
                        onTap: _openUnseenIncomingMessages,
                      ),
                    ),
                ],
              ),
            ),
            widget.composerReplacement ??
                ChatComposer(
                  controller: _textController,
                  inputEnabled: widget.active,
                  sendEnabled:
                      widget.active && joined && !_sending && !inputBlocked,
                  sending: _sending,
                  onSend: _send,
                  sendLabel: 'Send',
                  onHeightChanged: (_) => _keepBottomAfterLayoutIfNeeded(),
                ),
          ],
        ),
      ),
    );
  }
}

class _LocationChatBackgroundImage extends StatelessWidget {
  const _LocationChatBackgroundImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final provider = _locationChatBackgroundProvider(imageUrl);
    if (provider == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(image: provider, fit: BoxFit.cover),
      ),
    );
  }
}

ImageProvider? _locationChatBackgroundProvider(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return null;
  return url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url);
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
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('location-chat-new-message-notice'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$count 条新消息',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
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
