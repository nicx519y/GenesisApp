part of 'location_chat_page.dart';

extension _LocationChatMessageViewport on _LocationChatPanelState {
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

    final messageList = ChatStreamingEffects(
      key: ValueKey((widget.worldId, widget.locationId)),
      settings: locationChatBubbleLayoutSettings.value,
      child: ChatMentionScope(
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
            final actions = controls.actions;
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
              replyActionsVisible:
                  !controls.goOnContentIsRendering &&
                  _suppressedReplyActionsIdentity != replyActionsIdentity,
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
              onOldestEdgeLoadingCollapsed:
                  _handleOlderMessagesLoadingCollapsed,
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
