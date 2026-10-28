part of 'world_chatroom_service.dart';

/// Correlation/presentation state only. All deadlines belong to sendGate.
class _ChatroomStreamWatch {
  _ChatroomStreamWatch({
    required this.operation,
    this.clientMsgId = '',
    this.roundId = '',
  });
  final ChatSendOperation operation;
  final String clientMsgId;
  String roundId;
  bool started = false;
  bool ended = false;
  bool timedOut = false;
  bool accepted = false;
  bool interrupted = false;
}

extension _WorldChatroomStreamWatchdog on WorldChatroomService {
  void _bindStreamWatch(String location, String round) {
    if (round.isEmpty) return;
    var watch = _streamWatches[location];
    if (watch == null || (watch.roundId.isNotEmpty && watch.roundId != round)) {
      if (_streamLocallyEnded(location, round)) return;
      final previous = int.tryParse(watch?.roundId ?? '') ?? 0;
      if (previous > 0 && (int.tryParse(round) ?? 0) <= previous) return;
      final operation =
          _replyActionsController?.sendOperationForRound(location, round) ??
          sendGate.forRound(_worldId, location, round) ??
          beginSendWait(location, 'round:$round', 'conversation_wait');
      watch = _ChatroomStreamWatch(operation: operation, roundId: round);
      _streamWatches[location] = watch;
      final captured = watch;
      operation.onRelease(() => _expireStreamWatch(location, captured));
    }
    watch.roundId = round;
    watch.operation.diagnostics['round_id'] = round;
    watch.operation.progress(('round', round), phase: 'awaiting_stream');
    if (watch.timedOut || watch.operation.released) {
      _locallyEndedStreamRounds[(location, round)] = DateTime.now().add(
        _closedConversationRoundRetention,
      );
      _replyActionsController?.finishLocallyStalledStream(location, round);
    }
  }

  bool _streamLocallyEnded(String location, String round) {
    final watch = _streamWatches[location];
    if (watch?.roundId == round && watch!.operation.released) return true;
    if (sendGate.find(_worldId, location, 'round:$round')?.released ?? false) {
      return true;
    }
    final now = DateTime.now();
    _locallyEndedStreamRounds.removeWhere((_, expiry) => !expiry.isAfter(now));
    return _locallyEndedStreamRounds.containsKey((location, round));
  }

  _ChatroomStreamWatch? _watchForStream(String location, String round) {
    if (location.isEmpty ||
        round.isEmpty ||
        _streamLocallyEnded(location, round)) {
      return null;
    }
    final active = _state.conversationRoundStatesByLocation[location];
    if (active != null &&
        active.conversationRoundId.isNotEmpty &&
        active.conversationRoundId != round) {
      return null;
    }
    _bindStreamWatch(location, round);
    final watch = _streamWatches[location];
    return watch?.roundId == round && !watch!.operation.released ? watch : null;
  }

  void _noteStreamActivity(
    String location,
    String round, {
    required String streamId,
    required Object frameId,
    String? generationKey,
    int? attemptNo,
  }) {
    final watch = _watchForStream(location, round);
    if (watch == null) return;
    watch.started = true;
    watch.ended = false;
    watch.operation.stream(
      streamId,
      frameId,
      generationKey: generationKey,
      attemptNo: attemptNo,
    );
  }

  void _noteStreamEnd(
    String location,
    String round, {
    required String streamId,
  }) {
    final watch = _watchForStream(location, round);
    if (watch == null) return;
    watch.operation.stream(streamId, 'end', end: true);
    watch.ended = !watch.operation.streaming;
    if (watch.ended &&
        !_state.conversationRoundStatesByLocation.containsKey(location) &&
        _replyActionsController?.sendOperationForRound(location, round) ==
            null) {
      watch.operation.finish();
    }
  }

  void _expireStreamWatch(String location, _ChatroomStreamWatch watch) {
    if (_disposed) return;
    watch.ended = true;
    watch.timedOut = true;
    if (watch.clientMsgId.isNotEmpty && !watch.accepted) {
      _session?.cancelSendMessageWait(watch.clientMsgId);
    }
    final round = watch.roundId;
    if (round.isNotEmpty) {
      _locallyEndedStreamRounds[(location, round)] = DateTime.now().add(
        _closedConversationRoundRetention,
      );
    }
    for (final generation in _llmGenerations.values) {
      if (generation.id.location == location && generation.id.round == round) {
        for (final attempt in generation.attempts.values) {
          attempt.waitingExpired = true;
        }
      }
    }
    final messages = <WorldChatroomMessage>[
      for (final message
          in _state.messagesByLocation[location] ??
              const <WorldChatroomMessage>[])
        if (round.isNotEmpty &&
            message.conversationRoundId == round &&
            message.streaming)
          message.copyWith(streaming: false),
    ];
    for (final accumulator in _streamAccumulators.values) {
      final message = accumulator.message;
      if (round.isNotEmpty &&
          message.locationId == location &&
          message.conversationRoundId == round) {
        accumulator.message = message.copyWith(streaming: false);
        messages.add(accumulator.message);
      }
    }
    if (messages.isNotEmpty) _upsertMessages(messages, persist: false);
    _replyActionsController?.finishLocallyStalledStream(location, round);
    final current = _state.conversationRoundStatesByLocation[location];
    if (current != null &&
        ((watch.clientMsgId.isNotEmpty &&
                current.clientMsgId == watch.clientMsgId) ||
            (round.isNotEmpty && current.conversationRoundId == round))) {
      _clearConversationRound(
        location,
        expectedGeneration: current.generation,
        action: 'sendGateReleased',
      );
    }
    _setState(_state);
  }

  void _interruptStreamWatches() {
    // Disconnect is not progress and cannot extend an existing deadline.
    for (final watch in _streamWatches.values) {
      watch.interrupted = true;
    }
    sendGate.reconcile();
  }

  void _clearStreamWatches() {
    // Session-owned operations survive page/service reconstruction. The next
    // owner attaches to the same request identity instead of restarting time.
    _entrySendWaits.clear();
    _streamWatches.clear();
    _locallyEndedStreamRounds.clear();
  }
}
