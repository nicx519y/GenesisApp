part of 'world_chatroom_service.dart';

class _ChatroomStreamWatch {
  _ChatroomStreamWatch({this.clientMsgId = '', this.roundId = ''});

  final String clientMsgId;
  String roundId;
  Timer? timer;
  bool started = false;
  bool ended = false;
  bool timedOut = false;
  bool accepted = false;
  bool interrupted = false;
  DateTime? deadlineAt;
}

extension _WorldChatroomStreamWatchdog on WorldChatroomService {
  void _bindStreamWatch(String location, String round) {
    final watch = _streamWatches[location];
    if (watch == null ||
        round.isEmpty ||
        (watch.roundId.isNotEmpty && watch.roundId != round)) {
      return;
    }
    watch.roundId = round;
    if (watch.timedOut) {
      _locallyEndedStreamRounds[(location, round)] = DateTime.now().add(
        _closedConversationRoundRetention,
      );
      _replyActionsController?.finishLocallyStalledStream(location, round);
      if (watch.interrupted) _releaseInterruptedStreamWatch(location, watch);
    }
  }

  bool _streamLocallyEnded(String location, String round) {
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
    final current = _streamWatches[location];
    if (current != null && current.roundId.isEmpty) {
      final active = _state.conversationRoundStatesByLocation[location];
      if (active?.conversationRoundId.isNotEmpty == true &&
          active!.conversationRoundId != round) {
        return null;
      }
      _bindStreamWatch(location, round);
      return current.timedOut ? null : current;
    }
    if (current?.roundId == round) return current;
    // Delayed frames from an older round must not replace the new send's watch.
    final active = _state.conversationRoundStatesByLocation[location];
    if (active != null &&
        active.conversationRoundId.isNotEmpty &&
        active.conversationRoundId != round) {
      return null;
    }
    if (current != null &&
        (int.tryParse(round) ?? 0) <= (int.tryParse(current.roundId) ?? 0)) {
      return null;
    }
    current?.timer?.cancel();
    final next = _ChatroomStreamWatch(roundId: round);
    _streamWatches[location] = next;
    return next;
  }

  void _noteStreamActivity(String location, String round) {
    final watch = _watchForStream(location, round);
    if (watch == null) return;
    watch.ended = false;
    _armStreamWatch(location, watch);
  }

  void _noteStreamEnd(String location, String round) {
    final watch = _watchForStream(location, round);
    if (watch == null) return;
    if (_streamAccumulators.values.any(
      (a) =>
          a.message.locationId == location &&
          a.message.conversationRoundId == round,
    )) {
      return;
    }
    watch.ended = true;
    watch.timer?.cancel();
    watch.timer = null;
  }

  void _armStreamWatch(
    String location,
    _ChatroomStreamWatch watch, {
    bool preserveDeadline = false,
  }) {
    watch.started = true;
    if (_generationPresentationPending(location, watch.roundId)) {
      watch.timer?.cancel();
      watch.timer = null;
      return;
    }
    if (!preserveDeadline || watch.deadlineAt == null) {
      watch.deadlineAt = DateTime.now().add(_streamIdleTimeout);
    }
    watch.timer?.cancel();
    final remaining = watch.deadlineAt!.difference(DateTime.now());
    void expire() {
      if (_disposed || !identical(_streamWatches[location], watch)) return;
      watch.timer = null;
      watch.ended = true;
      watch.timedOut = true;
      for (final generation in _llmGenerations.values) {
        if (generation.id.location == location &&
            generation.id.round == watch.roundId) {
          for (final attempt in generation.attempts.values) {
            attempt.waitingExpired = true;
          }
        }
      }
      if (watch.clientMsgId.isNotEmpty && !watch.accepted) {
        watch.interrupted = true;
        _session?.cancelSendMessageWait(watch.clientMsgId);
      }
      final round = watch.roundId.isNotEmpty
          ? watch.roundId
          : _state
                    .conversationRoundStatesByLocation[location]
                    ?.conversationRoundId ??
                '';
      watch.roundId = round;
      if (round.isNotEmpty) {
        _locallyEndedStreamRounds[(location, round)] = DateTime.now().add(
          _closedConversationRoundRetention,
        );
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
        if (round.isEmpty ||
            message.locationId != location ||
            message.conversationRoundId != round) {
          continue;
        }
        accumulator.message = message.copyWith(streaming: false);
        messages.add(accumulator.message);
      }
      // Presentation-only completion: no fake server end, IDs, billing or
      // successful generation state. A healthy round retains its 30s cleanup
      // deadline, but its timed-out local presentation no longer blocks sends.
      if (messages.isNotEmpty) _upsertMessages(messages, persist: false);
      _replyActionsController?.finishLocallyStalledStream(location, round);
      if (watch.interrupted) _releaseInterruptedStreamWatch(location, watch);
      _setState(_state);
      _recordServiceQueueDebug(
        action: 'streamIdleTimedOut',
        locationId: location,
        details: {'conversationRoundId': round},
      );
    }

    if (remaining <= Duration.zero) {
      expire();
    } else {
      watch.timer = Timer(remaining, expire);
    }
  }

  void _releaseInterruptedStreamWatch(
    String location,
    _ChatroomStreamWatch watch,
  ) {
    final round = watch.roundId;
    if (round.isNotEmpty) {
      _rememberClosedConversationRound(location, round);
      _replyActionsController?.finishLocallyStalledStream(location, round);
    }
    final current = _state.conversationRoundStatesByLocation[location];
    if (current == null) return;
    if ((watch.clientMsgId.isNotEmpty &&
            current.clientMsgId == watch.clientMsgId) ||
        (round.isNotEmpty && current.conversationRoundId == round)) {
      _clearConversationRound(
        location,
        expectedGeneration: current.generation,
        action: 'conversationRoundInterruptedStreamTimedOut',
      );
    }
  }

  void _interruptStreamWatches() {
    for (final entry in _streamWatches.entries.toList()) {
      final watch = entry.value;
      watch.interrupted = true;
      if (watch.timedOut) {
        _releaseInterruptedStreamWatch(entry.key, watch);
      } else if (watch.started && !watch.ended && watch.timer == null) {
        _armStreamWatch(entry.key, watch, preserveDeadline: true);
      }
    }
  }

  void _clearStreamWatches() {
    for (final watch in _streamWatches.values) {
      watch.timer?.cancel();
    }
    _streamWatches.clear();
    _locallyEndedStreamRounds.clear();
  }
}
