part of 'location_chat_page.dart';

extension _LocationChatMessageViewport on _LocationChatPanelState {
  ChatroomReplyRoundState? get _renderedReplyState =>
      _initialOutgoingMessage != null && !_initialOutgoingMessageReconciled
      ? null
      : _displayReplyState;

  // One backend/presentation barrier for the toolbar, composer and send entry.
  ({bool backendPending, bool presentationSettled, bool discardPending})
  _replyRenderStatus(BuildContext context, {bool listen = true}) {
    final presentation = _renderedReplyState;
    final replyState =
        _initialOutgoingMessage != null && !_initialOutgoingMessageReconciled
        ? null
        : (_usesPreparedEntry
              ? _preparedEntry?.snapshot?.actions
              : _replyController?.stateFor(widget.locationId));
    final controls = _replyControlsFor(
      replyState,
      presentation,
      _replyProjection.presentation(presentation).messages,
    );
    return (
      backendPending:
          _sending ||
          _sendAwaitingResponse ||
          _replyGenerationInProgress ||
          controls.regenerationInProgress ||
          replyState?.complete == false,
      presentationSettled:
          ChatStreamingEffects.isSettledOf(context, listen: listen) &&
          !_replyCardTransitionBusy,
      discardPending: controls.tickSupersededReply || replyState?.error != null,
    );
  }

  bool _replyReadyToSend(BuildContext context, {bool listen = true}) {
    final status = _replyRenderStatus(context, listen: listen);
    return status.discardPending ||
        (!status.backendPending && status.presentationSettled);
  }

  bool get _replyPresentationBlocksSend {
    final context = _replyPresentationContextKey.currentContext;
    return context != null && !_replyReadyToSend(context, listen: false);
  }

  Widget _withReplyStreamingEffects(Widget child) {
    final presentation = _renderedReplyState;
    final messages = _replyProjection.presentation(presentation).messages;
    return ChatStreamingEffects(
      key: ValueKey((widget.worldId, widget.locationId)),
      settings: locationChatBubbleLayoutSettings.value,
      operationIdentity: (_replyBindingGeneration, _waitingPositionOperation),
      presentationRevision: (
        presentation?.roundId,
        presentation?.viewedCardId,
        presentation?.contentRevision,
        _replyRegenerationDispatchRevision,
        _replyCardTransitionBusy,
        Object.hashAll(
          messages.map(
            (message) => (
              _locationChatMessageLayoutId(message),
              message.status,
              message.text,
              message.imageUrl,
            ),
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _buildMessageViewport({
    required ChatUiStyleConfig style,
    required double selfMessageBubbleMaxWidthCap,
    required double otherMessageBubbleMaxWidthCap,
  }) {
    assert(() {
      debugLocationChatMessageViewportBuildCount++;
      return true;
    }());

    // Opening history is not a new reply to the queued launch message.
    final awaitingOpeningEcho =
        _initialOutgoingMessage != null && !_initialOutgoingMessageReconciled;
    final replyPresentationState = awaitingOpeningEcho
        ? null
        : _displayReplyState;
    final replyPresentation = _replyProjection.presentation(
      replyPresentationState,
    );
    final replyActionsIdentity = replyPresentationState == null
        ? null
        : '${widget.worldId}/${widget.locationId}/${replyPresentationState.roundId}';
    final displayMessages = replyPresentation.messages;
    final loadingRoundId = _ackLoadingRoundId();
    final loadingAfterMessageLocalId =
        _ackLoadingMessageLocalId != null &&
            !_hasVisibleAiReplyForRound(displayMessages, loadingRoundId)
        ? _ackLoadingMessageLocalId
        : null;

    final messageList = ChatMentionScope(
      key: _replyPresentationContextKey,
      catalog: _textController.catalog,
      child: ValueListenableBuilder<int>(
        valueListenable: _replyControlsRevision,
        builder: (context, _, child) {
          final replyState = awaitingOpeningEcho
              ? null
              : (_usesPreparedEntry
                    ? _preparedEntry?.snapshot?.actions
                    : _replyController?.stateFor(widget.locationId));
          final controls = _replyControlsFor(
            replyState,
            replyPresentationState,
            displayMessages,
          );
          _scheduleInspirationConversationRendered(
            displayMessages,
            ackRoundId:
                loadingAfterMessageLocalId != null &&
                    displayMessages.any(
                      (message) =>
                          message.localId == loadingAfterMessageLocalId,
                    )
                ? int.tryParse(loadingRoundId) ??
                      (_inspirationAckPreviousRound + 1)
                : null,
            goOnRoundId: controls.goOnAwaitingRoundId,
          );
          final renderStatus = _replyRenderStatus(context);
          final renderedControls = _replyRenderGate.resolve(
            (
              actions: controls.actions,
              visible:
                  !controls.goOnContentIsRendering &&
                  _suppressedReplyActionsIdentity != replyActionsIdentity,
            ),
            backendPending: renderStatus.backendPending,
            presentationSettled: renderStatus.presentationSettled,
            discardPending: renderStatus.discardPending,
          );
          final actions = renderedControls.actions;
          final regenerateFeature = actions.hidden
              ? const LocationChatRegenerateFeature.disabled()
              : _regenerateFeature(actions);
          final goOnFeature = actions.hidden
              ? const LocationChatGoOnFeature.disabled()
              : _goOnFeature(actions.goOn);
          final editFeature = actions.hidden
              ? const LocationChatEditFeature.disabled()
              : _editFeature(
                  actions.edit,
                  style,
                  selfMessageBubbleMaxWidthCap,
                  otherMessageBubbleMaxWidthCap,
                );
          final inspirationFeature = actions.hidden
              ? const LocationChatInspirationFeature.disabled()
              : _inspirationFeature(actions.inspiration);
          return LocationChatAnchoredMessageList(
            key: const ValueKey<String>('location-chat-message-list'),
            coordinator: _scrollCoordinator,
            active: widget.active,
            messages: displayMessages,
            loadingAfterMessageLocalId: loadingAfterMessageLocalId,
            loadingIdentity: _ackLoadingClientMsgId,
            preAckWaitingAfterMessageLocalId: _preAckWaitingMessageLocalId,
            preAckWaitingIdentity: _preAckWaitingClientMsgId,
            waitingPositionResetRevision: _waitingPositionResetRevision,
            waitingPositionClientMsgId: _waitingPositionClientMsgId,
            waitingPositionIdentity: _waitingPositionOperation == 0
                ? null
                : '$_replyBindingGeneration/${widget.worldId}/${widget.locationId}/$_waitingPositionOperation',
            goOnAwaitingContentIdentity: controls.goOnAwaitingContentIdentity,
            replyWaitingPositioningEnabled: locationChatBubbleLayoutSettings
                .value
                .replyWaitingPositioningEnabled,
            replyViewportReserveFraction: locationChatBubbleLayoutSettings
                .value
                .replyViewportReserveFraction,
            messageLayoutId: _locationChatMessageLayoutId,
            replyActionsIdentity: replyActionsIdentity,
            replyActionsMessageId:
                replyPresentation.replyMessages.lastOrNull?.localId,
            replyActionsVisible: renderedControls.visible,
            replyPresentationRevision:
                replyPresentationState?.presentationRevision ?? 0,
            replyCards: _replyProjection.cards(
              replyPresentationState,
              replyPresentation.replyMessages,
            ),
            replyCurrentCardId: replyPresentationState?.viewedCardId ?? 0,
            replyCardBindingIdentity:
                '$_replyBindingGeneration/${widget.worldId}/${widget.locationId}/${replyPresentationState?.roundId}',
            replyCardSwitchEnabled: controls.cardSwitchEnabled,
            replyRegenerationInProgress: controls.regenerationInProgress,
            replyRegenerationDispatchRevision:
                _replyRegenerationDispatchRevision,
            onReplyCardSelected: _commitReplyCard,
            onReplyCardTransitionChanged: _replyTransitionChangedHandler,
            regenerateFeature: regenerateFeature,
            goOnFeature: goOnFeature,
            editFeature: editFeature,
            replyCardIndex: math.max(
              0,
              (replyPresentationState?.cardPosition ?? 1) - 1,
            ),
            replyCardCount: controls.tickSupersededReply
                ? 0
                : replyPresentationState?.cardCount ?? 0,
            replyCardsConfirmed: replyPresentationState?.confirmed ?? false,
            showConfirmedCardPagination: controls.showConfirmedCardPagination,
            onPreviousReplyCard: () => _browseReplyCard(-1),
            onNextReplyCard: () => _browseReplyCard(1),
            inspirationFeature: inspirationFeature,
            inspirationIdentity:
                '${_currentInspirationSource?.key}:$_inspirationResetRevision',
            inspirationPresentationRevision: _inspirationPresentationRevision,
            topTitle: '',
            oldestEdgeLoading: _showOlderMessagesLoading,
            onOldestEdgeLoadingCollapsed: _handleOlderMessagesLoadingCollapsed,
            onMessageLongPressStart: _messageLongPressHandler,
            onFailedMessageTap: _failedMessageTapHandler,
            onCharactersMovedLocationTap:
                widget.onCharactersMovedLocationTap == null
                ? null
                : _movementTapHandler,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            showDateDividers: false,
            selfMessageBubbleMaxWidthCap: selfMessageBubbleMaxWidthCap,
            otherMessageBubbleMaxWidthCap: otherMessageBubbleMaxWidthCap,
            style: style,
          );
        },
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _scrollCoordinator.handleScrollNotification,
            child: messageList,
          ),
        ),
        if (widget.emptyState != null)
          Positioned.fill(child: IgnorePointer(child: widget.emptyState)),
        if (_newMessageNoticeCount > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: _LocationChatNewMessageNotice(
                count: _newMessageNoticeCount,
                onTap: _openUnseenIncomingMessages,
              ),
            ),
          ),
      ],
    );
  }
}
