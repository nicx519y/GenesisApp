part of 'location_chat_scroll_coordinator.dart';

class _OutgoingAttempt {
  _OutgoingAttempt(
    this.attempt,
    this.messages,
    this.index,
    this.release, {
    this.cardId,
    this.cardBindingIdentity,
  });
  final LlmAttempt attempt;
  final List<ChatMessageVm> messages;
  final int index;
  final VoidCallback release;
  final int? cardId;
  final Object? cardBindingIdentity;

  bool belongsToCard(int id, Object? binding) =>
      cardId == id && cardBindingIdentity == binding;
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
    if (attempt.generation.card != null) {
      _regenerateWaitingOperation =
          _LocationChatAnchoredMessageListState._replyWaitingOperation(widget);
    }
    final source = _renderedMessages;
    final card = _currentReplyCard;
    final cardReceipts = card?.messages.map(_receiptIdentity).toSet() ?? {};
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
      // Go On replies can follow the previous round's original (card 0)
      // deck. Ordinary generation provenance does not make them part of it.
      cardId: snapshots.any((m) => cardReceipts.contains(_receiptIdentity(m)))
          ? card?.id
          : null,
      cardBindingIdentity: widget.replyCardBindingIdentity,
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
              o.belongsToCard(cardId, widget.replyCardBindingIdentity),
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

  void _releaseRetractions({bool candidatesOnly = false}) {
    bool shouldRelease(LlmAttempt attempt) =>
        !candidatesOnly || attempt.generation.card != null;
    for (final attempt
        in _attemptListeners.keys.where(shouldRelease).toList()) {
      attempt.removeListener(_attemptListeners.remove(attempt)!);
    }
    _retrySources.removeWhere((_, attempt) => shouldRelease(attempt));
    for (final attempt
        in _outgoingAttempts.keys.where(shouldRelease).toList()) {
      _outgoingAttempts.remove(attempt)!.release();
    }
  }
}
