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
    _unseenReplyMessageLocalIds.clear();
    _observedReplyMessageLocalIds.clear();
    _replyProjection.clear();
    _replyController = null;
    _preparingReplyAction = false;
    _replyCardTransitionBusy = false;
    _replyRequestLoading = false;
    _replyLoadingForRegeneration = false;
    _replyConnectionActionGeneration++;
    _replyConnectionAction = null;
    _replyConnectionActionRoundId = null;
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
          _setLocationChatState(_syncUnseenReplyMessages);
        } else {
          _setReplyControlsState(() {});
        }
        _scheduleDeferredTickReleaseIfReady();
      }
    });
  }

  void _syncUnseenReplyMessages() {
    final state = _replyController?.stateFor(widget.locationId);
    final card = state?.viewedCard;
    final ids = state != null && state.showCandidates && card != null
        ? _replyProjection
              .messages(state.messagesForCard(card.cardId), cardId: card.cardId)
              .where(
                (message) => message.text.trim().isNotEmpty || message.isImage,
              )
              .map((message) => message.localId)
              .toSet()
        : <String>{};
    _unseenReplyMessageLocalIds.retainAll(ids);
    // Restoring or browsing existing cards must not create new-message notices.
    if (_replyLoadingForRegeneration &&
        card != null &&
        !card.isOriginal &&
        !_replyRegenerationBaselineCardIds.contains(card.cardId)) {
      _unseenReplyMessageLocalIds.addAll(
        ids.difference(_observedReplyMessageLocalIds),
      );
    }
    _observedReplyMessageLocalIds.addAll(ids);
  }

  Future<void> _runReplyGeneration(
    Future<void> Function(ChatroomReplyActionsController) action, {
    required bool regenerating,
  }) async {
    final controller = _replyController;
    if (controller == null ||
        _preparingReplyAction ||
        _inspirationLoading ||
        _sending ||
        (_replyCardTransitionBusy &&
            _replyConnectionAction !=
                (regenerating
                    ? _LocationChatReplyConnectionAction.regenerate
                    : _LocationChatReplyConnectionAction.goOn))) {
      return;
    }
    final location = widget.locationId;
    final operation = _LocationChatReplyOperationScope(this);
    final replyState = controller.stateFor(location);
    _setReplyControlsState(() {
      _preparingReplyAction = true;
      _replyRequestLoading = true;
      if (!regenerating) {
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
      _replyLoadingForRegeneration = regenerating;
      if (regenerating) {
        _replyRegenerationDispatchRevision++;
        _unseenReplyMessageLocalIds.clear();
        _observedReplyMessageLocalIds.clear();
        _replyRegenerationHasRenderedContent = false;
        _replyRegenerationBaselineCardIds = {
          for (final card in replyState?.cards ?? const []) card.cardId,
        };
      }
    });
    _scrollCoordinator.requestBottom(
      reason: LocationChatBottomReason.replyGeneration,
      behavior: LocationChatBottomBehavior.animate,
      duration: const Duration(milliseconds: 500),
    );
    try {
      await action(controller);
    } catch (error) {
      if (mounted && operation.canApplyToReply) {
        // HTTP and WS business errors already use the global presenter.
        if (!isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
      }
    } finally {
      if (operation.ownsReplyTarget) {
        _setReplyControlsState(() {
          _preparingReplyAction = false;
          _replyRequestLoading = false;
          if (!regenerating &&
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
}
