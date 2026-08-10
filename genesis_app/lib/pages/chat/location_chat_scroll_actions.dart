part of 'location_chat_page.dart';

extension _LocationChatScrollActions on _LocationChatPanelState {
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

  void _setAutoFollowLatestMessages(bool value, {required String action}) {
    if (_autoFollowLatestMessages == value) return;
    if (mounted) {
      _setLocationChatState(() => _autoFollowLatestMessages = value);
    } else {
      _autoFollowLatestMessages = value;
    }
    _recordPanelDebug(action: action, details: {'enabled': value});
  }

  void _cancelInitialBottomScroll({required String action}) {
    if (!_initialBottomScrollPending) return;
    _initialBottomScrollPending = false;
    _initialBottomScrollShouldComplete = false;
    _initialBottomScrollDidJump = false;
    _recordPanelDebug(action: action);
  }

  double _bottomScrollOffset() {
    if (!_scrollController.hasClients) return 0;
    return _scrollController.position.maxScrollExtent;
  }

  void _startInitialBottomScroll() {
    _autoFollowLatestMessages = true;
    _initialBottomScrollPending = true;
    _initialBottomScrollShouldComplete = false;
    _initialBottomScrollDidJump = false;
    _recordPanelDebug(action: 'initialBottomScrollStart');
    _scheduleInitialBottomScroll(complete: _messages.isNotEmpty);
  }

  void _scheduleInitialBottomScroll({required bool complete}) {
    if (!_initialBottomScrollPending) return;
    if (!_autoFollowLatestMessages) {
      _cancelInitialBottomScroll(action: 'initialBottomScrollCancelled');
      return;
    }
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
      if (!_autoFollowLatestMessages) {
        _cancelInitialBottomScroll(action: 'initialBottomScrollCancelled');
        return;
      }
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
    _setAutoFollowLatestMessages(true, action: 'autoFollowEnabledByScroll');
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
    _setAutoFollowLatestMessages(true, action: 'autoFollowEnabledByForce');
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
    _setAutoFollowLatestMessages(true, action: 'autoFollowEnabledByComposer');
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
    if (!_autoFollowLatestMessages) {
      _deactivateComposerFocusBottomPin();
      return;
    }
    if (_composerFocusBottomScheduled) return;
    _composerFocusBottomScheduled = true;
    _recordPanelDebug(action: 'composerFocusBottomPinScheduled');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerFocusBottomScheduled = false;
      if (!mounted ||
          !_composerFocusNode.hasFocus ||
          !_composerFocusBottomPinActive ||
          !_autoFollowLatestMessages) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_bottomScrollOffset());
      }
    });
  }

  bool _handleMessageListScrollNotification(ScrollNotification notification) {
    final userDriven =
        notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle ||
        notification is ScrollUpdateNotification &&
            notification.dragDetails != null;
    if (!userDriven) {
      return false;
    }
    final atBottom =
        notification.metrics.maxScrollExtent - notification.metrics.pixels <=
        24;
    _setAutoFollowLatestMessages(
      atBottom,
      action: atBottom ? 'autoFollowEnabledByUser' : 'autoFollowDisabledByUser',
    );
    if (atBottom) return false;
    _cancelInitialBottomScroll(action: 'initialBottomScrollCancelledByUser');
    if (_composerFocusBottomPinActive) {
      _deactivateComposerFocusBottomPin();
    }
    return false;
  }

  void _keepBottomAfterLayoutIfNeeded() {
    if (!_autoFollowLatestMessages) return;
    if (!_isAtBottom()) return;
    if (_keepBottomAfterLayoutScheduled) return;
    _keepBottomAfterLayoutScheduled = true;
    _recordPanelDebug(action: 'keepBottomAfterLayoutScheduled');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keepBottomAfterLayoutScheduled = false;
      if (!mounted ||
          !_autoFollowLatestMessages ||
          !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_bottomScrollOffset());
      _recordPanelDebug(action: 'keepBottomAfterLayoutJump');
    });
  }

  void _clearUnseenIncomingCount() {
    if (_unseenIncomingCount == 0 || !mounted) return;
    _setLocationChatState(() => _unseenIncomingCount = 0);
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
    final tick = message.tickNo > 0
        ? 'Tick ${message.tickNo}${message.subTickNo > 0 ? '-${message.subTickNo}' : ''}'
        : 'Tick';
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
}
