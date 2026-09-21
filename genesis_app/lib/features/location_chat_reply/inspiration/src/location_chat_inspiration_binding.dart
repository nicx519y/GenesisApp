part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatInspirationBinding on _LocationChatPanelState {
  void _scheduleInspirationConversationRendered(
    List<ChatMessageVm> messages, {
    int? ackRoundId,
    int? goOnRoundId,
  }) {
    final controller = _inspirationController;
    final generation = ++_inspirationRenderGeneration;
    if (!widget.active || controller == null) return;
    var round = math.max(ackRoundId ?? 0, goOnRoundId ?? 0);
    for (final message in messages) {
      round = math.max(round, int.tryParse(message.roundId) ?? 0);
      if (message.timelinePayload is ChatTickProgressPayloadVm) {
        // Tick progress can render before its round ID arrives. Retire through
        // its captured predecessor without treating later progress builds as
        // additional conversations.
        round = math.max(round, _inspirationTickPreviousRound + 1);
      }
    }
    if (round <= 0) return;
    final binding = _replyBindingGeneration;
    final location = widget.locationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          generation != _inspirationRenderGeneration ||
          binding != _replyBindingGeneration ||
          location != widget.locationId ||
          !identical(controller, _inspirationController)) {
        return;
      }
      unawaited(
        controller.conversationRendered(location, round).catchError((
          Object error,
        ) {
          debugPrint('[Inspiration] cache cleanup failed: $error');
        }),
      );
    });
  }

  void _editInspiration(String text) {
    if (_replyCardTransitionBusy) return;
    _textController.setSerializedText(text);
    if (_composerFocusNode.hasFocus) {
      // The system back button can hide the keyboard without dropping focus.
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    } else {
      _composerFocusNode.requestFocus();
    }
    _finishInspirationAnalytics(_inspirationAnalyticsAttempt, 'edit');
  }

  LocationChatInspirationFeature _inspirationFeature(
    LocationChatReplyActionState state,
  ) => LocationChatInspirationFeature(
    messages: _inspirationMessages,
    state: state,
    freeUsesRemaining: _freeUsesRemaining(
      'inspiration',
      queried: _inspirationQuotaQueried,
    ),
    onExpandedChanged: _onInspirationExpanded,
    onSend: _sendInspiration,
    onEdit: _editInspiration,
  );

  ChatroomInspirationSource? get _currentInspirationSource {
    if (!widget.active) {
      return null;
    }
    final deferredTick = _deferredTickLocalId != null;
    if (!deferredTick &&
        (_chatroomState.inputBlocked || widget.worldTickInProgress)) {
      return null;
    }
    return (deferredTick
            ? _displayReplyState
            : _replyController?.stateFor(widget.locationId))
        ?.inspirationSource;
  }

  void _bindInspirations() {
    final next = _service?.inspirations;
    if (identical(next, _inspirationController)) return;
    _detachInspirations();
    _inspirationController = next;
    next?.addListener(_onInspirationInvalidated);
  }

  void _detachInspirations() {
    _inspirationController?.removeListener(_onInspirationInvalidated);
    _resetInspiration();
    _inspirationController = null;
    _inspirationRenderGeneration++;
  }

  void _resetInspiration() {
    final attempt = _inspirationAnalyticsAttempt;
    if (attempt != null && !attempt.finished) {
      if (attempt.phase == _LocationChatInspirationAnalyticsPhase.displayed) {
        _finishInspirationAnalytics(attempt, 'dismissed');
      } else if (attempt.phase !=
          _LocationChatInspirationAnalyticsPhase.sending) {
        _finishInspirationAnalytics(attempt, 'unknown');
      }
    }
    final location =
        _inspirationRequestSource?.locationId ??
        _inspirationDisplayedSource?.locationId;
    if (location != null) _inspirationController?.cancelView(location);
    _inspirationRequestGeneration++;
    _inspirationResetRevision++;
    _inspirationMessages = const [];
    _inspirationRequestSource = null;
    _inspirationDisplayedSource = null;
    _inspirationEpoch = null;
    _inspirationQuotaChecking = false;
    _inspirationLoading = false;
  }

  void _onInspirationInvalidated() {
    final source = _inspirationDisplayedSource ?? _inspirationRequestSource;
    final epoch = _inspirationEpoch;
    if (source == null ||
        epoch == null ||
        (_inspirationController?.isCurrent(source, epoch) ?? false)) {
      return;
    }
    _resetInspiration();
    // Service notifications can arrive while a parent is rebuilding.
    scheduleMicrotask(() {
      if (mounted) _setReplyControlsState(() {});
    });
  }

  void _syncInspirationView() {
    if (_sending) return;
    final source = _inspirationDisplayedSource ?? _inspirationRequestSource;
    if (source != null && !source.sameOrigin(_currentInspirationSource)) {
      _resetInspiration();
    }
  }

  void _onInspirationExpanded(bool expanded) {
    if (expanded) {
      final attempt = _beginInspirationAnalytics();
      unawaited(
        _submitReplyAction(
          _LocationChatReplyActionTransaction(
            action: _LocationChatReplyConnectionAction.inspiration,
            commit: () => _loadInspirations(attempt),
            onFailure: (error) =>
                _finishInspirationAnalyticsFromError(attempt, error),
          ),
        ),
      );
    } else if (_inspirationQuotaChecking || _inspirationLoading) {
      _setReplyControlsState(_resetInspiration);
    } else {
      final attempt = _inspirationAnalyticsAttempt;
      scheduleMicrotask(() {
        if (attempt != null &&
            identical(_inspirationAnalyticsAttempt, attempt) &&
            attempt.phase == _LocationChatInspirationAnalyticsPhase.displayed) {
          _finishInspirationAnalytics(attempt, 'dismissed');
        }
      });
    }
  }

  Future<void> _loadInspirations(
    _LocationChatInspirationAnalyticsAttempt attempt,
  ) async {
    final service = _service;
    final controller = _inspirationController;
    final source = _currentInspirationSource;
    if (service == null ||
        controller == null ||
        source == null ||
        _inspirationQuotaChecking ||
        _inspirationLoading) {
      _finishInspirationAnalytics(attempt, 'failed');
      return;
    }
    _inspirationQuotaChecking = true;
    var generation = ++_inspirationRequestGeneration;
    final operation = _LocationChatReplyOperationScope(this);
    bool ownsRequest() =>
        operation.ownsBinding &&
        widget.active &&
        identical(service, _service) &&
        operation.ownsQuotaSession;
    bool sameConversation(ChatroomInspirationSource? candidate) =>
        candidate != null &&
        candidate.ownerUid == source.ownerUid &&
        candidate.worldId == source.worldId &&
        candidate.locationId == source.locationId &&
        candidate.roundId == source.roundId;
    ChatroomInspirationSource? verified;
    bool current() =>
        ownsRequest() &&
        generation == _inspirationRequestGeneration &&
        verified?.sameOrigin(_currentInspirationSource) == true;
    try {
      await service.ensureInspirationHistory(source.locationId);
      if (!ownsRequest() || !sameConversation(_currentInspirationSource)) {
        return;
      }
      // Rebase the click onto the authoritative source established by the
      // post-join history refresh. A formal reply can legitimately change
      // from sourceCardId=0 to its persisted card id without changing rounds.
      verified = _currentInspirationSource!;
      generation = ++_inspirationRequestGeneration;
      _inspirationQuotaChecking = true;
      _setReplyControlsState(() {
        _inspirationRequestSource = verified;
        if (!verified!.sameOrigin(_inspirationDisplayedSource)) {
          _inspirationDisplayedSource = null;
          _inspirationMessages = const [];
          _inspirationEpoch = null;
        }
      });
      _inspirationEpoch = controller.revision(source.locationId);
      var result = await controller.readCached(verified);
      if (!current()) return;
      if (result == null) {
        if (!await _refreshReplyFeatureQuota(
              'inspiration',
              current: current,
              onQuotaLookupStarted: () {
                if (current()) {
                  _setReplyControlsState(() => _inspirationLoading = true);
                }
              },
            ) ||
            !current()) {
          return;
        }
        if (!_inspirationLoading) {
          _setReplyControlsState(() => _inspirationLoading = true);
        }
        result = await controller.load(verified);
      }
      if (!current() || result == null) return;
      final latest = _currentInspirationSource!;
      if (latest.cardId != null && latest.sourceCardId != result.sourceCardId) {
        return;
      }
      final messages = result.messages;
      if (messages.isEmpty) {
        _finishInspirationAnalytics(attempt, 'failed');
        return;
      }
      attempt.phase = _LocationChatInspirationAnalyticsPhase.displayed;
      _setReplyControlsState(() {
        _inspirationDisplayedSource = verified;
        _inspirationMessages = messages;
        _inspirationQuotaQueried = true;
        _inspirationPresentationRevision++;
      });
      if (_featureQuotas?.quotaFor('inspiration') == null &&
          _featureQuotas?.isMember != true) {
        // Cached replies need only a display snapshot. The account-scoped
        // store notifies the UI; a failed lookup leaves the count unknown.
        _featureQuotas?.fetch().ignore();
      }
    } catch (error) {
      if (error is ChatroomFeatureQuotaException) {
        _finishInspirationAnalytics(attempt, 'failed');
        if (mounted && current()) {
          _setReplyControlsState(() => _inspirationQuotaQueried = true);
          if (error.quota == null) {
            showGenesisToast(context, error.message);
          }
        }
        return;
      }
      _finishInspirationAnalyticsFromError(attempt, error);
      if (mounted && ownsRequest()) {
        _showReplyActionFailure(
          error,
          _LocationChatReplyConnectionAction.inspiration,
        );
      }
    } finally {
      // Source changes reject the result; only a newer request owns these flags.
      if (mounted && generation == _inspirationRequestGeneration) {
        _setReplyControlsState(() {
          _inspirationQuotaChecking = false;
          _inspirationLoading = false;
        });
      }
    }
  }

  void _sendInspiration(String text) {
    final source = _inspirationDisplayedSource;
    final epoch = _inspirationEpoch;
    if (source == null ||
        epoch == null ||
        _sending ||
        !source.sameOrigin(_currentInspirationSource) ||
        !_inspirationMessages.contains(text)) {
      return;
    }
    final attempt = _inspirationAnalyticsAttempt;
    if (attempt != null) {
      attempt.phase = _LocationChatInspirationAnalyticsPhase.sending;
    }
    unawaited(
      _send(
        textOverride: text,
        inspirationSource: source,
        inspirationEpoch: epoch,
        positionWaitingImmediately: true,
        onCanonicalMessage: (_) =>
            _finishInspirationAnalytics(attempt, 'send_success'),
        onFailure: (error, _) =>
            _finishInspirationAnalyticsFromError(attempt, error),
      ),
    );
  }
}
