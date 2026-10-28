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

extension on _LocationChatReplyConnectionAction {
  String get failureMessage => switch (this) {
    _LocationChatReplyConnectionAction.regenerate =>
      GenesisL10n.current.chatRegenerateFailure,
    _LocationChatReplyConnectionAction.goOn =>
      GenesisL10n.current.chatGoFailure,
    _LocationChatReplyConnectionAction.edit =>
      GenesisL10n.current.chatEditFailure,
    _LocationChatReplyConnectionAction.inspiration =>
      GenesisL10n.current.chatInspirationFailure,
  };
}

final class _LocationChatConnectionGate {
  const _LocationChatConnectionGate({
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
    if (service.state.connected &&
        service.state.joinedLocationId == locationId) {
      onJoined();
      return;
    }

    // WorldChatroomService.join is the single connection/join primitive: it
    // coalesces an active connect and an active join internally. The page-level
    // join future additionally shares this request with lifecycle auto-join.
    if (!await join() ||
        !service.state.connected ||
        service.state.joinedLocationId != locationId) {
      throw ChatroomPreflightException(
        GenesisL10n.current.chatConnectionFailed,
      );
    }
    _checkCurrent();
    onJoined();
  }

  void _checkCurrent() {
    if (!isCurrent() || service.isDisposed) {
      throw StateError(GenesisL10n.current.chatInactive);
    }
  }
}

extension _LocationChatReplyConnection on _LocationChatPanelState {
  void _showReplyActionFailure(
    Object error,
    _LocationChatReplyConnectionAction action,
  ) {
    final message = chatroomOperationErrorMessage(error);
    if (message.isEmpty) {
      showGenesisToast(context, action.failureMessage);
    } else if (!isChatroomErrorPresentedGlobally(error)) {
      showGenesisToast(context, message);
    }
  }

  Future<void> _openChatConnectionGate({
    required WorldChatroomService service,
    required bool Function() isCurrent,
  }) => _LocationChatConnectionGate(
    service: service,
    locationId: widget.locationId,
    isCurrent: isCurrent,
    join: () => _joinLocation(service),
    onJoined: () => _joinedLocation = true,
  ).open();

  Future<void> _checkReplyActionConnection({
    required WorldChatroomService service,
    required bool Function() isCurrent,
  }) async {
    final hasNetwork = await _hasNetworkForSend();
    if (!isCurrent()) throw StateError(GenesisL10n.current.chatInactive);
    if (!hasNetwork) {
      throw ChatroomPreflightException(
        GenesisL10n.current.chatNoNetworkConnection,
      );
    }
    try {
      await _openChatConnectionGate(service: service, isCurrent: isCurrent);
    } catch (_) {
      if (!isCurrent()) rethrow;
      throw ChatroomPreflightException(
        GenesisL10n.current.chatConnectionFailed,
      );
    }
  }

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
    final wait = _beginPageWait(
      transaction.action == _LocationChatReplyConnectionAction.inspiration
          ? 'inspiration'
          : 'reply_prepare',
    );
    wait.phase = 'connecting';
    _replyPreparationWait = wait;
    wait.diagnostics['reply_action'] = transaction.action.name;
    final connectionService = _service;
    final connectionGeneration = connectionService?.connectionWaitGeneration;
    wait.onRelease(() {
      if (wait.phase == 'connecting') {
        connectionService?.abandonConnectionWait(
          expectedGeneration: connectionGeneration,
        );
      }
      if (!mounted || generation != _replyConnectionActionGeneration) return;
      if (wait.phase == 'connecting' && widget.active) {
        showGenesisToast(context, context.l10n.chatConnectionFailed);
      }
      if (transaction.action ==
          _LocationChatReplyConnectionAction.inspiration) {
        _resetInspiration();
      }
      _replyOperationGeneration++;
      _replyConnectionActionGeneration++;
      _setReplyControlsState(() {
        _replyConnectionAction = null;
        _replyConnectionActionRoundId = null;
        _preparingReplyAction = false;
        _replyRequestLoading = false;
        _inspirationLoading = false;
      });
    });
    try {
      final service = _service;
      if (service == null || !widget.isLeafLocation) {
        throw StateError(GenesisL10n.current.chatChatroomUnavailable);
      }
      await wait.guard(
        _checkReplyActionConnection(
          service: service,
          isCurrent: () => operation.canApplyToReply,
        ),
      );
      wait.check();
      wait.progress('joined', phase: 'preparing');
      if (!operation.canApplyToReply ||
          generation != _replyConnectionActionGeneration) {
        transaction.onFailure?.call(
          StateError(GenesisL10n.current.chatFailedConfirmReplyAction),
        );
        return;
      }
      await wait.guard(transaction.commit());
    } catch (error) {
      if (error is ChatSendWaitReleased) return;
      transaction.onFailure?.call(error);
      if (mounted &&
          operation.canApplyToReply &&
          generation == _replyConnectionActionGeneration) {
        _showReplyActionFailure(error, transaction.action);
      }
    } finally {
      wait.finish();
      if (identical(_replyPreparationWait, wait)) _replyPreparationWait = null;
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
