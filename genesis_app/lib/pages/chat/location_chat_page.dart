import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/bootstrap/service_registry.dart';
import '../../app/debug/location_chat_debug_slice.dart';
import '../../app/recent_chat/recent_world_chat_store.dart';
import '../../app/telemetry/firebase_analytics_monitoring.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/chatroom_failure_toast.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/gems/gem_balance_prompt.dart';
import '../../components/gems/memory_model_entry_button.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/chatroom/chatroom_connection_controller.dart';
import '../../network/chatroom/chatroom_message_type.dart';
import '../../network/chatroom/chatroom_models.dart';
import '../../network/chatroom/chatroom_timeline_payload.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/world.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_static_network_image.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_ugc_text.dart';
import 'location_chat_scroll_coordinator.dart';
import 'message_parsers/location_chat_message_parsers.dart';

part 'location_chat_panel_connection.dart';
part 'location_chat_message_reconciler.dart';
part 'location_chat_send_actions.dart';
part 'location_chat_message_window.dart';
part 'location_chat_identity.dart';
part 'location_chat_panel_actions.dart';
part 'location_chat_layout.dart';
part 'location_chat_tick_progress.dart';
part 'location_chat_panel_widgets.dart';
part 'location_chat_shared.dart';

const double _locationChatAvatarLogicalSize = 40;
const double _locationChatComposerBottomExtension = 60;
const double _locationChatMaxBackgroundImageDevicePixelRatio = 2;
const double _locationChatBackgroundPreviewLogicalWidth = 120;
const Duration _locationChatBackgroundFadeDuration = Duration(
  milliseconds: 150,
);
const double _locationChatEdgeSwipeWidth = 24;
const double _locationChatEdgeSwipeTriggerDistance = 64;
const double _locationChatEdgeSwipeTriggerVelocity = 450;
const int _locationChatMessageGapMaxAttempts = 3;
const double _locationChatOlderMessagesTriggerExtent = 180;
const Duration _locationChatOlderMessagesIdleDelay = Duration(milliseconds: 80);
const String _locationChatDefaultBackgroundAsset =
    'assets/images/map_default/location_default.webp';

@visibleForTesting
Future<void> runLocationChatMetadataUpdateBestEffort(
  Future<void> Function() update,
) async {
  try {
    await update();
  } catch (error, stackTrace) {
    debugPrint('[LocationChat] metadata update failed: $error\n$stackTrace');
  }
}

@visibleForTesting
bool locationChatShouldShowAiContentDisclaimerForTesting({
  required bool initialContentReady,
  required bool hasMoreOlderMessages,
  required bool loadingOlderMessages,
}) {
  return initialContentReady && !hasMoreOlderMessages && !loadingOlderMessages;
}

class LocationChatPage extends StatefulWidget {
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
    this.renderBackgroundImage = true,
    this.service,
    this.connection,
    this.onCharactersMovedLocationTap,
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
  final bool renderBackgroundImage;
  final WorldChatroomService? service;
  final ChatroomConnectionController? connection;
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;

  @override
  State<LocationChatPage> createState() => _LocationChatPageState();
}

class _LocationChatPageState extends State<LocationChatPage> {
  bool _openingCharactersMovedLocation = false;

  Future<void> _openCharactersMovedLocation(
    ChatCharacterMovementVm movement,
  ) async {
    final targetLocationId = movement.toLocationId.trim();
    if (targetLocationId.isEmpty ||
        targetLocationId == widget.locationId.trim()) {
      return;
    }
    if (_openingCharactersMovedLocation) return;
    _openingCharactersMovedLocation = true;
    final customHandler = widget.onCharactersMovedLocationTap;
    if (customHandler != null) {
      try {
        customHandler(movement);
      } catch (error) {
        GenesisTelemetry.collectLog(
          actionType: 'event',
          action: 'location_chat_movement_navigation_failed',
          object1: widget.worldId,
          object2: targetLocationId,
        );
        if (kDebugMode) {
          debugPrint('[LocationChat] movement callback failed: $error');
        }
      } finally {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openingCharactersMovedLocation = false;
        });
      }
      return;
    }
    try {
      await Navigator.of(context).pushReplacementNamed(
        RouteNames.locationChat,
        arguments: <String, Object?>{
          'world_id': widget.worldId,
          'location_id': targetLocationId,
          'world_name': widget.worldName ?? '',
          'location_name': movement.toLocationName,
          'is_leaf_location': true,
          'local_message_location_ids': <String>[targetLocationId],
          if (widget.service != null) 'world_chatroom_service': widget.service,
          if (widget.connection != null)
            'chatroom_connection': widget.connection,
        },
      );
    } catch (error) {
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'location_chat_movement_navigation_failed',
        object1: widget.worldId,
        object2: targetLocationId,
      );
      if (kDebugMode) {
        debugPrint('[LocationChat] movement navigation failed: $error');
      }
    } finally {
      if (mounted) _openingCharactersMovedLocation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocationChatPanel(
      worldId: widget.worldId,
      locationId: widget.locationId,
      isLeafLocation: widget.isLeafLocation,
      localMessageLocationIds: widget.localMessageLocationIds,
      recentChatLocationPathIds: widget.recentChatLocationPathIds,
      worldName: widget.worldName,
      locationName: widget.locationName,
      backgroundImageUrl: widget.backgroundImageUrl,
      backgroundPreviewImageUrl: widget.backgroundPreviewImageUrl,
      renderBackgroundImage: widget.renderBackgroundImage,
      service: widget.service,
      connection: widget.connection,
      active: true,
      leaveOnInactive: widget.service == null,
      showMoreButton: false,
      onBack: () => Navigator.of(context).maybePop(),
      onCharactersMovedLocationTap: (movement) {
        unawaited(_openCharactersMovedLocation(movement));
      },
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
    this.renderBackgroundImage = true,
    this.openingPreviewMessages = const <WorldChatroomMessage>[],
    this.openingPreviewEntities = const <WorldChatroomEntity>[],
    this.service,
    this.connection,
    this.worldTickInProgress = false,
    this.worldTickProgressFailureRevision = 0,
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
    this.onCharactersMovedLocationTap,
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
  final bool renderBackgroundImage;
  final List<WorldChatroomMessage> openingPreviewMessages;
  final List<WorldChatroomEntity> openingPreviewEntities;
  final WorldChatroomService? service;
  final ChatroomConnectionController? connection;
  final bool worldTickInProgress;
  final int worldTickProgressFailureRevision;
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
  final ChatCharacterMovementTap? onCharactersMovedLocationTap;

  @override
  State<LocationChatPanel> createState() => _LocationChatPanelState();
}

class _LocationChatPanelState extends State<LocationChatPanel> {
  late final LocationChatScrollCoordinator _scrollCoordinator;
  ScrollController get _scrollController => _scrollCoordinator.controller;
  final _textController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final Stopwatch _panelStopwatch = Stopwatch()..start();
  final _messages = <ChatMessageVm>[];
  final Map<String, _LocationChatTimelineVmCacheEntry> _timelineVmCache =
      <String, _LocationChatTimelineVmCacheEntry>{};
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
  bool _hasDraftText = false;
  bool _loadingOlderMessages = false;
  Timer? _olderMessagesLoadIdleTimer;
  bool _showOlderMessagesLoading = false;
  bool _hasMoreOlderMessages = true;
  bool _olderMessagesExhaustedByRemote = false;
  bool _olderMessagesExhaustedByCursorlessContent = false;
  bool _initialContentReadyNotified = false;
  Future<void>? _initialLatestMessagesRefresh;
  final Set<String> _unseenIncomingMessageLocalIds = <String>{};
  int get _unseenIncomingCount => _unseenIncomingMessageLocalIds.length;
  int _clientMsgCounter = 0;
  final Set<String> _messageGapFillKeys = <String>{};
  final Set<int> _messageGapFillBeforeLocationMessageIds = <int>{};
  final Map<String, int> _messageGapFillAttempts = <String, int>{};
  final Set<String> _releasedMessageGapKeys = <String>{};
  bool _deferredVisibleMessageGapFill = false;
  double _edgeSwipeBackDragDistance = 0;
  bool _edgeSwipeBackTriggered = false;
  bool _openingModelPage = false;
  late bool _retainModelEntryInHeader;
  int _serviceGeneration = 0;
  int _selectedModelLoadGeneration = 0;
  ValueListenable<int>? _userInfoRevisionListenable;
  int _tickProgressGeneration = 0;
  bool _tickProgressSessionActive = false;
  bool _awaitingTickProgressMessage = false;
  String _activeTickProgressSlotId = '';
  Set<String> _tickProgressBaselineLocalIds = const <String>{};
  int _tickProgressBaselineLocationMessageId = 0;
  int _tickProgressBaselineMessageId = 0;
  DateTime _tickProgressStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, String> _tickProgressLayoutIdByMessageLocalId =
      <String, String>{};
  final ChatMessageVm _aiContentDisclaimerMessage =
      ChatMessageVm.aiContentDisclaimer();

  bool get _sendAwaitingResponse {
    final state = _service?.state ?? _chatroomState;
    return state.conversationRoundStatesByLocation.containsKey(
      widget.locationId,
    );
  }

  bool get _shouldShowAiContentDisclaimer =>
      locationChatShouldShowAiContentDisclaimerForTesting(
        initialContentReady: _initialContentReadyNotified,
        hasMoreOlderMessages: _hasMoreOlderMessages,
        loadingOlderMessages: _loadingOlderMessages,
      );

  void _setLocationChatState(VoidCallback callback) {
    setState(callback);
  }

  void _handleViewportCoordinatorChanged() {
    if (!mounted) return;
    _setLocationChatState(() {});
    _handleMessageListScroll();
  }

  @override
  void initState() {
    super.initState();
    _retainModelEntryInHeader = widget.active;
    _scrollCoordinator = LocationChatScrollCoordinator()
      ..addListener(_handleViewportCoordinatorChanged);
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
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    _textController.addListener(_handleDraftTextChanged);
    _scrollController.addListener(_handleMessageListScroll);
    _scrollCoordinator.enter();
    _prepareConnection();
    unawaited(_loadSelectedModelCodeFromCache());
  }

  @override
  void dispose() {
    _cancelOlderMessagesLoadSchedule();
    _selectedModelLoadGeneration++;
    _timelineVmCache.clear();
    _userInfoRevisionListenable?.removeListener(_handleCachedUserInfoChanged);
    _recordPanelDebug(action: 'dispose', activeOverride: false);
    final service = _service;
    if (_ownsService && service != null) {
      unawaited(service.disconnect().catchError((Object _) {}));
    }
    unawaited(_closeChatroom());
    widget.onDraftTextChanged?.call(_textController.text);
    _scrollController.removeListener(_handleMessageListScroll);
    _scrollCoordinator.removeListener(_handleViewportCoordinatorChanged);
    _scrollCoordinator.dispose();
    _composerFocusNode.removeListener(_handleComposerFocusChanged);
    _composerFocusNode.dispose();
    _textController.removeListener(_handleDraftTextChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _retainModelEntryInHeader = true;
    }
    if (oldWidget.worldId != widget.worldId ||
        (!oldWidget.active && widget.active)) {
      unawaited(_loadSelectedModelCodeFromCache());
    }
    final changedChatTarget =
        oldWidget.service != widget.service ||
        oldWidget.worldId != widget.worldId ||
        oldWidget.locationId != widget.locationId;
    final becameActive = !oldWidget.active && widget.active;
    final becameInactive = oldWidget.active && !widget.active;
    final worldTickProgressChanged =
        oldWidget.worldTickInProgress != widget.worldTickInProgress;
    final worldTickProgressFailed =
        oldWidget.worldTickProgressFailureRevision !=
        widget.worldTickProgressFailureRevision;
    final changedOpeningPreview =
        !listEquals(
          oldWidget.openingPreviewMessages,
          widget.openingPreviewMessages,
        ) ||
        !listEquals(
          oldWidget.openingPreviewEntities,
          widget.openingPreviewEntities,
        );
    if (widget.active && (changedChatTarget || becameActive)) {
      _scrollCoordinator.enter();
    } else if (becameInactive || (!widget.active && changedChatTarget)) {
      _scrollCoordinator.deactivate();
    }
    if (worldTickProgressChanged) {
      final source =
          _chatroomState.messagesByLocation[widget.locationId] ??
          const <WorldChatroomMessage>[];
      _syncTickProgressState(
        progressing: widget.worldTickInProgress || _chatroomState.inputBlocked,
        nextSource: source,
      );
    }
    if (worldTickProgressFailed) {
      _cancelTickProgressMessage();
    }
    if (becameActive &&
        !widget.worldTickInProgress &&
        !(widget.service?.state.inputBlocked ?? _chatroomState.inputBlocked)) {
      _discardStaleTickProgressMessage();
    }
    if (changedChatTarget || changedOpeningPreview) {
      _cancelOlderMessagesLoadSchedule();
      _initialContentReadyNotified = false;
      unawaited(
        _closeChatroom().then((_) {
          if (!mounted) return;
          _hasMoreOlderMessages = true;
          if (changedChatTarget) {
            _olderMessagesExhaustedByRemote = false;
            _olderMessagesExhaustedByCursorlessContent = false;
          }
          _loadingOlderMessages = false;
          _showOlderMessagesLoading = false;
          _initialContentReadyNotified = false;
          _initialLatestMessagesRefresh = null;
          _messageGapFillKeys.clear();
          _messageGapFillBeforeLocationMessageIds.clear();
          _messageGapFillAttempts.clear();
          _releasedMessageGapKeys.clear();
          _deferredVisibleMessageGapFill = false;
          _prepareConnection();
        }),
      );
      return;
    }
    if (becameActive) {
      _activateConnection();
    } else if (becameInactive) {
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
    _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
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
                !_sendAwaitingResponse &&
                !inputBlocked,
            sending: false,
            onSend: _send,
            sendLabel: 'Send',
            style: style,
            onHeightChanged: _handleComposerHeightChanged,
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
      trailing: _retainModelEntryInHeader
          ? ExcludeSemantics(
              excluding: !widget.active,
              child: IgnorePointer(
                ignoring: !widget.active,
                child: MemoryModelEntryButton(
                  modelLabel: _selectedModelCode.isEmpty
                      ? 'Model'
                      : _selectedModelCode,
                  darkHeader: true,
                  compact: true,
                  onTap: () => unawaited(_openMemoryModelPage()),
                ),
              ),
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
    final displayMessages = _locationChatDisplayMessages();
    final messageList = LocationChatAnchoredMessageList(
      key: const ValueKey<String>('location-chat-message-list'),
      coordinator: _scrollCoordinator,
      messages: displayMessages,
      messageLayoutId: _locationChatMessageLayoutId,
      topTitle: '',
      oldestEdgeLoading: _showOlderMessagesLoading,
      onOldestEdgeLoadingCollapsed: _handleOlderMessagesLoadingCollapsed,
      onMessageLongPressStart: _showMessageActionMenu,
      onFailedMessageTap: (message) => unawaited(_retryFailedMessage(message)),
      onCharactersMovedLocationTap: widget.onCharactersMovedLocationTap == null
          ? null
          : (movement) {
              final targetLocationId = movement.toLocationId.trim();
              if (targetLocationId.isEmpty ||
                  targetLocationId == widget.locationId.trim()) {
                return;
              }
              widget.onCharactersMovedLocationTap!(movement);
            },
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
                enabled: widget.renderBackgroundImage,
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
                                _scrollCoordinator.handleScrollNotification,
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
