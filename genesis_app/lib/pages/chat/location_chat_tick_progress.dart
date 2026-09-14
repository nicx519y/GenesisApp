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
    if (activeStreams.isEmpty && activeActions.isEmpty) return;

    _deferredTickLocalId = locationChatMessageLocalId(newTick);
    _deferredTickStreamKeys.addAll(activeStreams.map(_tickStreamKey));
    _deferredTickActionRoundIds.addAll(
      activeActions.map((round) => round.roundId),
    );
    _tickPrecedingStreamKeys[_deferredTickLocalId!] = _deferredTickStreamKeys
        .toSet();
    _tickPrecedingActionRoundIds[_deferredTickLocalId!] =
        _deferredTickActionRoundIds.toSet();
    for (final round in activeActions.reversed) {
      if (round.showCardPresentation) {
        _deferredTickPresentationRoundId = round.roundId;
        break;
      }
    }
  }

  bool _deferredTickReadyToDisplay() {
    if (_deferredTickLocalId == null) return false;
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
        _resolveTickProgressMessageIfAvailable();
      });
    });
  }

  void _clearDeferredTick({bool resetOrdering = false}) {
    _deferredTickGeneration++;
    _deferredTickReleaseScheduled = false;
    _deferredTickLocalId = null;
    _deferredTickPresentationRoundId = null;
    _deferredTickStreamKeys.clear();
    _deferredTickActionRoundIds.clear();
    if (resetOrdering) {
      _tickPrecedingStreamKeys.clear();
      _tickPrecedingActionRoundIds.clear();
    }
  }

  bool _messageBelongsBeforeTick(ChatMessageVm message, String tickLocalId) {
    if (message.isTick) return false;
    if (_tickPrecedingStreamKeys[tickLocalId]?.contains(
          '${message.roundId}:${message.senderId}',
        ) ??
        false) {
      return true;
    }
    final sourceRoundIds = _tickPrecedingActionRoundIds[tickLocalId];
    if (sourceRoundIds == null) return false;
    final controller = _replyController;
    if (controller == null) return false;
    return sourceRoundIds.any((sourceRoundId) {
      final continuedRoundId = controller
          .stateForRound(widget.locationId, sourceRoundId)
          ?.goOnRoundId;
      return continuedRoundId != null && message.roundId == '$continuedRoundId';
    });
  }

  List<ChatMessageVm> _sequenceMessagesBeforeDeferredTicks() {
    if (_tickPrecedingStreamKeys.isEmpty &&
        _tickPrecedingActionRoundIds.isEmpty) {
      return _messages;
    }
    final sequenced = _messages.toList();
    // A stream can receive its final server message ID after the Tick ID.
    // Preserve the visible completion order without changing canonical history.
    for (final tickLocalId in _tickPrecedingStreamKeys.keys) {
      final tickIndex = sequenced.indexWhere(
        (message) => message.localId == tickLocalId,
      );
      if (tickIndex < 0) continue;
      final preceding = <ChatMessageVm>[];
      for (var index = sequenced.length - 1; index > tickIndex; index -= 1) {
        final message = sequenced[index];
        if (_messageBelongsBeforeTick(message, tickLocalId)) {
          preceding.insert(0, sequenced.removeAt(index));
        }
      }
      sequenced.insertAll(tickIndex, preceding);
    }
    return sequenced;
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
    final sequenced = _sequenceMessagesBeforeDeferredTicks();
    final deferredLocalId = _deferredTickLocalId;
    if (deferredLocalId == null) {
      return _collapseConsecutiveLocationChatTicksForDisplay(sequenced);
    }
    final deferredIndex = sequenced.indexWhere(
      (message) => message.localId == deferredLocalId,
    );
    return _collapseConsecutiveLocationChatTicksForDisplay(
      deferredIndex < 0 ? sequenced : sequenced.sublist(0, deferredIndex),
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
