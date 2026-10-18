part of 'location_chat_page.dart';

extension _LocationChatMessageViewport on _LocationChatPanelState {
  List<ChatMessageVm> _withVisitEntry(List<ChatMessageVm> source) {
    if (!_freshLocationEntry || _entrySectionMessageId == null) return source;
    final service = _service;
    final received = service?.latestOwnLocationEntry;
    if (_entryForVisit == null &&
        received != null &&
        !identical(received, _entryBeforeVisit) &&
        received.locationId == widget.locationId) {
      _entryForVisit = received;
    }
    final canonical = _entryForVisit;
    // Joining alone does not imply a new entry message. Keep this visit's
    // path-only boundary unless an actual entry message is received.
    final text = canonical?.content ?? '';
    final old = _visitEntryMessage;
    final canonicalRound = canonical?.conversationRoundId ?? '';
    if (old == null || old.text != text || old.roundId != canonicalRound) {
      _visitEntryMessage = ChatMessageVm(
        localId: _entrySectionMessageId!,
        roundId: canonicalRound,
        createdAt: old?.createdAt,
        senderId: '',
        senderName: '',
        text: text,
        isMe: false,
        status: 'system',
        senderType: chatroomUserEnterLocationSenderType,
        timelinePayload: ChatUserEnterLocationPayloadVm(
          characterId: '',
          toLocationId: widget.locationId,
          text: text,
        ),
      );
    }
    final rows = source
        .where(
          (m) =>
              !(canonical != null &&
                  m.isUserEnterLocation &&
                  _worldHistory.locationFor(m) == widget.locationId &&
                  ((canonical.globalMessageId > 0 &&
                          m.globalMessageId == canonical.globalMessageId) ||
                      (canonical.locationMessageId > 0 &&
                          m.locationMessageId == canonical.locationMessageId))),
        )
        .toList();
    for (final m in rows) {
      if (m.clientMsgId.isNotEmpty &&
          !_entryExistingClientIds.contains(m.clientMsgId) &&
          LocationChatLocalMessageOrder.isUnconfirmed(m)) {
        _entryNewClientIds.add(m.clientMsgId);
      }
    }
    final round = service?.firstRealtimeRoundSinceEntry;
    // Freeze a complete history frontier once all locations' newest pages are
    // available. Later notification-driven HTTP rows land after this frontier;
    // pagination of older rows cannot push the marker to the end again.
    if (_entryHistoryBoundary == null && _worldHistory.ready) {
      var boundary = (0, 0);
      for (final m in rows) {
        final r = int.tryParse(m.roundId) ?? 0;
        if (round != null && r >= round) continue;
        if (_entryNewClientIds.contains(m.clientMsgId)) continue;
        if (r > boundary.$1 ||
            (r == boundary.$1 && m.globalMessageId > boundary.$2)) {
          boundary = (r, m.globalMessageId);
        }
      }
      _entryHistoryBoundary = boundary;
    }
    final boundary = _entryHistoryBoundary;
    final index = rows.indexWhere((m) {
      if (m.isAiContentDisclaimer) return false;
      final r = int.tryParse(m.roundId) ?? 0;
      return _entryNewClientIds.contains(m.clientMsgId) ||
          (round != null && r >= round) ||
          (boundary != null &&
              (r > boundary.$1 ||
                  (r == boundary.$1 && m.globalMessageId > boundary.$2)));
    });
    rows.insert(index < 0 ? rows.length : index, _visitEntryMessage!);
    _worldHistory._locations[_entrySectionMessageId!] = widget.locationId;
    return rows;
  }

  List<String>? _locationBoundaryParts(
    ChatMessageVm message,
    ChatMessageVm? previous,
  ) {
    if (message.localId == _entrySectionMessageId) {
      return _locationPathParts(widget.locationId);
    }
    if (!_worldHistory.ready ||
        previous == null ||
        message.isAiContentDisclaimer ||
        previous.isAiContentDisclaimer ||
        _worldHistory.locationFor(message) ==
            _worldHistory.locationFor(previous)) {
      return null;
    }
    return _locationPathParts(_worldHistory.locationFor(message));
  }

  List<String> _locationPathParts(String id) {
    final location = _mentionCatalogForState(
      _chatroomState,
    ).locations.where((l) => l.id == id).firstOrNull;
    final tree = _chatroomState.world?.processedLocationTree;
    var node = tree?.nodeById(id);
    final names = <String>[];
    final visited = <String>{};
    while (node != null && visited.add(node.id)) {
      final name = normalizeGenesisUgcTextForDisplay(
        _firstMapString(node.value, const ['location_name', 'name']),
      ).trim();
      if (name.isNotEmpty) names.insert(0, name);
      node = tree?.nodeById(node.parentId);
    }
    return names.isNotEmpty
        ? names
        : [
            if (location?.subtitle.isNotEmpty ?? false) location!.subtitle,
            location?.name ??
                (id == widget.locationId
                    ? firstNonEmpty([widget.locationName, id])
                    : id),
          ];
  }

  Object? _locationBoundaryVersion(
    ChatMessageVm message,
    ChatMessageVm? previous,
  ) {
    final section = _historySections.headerFor(message);
    if (section != null) {
      return (
        section.id,
        _historySections.expanded.contains(section.id),
        _locationPathParts(section.locationId).join(' > '),
      );
    }
    final parts = _locationBoundaryParts(message, previous);
    return parts == null ? null : (parts.length, parts.join(' > '));
  }

  Widget _decorateLocationBoundary(
    ChatMessageVm message,
    ChatMessageVm? previous,
    Widget child,
  ) {
    final section = _historySections.headerFor(message);
    if (section != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _historySections.toggle(section),
            child: _locationPathDivider(
              _locationPathParts(section.locationId),
              key: _worldHistory.boundaryKey(message.localId),
              trailing: _historySections.button(section),
            ),
          ),
          if (_historySections.expanded.contains(section.id)) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      );
    }
    final parts = _locationBoundaryParts(message, previous);
    if (parts == null) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _locationPathDivider(
          parts,
          key: _worldHistory.boundaryKey(message.localId),
        ),
        if (message.localId != _entrySectionMessageId ||
            message.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          child,
        ],
      ],
    );
  }

  Widget _locationPathDivider(
    List<String> parts, {
    Key? key,
    Widget? trailing,
  }) {
    final visibleParts = parts.skip(math.max(0, parts.length - 2)).toList();
    final pathStyle = kLocationChatStyle.bubbleTextStyle.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: GenesisColors.darkTextSecondary,
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(0, constraints.maxWidth - 24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: GenesisColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (visibleParts.length > 1)
                                    TextSpan(text: '${visibleParts.first} > '),
                                  TextSpan(
                                    text: visibleParts.last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              softWrap: true,
                              style: pathStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0x29FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ] else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  void _handleTimelineMessageLongPress(
    BuildContext context,
    ChatMessageVm message,
    LongPressStartDetails details,
  ) {
    if (message.localId == _entrySectionMessageId) return;
    if (!message.localId.startsWith('world-history:')) {
      _messageLongPressHandler(context, message, details);
    }
  }

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
    final displayMessages = _withVisitEntry(
      _worldHistory.project(replyPresentation.messages),
    );
    _historySections.project(displayMessages);
    final lastTimelineMessage = displayMessages.reversed
        .where((message) => !message.isAiContentDisclaimer)
        .firstOrNull;
    final hasUnconfirmedLocalMessageAtEnd =
        lastTimelineMessage != null &&
        LocationChatLocalMessageOrder.isUnconfirmed(lastTimelineMessage);
    final hasFailedLocalMessageAtEnd =
        hasUnconfirmedLocalMessageAtEnd &&
        lastTimelineMessage.status == 'failed';
    final replyGroupBeforeMessageLocalId =
        _localMessageOrder.firstLocalAfterRound(
          '${replyPresentationState?.roundId ?? ''}',
          displayMessages,
        ) ??
        (hasFailedLocalMessageAtEnd ? lastTimelineMessage.localId : null);
    final loadingRoundId = _ackLoadingRoundId();
    final loadingAfterMessageLocalId =
        _ackLoadingMessageLocalId != null &&
            !_hasVisibleAiReplyForRound(displayMessages, loadingRoundId)
        ? _ackLoadingMessageLocalId
        : null;
    final enterWaiting = _enterConversationWaitingFor(displayMessages);

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
                  !hasFailedLocalMessageAtEnd &&
                  _suppressedReplyActionsIdentity != replyActionsIdentity,
            ),
            backendPending: renderStatus.backendPending,
            presentationSettled: renderStatus.presentationSettled,
            discardPending:
                renderStatus.discardPending || hasFailedLocalMessageAtEnd,
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
            key: ValueKey((
              'location-chat-message-list',
              widget.worldId,
              widget.locationId,
            )),
            coordinator: _scrollCoordinator,
            active: widget.active,
            messages: displayMessages,
            onReadingMessageChanged: _historySections.reading,
            hiddenMessageIds: _historySections.hidden,
            historyReveal: _historySections.reveal,
            expandedHistoryHeaders: _historySections.expandedHeaders,
            pinnedHistoryHeaderBuilder: _historySections.pinnedHeader,
            messageReadingMarkerKey: _worldHistory.existingBoundaryKey,
            messageDecorator: _decorateLocationBoundary,
            messageDecorationVersion: _locationBoundaryVersion,
            entrySectionMessageId: _freshLocationEntry
                ? _entrySectionMessageId
                : null,
            restoreInitialCompletedContent: true,
            initialContentReady: _initialContentReadyNotified,
            historyGapLoaders: _historyGapLoaders(
              displayMessages
                  .where(
                    (m) => _worldHistory.locationFor(m) == widget.locationId,
                  )
                  .toList(),
            ),
            loadingAfterMessageLocalId: loadingAfterMessageLocalId,
            loadingIdentity: _ackLoadingClientMsgId,
            enterWaitingAfterMessageLocalId: enterWaiting?.messageLocalId,
            enterWaitingIdentity: enterWaiting?.identity,
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
            replyGroupBeforeMessageLocalId: replyGroupBeforeMessageLocalId,
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
            oldestEdgeLoading:
                _showOlderMessagesLoading || _worldHistory.loading,
            onOldestEdgeLoadingCollapsed: _handleOlderMessagesLoadingCollapsed,
            onMessageLongPressStart: _handleTimelineMessageLongPress,
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
            child: widget.previewContent ?? messageList,
          ),
        ),
        if (widget.emptyState != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.emptyStateInteractive,
              child: widget.emptyState,
            ),
          ),
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

  ({String messageLocalId, String identity})? _enterConversationWaitingFor(
    List<ChatMessageVm> messages,
  ) {
    final state = _service?.state ?? _chatroomState;
    final activeRound =
        state.conversationRoundStatesByLocation[widget.locationId];
    if (activeRound?.phase != ConversationRoundPhase.processing) return null;

    final roundId = activeRound!.conversationRoundId.trim();
    final numericRoundId = int.tryParse(roundId);
    if (numericRoundId == null || numericRoundId <= 0) return null;

    final enterIndex = messages.indexWhere(
      (message) =>
          message.isUserEnterLocation && message.roundId.trim() == roundId,
    );
    if (enterIndex < 0) return null;

    final contentStarted = messages
        .skip(enterIndex + 1)
        .any(
          (message) =>
              message.roundId.trim() == roundId &&
              _isVisibleEnterConversationContent(message),
        );
    if (contentStarted) return null;

    final enterMessage = messages[enterIndex];
    return (
      messageLocalId: enterMessage.localId,
      identity:
          '${widget.worldId}/${widget.locationId}/$roundId/${enterMessage.localId}',
    );
  }

  bool _isVisibleEnterConversationContent(ChatMessageVm message) {
    if (message.isUserEnterLocation || message.isAiContentDisclaimer) {
      return false;
    }
    return message.text.trim().isNotEmpty ||
        message.imageUrl.trim().isNotEmpty ||
        message.timelinePayload != null;
  }
}
