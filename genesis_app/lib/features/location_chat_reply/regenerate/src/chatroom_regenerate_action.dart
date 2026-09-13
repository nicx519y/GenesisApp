part of '../../../../network/chatroom/chatroom_reply_actions_controller.dart';

/// Internal implementation. Callers only see the regenerate feature contract.
extension ChatroomRegenerateFeatureImplementation
    on ChatroomReplyActionsController {
  Future<void> regenerate(String locationId) async {
    await restore(locationId);
    final state = await _target(locationId);
    if (!state.canRegenerate) {
      throw StateError('This round cannot be regenerated');
    }
    _invalidateCardsCache(state);
    final dispatchGeneration = ++state._regenerationDispatchGeneration;
    state._regenerateDispatching = true;
    state._regenerationRequestUncertain = false;
    ++state._generation;
    state._error = null;
    final oldView = _completeCard(state.viewedCard)
        ? state._viewedCardId
        : state._lastCompleteCardId;
    final originalMessages = state.formalReplyMessages;
    _notify(state.locationId);
    var dispatched = false;
    var candidatePrepared = false;
    var receiptReceived = false;
    String? requestId;
    try {
      if (state._cards.where((card) => card.cardId > 0).length >= 10 ||
          state._cards.any(
            (card) => card.cardId > 0 && !_terminal(card.generationState),
          )) {
        throw StateError('This round cannot be regenerated');
      }
      if (!state._eligible || state.frozen) {
        throw StateError('The source round changed');
      }
      final pendingIndex = state._cards.isEmpty
          ? 2
          : state._cards.fold<int>(
                  0,
                  (v, c) => c.cardIndex > v ? c.cardIndex : v,
                ) +
                1;
      if (state._cards.isEmpty) {
        // ID zero is a local preview only; it is never submitted as a card ID.
        state._cards.add(
          _placeholder(
            0,
            1,
            generationState: ChatroomCardGenerationState.succeeded,
          ),
        );
      }
      state._cards.add(_placeholder(-1, pendingIndex));
      state._viewedCardId = -1;
      state._presentationRevision++;
      candidatePrepared = true;
      state._generating = true;
      state._regenerationRequestId = requestId = _request('regenerate');
      await _persist(state);
      _notify(state.locationId);
      final session = _requireSession();
      dispatched = true;
      final receipt = await session.regenerateLlmCard(
        locationId: locationId,
        conversationRoundId: state.roundId,
        clientMsgId: state._regenerationRequestId!,
      );
      _checkCurrent();
      if (dispatchGeneration != state._regenerationDispatchGeneration) return;
      receiptReceived = true;
      await _applyRegenerationReceipt(
        state,
        receipt,
        oldView: oldView,
        originalMessages: originalMessages,
        pendingIndex: pendingIndex,
        dispatchGeneration: dispatchGeneration,
      );
    } catch (error) {
      if (!_disposed &&
          dispatchGeneration == state._regenerationDispatchGeneration) {
        state._error = error;
        // Unknown acceptance is checked with GET cards. Keep a server-visible
        // candidate, otherwise release the local placeholder; never resend.
        if (candidatePrepared && !receiptReceived) {
          if (!dispatched || _definiteRejection(error)) {
            state._cards.removeWhere((card) => card.cardId <= 0);
            state._regenerationRequestId = null;
            state._viewedCardId = state._lastCompleteCardId;
          } else {
            state._regenerationRequestUncertain = true;
            try {
              await _loadCards(state, force: true);
            } catch (_) {
              // The original WS error remains the useful user-facing cause.
            }
            // If the authoritative read cannot identify a terminal result,
            // retain the placeholder and request ID. A lost ACK is not proof
            // that regeneration failed, so only later recovery may unlock it.
          }
        }
        if (dispatchGeneration != state._regenerationDispatchGeneration) {
          rethrow;
        }
        state._generating = state._cards.any(
          (card) => !_terminal(card.generationState),
        );
        if (!state._generating) _cancelRegenerationWatchdog(state);
        await _persist(state);
        if (error is ChatroomFailureEvent &&
            isChatroomBalanceFailureCode(error.code) &&
            requestId != null) {
          unawaited(_refreshRejectedReplyBalance(state, requestId));
        }
      }
      rethrow;
    } finally {
      _finishRegenerationDispatch(state, dispatchGeneration);
    }
  }

  void _finishRegenerationDispatch(
    ChatroomReplyRoundState state,
    int dispatchGeneration,
  ) {
    if (_disposed ||
        dispatchGeneration != state._regenerationDispatchGeneration) {
      return;
    }
    state._regenerateDispatching = false;
    _notify(state.locationId);
    if (state.frozen) {
      if ((state._fixedCardId ?? 0) <= 0) {
        state._fixedCardId = state.lastCompleteCardId;
      }
      _background(state, () => finalizeBeforeSend(state.locationId));
    }
  }

  void _receiveLateRegenerationAck(ChatroomAck ack) {
    final receipt = ack.regeneration;
    if (receipt == null ||
        ack.worldId != worldId ||
        ack.locationId.isEmpty ||
        ack.clientMsgId.isEmpty ||
        ack.cardConversationRoundId != receipt.conversationRoundId ||
        (ack.userId.isNotEmpty && ack.userId != ownerUid)) {
      return;
    }
    final state = stateForRound(ack.locationId, receipt.conversationRoundId);
    if (state == null ||
        state._regenerationRequestId != ack.clientMsgId ||
        (state._regenerateDispatching &&
            !state._regenerationRequestUncertain)) {
      return;
    }
    final oldView = _completeCard(state.viewedCard)
        ? state._viewedCardId
        : state._lastCompleteCardId;
    final originalMessages = state.formalReplyMessages;
    final pendingIndex =
        state._card(receipt.cardId)?.cardIndex ??
        state._card(-1)?.cardIndex ??
        state._cards.fold<int>(
              1,
              (index, card) => card.cardIndex > index ? card.cardIndex : index,
            ) +
            1;
    final dispatchGeneration = ++state._regenerationDispatchGeneration;
    ++state._generation;
    _invalidateCardsCache(state);
    state._regenerateDispatching = true;
    state._regenerationRequestUncertain = false;
    _background(state, () async {
      try {
        await _applyRegenerationReceipt(
          state,
          receipt,
          oldView: oldView,
          originalMessages: originalMessages,
          pendingIndex: pendingIndex,
          dispatchGeneration: dispatchGeneration,
        );
      } catch (error) {
        if (!_disposed &&
            dispatchGeneration == state._regenerationDispatchGeneration) {
          state._error = error;
          await _persist(state);
        }
      } finally {
        _finishRegenerationDispatch(state, dispatchGeneration);
      }
    });
  }

  /// Shared by the original request future and a receipt arriving after that
  /// future timed out. Neither path dispatches another generation request.
  Future<void> _applyRegenerationReceipt(
    ChatroomReplyRoundState state,
    ChatroomCardRegeneration receipt, {
    required int oldView,
    required List<WorldChatroomMessage> originalMessages,
    required int pendingIndex,
    required int dispatchGeneration,
  }) async {
    _checkCurrent();
    if (dispatchGeneration != state._regenerationDispatchGeneration) return;
    state._regenerationRequestUncertain = false;
    state._error = null;
    final stillPendingView = state._viewedCardId == -1;
    state._cards.removeWhere((card) => card.cardId == -1);
    if (state._card(receipt.cardId) == null) {
      state._cards.add(
        _placeholder(
          receipt.cardId,
          pendingIndex,
          generationState: receipt.generationState,
        ),
      );
    }
    if (stillPendingView) state._viewedCardId = receipt.cardId;
    if (state._card(receipt.originalCardId) == null) {
      state._cards.removeWhere((card) => card.cardId == 0);
      state._cards.add(
        _assembledCard(
          state,
          receipt.originalCardId,
          1,
          originalMessages,
          billing: const ChatroomCardBilling(
            status: ChatroomCardBillingStatus.notRequired,
          ),
          isOriginal: true,
        ),
      );
      if (state._viewedCardId == 0) {
        state._viewedCardId = receipt.originalCardId;
      }
    }
    state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
    if (oldView == 0 && state._lastCompleteCardId == 0) {
      state._lastCompleteCardId = receipt.originalCardId;
    }
    state._generating = state._cards.any(
      (card) => !_terminal(card.generationState),
    );
    if (state._generating) {
      _watchRegeneration(state, receipt.cardId);
    } else {
      _cancelRegenerationWatchdog(state);
    }
    if (receipt.generationState == ChatroomCardGenerationState.failed) {
      // A successful outer ACK can already contain the failed final state.
      // The real candidate remains a counted attempt; restore the complete
      // card immediately and reconcile its billing/permissions from HTTP.
      state._cards.removeWhere((card) => card.cardId == receipt.cardId);
      state._cards.add(
        _assembledCard(
          state,
          receipt.cardId,
          pendingIndex,
          const [],
          billing: receipt.billing,
          generation: ChatroomCardGenerationState.failed,
          editable: false,
          error: receipt.error,
        ),
      );
      state._cards.sort((a, b) => a.cardIndex.compareTo(b.cardIndex));
      state._authoritativeCards.add(receipt.cardId);
      state._streamMessages.remove(receipt.cardId);
      if (state._viewedCardId == receipt.cardId || state._viewedCardId == -1) {
        state._viewedCardId = oldView == 0 ? receipt.originalCardId : oldView;
        state._presentationRevision++;
      }
      state._generating = false;
      state._regenerateDispatching = false;
      state._regenerationRequestId = null;
      _cancelRegenerationWatchdog(state);
      state._error = ChatroomFailureEvent(
        code: chatroomCardFailureCode(receipt.error).toString(),
        message: chatroomCardFailureMessage(receipt.error),
        requestType: 'regenerate_llm_card',
        sourceType: 'ack',
        cause: receipt,
      );
      _notify(state.locationId);
      _background(
        state,
        () => _refreshRegenerationOutcome(
          state,
          receipt.cardId,
          reloadCards: true,
        ),
      );
    } else if (receipt.generationState ==
        ChatroomCardGenerationState.succeeded) {
      // Idempotent receipt replay does not replay streams or terminal events.
      state._regenerationRequestId = null;
      try {
        await _loadCards(state, force: true);
      } catch (_) {
        // Receipt replay proves success but contains no body. Keep the
        // actual candidate for a later read and display the complete source.
        if (dispatchGeneration == state._regenerationDispatchGeneration &&
            state._viewedCardId == receipt.cardId &&
            !_completeCard(state.viewedCard)) {
          state._viewedCardId = oldView == 0 ? receipt.originalCardId : oldView;
          state._presentationRevision++;
        }
        rethrow;
      } finally {
        await _refreshRegenerationOutcome(
          state,
          receipt.cardId,
          reloadCards: false,
        );
      }
    }
    await _persist(state);
  }
}
