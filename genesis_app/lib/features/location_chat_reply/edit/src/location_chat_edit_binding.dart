part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatEditBinding on _LocationChatPanelState {
  Future<void> _startEditCurrentReply(
    ChatUiStyleConfig style,
    double? selfCap,
    double? otherCap,
    _LocationChatEditAnalyticsAttempt attempt,
  ) => _submitReplyAction(
    _LocationChatReplyActionTransaction(
      action: _LocationChatReplyConnectionAction.edit,
      commit: () => _editCurrentReply(style, selfCap, otherCap, attempt),
      onFailure: (error) => _finishEditAnalyticsFromError(attempt, error),
    ),
  );

  Future<void> _editCurrentReply(
    ChatUiStyleConfig style,
    double? selfCap,
    double? otherCap,
    _LocationChatEditAnalyticsAttempt attempt,
  ) async {
    final controller = _replyController;
    if (controller == null ||
        _sending ||
        (_replyCardTransitionBusy &&
            _replyConnectionAction !=
                _LocationChatReplyConnectionAction.edit) ||
        _editQuotaChecking ||
        _preparingReplyAction ||
        _inspirationLoading ||
        _replyEditorOpen) {
      _finishEditAnalyticsFromError(
        attempt,
        StateError('This reply is no longer editable'),
      );
      return;
    }
    final location = widget.locationId;
    final requestedRound = controller.stateFor(location)?.roundId;
    final operation = _LocationChatReplyOperationScope(this);
    bool currentEditor() =>
        operation.canApplyToReply &&
        operation.ownsQuotaSession &&
        controller.stateFor(location)?.roundId == requestedRound;
    _editQuotaChecking = true;
    try {
      if (!await _refreshReplyFeatureQuota(
            'conversation_edit',
            current: currentEditor,
            onQuotaLookupStarted: () {
              if (!currentEditor()) return;
              _setReplyControlsState(() {
                _preparingReplyAction = true;
                _editQuotaLoading = true;
              });
            },
          ) ||
          !currentEditor()) {
        _finishEditAnalyticsFromError(
          attempt,
          StateError('This reply is no longer editable'),
        );
        return;
      }
      if (!_editQuotaLoading) {
        _setReplyControlsState(() {
          _preparingReplyAction = true;
          _editQuotaLoading = true;
        });
      }
      final target = await controller.prepareEditor(location);
      if (!currentEditor()) {
        _finishEditAnalyticsFromError(
          attempt,
          StateError('This reply is no longer editable'),
        );
        return;
      }
      final messages = _replyProjection.messages(
        target.messages,
        cardId: target.cardId,
      );
      List<ChatroomLlmMessageOperation> operations(
        LocationChatEditResult result,
      ) => [
        for (final message in messages)
          if (result.deletedMessageIds.contains(message.localId))
            ChatroomLlmMessageOperation.delete(
              globalMessageId: message.globalMessageId,
            )
          else if (result.texts[message.localId] case final text?)
            if (text != message.text)
              if (text.trim().isEmpty)
                ChatroomLlmMessageOperation.delete(
                  globalMessageId: message.globalMessageId,
                )
              else
                ChatroomLlmMessageOperation.edit(
                  globalMessageId: message.globalMessageId,
                  content: text,
                ),
      ];
      _setReplyControlsState(() => _editQuotaLoading = false);
      await _openReplyEditor(
        LocationChatEditPageArgs(
          worldId: widget.worldId,
          locationId: location,
          roundId: target.roundId,
          cardId: target.cardId,
          messages: messages,
          style: style,
          backgroundImageUrl: widget.backgroundImageUrl,
          backgroundPreviewImageUrl: widget.backgroundPreviewImageUrl,
          selfMessageBubbleMaxWidthCap: selfCap,
          otherMessageBubbleMaxWidthCap: otherCap,
          mentionCatalog: _textController.catalog,
          onOpened: () => attempt.finish('edit_opened|${attempt.roundId}'),
          onOpenFailed: () => _finishEditAnalyticsFromError(
            attempt,
            StateError('The editor could not be opened'),
          ),
          onSave: (result) async {
            if (!currentEditor()) {
              throw StateError('This chat is no longer active.');
            }
            try {
              await controller.submitEdit(target, operations(result));
            } on ChatroomFeatureQuotaException {
              if (currentEditor()) {
                _setReplyControlsState(() => _editQuotaQueried = true);
              }
              rethrow;
            }
          },
        ),
      );
    } catch (error) {
      _finishEditAnalyticsFromError(attempt, error);
      if (mounted && currentEditor()) {
        if (!isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
      }
    } finally {
      // A changed round invalidates results, but this operation still owns
      // its loading flags until the binding or account changes.
      if (operation.ownsReplyTarget && operation.ownsQuotaSession) {
        _setReplyControlsState(() {
          _editQuotaChecking = false;
          _preparingReplyAction = false;
          _editQuotaLoading = false;
        });
      }
    }
  }
}
