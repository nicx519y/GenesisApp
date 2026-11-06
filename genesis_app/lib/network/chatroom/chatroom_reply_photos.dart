part of 'chatroom_reply_actions_controller.dart';

/// Resolve local photo targets; candidate updates stay outside formal history.
extension ChatroomReplyPhotos on ChatroomReplyActionsController {
  Future<({int roundId, int? cardId})> preparePhotoTarget(
    String location,
  ) async => _resolvePhotoTarget(location);

  /// Revalidate a new write after confirmation/storage without changing its
  /// target. Uncertain writes instead replay their saved identity unchanged.
  void validatePhotoTarget(
    String location,
    ({int roundId, int? cardId}) target,
  ) {
    if (_resolvePhotoTarget(location) != target) {
      throw StateError(GenesisL10n.current.chatReplyActionUnavailable);
    }
  }

  ({int roundId, int? cardId}) _resolvePhotoTarget(String location) {
    _checkCurrent();
    final state = stateFor(location);
    if (state == null || !state.canTakePhoto) {
      throw StateError(GenesisL10n.current.chatReplyActionUnavailable);
    }
    // Formal replies do not need a card group. Never query cards merely to
    // turn a formal photo request into a candidate request.
    if (!state.hasCardGroup) {
      return (roundId: state.roundId, cardId: null);
    }
    final card = state.viewedCard;
    if (!_completeCard(card) || card!.cardId <= 0) {
      throw StateError(GenesisL10n.current.chatReplyActionUnavailable);
    }
    return (roundId: state.roundId, cardId: card.cardId);
  }

  /// Read only the requested card into its existing slot. A background photo
  /// must not complete, replace, or steal focus from a text regeneration.
  Future<void> refreshPhotoCard(String location, int round, int cardId) async {
    await refreshPhotoCards(location, round, {cardId});
  }

  /// One round response for this recovery batch. Return only targets whose
  /// response is still authoritative, so stale reads cannot clear job journals.
  Future<Set<int>> refreshPhotoCards(
    String location,
    int round,
    Set<int> cardIds,
  ) async {
    _checkCurrent();
    if (cardIds.isEmpty) return const {};
    final state = _state(location, round);
    final queries = <int, int>{};
    for (final id in cardIds) {
      final key = (location, round, id);
      queries[id] = _photoQueries[key] = (_photoQueries[key] ?? 0) + 1;
    }
    final result = await _http.getLlmCards(
      worldId: worldId,
      locationId: location,
      conversationRoundId: round,
    );
    _checkCurrent();
    final currentIds = {
      for (final entry in queries.entries)
        if (_photoQueries[(location, round, entry.key)] == entry.value)
          entry.key,
    };
    if (currentIds.isEmpty) return const {};
    final returned = {for (final card in result.list) card.cardId: card};
    if (currentIds.any((id) => !returned.containsKey(id))) {
      throw StateError(GenesisL10n.current.chatPhotoUnavailable);
    }
    // Initialization may apply the group only while all requested versions
    // remain current. Otherwise apply solely the non-stale target slots.
    if (currentIds.length == queries.length &&
        (state._cards.isEmpty || state.provisional && !state.generating)) {
      await _applyCards(state, result);
      return currentIds;
    }
    var changed = false;
    for (final id in currentIds) {
      final index = state._cards.indexWhere((c) => c.cardId == id);
      final card = index < 0
          ? returned[id]!
          : _mergeCardPhotos(state._cards[index], returned[id]!);
      if (index >= 0 && _samePhotoCard(state._cards[index], card)) continue;
      if (index < 0) {
        state._cards.add(card);
      } else {
        state._cards[index] = card;
      }
      changed = true;
    }
    if (changed) {
      state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
      _invalidateCardsCache(state);
      _notify(location);
      await _persist(state);
    }
    return currentIds;
  }

  // GET cards also carries text generation metadata. A photo read must not
  // replace an already known text attempt (or its local stream decoding
  // provenance), even when the response describes the same visible text with
  // different request/attempt fields. Text events and normal card recovery
  // remain authoritative for text changes; this path owns only live_photo.
  ChatroomLlmCard _mergeCardPhotos(
    ChatroomLlmCard current,
    ChatroomLlmCard incoming,
  ) => ChatroomLlmCard(
    cardId: current.cardId,
    cardIndex: current.cardIndex,
    isOriginal: current.isOriginal,
    generationState: current.generationState,
    canEdit: current.canEdit,
    canDelete: current.canDelete,
    messages: [
      ...current.messages.where((m) => m.message.type != 'live_photo'),
      ...incoming.messages.where((m) => m.message.type == 'live_photo'),
    ]..sort((a, b) => a.cardMessageIndex.compareTo(b.cardMessageIndex)),
    billing: current.billing,
    createdAt: current.createdAt,
    rawJson: current.rawJson,
    error: current.error,
  );

  bool _samePhotoCard(ChatroomLlmCard a, ChatroomLlmCard b) =>
      a.cardId == b.cardId &&
      a.cardIndex == b.cardIndex &&
      a.isOriginal == b.isOriginal &&
      a.generationState == b.generationState &&
      a.canEdit == b.canEdit &&
      a.canDelete == b.canDelete &&
      a.createdAt == b.createdAt &&
      a.billing.status == b.billing.status &&
      a.billing.priceCent == b.billing.priceCent &&
      a.billing.pricingVersion == b.billing.pricingVersion &&
      _ReplyCardPerformance._sameJson(a.error, b.error) &&
      _ReplyCardPerformance._sameJson(a.rawJson, b.rawJson) &&
      a.messages.length == b.messages.length &&
      Iterable<int>.generate(a.messages.length).every(
        (i) =>
            a.messages[i].isLlmStreamMessage ==
                b.messages[i].isLlmStreamMessage &&
            _ReplyCardPerformance._sameJson(
              a.messages[i].message.toJson(),
              b.messages[i].message.toJson(),
            ),
      );

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
}
