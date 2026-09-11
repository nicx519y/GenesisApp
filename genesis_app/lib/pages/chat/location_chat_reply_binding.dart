part of 'location_chat_page.dart';

extension _LocationChatReplyBinding on _LocationChatPanelState {
  void _detachReplyActions() {
    _detachInspirations();
    _replyBindingGeneration++;
    _replyController?.removeListener(_onReplyActionsChanged);
    _replyController = null;
    _preparingReplyAction = false;
    _replyCardTransitionBusy = false;
    _replyRequestLoading = false;
    _replyLoadingForRegeneration = false;
    _lastReplyStatusError = null;
    _restoredReplyLocations.clear();
  }

  void _bindReplyActions() {
    final service = _service;
    if (service == null || !widget.isLeafLocation) return;
    final next = service.replyActions;
    if (next == null) return;
    if (!identical(next, _replyController)) {
      _detachReplyActions();
      _replyController = next;
      next.addListener(_onReplyActionsChanged);
      _bindInspirations();
      service.setReplyWalletRefresher(
        AppServicesScope.read(context).gemWallet.refresh,
      );
    }
    if (_restoredReplyLocations.add(widget.locationId)) {
      unawaited(
        next.restore(widget.locationId).catchError((Object error) {
          debugPrint('[ReplyActions] restore failed: $error');
        }),
      );
    }
  }

  void _onReplyActionsChanged() {
    if (_replyRebuildScheduled) return;
    _replyRebuildScheduled = true;
    scheduleMicrotask(() {
      _replyRebuildScheduled = false;
      if (mounted && widget.active) {
        _syncInspirationView();
        final error = _replyController?.stateFor(widget.locationId)?.error;
        if (error != null &&
            !identical(error, _lastReplyStatusError) &&
            !_preparingReplyAction &&
            !isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
        _lastReplyStatusError = error;
        _setLocationChatState(() {});
      }
    });
  }

  Future<void> _runReplyAction(
    Future<void> Function(ChatroomReplyActionsController) action, {
    bool generating = false,
    bool regenerating = false,
  }) async {
    final controller = _replyController;
    if (controller == null ||
        _preparingReplyAction ||
        _inspirationLoading ||
        _sending ||
        _replyCardTransitionBusy) {
      return;
    }
    final location = widget.locationId;
    final bindingGeneration = _replyBindingGeneration;
    _setLocationChatState(() {
      _preparingReplyAction = true;
      _replyRequestLoading = generating;
      if (generating) {
        _replyLoadingForRegeneration = regenerating;
      }
    });
    if (generating) {
      _scrollCoordinator.requestBottom(
        reason: LocationChatBottomReason.replyGeneration,
        behavior: LocationChatBottomBehavior.animate,
        duration: const Duration(milliseconds: 500),
      );
    }
    try {
      await action(controller);
    } catch (error) {
      if (mounted &&
          widget.active &&
          bindingGeneration == _replyBindingGeneration &&
          widget.locationId == location &&
          identical(controller, _replyController)) {
        // HTTP and WS business errors already use the global presenter.
        if (!isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
      }
    } finally {
      if (mounted &&
          bindingGeneration == _replyBindingGeneration &&
          widget.locationId == location &&
          identical(controller, _replyController)) {
        _setLocationChatState(() {
          _preparingReplyAction = false;
          _replyRequestLoading = false;
        });
      }
    }
  }

  void _browseReplyCard(int delta) {
    final controller = _replyController;
    if (controller == null ||
        _sending ||
        _preparingReplyAction ||
        _inspirationLoading) {
      return;
    }
    unawaited(
      controller.browse(widget.locationId, delta).catchError((Object error) {
        debugPrint('[ReplyActions] card position persistence failed: $error');
      }),
    );
  }

  bool _commitReplyCard(int cardId) {
    final state = _replyController?.stateFor(widget.locationId);
    if (!mounted ||
        !widget.active ||
        state == null ||
        _sending ||
        _preparingReplyAction ||
        _inspirationLoading ||
        state.busy ||
        state.frozen ||
        !state.showCandidates) {
      return false;
    }
    final targetIndex = state.cards.indexWhere((card) => card.cardId == cardId);
    final delta = targetIndex - (state.cardPosition - 1);
    if (targetIndex < 0 || delta.abs() != 1) return false;
    _browseReplyCard(delta);
    return state.viewedCardId == cardId;
  }

  List<LocationChatReplyCard> _replyCardPages(ChatroomReplyRoundState? state) {
    if (state == null || !state.showCandidates) return const [];
    return [
      for (final card in state.cards)
        LocationChatReplyCard(
          id: card.cardId,
          messages: _replyMessageVms(
            state.messagesForCard(card.cardId),
            cardId: card.cardId,
          ),
        ),
    ];
  }

  ({List<ChatMessageVm> messages, int? anchorIndex}) _replyPresentation(
    ChatroomReplyRoundState? state,
  ) {
    final source = _locationChatDisplayMessages();
    if (state == null) return (messages: source, anchorIndex: null);
    return buildLocationChatReplyPresentation(
      source: source,
      roundId: '${state.roundId}',
      replyMessageIds: state.formalReplyMessages
          .map((message) => message.globalMessageId)
          .where((id) => id > 0)
          .toSet(),
      candidates: state.showCandidates
          ? _replyMessageVms(
              state.displayedMessages,
              cardId: state.viewedCardId,
            )
          : null,
    );
  }

  List<ChatMessageVm> _replyMessageVms(
    List<WorldChatroomMessage> source, {
    int? cardId,
  }) {
    final identity = _LocationChatTimelineIdentityIndex.fromState(
      _chatroomState,
      currentUserIds: _myUserIdKeys,
      currentSenderIds: _mySenderIdKeys,
    );
    final parseContext = LocationChatMessageParseContext(
      currentLocationId: widget.locationId,
      isMine: (_) => false,
      senderName: _messageSenderDisplayName,
      avatarUrl: _messageAvatarUrl,
      isPlayerControlledRole: _messageSenderIsPlayerControlledRole,
      characterName: identity.characterName,
      locationName: identity.locationName,
      roleName: identity.roleName,
      roleIsAi: identity.roleIsAi,
      roleAvatarUrl: identity.roleAvatarUrl,
    );
    return [
      for (final message in source)
        if (_parserForMessage(message)?.parse(message, parseContext)
            case final parsed?)
          ChatMessageVm(
            localId:
                'reply:${widget.worldId}:${widget.locationId}:${parsed.roundId}:${cardId ?? 0}:${parsed.globalMessageId}',
            globalMessageId: parsed.globalMessageId,
            messageId: parsed.messageId,
            locationMessageId: parsed.locationMessageId,
            roundId: parsed.roundId,
            tickNo: parsed.tickNo,
            subTickNo: parsed.subTickNo,
            senderId: parsed.senderId,
            senderName: parsed.senderName,
            avatarUrl: parsed.avatarUrl,
            imageUrl: parsed.imageUrl,
            text: parsed.text,
            currentTime: parsed.currentTime,
            isMe: false,
            status: parsed.status,
            senderType: parsed.senderType,
            createdAt: parsed.createdAt,
          ),
    ];
  }
}
