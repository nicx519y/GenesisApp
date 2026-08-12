part of 'location_chat_page.dart';

extension _LocationChatPanelConnection on _LocationChatPanelState {
  Future<void> _closeChatroom() async {
    final service = _service;
    final ownsService = _ownsService;
    _serviceGeneration++;
    _service = null;
    _sending = false;
    _joinedLocation = false;

    await _stateSubscription?.cancel();
    await _failuresSubscription?.cancel();
    await _balanceAlertSubscription?.cancel();
    _stateSubscription = null;
    _failuresSubscription = null;
    _balanceAlertSubscription = null;

    if (service == null) return;
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
    if (!ownsService) return;
    try {
      await service.disconnect();
    } catch (_) {}
    await service.dispose();
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
      _setLocationChatState(() => _selectedModelCode = modelCode);
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
        _setLocationChatState(() => _selectedModelCode = normalized);
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
    if (changedMessages && mounted) _setLocationChatState(() {});
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
      if (widget.isLeafLocation &&
          !_joinedLocation &&
          provided.state.connected) {
        unawaited(_joinLocation(provided));
      }
      return;
    }

    if (_service != null) {
      final service = _service!;
      _attachService(service);
      if (widget.isLeafLocation &&
          !_joinedLocation &&
          service.state.connected) {
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
    _joiningLocation = false;
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
    if (mounted) _setLocationChatState(() {});
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
      _setLocationChatState(() {
        _messages.add(ChatMessageVm.system('WebSocket connection failed: $e'));
      });
    }
  }

  Future<void> _joinLocation(WorldChatroomService service) async {
    if (_joiningLocation || _joinedLocation) return;
    _joiningLocation = true;
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
      _setLocationChatState(() {
        _messages.add(ChatMessageVm.system('Join failed: $e'));
      });
    } finally {
      _joiningLocation = false;
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
    if (message.isTimelineEvent) return false;
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
    if (widget.active &&
        widget.isLeafLocation &&
        service != null &&
        state.connected &&
        !state.joining &&
        state.joinedLocationId != widget.locationId &&
        !_joinedLocation &&
        !_joiningLocation) {
      unawaited(_joinLocation(service));
    }
    final wasFollowingLatest =
        _scrollCoordinator.shouldFollowLatest && _scrollCoordinator.isAtBottom;
    final previousSource =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final previousLatestLocalId = _latestMessageLocalId();
    final nextSource =
        state.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    final tickProgressStarted = _syncTickProgressState(
      progressing: widget.worldTickInProgress || state.inputBlocked,
      nextSource: nextSource,
    );
    _absorbHistoricalTickProgressBaseline(
      nextSource,
      connected: state.connected,
    );
    final beforeVmCount = _messages.length;
    final reconcileStopwatch = _panelMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final changedMessages = _reconcileMessages(
      nextSource,
      identityState: state,
    );
    final tickProgressResolved = _resolveTickProgressMessageIfAvailable();
    final changedHasMoreOlder = _syncHasMoreOlderMessagesForSource(nextSource);
    final olderLoadRendered = _olderLoadHasRenderedNewMessages();
    final shouldRebuild =
        changedMessages ||
        changedHasMoreOlder ||
        olderLoadRendered ||
        tickProgressStarted ||
        tickProgressResolved ||
        _hasVisibleChatroomStateChange(_chatroomState, state);
    if (shouldRebuild) {
      _setLocationChatState(() {
        _chatroomState = state;
        if (olderLoadRendered) _finishOlderMessagesLoading();
      });
    } else {
      _chatroomState = state;
      if (olderLoadRendered) _finishOlderMessagesLoading();
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
    if (changedMessages && wasFollowingLatest) {
      _clearUnseenIncomingCount();
    } else if (changedMessages &&
        previousLatestLocalId.isNotEmpty &&
        _latestMessageLocalId() != previousLatestLocalId) {
      final newIncomingCount = _newIncomingTailMessageCount(
        previousSource,
        nextSource,
      );
      if (newIncomingCount > 0) {
        _setLocationChatState(() {
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
        previous.inputBlocked != next.inputBlocked ||
        previous.conversationRoundStatesByLocation[widget.locationId] !=
            next.conversationRoundStatesByLocation[widget.locationId]) {
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
      awaitingAiResponse: _sendAwaitingResponse,
      scroll: {
        'hasClients': hasClients,
        'pixels': hasClients ? _scrollController.position.pixels : 0,
        'extentBefore': hasClients
            ? _scrollController.position.extentBefore
            : 0,
        'maxScrollExtent': hasClients
            ? _scrollController.position.maxScrollExtent
            : 0,
        'viewportMode': _scrollCoordinator.mode.name,
        'isAtBottom': _scrollCoordinator.isAtBottom,
        'commandGeneration': _scrollCoordinator.commandGeneration,
      },
    );
  }
}
