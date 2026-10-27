part of 'world_chatroom_service.dart';

extension _WorldChatroomGenerationRecovery on WorldChatroomService {
  bool _isAttemptCurrent(LlmAttempt? attempt) {
    if (attempt == null) return true;
    final state = _llmGenerations[attempt.generation];
    return !attempt.invalidated &&
        !(state?.failed ?? false) &&
        !(state?.invalidated.contains(attempt.number) ?? false) &&
        attempt.number >= (state?.latest ?? 0);
  }

  void _observeAttempt(LlmAttempt attempt) {
    // Presentation is not a network frame; never pause or extend stream time.
  }

  void _removeRetractedOutputs(LlmGenerationState generation) {
    bool obsolete(WorldChatroomMessage m) =>
        m.llmAttempt?.generation == generation.id &&
        !_isAttemptCurrent(m.llmAttempt);
    _streamAccumulators.removeWhere((_, a) => obsolete(a.message));
    for (final refresh in _historyRefreshes.values) {
      refresh.liveMessages.removeWhere((_, m) => obsolete(m));
    }
    _setState(
      _state.copyWith(
        worldMessages: _state.worldMessages.where((m) => !obsolete(m)).toList(),
        messagesByLocation: {
          for (final e in _state.messagesByLocation.entries)
            e.key: e.value.where((m) => !obsolete(m)).toList(),
        },
        streamMessagesByKey: Map.of(_state.streamMessagesByKey)
          ..removeWhere((_, m) => obsolete(m)),
      ),
    );
    final owner = _storageOwnerUid;
    final ticket = _historyTicket(generation.id.location);
    unawaited(
      _withLocationWrite(generation.id.location, () async {
        if (!_historyIsCurrent(generation.id.location, ticket) ||
            owner.isEmpty) {
          return;
        }
        await _messageStorage.removeGenerationAttempts(
          ownerUid: owner,
          worldId: generation.id.world,
          locationId: generation.id.location,
          generationKey: generation.id.key,
          shouldRemove: (number) =>
              generation.failed ||
              number < generation.latest ||
              generation.invalidated.contains(number),
          isCurrent: () => _historyIsCurrent(generation.id.location, ticket),
        );
      }).catchError((Object error) {
        _recordFailure(
          ChatroomFailureEvent(
            code: 'message_cache_failed',
            message: 'Something went wrong',
            sourceType: 'message_cache',
            cause: error,
          ),
        );
      }),
    );
  }

  void _handleGenerationState(ChatroomLlmGenerationState event) {
    final id = event.generation;
    if (id.world != _worldId) return;
    if (id.card != null) {
      if (event.state == 'failed' &&
          (_replyActionsController?.generationFailed(id) ?? false)) {
        _recordFailure(
          ChatroomFailureEvent(
            code: '2004',
            message: 'Generation failed',
            sourceType: 'llm_generation_state',
            requestType: 'regenerate_llm_card',
            cause: event,
          ),
        );
      }
      return;
    }
    final state = _llmGenerations.putIfAbsent(id, () => LlmGenerationState(id));
    final changed = state.retract(
      event.retractAttemptNo,
      retrying: event.state == 'retrying',
      next: event.nextAttemptNo,
    );
    _removeRetractedOutputs(state);
    if (!changed) return;
    if (event.state == 'retrying') {
      // Retrying is not a new stream frame.
    } else {
      final watch = _streamWatches[id.location];
      if (watch?.roundId == id.round) {
        watch!.ended = true;
        watch.operation.finish();
      }
      _completeConversationRound(
        locationId: id.location,
        conversationRoundId: id.round,
      );
      _replyActionsController?.failGeneration(id.location, id.round);
      _recordFailure(
        ChatroomFailureEvent(
          code: 'stream_failed',
          message: 'Something went wrong',
          sourceType: 'llm_generation_state',
          cause: event,
        ),
      );
    }
  }

  bool _handleAttemptStream(ChatroomEvent event) {
    final identity = switch (event) {
      ChatroomAiStreamStart e => e.identity,
      ChatroomAiStreamChunk e => e.identity,
      ChatroomAiStreamEnd e => e.identity,
      _ => null,
    };
    if (identity?.attemptNo == null) return false;
    final i = identity!;
    if (i.worldId != _worldId || i.globalMessageId <= 0) return true;
    final id = LlmGenerationId(
      i.worldId,
      i.locationId,
      i.conversationRoundId,
      i.gatewayRequestId,
    );
    final generation = _llmGenerations.putIfAbsent(
      id,
      () => LlmGenerationState(id),
    );
    final previous = generation.latest;
    final attempt = generation.accept(
      i.attemptNo!,
      i.globalMessageId,
      end: event is ChatroomAiStreamEnd,
    );
    if (attempt == null) return true;
    _observeAttempt(attempt);
    attempt.waitingExpired = _streamLocallyEnded(
      i.locationId,
      i.conversationRoundId,
    );
    if (previous != generation.latest &&
        (previous > 0 ||
            generation.attempts.values.any((a) => a.invalidated))) {
      _removeRetractedOutputs(generation);
    }
    _replyActionsController?.receiveEvent(event);
    _notifyHistoryChange(event);
    final key = i.stableKey!;
    final existing = _streamAccumulators[key];
    final WorldChatroomMessage incoming;
    if (event is ChatroomAiStreamStart) {
      incoming = WorldChatroomMessage.fromAiStreamStart(
        event,
      ).copyWith(llmAttempt: attempt);
    } else {
      final chunk = event is ChatroomAiStreamChunk ? event : null;
      final end = event is ChatroomAiStreamEnd ? event : null;
      incoming = WorldChatroomMessage(
        globalMessageId: i.globalMessageId,
        messageId: i.messageId,
        locationMessageId: chunk?.locationMessageId ?? end!.locationMessageId,
        conversationRoundId: i.conversationRoundId,
        locationId: i.locationId,
        conversationType: chunk?.conversationType ?? end!.conversationType,
        triggerUid: chunk?.triggerUid ?? end!.triggerUid,
        roundOrder: 0,
        senderType: chunk?.senderType ?? end!.senderType,
        senderId: i.senderId,
        senderName: chunk?.senderName ?? end!.senderName,
        content: '',
        streaming: true,
        isLlmStreamMessage: true,
        businessType: chunk?.businessType ?? end!.businessType,
        streamType: chunk?.streamType ?? end!.streamType,
        currentTime: chunk?.currentTime ?? end!.currentTime,
        messageType: chunk?.messageType ?? end!.messageType,
        createdAt: end?.createdAt,
        rawPayload: chunk?.rawPayload ?? end!.rawPayload,
        llmAttempt: attempt,
      );
    }
    final accumulator =
        existing ?? _ChatroomStreamAccumulator(message: incoming);
    if (event is ChatroomAiStreamStart && existing != null) return true;
    if (event is ChatroomAiStreamChunk) {
      if (accumulator.chunks.containsKey(event.seq)) return true;
      accumulator.chunks[event.seq] = event.chunk;
      accumulator.message = incoming.copyWith(
        content: accumulator.chunks.values.join(),
      );
    } else if (event is ChatroomAiStreamEnd) {
      accumulator.message = incoming.copyWith(
        content: event.content,
        streaming: false,
      );
    }
    if (event is ChatroomAiStreamEnd) {
      _streamAccumulators.remove(key);
      _noteStreamEnd(i.locationId, i.conversationRoundId, streamId: key);
    } else {
      _streamAccumulators[key] = accumulator;
      if (event is! ChatroomAiStreamChunk || event.chunk.isNotEmpty) {
        _noteStreamActivity(
          i.locationId,
          i.conversationRoundId,
          streamId: key,
          frameId: event is ChatroomAiStreamChunk ? event.seq : 'start',
          generationKey: id.key,
          attemptNo: i.attemptNo,
        );
      }
    }
    _streamWatches[i.locationId]?.operation.diagnostics.addAll({
      'gateway_request_id': i.gatewayRequestId,
      'global_message_id': i.globalMessageId,
    });
    _upsertMessage(
      accumulator.message,
      persist: event is ChatroomAiStreamEnd,
      socketCurrentTime: accumulator.message.currentTime,
    );
    return true;
  }
}
