part of '../../../../network/chatroom/chatroom_reply_actions_controller.dart';

/// Internal implementation. Callers only see the Go On feature contract.
extension ChatroomGoOnFeatureImplementation on ChatroomReplyActionsController {
  Future<ChatroomGoOnReceipt> goOn(String locationId) async {
    await restore(locationId);
    final state = await _target(locationId);
    if (!state.canGoOn) throw StateError('This round cannot continue');
    final dispatchGeneration = ++state._goOnDispatchGeneration;
    final requestId = _request('go-on');
    // Block a second tap synchronously, before any save/select awaits.
    state._goOn = _PendingGoOn(requestId);
    state._error = null;
    _notify(state.locationId);
    var dispatched = false;
    try {
      await finalizeBeforeSend(locationId);
      if (!state._eligible || _isTickLocked()) {
        throw StateError('The source round changed');
      }
      state._busy = true;
      await _persist(state);
      final session = _requireSession();
      dispatched = true;
      final receipt = await session.goOn(
        locationId: locationId,
        sourceConversationRoundId: state.roundId,
        clientMsgId: state._goOn!.clientMsgId,
      );
      _checkCurrent();
      if (dispatchGeneration != state._goOnDispatchGeneration) return receipt;
      state._goOn!.roundId = receipt.conversationRoundId;
      final next = _state(locationId, receipt.conversationRoundId);
      if (!next._ended) {
        next._active = true;
        _onGoOnAccepted?.call(locationId, receipt.conversationRoundId);
      }
      state._goOn!.ended = next._ended;
      if (receipt.conversationRoundId > (_latest[locationId] ?? 0)) {
        _latest[locationId] = receipt.conversationRoundId;
      }
      await _persist(state);
      if (next._ended) {
        await _recoverGoOn(state);
      } else {
        _watchGoOn(
          state,
          streamStarted:
              next._formal.any((message) => message.streaming) ||
              next._formal.any(_isReply),
        );
      }
      return receipt;
    } catch (error) {
      if (!_disposed && dispatchGeneration == state._goOnDispatchGeneration) {
        state._error = error;
        if (!dispatched || _definiteRejection(error)) {
          state._goOn = null;
        } else {
          state._goOn!.uncertain = true;
        }
        await _persist(state);
        if (error is ChatroomFailureEvent &&
            isChatroomBalanceFailureCode(error.code)) {
          unawaited(_refreshRejectedReplyBalance(state, requestId));
        }
        if (state._goOn case final pending?
            when pending.uncertain && !pending.finished) {
          // A refresh without a correlated terminal result cannot prove that
          // this non-idempotent request failed. Keep the receipt pending so a
          // late event or reconnect recovery can resolve it without resending.
          if (!_disposed && identical(state._goOn, pending)) {
            await _persist(state);
          }
        }
      }
      rethrow;
    } finally {
      if (dispatchGeneration == state._goOnDispatchGeneration) {
        state._busy = false;
      }
      _notify(state.locationId);
    }
  }
}
