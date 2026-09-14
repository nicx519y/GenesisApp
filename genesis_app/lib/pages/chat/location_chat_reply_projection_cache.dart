part of 'location_chat_page.dart';

typedef _ReplyProjection = ({
  List<ChatMessageVm> messages,
  List<ChatMessageVm> replyMessages,
});

/// Page-owned projection and VM cache. The request/controller lifecycle remains
/// on the panel; this object owns cache invalidation, reuse and eviction.
class _LocationChatReplyProjectionCache {
  _LocationChatReplyProjectionCache(this._owner);
  final _LocationChatPanelState _owner;

  Object? _replyProjectionKey;
  _ReplyProjection? _replyProjectionCache;
  Object? _replyIdentityCacheKey;
  LocationChatMessageParseContext? _parseContext;
  final Map<String, _LocationChatReplyVmCache> _replyVmCaches = {};

  void clear() {
    _replyProjectionKey = null;
    _replyProjectionCache = null;
    _replyIdentityCacheKey = null;
    _parseContext = null;
    _replyVmCaches.clear();
  }

  List<LocationChatReplyCard> cards(
    ChatroomReplyRoundState? state,
    List<ChatMessageVm> currentReplyMessages,
  ) {
    if (state == null) return const [];
    if (!state.showCardPresentation) {
      return currentReplyMessages.isEmpty
          ? const []
          : [LocationChatReplyCard(id: 0, messages: currentReplyMessages)];
    }
    final viewedCardId = state.viewedCardId;
    if (!_owner._replyCardTransitionBusy) {
      final currentKey = '${state.roundId}/$viewedCardId';
      _replyVmCaches.removeWhere((key, _) => key != currentKey);
    }
    return [
      for (final card in state.cards)
        LocationChatReplyCard.lazy(
          id: card.cardId,
          contentIdentity: (
            _owner._replyBindingGeneration,
            state.roundId,
            card.cardId,
            state.cardContentRevision(card.cardId),
            // A promoted card reads formal history, whose content can change
            // independently of the candidate card revision (for example Edit).
            card.cardId == viewedCardId ? currentReplyMessages : null,
            _identityKey,
          ),
          resolveMessages: () => card.cardId == viewedCardId
              ? currentReplyMessages
              : messages(
                  state.messagesForCard(card.cardId),
                  cardId: card.cardId,
                ),
        ),
    ];
  }

  _ReplyProjection presentation(ChatroomReplyRoundState? state) {
    final controller = _owner._replyController;
    final revisions = controller?.revisionsForLocation(
      _owner.widget.locationId,
    );
    final key = (
      _owner._replyProjectionEpoch,
      _owner._preparedEntry?.revision,
      revisions?.structureRevision,
      revisions?.contentRevision,
      _identityKey,
      state?.roundId,
      _owner._shouldShowAiContentDisclaimer,
      _owner._awaitingTickProgressMessage,
      _owner._activeTickProgressSlotId,
    );
    if (_replyProjectionKey == key && _replyProjectionCache != null) {
      return _replyProjectionCache!;
    }
    assert(() {
      debugLocationChatReplyProjectionCount++;
      return true;
    }());
    var source = _owner._locationChatDisplayMessages();
    final retained = controller == null
        ? const <ChatroomReplyRoundState>[]
        : _owner._usesPreparedEntry
        ? _owner._preparedEntry?.snapshot?.retainedReplies ??
              const <ChatroomReplyRoundState>[]
        : controller.statesFor(_owner.widget.locationId);
    for (final previous in retained) {
      if (identical(previous, state) ||
          (state != null && previous.roundId >= state.roundId) ||
          !previous.selectedCardAwaitingFormalHistory) {
        continue;
      }
      final ids = _replyMessageIds(previous);
      // Do not resurrect a round that has already scrolled out of the
      // projected window. The round projection below is shared with Go On.
      if (!source.any(
        (message) =>
            message.roundId == '${previous.roundId}' &&
            ids.contains(message.globalMessageId),
      )) {
        continue;
      }
      source = _presentReplyRound(source, previous).messages;
    }
    _replyProjectionKey = key;
    return _replyProjectionCache = state == null
        ? (
            messages: List<ChatMessageVm>.unmodifiable(source),
            replyMessages: const <ChatMessageVm>[],
          )
        : _presentReplyRound(source, state);
  }

  _ReplyProjection _presentReplyRound(
    List<ChatMessageVm> source,
    ChatroomReplyRoundState state,
  ) {
    final replyMessageIds = _replyMessageIds(state);
    final candidateMessages = state.showCardPresentation
        ? messages(state.displayedMessages, cardId: state.viewedCardId)
        : null;
    final presentation = buildLocationChatReplyPresentation(
      source: source,
      roundId: '${state.roundId}',
      replyMessageIds: replyMessageIds,
      candidates: candidateMessages,
    );
    final currentReplyMessages =
        candidateMessages ??
        [
          for (final message in source)
            if (message.roundId == '${state.roundId}' &&
                message.globalMessageId > 0 &&
                replyMessageIds.contains(message.globalMessageId))
              message,
        ];
    return (messages: presentation, replyMessages: currentReplyMessages);
  }

  Set<int> _replyMessageIds(ChatroomReplyRoundState state) => state
      .formalReplyMessages
      .map((message) => message.globalMessageId)
      .where((id) => id > 0)
      .toSet();

  Object get _identityKey => (
    _owner._replyBindingGeneration,
    _owner._chatroomState.world,
    _owner._chatroomState.entitiesById,
    Object.hashAll(_owner._myUserIdKeys),
    Object.hashAll(_owner._mySenderIdKeys),
    _owner._devicePixelRatio,
    _owner._userInfoRevisionListenable?.value,
  );

  List<ChatMessageVm> messages(
    List<WorldChatroomMessage> source, {
    int? cardId,
  }) {
    final identityKey = _identityKey;
    if (_replyIdentityCacheKey != identityKey) {
      _replyIdentityCacheKey = identityKey;
      final identity = _LocationChatTimelineIdentityIndex.fromState(
        _owner._chatroomState,
        currentUserIds: _owner._myUserIdKeys,
        currentSenderIds: _owner._mySenderIdKeys,
      );
      _parseContext = LocationChatMessageParseContext(
        currentLocationId: _owner.widget.locationId,
        isMine: (_) => false,
        senderName: _owner._messageSenderDisplayName,
        avatarUrl: _owner._messageAvatarUrl,
        isPlayerControlledRole: _owner._messageSenderIsPlayerControlledRole,
        characterName: identity.characterName,
        locationName: identity.locationName,
        roleName: identity.roleName,
        roleIsAi: identity.roleIsAi,
        roleAvatarUrl: identity.roleAvatarUrl,
      );
      _replyVmCaches.clear();
    }
    final key =
        '${source.firstOrNull?.conversationRoundId ?? ''}/${cardId ?? 0}';
    final cached = _replyVmCaches.remove(key);
    if (cached != null && identical(cached.source, source)) {
      _replyVmCaches[key] = cached;
      return cached.messages;
    }
    final messages = <ChatMessageVm>[];
    final retained = <int, (WorldChatroomMessage, ChatMessageVm)>{};
    for (final message in source) {
      final previous = cached?.entries[message.globalMessageId];
      if (previous != null && identical(previous.$1, message)) {
        retained[message.globalMessageId] = previous;
        messages.add(previous.$2);
        continue;
      }
      assert(() {
        debugLocationChatReplyMessageParseCount++;
        return true;
      }());
      final parsed = _owner
          ._parserForMessage(message)
          ?.parse(message, _parseContext!);
      if (parsed == null) continue;
      var vm = ChatMessageVm(
        localId:
            'reply:${_owner.widget.worldId}:${_owner.widget.locationId}:${parsed.roundId}:${cardId ?? 0}:${parsed.globalMessageId}',
        globalMessageId: parsed.globalMessageId,
        messageId: parsed.messageId,
        locationMessageId: parsed.locationMessageId,
        roundId: parsed.roundId,
        tickNo: parsed.tickNo,
        subTickNo: parsed.subTickNo,
        senderId: parsed.senderId,
        senderName: parsed.senderName,
        avatarUrl: parsed.avatarUrl,
        imageUrl: parsed.imageUrl,
        text: parsed.text,
        currentTime: parsed.currentTime,
        isMe: false,
        status: parsed.status,
        senderType: parsed.senderType,
        createdAt: parsed.createdAt,
      );
      if (previous != null &&
          locationChatReplyMessagePresentationEqual(previous.$2, vm)) {
        // Promotion assigns canonical cursors without changing the displayed
        // card. Reuse its VM/list/widget and let actions read the updated ids.
        previous.$2.messageId = vm.messageId;
        previous.$2.locationMessageId = vm.locationMessageId;
        vm = previous.$2;
      }
      retained[message.globalMessageId] = (message, vm);
      messages.add(vm);
    }
    final stableMessages =
        cached != null && listEquals(cached.messages, messages)
        ? cached.messages
        : List<ChatMessageVm>.unmodifiable(messages);
    _replyVmCaches[key] = _LocationChatReplyVmCache(
      source,
      stableMessages,
      retained,
    );
    while (_replyVmCaches.length > 2) {
      _replyVmCaches.remove(_replyVmCaches.keys.first);
    }
    return stableMessages;
  }
}

class _LocationChatReplyVmCache {
  const _LocationChatReplyVmCache(this.source, this.messages, this.entries);
  final List<WorldChatroomMessage> source;
  final List<ChatMessageVm> messages;
  final Map<int, (WorldChatroomMessage, ChatMessageVm)> entries;
}
