part of 'location_chat_page.dart';

const String _locationChatTickProgressTitle = 'Progressing the World';

extension _LocationChatTickProgress on _LocationChatPanelState {
  String _tickStreamKey(WorldChatroomMessage message) =>
      '${message.conversationRoundId}:${message.senderId}';

  void _deferNewTickUntilCurrentMessageFinishes(
    List<WorldChatroomMessage> previousSource,
    List<WorldChatroomMessage> nextSource,
  ) {
    if (_deferredTickLocalId != null) return;
    final previousIds = previousSource.map(locationChatMessageLocalId).toSet();
    WorldChatroomMessage? newTick;
    for (final message in nextSource) {
      if (locationChatBusinessType(message) == 'tick' &&
          !previousIds.contains(locationChatMessageLocalId(message))) {
        newTick = message;
        break;
      }
    }
    if (newTick == null) return;

    final activeStreams = previousSource.where((message) => message.streaming);
    final activeConversation =
        _chatroomState.conversationRoundStatesByLocation[widget.locationId];
    final waitsForConversationCompletion = _currentReplyConversationInProgress;
    final tickRoundId = int.tryParse(newTick.conversationRoundId);
    final activeActions =
        _replyController
            ?.statesFor(widget.locationId)
            .where(
              (round) =>
                  round.invalidatedByTick &&
                  (tickRoundId == null || round.roundId != tickRoundId) &&
                  (round.generating || round.goOnPending),
            )
            .toList(growable: false) ??
        const <ChatroomReplyRoundState>[];
    if (activeStreams.isEmpty &&
        activeActions.isEmpty &&
        activeConversation == null &&
        !waitsForConversationCompletion) {
      return;
    }

    _deferredTickLocalId = locationChatMessageLocalId(newTick);
    // Capture the predecessor instead of consulting the latest round later:
    // the Tick has already advanced canonical state by the time this runs.
    _deferredTickConversationGeneration = activeConversation?.generation;
    _deferredTickWaitsForConversationCompletion =
        waitsForConversationCompletion;
    _deferredTickStreamKeys.addAll(activeStreams.map(_tickStreamKey));
    _deferredTickActionRoundIds.addAll(
      activeActions.map((round) => round.roundId),
    );
    for (final round in activeActions.reversed) {
      if (round.showCardPresentation) {
        _deferredTickPresentationRoundId = round.roundId;
        break;
      }
    }
    final transactionRoundId = _replyConnectionActionRoundId;
    if (_deferredTickPresentationRoundId == null &&
        transactionRoundId != null) {
      final round = _replyController?.stateForRound(
        widget.locationId,
        transactionRoundId,
      );
      if (round?.showCardPresentation ?? false) {
        _deferredTickPresentationRoundId = transactionRoundId;
      }
    }
  }

  bool _deferredTickReadyToDisplay() {
    if (_deferredTickLocalId == null) return false;
    final deferredConversationGeneration = _deferredTickConversationGeneration;
    if (deferredConversationGeneration != null &&
        _chatroomState
                .conversationRoundStatesByLocation[widget.locationId]
                ?.generation ==
            deferredConversationGeneration) {
      return false;
    }
    if (_deferredTickWaitsForConversationCompletion &&
        _currentReplyConversationInProgress) {
      return false;
    }
    final source =
        _chatroomState.messagesByLocation[widget.locationId] ??
        const <WorldChatroomMessage>[];
    if (source.any(
      (message) =>
          message.streaming &&
          _deferredTickStreamKeys.contains(_tickStreamKey(message)),
    )) {
      return false;
    }
    final controller = _replyController;
    if (controller != null &&
        _deferredTickActionRoundIds.any((roundId) {
          final round = controller.stateForRound(widget.locationId, roundId);
          return round != null && (round.generating || round.goOnPending);
        })) {
      return false;
    }
    return true;
  }

  void _scheduleDeferredTickReleaseIfReady() {
    if (_deferredTickReleaseScheduled || !_deferredTickReadyToDisplay()) {
      return;
    }
    _deferredTickReleaseScheduled = true;
    final generation = _deferredTickGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _deferredTickGeneration) return;
      _deferredTickReleaseScheduled = false;
      if (!mounted || !_deferredTickReadyToDisplay()) return;
      _setLocationChatState(() {
        _clearDeferredTick();
        _syncInspirationView();
        _resolveTickProgressMessageIfAvailable();
      });
    });
  }

  void _clearDeferredTick() {
    _deferredTickGeneration++;
    _deferredTickReleaseScheduled = false;
    _deferredTickLocalId = null;
    _deferredTickPresentationRoundId = null;
    _deferredTickStreamKeys.clear();
    _deferredTickActionRoundIds.clear();
    _deferredTickConversationGeneration = null;
    _deferredTickWaitsForConversationCompletion = false;
  }

  bool _syncTickProgressState({
    required bool progressing,
    required List<WorldChatroomMessage> nextSource,
  }) {
    if (!progressing) {
      _tickProgressSessionActive = false;
      return false;
    }
    if (_tickProgressSessionActive) return false;
    _tickProgressSessionActive = true;
    _inspirationTickPreviousRound = nextSource.fold<int>(
      0,
      (round, message) => math.max(round, message.conversationRoundNumber),
    );
    _tickProgressGeneration += 1;
    _activeTickProgressSlotId =
        'location-chat-tick-progress-${widget.locationId}-$_tickProgressGeneration';
    _awaitingTickProgressMessage = true;
    _tickProgressStartedAt = DateTime.now();
    _tickProgressBaselineLocalIds = nextSource
        .where(_isTickProgressCompletionSource)
        .map(locationChatMessageLocalId)
        .toSet();
    _tickProgressBaselineLocationMessageId = 0;
    _tickProgressBaselineMessageId = 0;
    for (final message in nextSource.where(_isTickProgressCompletionSource)) {
      _tickProgressBaselineLocationMessageId = math.max(
        _tickProgressBaselineLocationMessageId,
        message.locationMessageId,
      );
      _tickProgressBaselineMessageId = math.max(
        _tickProgressBaselineMessageId,
        message.messageId,
      );
    }
    return true;
  }

  void _cancelTickProgressMessage() {
    _tickProgressSessionActive = false;
    _awaitingTickProgressMessage = false;
    _activeTickProgressSlotId = '';
    _tickProgressBaselineLocalIds = const <String>{};
    _tickProgressBaselineLocationMessageId = 0;
    _tickProgressBaselineMessageId = 0;
  }

  void _discardStaleTickProgressMessage() {
    if (!_awaitingTickProgressMessage) return;
    _cancelTickProgressMessage();
  }

  void _absorbHistoricalTickProgressBaseline(
    List<WorldChatroomMessage> source, {
    required bool connected,
  }) {
    if (!_awaitingTickProgressMessage || connected) return;
    final baselineLocalIds = _tickProgressBaselineLocalIds.toSet();
    for (final message in source.where(_isTickProgressCompletionSource)) {
      baselineLocalIds.add(locationChatMessageLocalId(message));
      _tickProgressBaselineLocationMessageId = math.max(
        _tickProgressBaselineLocationMessageId,
        message.locationMessageId,
      );
      _tickProgressBaselineMessageId = math.max(
        _tickProgressBaselineMessageId,
        message.messageId,
      );
    }
    _tickProgressBaselineLocalIds = baselineLocalIds;
  }

  bool _resolveTickProgressMessageIfAvailable() {
    final retainedMessageLocalIds = _messages
        .map((message) => message.localId)
        .toSet();
    _tickProgressLayoutIdByMessageLocalId.removeWhere(
      (localId, _) => !retainedMessageLocalIds.contains(localId),
    );
    if (_deferredTickLocalId != null ||
        !_awaitingTickProgressMessage ||
        _activeTickProgressSlotId.isEmpty) {
      return false;
    }
    for (final message in _messages.reversed) {
      if (!message.isTick ||
          message.timelinePayload is ChatTickProgressPayloadVm ||
          !_isTickMessageNewerThanProgressBaseline(message)) {
        continue;
      }
      _tickProgressLayoutIdByMessageLocalId[message.localId] =
          _activeTickProgressSlotId;
      _awaitingTickProgressMessage = false;
      return true;
    }
    return false;
  }

  bool _isTickMessageNewerThanProgressBaseline(ChatMessageVm message) {
    if (_tickProgressBaselineLocalIds.contains(message.localId)) return false;
    if (message.locationMessageId > 0) {
      return message.locationMessageId > _tickProgressBaselineLocationMessageId;
    }
    final messageId = message.messageId ?? 0;
    if (messageId > 0) {
      return messageId > _tickProgressBaselineMessageId;
    }
    return !message.createdAt.isBefore(_tickProgressStartedAt);
  }

  bool _isTickProgressCompletionSource(WorldChatroomMessage message) {
    return locationChatBusinessType(message) == 'tick';
  }

  List<ChatMessageVm> _locationChatDisplayMessages() {
    // Keep every canonical Tick in `_messages` for cursor and unread state;
    // collapse only the projection handed to the message list. The disclaimer
    // is display-only and never enters the canonical or persisted queues.
    final projectedMessages = _locationChatProjectedMessages();
    final displayMessages = _shouldShowAiContentDisclaimer
        ? <ChatMessageVm>[_aiContentDisclaimerMessage, ...projectedMessages]
        : projectedMessages;
    if (!_awaitingTickProgressMessage || _activeTickProgressSlotId.isEmpty) {
      return displayMessages;
    }
    return <ChatMessageVm>[
      ...displayMessages,
      ChatMessageVm(
        localId: _activeTickProgressSlotId,
        senderId: 'tick',
        senderName: 'Time',
        text: '',
        isMe: false,
        status: 'progressing',
        senderType: 'tick',
        createdAt: _tickProgressStartedAt,
        timelinePayload: ChatTickProgressPayloadVm(
          title: _locationChatTickProgressTitle,
          avatars: _locationChatTickProgressAvatars(),
        ),
      ),
    ];
  }

  List<ChatMessageVm> _locationChatProjectedMessages() {
    final deferredLocalId = _deferredTickLocalId;
    if (deferredLocalId == null) {
      return _collapseConsecutiveLocationChatTicksForDisplay(_messages);
    }
    // Defer only the Tick itself. Messages that receive a later
    // location_message_id stay mounted and keep their reveal state; once the
    // Tick is released, the canonical location order inserts it before them.
    return _collapseConsecutiveLocationChatTicksForDisplay(
      _messages
          .where((message) => message.localId != deferredLocalId)
          .toList(growable: false),
    );
  }

  String _locationChatMessageLayoutId(ChatMessageVm message) {
    return _tickProgressLayoutIdByMessageLocalId[message.localId] ??
        _openingLayoutIds[message.localId] ??
        message.localId;
  }

  List<ChatTickProgressAvatarVm> _locationChatTickProgressAvatars() {
    final world = _chatroomState.world;
    if (world == null) return const <ChatTickProgressAvatarVm>[];
    return world.characters
        .map(
          (character) => ChatTickProgressAvatarVm(
            name: _firstMapString(character, const [
              'name',
              'character_name',
              'player_username',
            ]),
            url: _firstMapImageUrl(character, const [
              'avatar',
              'avatar_url',
              'role_avatar',
            ]),
          ),
        )
        .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
        .toList(growable: false);
  }
}

List<ChatMessageVm> _collapseConsecutiveLocationChatTicksForDisplay(
  List<ChatMessageVm> messages,
) {
  if (messages.length < 2) return messages;
  List<ChatMessageVm>? collapsed;
  for (var index = 1; index < messages.length; index += 1) {
    final message = messages[index];
    if (message.isTick && messages[index - 1].isTick) {
      collapsed ??= messages.sublist(0, index);
      collapsed[collapsed.length - 1] = message;
      continue;
    }
    collapsed?.add(message);
  }
  return collapsed ?? messages;
}
