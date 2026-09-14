part of 'location_chat_page.dart';

extension _LocationChatReplyControls on _LocationChatPanelState {
  ({
    LocationChatReplyControlsSnapshot actions,
    bool regenerationInProgress,
    bool goOnContentIsRendering,
    String? goOnAwaitingContentIdentity,
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
    final acceptedGoOn = pending
        .where((state) => state.goOnRoundId != null)
        .firstOrNull;
    // A Tick retires the old controls while preserving in-flight card content.
    final tickSuperseded =
        _deferredTickLocalId != null ||
        (presentationState?.invalidatedByTick ?? false) ||
        rounds.any(
          (state) =>
              state.invalidatedByTick &&
              (state.generating || state.goOnPending),
        );
    final regenerationInProgress =
        (replyState?.generating ?? false) ||
        (_replyRequestLoading && _replyLoadingForRegeneration);
    if (regenerationInProgress &&
        _replyRegenerationContentIsRendering(replyState, displayMessages)) {
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
          (_replyController?.stateFor(widget.locationId)?.generating ??
              false) ||
          (_replyRequestLoading && _replyLoadingForRegeneration),
      goOn:
          pending.isNotEmpty ||
          (_replyRequestLoading && !_replyLoadingForRegeneration),
      edit: _editQuotaChecking || _editQuotaLoading,
      inspiration: _inspirationQuotaChecking || _inspirationLoading,
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
          regenerate: replyState?.canRegenerate ?? false,
          goOn: replyState?.canGoOn ?? false,
          edit: replyState?.canEdit ?? false,
          inspiration:
              _currentInspirationSource != null &&
              !_sending &&
              !_preparingReplyAction,
        ),
        busy: (
          regenerate:
              (replyState?.generating ?? false) || operations.regenerate,
          goOn: operations.goOn && !goOnContentIsRendering,
          edit: _editQuotaLoading,
          inspiration: _inspirationLoading,
        ),
        active: operations,
        regenerationContentRendering:
            regenerationInProgress && _replyRegenerationHasRenderedContent,
        regenerateLimitReached: replyState?.regenerateLimitReached ?? false,
      ),
      regenerationInProgress: regenerationInProgress,
      goOnContentIsRendering: goOnContentIsRendering,
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
