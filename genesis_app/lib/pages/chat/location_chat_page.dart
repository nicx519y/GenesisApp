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
import '../../network/chatroom/chatroom_message_type.dart';
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

part 'location_chat_panel_connection.dart';
part 'location_chat_message_reconciler.dart';
part 'location_chat_send_actions.dart';
part 'location_chat_message_window.dart';
part 'location_chat_identity.dart';
part 'location_chat_scroll_actions.dart';
part 'location_chat_layout.dart';
part 'location_chat_panel_widgets.dart';
part 'location_chat_shared.dart';

const double _locationChatAvatarLogicalSize = 40;
const double _locationChatComposerBottomExtension = 60;
const double _locationChatEdgeSwipeWidth = 24;
const double _locationChatEdgeSwipeTriggerDistance = 64;
const double _locationChatEdgeSwipeTriggerVelocity = 450;
const int _locationChatMessageGapMaxAttempts = 3;
const String _locationChatDefaultBackgroundAsset =
    'assets/images/map_default/location_default.webp';

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
  bool _joiningLocation = false;
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

  void _setLocationChatState(VoidCallback callback) {
    setState(callback);
  }

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
}
