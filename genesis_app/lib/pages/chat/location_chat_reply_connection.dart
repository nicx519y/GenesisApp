part of 'location_chat_page.dart';

enum _LocationChatReplyConnectionAction { regenerate, goOn, edit, inspiration }

final class _LocationChatReplyActionTransaction {
  const _LocationChatReplyActionTransaction({
    required this.action,
    required this.commit,
  });

  final _LocationChatReplyConnectionAction action;
  final Future<void> Function() commit;
}

extension on _LocationChatReplyConnectionAction {
  String get failureMessage => switch (this) {
    _LocationChatReplyConnectionAction.regenerate => 'Regenerate failure',
    _LocationChatReplyConnectionAction.goOn => 'Go on failure',
    _LocationChatReplyConnectionAction.edit => 'Edit failure',
    _LocationChatReplyConnectionAction.inspiration => 'Inspiration failure',
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

  Future<void> _submitReplyAction(
    _LocationChatReplyActionTransaction transaction,
  ) async {
    if (_replyConnectionAction != null) return;
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
      await _openChatConnectionGate(
        service: service,
        isCurrent: () => operation.canApplyToReply,
      );
      if (!operation.canApplyToReply ||
          generation != _replyConnectionActionGeneration) {
        return;
      }
      await transaction.commit();
    } catch (error) {
      if (mounted &&
          operation.canApplyToReply &&
          generation == _replyConnectionActionGeneration) {
        _showReplyActionFailure(error, transaction.action);
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
