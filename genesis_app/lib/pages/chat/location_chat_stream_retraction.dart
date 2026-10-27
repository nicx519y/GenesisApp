part of 'location_chat_scroll_coordinator.dart';

class _OutgoingAttempt {
  _OutgoingAttempt(this.attempt, this.messages, this.index, this.release);
  final LlmAttempt attempt;
  final List<ChatMessageVm> messages;
  final int index;
  final VoidCallback release;
}

extension _LocationChatStreamRetraction
    on _LocationChatAnchoredMessageListState {
  void _observeRetractionAttempts() {
    if (widget.readOnlyArchive) return;
    final incoming = <ChatMessageVm>[
      ...widget.messages,
      ...?widget.replyCards
          .where((c) => c.id == widget.replyCurrentCardId)
          .firstOrNull
          ?.messages,
    ];
    final wanted =
        incoming.map((m) => m.llmAttempt).whereType<LlmAttempt>().toSet()
          ..addAll(_outgoingAttempts.keys);
    for (final attempt in _attemptListeners.keys.toList()) {
      if (wanted.contains(attempt)) continue;
      attempt.removeListener(_attemptListeners.remove(attempt)!);
    }
    for (final attempt in wanted) {
      if (_attemptListeners.containsKey(attempt) || attempt.invalidated) {
        continue;
      }
      void listener() => _beginAttemptRetraction(attempt);
      _attemptListeners[attempt] = listener;
      attempt.addListener(listener);
    }
  }

  void _beginAttemptRetraction(LlmAttempt attempt) {
    if (!mounted ||
        !attempt.animateRetraction ||
        _outgoingAttempts.containsKey(attempt)) {
      return;
    }
    _retrySources[attempt.generation] = attempt;
    final source = _renderedMessages;
    final snapshots = <ChatMessageVm>[];
    final seen = <Object>{};
    for (final message in [...source, ...?_currentReplyCard?.messages]) {
      if (message.llmAttempt != attempt ||
          !seen.add(_receiptIdentity(message))) {
        continue;
      }
      final frozen = freezeLocationChatReplyMessage(message);
      if (ChatStreamingEffects.retract(
        context,
        _streamIdentity(message),
        () => _finishRetractingMessage(attempt, frozen),
      )) {
        snapshots.add(frozen);
      }
    }
    if (snapshots.isEmpty) return;
    final index = source.indexWhere((m) => m.llmAttempt == attempt);
    _outgoingAttempts[attempt] = _OutgoingAttempt(
      attempt,
      snapshots,
      math.max(0, index),
      attempt.retainPresentation(),
    );
    _retractionRevision++;
    _replaceRenderedMessages(_inputMessages, rebuild: true);
  }

  void _finishRetractingMessage(LlmAttempt attempt, ChatMessageVm message) {
    if (!mounted) return;
    final outgoing = _outgoingAttempts[attempt];
    if (outgoing == null || !outgoing.messages.remove(message)) return;
    if (outgoing.messages.isEmpty) {
      _outgoingAttempts.remove(attempt);
      outgoing.release();
    }
    _retractionRevision++;
    // A fully buffered end is still a live arrival after the outgoing batch.
    for (final message in widget.messages) {
      if (message.llmAttempt?.generation == attempt.generation &&
          message.llmAttempt?.invalidated == false) {
        _liveRevealMessageIds.add(_receiptIdentity(message));
        _restoredEntryContent.remove(_streamIdentity(message));
      }
    }
    _replaceRenderedMessages(_inputMessages, rebuild: true);
  }

  List<ChatMessageVm> _projectRetractions(
    List<ChatMessageVm> incoming, {
    int? cardId,
  }) {
    if (_outgoingAttempts.isEmpty) return incoming;
    final relevant = _outgoingAttempts.values
        .where(
          (o) =>
              cardId == null ||
              o.attempt.generation.card == cardId ||
              (cardId == 0 && o.attempt.generation.card == null),
        )
        .toList();
    if (relevant.isEmpty) return incoming;
    final generations = relevant.map((o) => o.attempt.generation).toSet();
    final result = incoming
        .where((m) => !generations.contains(m.llmAttempt?.generation))
        .toList();
    for (final outgoing in relevant) {
      final first = incoming.indexWhere(
        (m) => m.llmAttempt?.generation == outgoing.attempt.generation,
      );
      final index = cardId != null
          ? 0
          : (first < 0 ? outgoing.index : first).clamp(0, result.length);
      result.insertAll(index, outgoing.messages);
    }
    return result;
  }

  void _releaseRetractions() {
    for (final entry in _attemptListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _attemptListeners.clear();
    _retrySources.clear();
    for (final outgoing in _outgoingAttempts.values) {
      outgoing.release();
    }
    _outgoingAttempts.clear();
  }
}
