part of 'location_chat_page.dart';

extension _LocationChatReplyControls on _LocationChatPanelState {
  ({
    LocationChatReplyControlsSnapshot actions,
    bool regenerationInProgress,
    bool goOnContentIsRendering,
    String? goOnAwaitingContentIdentity,
    int? goOnAwaitingRoundId,
    bool tickSupersededReply,
    bool cardSwitchEnabled,
    bool showConfirmedCardPagination,
  })
  _replyControlsFor(
    ChatroomReplyRoundState? replyState,
    ChatroomReplyRoundState? presentationState,
    List<ChatMessageVm> displayMessages,
  ) {
    final rounds = _replyController?.statesFor(widget.locationId) ?? const [];
    final pending = rounds.where((state) => state.goOnPending).toList();
    final regenerationState = presentationState ?? replyState;
    final acceptedGoOn = pending
        .where((state) => state.goOnRoundId != null)
        .firstOrNull;
    // Retire old controls as soon as Tick progress is displayed, including the
    // interval between unlocking input and receiving the formal Tick message.
    final tickSuperseded =
        widget.worldTickInProgress ||
        (_service?.state ?? _chatroomState).inputBlocked ||
        _awaitingTickProgressMessage ||
        _deferredTickLocalId != null ||
        (presentationState?.invalidatedByTick ?? false) ||
        rounds.any(
          (state) =>
              state.invalidatedByTick &&
              (state.generating || state.goOnPending),
        );
    final regenerationInProgress =
        (regenerationState?.generating ?? false) ||
        (_replyRequestLoading && _replyLoadingForRegeneration);
    if (regenerationInProgress &&
        _replyRegenerationContentIsRendering(
          regenerationState,
          displayMessages,
        )) {
      _replyRegenerationHasRenderedContent = true;
    }
    final goOnContentIsRendering = _replyGoOnContentIsRendering(
      displayMessages,
      pending,
    );
    final awaitingGoOn =
        !tickSuperseded && acceptedGoOn != null && !goOnContentIsRendering;
    final operations = (
      regenerate:
          _replyConnectionAction ==
              _LocationChatReplyConnectionAction.regenerate ||
          rounds.any((state) => state.generating) ||
          (_replyRequestLoading && _replyLoadingForRegeneration),
      goOn:
          _replyConnectionAction == _LocationChatReplyConnectionAction.goOn ||
          pending.isNotEmpty ||
          (_replyRequestLoading && !_replyLoadingForRegeneration),
      edit:
          _replyConnectionAction == _LocationChatReplyConnectionAction.edit ||
          _editQuotaChecking ||
          _editQuotaLoading,
      inspiration:
          _replyConnectionAction ==
              _LocationChatReplyConnectionAction.inspiration ||
          _inspirationQuotaChecking ||
          _inspirationLoading,
    );
    final preAck = operations.goOn && !awaitingGoOn
        ? _goOnPreAckCapabilities
        : null;
    final blocked = _replyActionsBlockedFor(goOnPending: pending.isNotEmpty);
    final inspirationState = _usesPreparedEntry
        ? _displayReplyState
        : _replyController?.stateFor(widget.locationId);
    return (
      actions: resolveLocationChatReplyControls(
        hidden: tickSuperseded || awaitingGoOn,
        blocked: blocked,
        showWhenUnavailable: _usesPreparedEntry,
        supported: (
          regenerate:
              preAck?.regenerate ?? replyState?.supportsRegenerate ?? false,
          goOn: replyState?.supportsGoOn ?? false,
          edit: preAck?.edit ?? replyState?.supportsEdit ?? false,
          inspiration:
              preAck?.inspiration ??
              inspirationState?.supportsInspiration ??
              false,
        ),
        canInvoke: (
          regenerate: replyState?.canStartRegenerate ?? false,
          goOn: replyState?.canStartGoOn ?? false,
          edit: replyState?.canStartEdit ?? false,
          inspiration: replyState?.canStartInspiration ?? false,
        ),
        busy: (
          regenerate:
              (regenerationState?.generating ?? false) || operations.regenerate,
          goOn: operations.goOn && !goOnContentIsRendering,
          edit: operations.edit,
          inspiration: operations.inspiration,
        ),
        active: operations,
        regenerationContentRendering:
            regenerationInProgress && _replyRegenerationHasRenderedContent,
        regenerateLimitReached: replyState?.regenerateLimitReached ?? false,
      ),
      regenerationInProgress: regenerationInProgress,
      goOnContentIsRendering: goOnContentIsRendering,
      goOnAwaitingRoundId: awaitingGoOn ? acceptedGoOn.goOnRoundId : null,
      goOnAwaitingContentIdentity: awaitingGoOn
          ? 'go-on:${acceptedGoOn.roundId}:${acceptedGoOn.goOnRoundId}'
          : null,
      tickSupersededReply: tickSuperseded,
      cardSwitchEnabled:
          !tickSuperseded &&
          _replyCardSwitchEnabledFor(presentationState, blocked: blocked),
      showConfirmedCardPagination:
          !tickSuperseded &&
          (presentationState?.confirmed ?? false) &&
          (presentationState?.goOnPending ?? false) &&
          !goOnContentIsRendering,
    );
  }
}
