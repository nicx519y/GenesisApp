part of 'chatroom_reply_actions_controller.dart';

/// Photo updates share card storage and projection, never formal history.
extension ChatroomReplyPhotos on ChatroomReplyActionsController {
  Future<({int roundId, int cardId})> preparePhotoTarget(
    String location,
  ) async {
    _checkCurrent();
    final state = stateFor(location);
    if (state == null || !state._eligible || state.busy || state.generating) {
      throw StateError(GenesisL10n.current.chatReplyActionUnavailable);
    }
    final requestedCard = state.viewedCardId;
    if (state.provisional || !state.hasCardGroup) {
      await _loadCards(state, force: true);
    }
    _checkCurrent();
    final card = requestedCard > 0
        ? state._card(requestedCard)
        : state.viewedCard;
    if (!state.isLatest ||
        !_completeCard(card) ||
        card!.cardId <= 0 ||
        (state.confirmed && state.selectedCardId != card.cardId)) {
      throw StateError(GenesisL10n.current.chatReplyActionUnavailable);
    }
    return (roundId: state.roundId, cardId: card.cardId);
  }

  /// Read only the requested card into its existing slot. A background photo
  /// must not complete, replace, or steal focus from a text regeneration.
  Future<void> refreshPhotoCard(String location, int round, int cardId) async {
    final state = _state(location, round);
    final key = (location, round, cardId);
    final query = (_photoQueries[key] ?? 0) + 1;
    _photoQueries[key] = query;
    final result = await _http.getLlmCards(
      worldId: worldId,
      locationId: location,
      conversationRoundId: round,
    );
    _checkCurrent();
    if (_photoQueries[key] != query) return;
    if (state._cards.isEmpty || state.provisional && !state.generating) {
      await _applyCards(state, result);
      return;
    }
    final card = result.list.where((c) => c.cardId == cardId).firstOrNull;
    if (card == null) {
      throw StateError(GenesisL10n.current.chatPhotoUnavailable);
    }
    final index = state._cards.indexWhere((c) => c.cardId == cardId);
    if (index < 0) {
      state._cards.add(card);
      state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    } else {
      state._cards[index] = card;
    }
    _invalidateCardsCache(state);
    _notify(location);
    await _persist(state);
  }

  Future<void> acceptCardPhoto(ChatroomV2Message message) async {
    final cardId = chatPhotoId(message.payload['card_id']);
    final state = _state(message.locationId, message.conversationRoundId!);
    final card = state._card(cardId);
    final old = card?.messages
        .where((m) => m.globalMessageId == message.globalMessageId)
        .firstOrNull;
    final photo = ChatPhoto.fromJson(message.payload['photo']);
    final previous = old == null
        ? null
        : ChatPhoto.tryParse(old.message.payload['photo']);
    // Unknown tasks are ordered by authoritative cards, not arrival order.
    if (card == null || old == null || previous?.taskId != photo.taskId) {
      await refreshPhotoCard(message.locationId, state.roundId, cardId);
      return;
    }
    if (previous!.terminal && !photo.terminal) return;
    _photoQueries.update(
      (state.locationId, state.roundId, cardId),
      (v) => v + 1,
      ifAbsent: () => 1,
    );
    final updated = ChatroomLlmCardMessage.fromJson({
      ...old.rawJson,
      'payload': {...old.message.payload, ...message.payload},
    });
    final index = state._cards.indexWhere((c) => c.cardId == cardId);
    state._cards[index] = ChatroomLlmCard(
      cardId: card.cardId,
      cardIndex: card.cardIndex,
      isOriginal: card.isOriginal,
      generationState: card.generationState,
      canEdit: card.canEdit,
      canDelete: card.canDelete,
      messages: [
        for (final m in card.messages)
          if (m.globalMessageId == updated.globalMessageId) updated else m,
      ],
      billing: card.billing,
      createdAt: card.createdAt,
      rawJson: card.rawJson,
      error: card.error,
    );
    _invalidateCardsCache(state);
    _notify(state.locationId);
    await _persist(state);
  }

  Future<WorldChatroomMessage?> revealPhotoCard(
    String location,
    int round,
    int cardId,
    int messageId, {
    bool Function()? isCurrent,
  }) async {
    await refreshPhotoCard(location, round, cardId);
    if (isCurrent != null && !isCurrent()) return null;
    final state = _state(location, round);
    final card = state._card(cardId);
    final message = card?.messages
        .where(
          (m) =>
              m.globalMessageId == messageId && m.message.type == 'live_photo',
        )
        .firstOrNull;
    if (message == null) return null;
    state._viewedCardId = cardId;
    state._presentationRevision++;
    _notify(location);
    return _candidateToWorld(message);
  }
}
