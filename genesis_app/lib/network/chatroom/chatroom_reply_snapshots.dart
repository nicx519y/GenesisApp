part of 'chatroom_reply_actions_controller.dart';

const _replySnapshotVersion = 1;
const _replyCapabilityVersion = 5;

extension ChatroomReplySnapshots on ChatroomReplyActionsController {
  /// Value snapshot for a history batch. Never used as an action target.
  ChatroomReplyRoundState? snapshotForPresentation(String locationId) =>
      _snapshotReplyState(presentationStateFor(locationId));

  ChatroomReplyRoundState? snapshotForActions(String locationId) =>
      _snapshotReplyState(stateFor(locationId));

  ChatroomReplyRoundState? _snapshotReplyState(
    ChatroomReplyRoundState? source,
  ) {
    if (source == null) return null;
    final copy =
        ChatroomReplyRoundState._(this, source.locationId, source.roundId)
          .._conversationType = source._conversationType
          .._triggerUid = source._triggerUid
          .._metadataConflict = source._metadataConflict
          .._invalidated = source._invalidated
          .._active = source._active
          .._ended = source._ended
          .._roundFailed = source._roundFailed
          .._generating = source.generating
          .._busy = source._busy
          .._frozen = source._frozen
          .._confirmed = source._confirmed
          .._retainSelectedCardPresentation =
              source._retainSelectedCardPresentation
          .._selectedCardPromotedToFormal = source._selectedCardPromotedToFormal
          .._viewedCardId = source._viewedCardId
          .._lastCompleteCardId = source._lastCompleteCardId
          .._selectedCardId = source._selectedCardId
          .._formal = List.unmodifiable(source._formal)
          .._completionRevision = source._completionRevision
          .._snapshotChunkCardIds = Set.unmodifiable({
            for (final card in source.cards)
              if (source.hasCandidateChunk(card.cardId)) card.cardId,
          })
          .._presentationRevision = source._presentationRevision
          .._snapshotLatest = source.isLatest
          .._cardsResponse = source._cardsResponse
          .._goOn = source._goOn == null
              ? null
              : _PendingGoOn.fromJson(source._goOn!.toJson());
    copy._cards.addAll(source._cards);
    copy._snapshotMessages = {
      for (final card in source.cards)
        card.cardId: List.unmodifiable(source.messagesForCard(card.cardId)),
    };
    copy._performance.synchronize(copy);
    return copy;
  }

  List<ChatroomReplyRoundState> snapshotRetainedPresentations(
    String locationId,
  ) => List.unmodifiable([
    for (final state in statesFor(locationId))
      if (state.selectedCardAwaitingFormalHistory) _snapshotReplyState(state)!,
  ]);

  /// Clear display state without deleting drafts or pending operation receipts.
  Future<void> forgetCachedPresentation(String locationId) async {
    for (final state in statesFor(locationId)) {
      _cancelRegenerationWatchdog(state);
      state._generation++;
      _invalidateCardsCache(state);
      state._formal = const [];
      state._cards.clear();
      state._streamMessages.clear();
      state._cardsResponse = null;
      state._viewedCardId = 0;
      state._lastCompleteCardId = 0;
      state._selectedCardId = 0;
      state._confirmed = false;
      state._retainSelectedCardPresentation = false;
      state._selectedCardPromotedToFormal = false;
    }
    _latest.remove(locationId);
    await _writes;
    _notify(locationId);
  }

  /// Service queues are authoritative for which historical rounds remain retained.
  void reconcileRetainedRounds(
    String locationId,
    Set<int> retained,
    Set<int> active,
  ) {
    for (final state in statesFor(locationId)) {
      if (retained.contains(state.roundId) || active.contains(state.roundId)) {
        continue;
      }
      if (state._formal.isEmpty) continue;
      state._generation++;
      _invalidateCardsCache(state);
      state._formal = const [];
      state._cards.clear();
      state._cardsResponse = null;
      state._retainSelectedCardPresentation = false;
      state._streamMessages.clear();
    }
    final latest = stateFor(locationId);
    if (latest != null &&
        !retained.contains(latest.roundId) &&
        !active.contains(latest.roundId) &&
        !latest.goOnPending) {
      final rounds = {...retained, ...active}.toList()..sort();
      if (rounds.isEmpty) {
        _latest.remove(locationId);
      } else {
        _latest[locationId] = rounds.last;
      }
    }
    _notify(locationId);
  }

  bool historyCardsResolved(String locationId) {
    final state = stateFor(locationId);
    if (state == null || !state._isOwnSupportedRound || !state.complete) {
      return true;
    }
    return state._cardsResponse != null || state.hasCardGroup;
  }

  Future<void> persistHistorySupport(String locationId) async {
    final state = stateFor(locationId);
    if (state != null && state._formal.isNotEmpty && state.complete) {
      // A completed ordinary reply also has an explicit empty deck.
      state._cardsResponse ??= ChatroomLlmCardsResponse(
        conversationRoundId: state.roundId,
        originalCardId: 0,
        selectedCardId: 0,
        activeCardId: 0,
        confirmed: state.confirmed,
        canRegenerate: state.supportsRegenerate,
        canConfirm: false,
        list: const [],
        total: 0,
        rawJson: const {},
      );
      await _persist(state);
    }
  }

  bool _matchesSnapshotSource(
    ChatroomReplyRoundState state,
    Map<String, dynamic> json,
  ) {
    if (json['snapshot_version'] != null &&
        json['snapshot_version'] != _replySnapshotVersion) {
      return false;
    }
    final source = json['source_messages'];
    if (source is! Map) {
      return true; // Legacy snapshots are verified by normal history reads.
    }
    for (final message in state._formal) {
      final previous = source['${message.globalMessageId}'];
      if (previous == null || previous != message.content) return false;
    }
    return true;
  }

  Map<String, dynamic>? _storedSnapshot(ChatroomReplyRoundState state) {
    if (state._formal.isEmpty) return null;
    final completeCards = state._cards.every(
      (card) => card.cardId > 0 && _terminal(card.generationState),
    );
    // Preserve the last complete durable deck while a candidate is streaming.
    if (!completeCards || state.generating) return null;
    final hasSnapshot =
        completeCards &&
        (state._cards.isNotEmpty || state._cardsResponse != null);
    return {
      'snapshot_version': _replySnapshotVersion,
      'capability_version': _replyCapabilityVersion,
      'round_id': state.roundId,
      'conversation_type': state.conversationType,
      'trigger_uid': state.triggerUid,
      'metadata_conflict': state._metadataConflict,
      'round_failed': state._roundFailed,
      'invalidated': state._invalidated,
      'viewed_card_id': state.viewedCardId,
      'last_complete_card_id': state.lastCompleteCardId,
      'confirmed': state.confirmed,
      'retain_selected_presentation': state._retainSelectedCardPresentation,
      'selected_promoted_to_formal': state._selectedCardPromotedToFormal,
      'needs_refresh': state._cardsNeedRefresh,
      'cards_resolved': hasSnapshot || !state._isOwnSupportedRound,
      'source_messages': {
        for (final message in state._formal)
          '${message.globalMessageId}': message.content,
      },
      'supported_actions': {
        'regenerate': state.supportsRegenerate,
        'go_on': state.supportsGoOn,
        'edit': state.supportsEdit,
        'inspiration': state.supportsInspiration,
      },
      if (hasSnapshot) ...{
        'cards_cache': {
          'conversation_round_id': state.roundId,
          'original_card_id':
              state._cards
                  .where((card) => card.isOriginal)
                  .firstOrNull
                  ?.cardId ??
              0,
          'selected_card_id': state.selectedCardId,
          'active_card_id': 0,
          'confirmed': state.confirmed,
          'can_regenerate': state.supportsRegenerate,
          'can_confirm': state.hasCardGroup && !state.confirmed,
          'total': state._cards.length,
          'list': state._cards.map(_storedCard).toList(),
        },
        // Local provenance is not part of the server's wire schema.
        'stream_message_ids': [
          for (final card in state.cards)
            for (final message in card.messages)
              if (message.isLlmStreamMessage) message.globalMessageId,
        ],
      },
    };
  }

  Map<String, dynamic> _storedCard(ChatroomLlmCard card) => {
    'card_id': card.cardId,
    'card_index': card.cardIndex,
    'is_original': card.isOriginal,
    'generation_state': card.generationState.name,
    'can_edit': card.canEdit,
    'can_delete': card.canDelete,
    'created_at': card.createdAt,
    if (card.error != null)
      'error':
          card.error is Map ||
              card.error is List ||
              card.error is String ||
              card.error is num ||
              card.error is bool
          ? card.error
          : '${card.error}',
    'billing': {
      'status': switch (card.billing.status) {
        ChatroomCardBillingStatus.notRequired => 'not_required',
        ChatroomCardBillingStatus.notStarted => 'not_started',
        final status => status.name,
      },
      if (card.billing.priceCent != null) 'price_cent': card.billing.priceCent,
      if (card.billing.pricingVersion != null)
        'pricing_version': card.billing.pricingVersion,
    },
    'messages': [
      for (final message in card.messages)
        {
          ...message.message.toJson()
            ..remove('message_id')
            ..remove('location_message_id'),
          'stream_type': '',
          'card_id': card.cardId,
          'card_message_index': message.cardMessageIndex,
        },
    ],
  };

  ChatroomLlmCardsResponse _decodeStoredCards(Map<String, dynamic> json) {
    final result = ChatroomLlmCardsResponse.fromJson(json['cards_cache']);
    final streams =
        (json['stream_message_ids'] as List?)?.whereType<int>().toSet() ??
        <int>{};
    if (streams.isEmpty) return result;
    return ChatroomLlmCardsResponse(
      conversationRoundId: result.conversationRoundId,
      originalCardId: result.originalCardId,
      selectedCardId: result.selectedCardId,
      activeCardId: result.activeCardId,
      confirmed: result.confirmed,
      canRegenerate: result.canRegenerate,
      canConfirm: result.canConfirm,
      total: result.total,
      rawJson: result.rawJson,
      list: [
        for (final card in result.list)
          ChatroomLlmCard(
            cardId: card.cardId,
            cardIndex: card.cardIndex,
            isOriginal: card.isOriginal,
            generationState: card.generationState,
            canEdit: card.canEdit,
            canDelete: card.canDelete,
            billing: card.billing,
            createdAt: card.createdAt,
            rawJson: card.rawJson,
            error: card.error,
            messages: [
              for (final message in card.messages)
                ChatroomLlmCardMessage(
                  message: message.message,
                  cardId: message.cardId,
                  cardMessageIndex: message.cardMessageIndex,
                  rawJson: message.rawJson,
                  isLlmStreamMessage: streams.contains(message.globalMessageId),
                ),
            ],
          ),
      ],
    );
  }
}
