part of 'location_chat_page.dart';

const String _locationChatTickProgressTitle = 'Progressing the World';

extension _LocationChatTickProgress on _LocationChatPanelState {
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
    if (!_awaitingTickProgressMessage || _activeTickProgressSlotId.isEmpty) {
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
    if (!_awaitingTickProgressMessage || _activeTickProgressSlotId.isEmpty) {
      return _messages;
    }
    return <ChatMessageVm>[
      ..._messages,
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

  String _locationChatMessageLayoutId(ChatMessageVm message) {
    return _tickProgressLayoutIdByMessageLocalId[message.localId] ??
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
