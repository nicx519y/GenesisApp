part of 'location_chat_page.dart';

extension _LocationChatSendGateBinding on _LocationChatPanelState {
  bool get _tickBlocksSend {
    if (_service?.tickBlocksSend ?? _chatroomState.inputBlocked) return true;
    if (!widget.worldTickInProgress) return false;
    return (_service?.sendGate ?? _pageSendGate)
            ?.beginTick(widget.worldId)
            .blocks ??
        true;
  }

  void _bindSendGate() {
    final next =
        _service?.sendGate ?? AppServicesScope.read(context).chatSendGate;
    if (identical(next, _pageSendGate)) return;
    _pageSendGate?.removeListener(_onSendGateChanged);
    _pageSendGate = next;
    next.addListener(_onSendGateChanged);
  }

  void _onSendGateChanged() {
    if (!mounted) return;
    _setLocationChatState(() {});
  }

  ChatSendOperation _beginPageWait(String scene, {String? id}) {
    _bindSendGate();
    final operation = _pageSendGate!.begin(
      worldId: widget.worldId,
      locationId: widget.locationId,
      operationId:
          id ??
          '$scene:${DateTime.now().microsecondsSinceEpoch}:${++_pageWaitSequence}',
      scene: scene,
    );
    operation.phase = switch (scene) {
      'send_connect' => 'connecting',
      'send_finalize' => 'confirming',
      'reply_presentation' => 'displaying',
      _ => 'preparing',
    };
    return operation;
  }

  Future<T> _guardPageWait<T>(
    String scene,
    Future<T> Function(ChatSendOperation) work,
  ) async {
    final operation = _beginPageWait(scene);
    try {
      final result = await operation.guard(work(operation));
      operation.check();
      return result;
    } finally {
      operation.finish();
    }
  }

  void _syncPageSendWaits() {
    _bindSendGate();
    if (_initialMessageSendPending &&
        (_initialSendWait != null ||
            (widget.active &&
                widget.isLeafLocation &&
                !isGenesisUgcTextBlank(_initialMessageText)))) {
      final operation = _initialSendWait ??= _beginPageWait(
        'initial_send',
        id: 'initial:${_initialOutgoingMessage?.localId ?? DateTime.now().microsecondsSinceEpoch}',
      );
      if (operation.released) {
        scheduleMicrotask(_releaseInitialSendWait);
      } else {
        operation.onRelease(_releaseInitialSendWait);
      }
    } else {
      _initialSendWait?.finish();
    }
    if (_replyCardTransitionBusy && _presentationSendWait?.blocks != true) {
      _ensurePresentationWait('card_transition:$_waitingPositionOperation');
    }
  }

  void _releaseInitialSendWait() {
    if (!mounted || !_initialMessageSendPending) return;
    _setLocationChatState(() {
      _initialMessageSendPending = false;
      _initialMessageSendScheduled = false;
      _waitForComposerSpeaker = false;
      final outgoing = _initialOutgoingMessage;
      if (outgoing != null && outgoing.status == 'sending') {
        outgoing.status = 'failed';
      }
    });
  }

  ChatSendOperation _ensurePresentationWait(String id) {
    final operation = _presentationSendWait = _beginPageWait(
      'reply_presentation',
      id: id,
    );
    operation.onRelease(() {
      if (!mounted || !identical(_presentationSendWait, operation)) return;
      final presentationContext = _replyPresentationContextKey.currentContext;
      if (presentationContext != null) {
        ChatStreamingEffects.releaseLocalWait(presentationContext);
      }
      _scrollCoordinator.releasePresentationWait();
      final round = _renderedReplyState;
      if (round != null) {
        _replyController?.finishLocallyStalledStream(
          widget.locationId,
          '${round.roundId}',
        );
      }
      _setReplyControlsState(() => _replyCardTransitionBusy = false);
    });
    return operation;
  }

  bool _presentationWaitReleased(
    BuildContext context, {
    required bool settled,
  }) {
    final round = _renderedReplyState;
    if (round?.sendReleased ?? false) return true;
    final id =
        'presentation:${round?.roundId ?? 0}:${round?.viewedCardId ?? 0}:$_waitingPositionOperation';
    if (_presentationSendWait?.operationId != id) {
      _presentationSendWait?.finish();
      _presentationSendWait = null;
    }
    if (settled) {
      _presentationSendWait?.finish();
      return false;
    }
    // Stream/network wait owns its own deadline. This watches only a residual
    // presentation barrier once network work no longer blocks this location.
    if (_pageSendGate?.blocks(widget.worldId, widget.locationId) == true &&
        _presentationSendWait == null) {
      return false;
    }
    final operation = _presentationSendWait ?? _ensurePresentationWait(id);
    return operation.released;
  }
}
