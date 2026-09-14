part of '../../../../pages/chat/location_chat_page.dart';

extension _LocationChatEditBinding on _LocationChatPanelState {
  Future<void> _editCurrentReply(
    ChatUiStyleConfig style,
    double? selfCap,
    double? otherCap,
  ) async {
    final controller = _replyController;
    if (controller == null ||
        _sending ||
        _replyCardTransitionBusy ||
        _editQuotaChecking ||
        _preparingReplyAction ||
        _inspirationLoading ||
        _replyEditorOpen) {
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
      if (!await _checkReplyFeatureQuota(
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
