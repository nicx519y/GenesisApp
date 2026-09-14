part of 'location_chat_page.dart';

extension _LocationChatReplyBinding on _LocationChatPanelState {
  void _detachReplyActions() {
    _clearDeferredTick(resetOrdering: true);
    _entryChanges?.removeListener(_onPreparedEntryChanged);
    _entryChanges = null;
    _editQuotaChecking = false;
    _editQuotaLoading = false;
    _editQuotaQueried = false;
    _inspirationQuotaQueried = false;
    _detachInspirations();
    _replyBindingGeneration++;
    _replyRebuildScheduled = false;
    _replyLocationChanges?.removeListener(_onReplyActionsChanged);
    _replyLocationChanges = null;
    _lastReplyBodyRevision = null;
    _replyProjectionKey = null;
    _replyProjectionCache = null;
    _replyIdentityCacheKey = null;
    _replyIdentityCache = null;
    _replyVmCaches.clear();
    _replyController = null;
    _preparingReplyAction = false;
    _replyCardTransitionBusy = false;
    _replyRequestLoading = false;
    _replyLoadingForRegeneration = false;
    _goOnPreAckCapabilities = null;
    _replyRegenerationBaselineCardIds = const <int>{};
    _replyRegenerationHasRenderedContent = false;
    _lastReplyStatusError = null;
    _suppressedReplyActionsIdentity = null;
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
      _replyLocationChanges = next.changesForLocation(widget.locationId);
      _replyLocationChanges!.addListener(_onReplyActionsChanged);
      _bindInspirations();
      service.setReplyWalletRefresher(
        AppServicesScope.read(context).gemWallet.refresh,
      );
    }
    if (_usesPreparedEntry && _entryChanges == null) {
      _entryChanges = service.entryForLocation(widget.locationId);
      _entryChanges!.addListener(_onPreparedEntryChanged);
    }
    if (_restoredReplyLocations.add(widget.locationId) && !_usesPreparedEntry) {
      unawaited(
        next.restore(widget.locationId).catchError((Object error) {
          debugPrint('[ReplyActions] restore failed: $error');
        }),
      );
    }
  }

  void _onPreparedEntryChanged() {
    if (!mounted || _service == null || !widget.active) return;
    // A build caused by activation synchronously reads the same snapshot.
    _replyProjectionEpoch++;
    _syncFromServiceState(_service!);
    _setLocationChatState(() {});
  }

  void _onReplyActionsChanged() {
    if (_replyRebuildScheduled) return;
    _replyRebuildScheduled = true;
    final binding = _replyBindingGeneration;
    scheduleMicrotask(() {
      if (binding != _replyBindingGeneration) return;
      _replyRebuildScheduled = false;
      if (mounted && widget.active) {
        _syncInspirationView();
        final error = _replyController?.stateFor(widget.locationId)?.error;
        if (error != null &&
            error is! ChatroomFeatureQuotaException &&
            !identical(error, _lastReplyStatusError) &&
            !_preparingReplyAction &&
            !isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
        _lastReplyStatusError = error;
        final loadingChanged = _dismissAckLoadingIfVisible();
        final revisions = _replyController?.revisionsForLocation(
          widget.locationId,
        );
        final bodyRevision = (
          revisions?.structureRevision,
          revisions?.contentRevision,
        );
        if (loadingChanged || bodyRevision != _lastReplyBodyRevision) {
          _lastReplyBodyRevision = bodyRevision;
          _setLocationChatState(() {});
        } else {
          _setReplyControlsState(() {});
        }
        _scheduleDeferredTickReleaseIfReady();
      }
    });
  }

  Future<void> _runReplyAction(
    Future<void> Function(ChatroomReplyActionsController) action, {
    bool generating = false,
    bool regenerating = false,
    bool continuing = false,
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
    final replyState = controller.stateFor(location);
    _setReplyControlsState(() {
      _preparingReplyAction = true;
      _replyRequestLoading = generating;
      if (continuing) {
        // Card confirmation can remove a capability before Go On is accepted.
        // Keep the clicked toolbar's slots until the ACK replaces all four.
        _goOnPreAckCapabilities = (
          // At the card limit Regenerate remains visible but disabled. Preserve
          // that slot too: confirmation clears both support and limit state.
          regenerate:
              (replyState?.supportsRegenerate ?? false) ||
              (replyState?.regenerateLimitReached ?? false),
          edit: replyState?.supportsEdit ?? false,
          inspiration: replyState?.supportsInspiration ?? false,
        );
      }
      if (generating) {
        _replyLoadingForRegeneration = regenerating;
        if (regenerating) {
          _replyRegenerationHasRenderedContent = false;
          _replyRegenerationBaselineCardIds = {
            for (final card in replyState?.cards ?? const []) card.cardId,
          };
        }
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
        _setReplyControlsState(() {
          _preparingReplyAction = false;
          _replyRequestLoading = false;
          if (continuing &&
              !controller
                  .statesFor(location)
                  .any(
                    (state) => state.goOnPending && state.goOnRoundId == null,
                  )) {
            _goOnPreAckCapabilities = null;
          }
        });
      }
    }
  }

  void _browseReplyCard(int delta) {
    final controller = _replyController;
    final state = controller?.stateFor(widget.locationId);
    if (controller == null || !_replyCardSwitchEnabledFor(state)) return;
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
        !_replyCardSwitchEnabledFor(state)) {
      return false;
    }
    final targetIndex = state.cards.indexWhere((card) => card.cardId == cardId);
    final delta = targetIndex - (state.cardPosition - 1);
    if (targetIndex < 0 || delta.abs() != 1) return false;
    _browseReplyCard(delta);
    return state.viewedCardId == cardId;
  }

  List<LocationChatReplyCard> _replyCardPages(
    ChatroomReplyRoundState? state,
    List<ChatMessageVm> currentReplyMessages,
  ) {
    if (state == null) return const [];
    if (!state.showCardPresentation) {
      return currentReplyMessages.isEmpty
          ? const []
          : [LocationChatReplyCard(id: 0, messages: currentReplyMessages)];
    }
    final viewedCardId = state.viewedCardId;
    final currentKey = '${state.roundId}/$viewedCardId';
    if (!_replyCardTransitionBusy) {
      _replyVmCaches.removeWhere((key, _) => key != currentKey);
    }
    return [
      for (final card in state.cards)
        LocationChatReplyCard.lazy(
          id: card.cardId,
          contentIdentity: (
            _replyBindingGeneration,
            state.roundId,
            card.cardId,
            state.cardContentRevision(card.cardId),
            // A promoted card reads formal history, whose content can change
            // independently of the candidate card revision (for example Edit).
            card.cardId == viewedCardId ? currentReplyMessages : null,
            _replyIdentityKey,
          ),
          resolveMessages: () => card.cardId == viewedCardId
              ? currentReplyMessages
              : _replyMessageVms(
                  state.messagesForCard(card.cardId),
                  cardId: card.cardId,
                ),
        ),
    ];
  }

  ({
    List<ChatMessageVm> messages,
    int? anchorIndex,
    List<ChatMessageVm> replyMessages,
  })
  _replyPresentation(ChatroomReplyRoundState? state) {
    final controller = _replyController;
    final revisions = controller?.revisionsForLocation(widget.locationId);
    final key = (
      _replyProjectionEpoch,
      _preparedEntry?.revision,
      revisions?.structureRevision,
      revisions?.contentRevision,
      _replyIdentityKey,
      state?.roundId,
      _shouldShowAiContentDisclaimer,
      _awaitingTickProgressMessage,
      _activeTickProgressSlotId,
    );
    if (_replyProjectionKey == key && _replyProjectionCache != null) {
      return _replyProjectionCache!;
    }
    assert(() {
      debugLocationChatReplyProjectionCount++;
      return true;
    }());
    var source = _locationChatDisplayMessages();
    if (controller != null) {
      final retained = _usesPreparedEntry
          ? _preparedEntry?.snapshot?.retainedReplies ??
                const <ChatroomReplyRoundState>[]
          : controller.statesFor(widget.locationId);
      for (final previous in retained) {
        if (identical(previous, state) ||
            (state != null && previous.roundId >= state.roundId) ||
            !previous.selectedCardAwaitingFormalHistory) {
          continue;
        }
        final ids = _replyMessageIds(previous);
        // Do not resurrect a round that has already scrolled out of the
        // projected window. The round projection below is shared with Go On.
        if (!source.any(
          (message) =>
              message.roundId == '${previous.roundId}' &&
              ids.contains(message.globalMessageId),
        )) {
          continue;
        }
        source = _presentReplyRound(source, previous).messages;
      }
    }
    _replyProjectionKey = key;
    return _replyProjectionCache = state == null
        ? (
            messages: List<ChatMessageVm>.unmodifiable(source),
            anchorIndex: null,
            replyMessages: const <ChatMessageVm>[],
          )
        : _presentReplyRound(source, state);
  }

  ({
    List<ChatMessageVm> messages,
    int? anchorIndex,
    List<ChatMessageVm> replyMessages,
  })
  _presentReplyRound(
    List<ChatMessageVm> source,
    ChatroomReplyRoundState state,
  ) {
    final replyMessageIds = _replyMessageIds(state);
    final candidateMessages = state.showCardPresentation
        ? _replyMessageVms(state.displayedMessages, cardId: state.viewedCardId)
        : null;
    final presentation = buildLocationChatReplyPresentation(
      source: source,
      roundId: '${state.roundId}',
      replyMessageIds: replyMessageIds,
      candidates: candidateMessages,
    );
    final currentReplyMessages =
        candidateMessages ??
        [
          for (final message in source)
            if (message.roundId == '${state.roundId}' &&
                message.globalMessageId > 0 &&
                replyMessageIds.contains(message.globalMessageId))
              message,
        ];
    return (
      messages: presentation.messages,
      anchorIndex: presentation.anchorIndex,
      replyMessages: currentReplyMessages,
    );
  }

  Set<int> _replyMessageIds(ChatroomReplyRoundState state) => state
      .formalReplyMessages
      .map((message) => message.globalMessageId)
      .where((id) => id > 0)
      .toSet();

  Object get _replyIdentityKey => (
    _replyBindingGeneration,
    _chatroomState.world,
    _chatroomState.entitiesById,
    Object.hashAll(_myUserIdKeys),
    Object.hashAll(_mySenderIdKeys),
    _devicePixelRatio,
    _userInfoRevisionListenable?.value,
  );

  List<ChatMessageVm> _replyMessageVms(
    List<WorldChatroomMessage> source, {
    int? cardId,
  }) {
    final identityKey = _replyIdentityKey;
    if (_replyIdentityCacheKey != identityKey) {
      _replyIdentityCacheKey = identityKey;
      _replyIdentityCache = _LocationChatTimelineIdentityIndex.fromState(
        _chatroomState,
        currentUserIds: _myUserIdKeys,
        currentSenderIds: _mySenderIdKeys,
      );
      _replyVmCaches.clear();
    }
    final identity = _replyIdentityCache!;
    final key =
        '${source.firstOrNull?.conversationRoundId ?? ''}/${cardId ?? 0}';
    final cached = _replyVmCaches.remove(key);
    if (cached != null && identical(cached.source, source)) {
      _replyVmCaches[key] = cached;
      return cached.messages;
    }
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
    final messages = <ChatMessageVm>[];
    final retained = <int, (WorldChatroomMessage, ChatMessageVm)>{};
    for (final message in source) {
      final previous = cached?.entries[message.globalMessageId];
      if (previous != null && identical(previous.$1, message)) {
        retained[message.globalMessageId] = previous;
        messages.add(previous.$2);
        continue;
      }
      assert(() {
        debugLocationChatReplyMessageParseCount++;
        return true;
      }());
      final parsed = _parserForMessage(message)?.parse(message, parseContext);
      if (parsed == null) continue;
      var vm = ChatMessageVm(
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
      );
      if (previous != null && locationChatReplyMessagesEqual(previous.$2, vm)) {
        vm = previous.$2;
      }
      retained[message.globalMessageId] = (message, vm);
      messages.add(vm);
    }
    final stableMessages =
        cached != null && listEquals(cached.messages, messages)
        ? cached.messages
        : List<ChatMessageVm>.unmodifiable(messages);
    _replyVmCaches[key] = _LocationChatReplyVmCache(
      source,
      stableMessages,
      retained,
    );
    while (_replyVmCaches.length > 2) {
      _replyVmCaches.remove(_replyVmCaches.keys.first);
    }
    return stableMessages;
  }
}

class _LocationChatReplyVmCache {
  const _LocationChatReplyVmCache(this.source, this.messages, this.entries);
  final List<WorldChatroomMessage> source;
  final List<ChatMessageVm> messages;
  final Map<int, (WorldChatroomMessage, ChatMessageVm)> entries;
}
