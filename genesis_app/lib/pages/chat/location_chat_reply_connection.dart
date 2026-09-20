part of 'location_chat_page.dart';

enum _LocationChatReplyConnectionAction { regenerate, goOn, edit, inspiration }

final class _LocationChatReplyActionTransaction {
  const _LocationChatReplyActionTransaction({
    required this.action,
    required this.commit,
    this.onFailure,
  });

  final _LocationChatReplyConnectionAction action;
  final Future<void> Function() commit;
  final void Function(Object error)? onFailure;
}

final class _LocationChatReplyConnectionGate {
  const _LocationChatReplyConnectionGate({
    required this.service,
    required this.locationId,
    required this.isCurrent,
    required this.join,
    required this.onJoined,
  });

  final WorldChatroomService service;
  final String locationId;
  final bool Function() isCurrent;
  final Future<bool> Function() join;
  final VoidCallback onJoined;

  Future<void> open() async {
    _checkCurrent();
    final state = service.state;
    if (!state.connected && state.reconnecting) {
      await _waitForReconnect();
      _checkCurrent();
    }
    if (service.state.joinedLocationId == locationId) {
      onJoined();
      return;
    }

    // WorldChatroomService.join is the single connection/join primitive: it
    // coalesces an active connect and an active join internally. The page-level
    // join future additionally shares this request with lifecycle auto-join.
    if (!await join() || service.state.joinedLocationId != locationId) {
      throw StateError('Failed to join this location');
    }
    _checkCurrent();
    onJoined();
  }

  void _checkCurrent() {
    if (!isCurrent() || service.isDisposed) {
      throw StateError('This chat is no longer active');
    }
  }

  Future<void> _waitForReconnect() async {
    final completer = Completer<void>();
    late final StreamSubscription<WorldChatroomState> stateSubscription;
    late final StreamSubscription<ChatroomFailureEvent> failureSubscription;

    void completeFromState(WorldChatroomState state) {
      if (completer.isCompleted) return;
      if (!isCurrent() || service.isDisposed) {
        completer.completeError(StateError('This chat is no longer active'));
      } else if (state.connected) {
        completer.complete();
      } else if (!state.reconnecting) {
        completer.completeError(StateError('WebSocket reconnection stopped'));
      }
    }

    stateSubscription = service.states.listen(completeFromState);
    failureSubscription = service.failures.listen((failure) {
      if (completer.isCompleted) return;
      if (failure.sourceType == 'connect' || failure.requestType == 'connect') {
        completer.completeError(failure);
      }
    });
    completeFromState(service.state);
    try {
      await completer.future;
    } finally {
      await stateSubscription.cancel();
      await failureSubscription.cancel();
    }
  }
}

extension _LocationChatReplyConnection on _LocationChatPanelState {
  Future<void> _submitReplyAction(
    _LocationChatReplyActionTransaction transaction,
  ) async {
    if (_replyConnectionAction != null) {
      transaction.onFailure?.call(
        StateError('This reply action is no longer available'),
      );
      return;
    }
    final operation = _LocationChatReplyOperationScope(this);
    final generation = ++_replyConnectionActionGeneration;
    final sourceRoundId = _displayReplyState?.roundId;
    _setReplyControlsState(() {
      _replyConnectionAction = transaction.action;
      _replyConnectionActionRoundId = sourceRoundId;
    });
    try {
      final service = _service;
      if (service == null || !widget.isLeafLocation) {
        throw StateError('Chatroom is unavailable');
      }
      await _LocationChatReplyConnectionGate(
        service: service,
        locationId: widget.locationId,
        isCurrent: () => operation.canApplyToReply,
        join: () => _joinLocation(service),
        onJoined: () => _joinedLocation = true,
      ).open();
      if (!operation.canApplyToReply ||
          generation != _replyConnectionActionGeneration) {
        transaction.onFailure?.call(
          StateError('Could not confirm the reply action'),
        );
        return;
      }
      await transaction.commit();
    } catch (error) {
      transaction.onFailure?.call(error);
      if (mounted &&
          operation.canApplyToReply &&
          generation == _replyConnectionActionGeneration &&
          !isChatroomErrorPresentedGlobally(error)) {
        showGenesisToast(context, chatroomOperationErrorMessage(error));
      }
    } finally {
      if (operation.ownsReplyTarget &&
          generation == _replyConnectionActionGeneration) {
        _setReplyControlsState(() {
          _replyConnectionAction = null;
          _replyConnectionActionRoundId = null;
        });
      }
    }
  }
}
