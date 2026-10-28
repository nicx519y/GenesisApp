part of 'location_chat_scroll_coordinator.dart';

// View adapter only: the independent presentation controller owns attempt
// lifetime, projections and waiting policy; this bridge starts animations and
// invalidates the existing scroll layout after their callbacks.
extension _LocationChatStreamRetraction
    on _LocationChatAnchoredMessageListState {
  void _updateReplyPresentation() {
    _replyPresentation.update(
      messages: widget.messages,
      cards: widget.replyCards,
      currentCardId: widget.replyCurrentCardId,
      cardBindingIdentity: widget.replyCardBindingIdentity,
      sessionIdentity: widget.coordinator,
      operationIdentity: widget.waitingPositionIdentity,
      regenerationRevision: widget.replyRegenerationDispatchRevision,
      regenerationInProgress: widget.replyRegenerationInProgress,
      readOnly: widget.readOnlyArchive,
    );
  }

  void _beginAttemptRetraction(LlmAttempt attempt) {
    if (!mounted || !_replyPresentation.canRetract(attempt)) return;
    final source = _renderedMessages;
    final card = _currentReplyCard;
    final cardReceipts = card?.messages.map(_receiptIdentity).toSet() ?? {};
    final snapshots = <ChatMessageVm>[];
    final seen = <Object>{};
    for (final message in [...source, ...?card?.messages]) {
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
    _replyPresentation.beginRetraction(
      attempt,
      snapshots: snapshots,
      index: math.max(0, source.indexWhere((m) => m.llmAttempt == attempt)),
      cardId: snapshots.any((m) => cardReceipts.contains(_receiptIdentity(m)))
          ? card?.id
          : null,
    );
    if (snapshots.isNotEmpty) {
      _replaceRenderedMessages(_inputMessages, rebuild: true);
    }
  }

  void _finishRetractingMessage(LlmAttempt attempt, ChatMessageVm message) {
    if (!mounted) return;
    final result = _replyPresentation.finishMessage(attempt, message);
    if (!result.changed) return;
    if (result.generationFinished) {
      // Prepare the buffered replacement once, including a complete end that
      // arrived during retraction. Card-only messages must also reveal live.
      for (final message in _replyPresentation.incomingMessages) {
        if (message.llmAttempt?.generation == attempt.generation &&
            message.llmAttempt?.invalidated == false) {
          _liveRevealMessageIds.add(_receiptIdentity(message));
          _restoredEntryContent.remove(_streamIdentity(message));
        }
      }
    }
    _replaceRenderedMessages(_inputMessages, rebuild: true);
  }
}
