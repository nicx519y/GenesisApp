part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatInspirationBinding on _LocationChatPanelState {
  void _editInspiration(String text) {
    if (_replyCardTransitionBusy) return;
    _textController.setSerializedText(text);
    if (_composerFocusNode.hasFocus) {
      // The system back button can hide the keyboard without dropping focus.
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    } else {
      _composerFocusNode.requestFocus();
    }
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
    if (!widget.active ||
        _chatroomState.inputBlocked ||
        widget.worldTickInProgress) {
      return null;
    }
    return _replyController?.stateFor(widget.locationId)?.inspirationSource;
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
  }

  void _resetInspiration() {
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
      unawaited(_loadInspirations());
    } else if (_inspirationQuotaChecking || _inspirationLoading) {
      _setReplyControlsState(_resetInspiration);
    }
  }

  Future<void> _loadInspirations() async {
    final service = _service;
    final controller = _inspirationController;
    final source = _currentInspirationSource;
    if (service == null ||
        controller == null ||
        source == null ||
        _inspirationQuotaChecking ||
        _inspirationLoading) {
      return;
    }
    _inspirationQuotaChecking = true;
    final generation = ++_inspirationRequestGeneration;
    final operation = _LocationChatReplyOperationScope(this);
    bool current() =>
        operation.ownsBinding &&
        widget.active &&
        generation == _inspirationRequestGeneration &&
        identical(service, _service) &&
        operation.ownsQuotaSession &&
        source.sameOrigin(_currentInspirationSource);
    _setReplyControlsState(() {
      _inspirationRequestSource = source;
      if (!source.sameOrigin(_inspirationDisplayedSource)) {
        _inspirationDisplayedSource = null;
        _inspirationMessages = const [];
        _inspirationEpoch = null;
      }
    });
    try {
      if (!await _checkReplyFeatureQuota(
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
      await service.ensureInspirationHistory(source.locationId);
      if (!current()) return;
      final verified = _currentInspirationSource!;
      _inspirationEpoch = controller.revision(source.locationId);
      final result = await controller.load(verified);
      if (!current() || result == null) return;
      final latest = _currentInspirationSource!;
      if (latest.cardId != null && latest.sourceCardId != result.sourceCardId) {
        return;
      }
      _setReplyControlsState(() {
        _inspirationDisplayedSource = verified;
        _inspirationMessages = result.messages;
      });
    } catch (error) {
      if (error is ChatroomFeatureQuotaException) {
        if (mounted && current()) {
          _setReplyControlsState(() => _inspirationQuotaQueried = true);
          if (error.quota == null) {
            showGenesisToast(context, error.message);
          }
        }
        return;
      }
      if (mounted && current() && !isChatroomErrorPresentedGlobally(error)) {
        showGenesisToast(context, chatroomOperationErrorMessage(error));
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
    unawaited(
      _send(
        textOverride: text,
        inspirationSource: source,
        inspirationEpoch: epoch,
      ),
    );
  }
}
