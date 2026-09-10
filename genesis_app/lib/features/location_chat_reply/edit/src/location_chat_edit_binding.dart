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
        _preparingReplyAction ||
        _replyEditorOpen) {
      return;
    }
    final location = widget.locationId;
    final bindingGeneration = _replyBindingGeneration;
    bool currentEditor() =>
        mounted &&
        widget.active &&
        bindingGeneration == _replyBindingGeneration &&
        identical(controller, _replyController) &&
        location == widget.locationId;
    _setLocationChatState(() => _preparingReplyAction = true);
    try {
      final target = await controller.prepareEditor(location);
      if (!currentEditor()) {
        return;
      }
      final messages = _replyMessageVms(target.messages, cardId: target.cardId);
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
      await _openReplyEditor(
        LocationChatEditPageArgs(
          worldId: widget.worldId,
          locationId: location,
          roundId: target.roundId,
          cardId: target.cardId,
          messages: messages,
          style: style,
          canEdit: target.canEdit,
          canDelete: target.canDelete,
          backgroundImageUrl: widget.backgroundImageUrl,
          backgroundPreviewImageUrl: widget.backgroundPreviewImageUrl,
          selfMessageBubbleMaxWidthCap: selfCap,
          otherMessageBubbleMaxWidthCap: otherCap,
          mentionCatalog: _textController.catalog,
          onSave: (result) => controller.submitEdit(target, operations(result)),
        ),
      );
    } catch (error) {
      if (mounted && currentEditor()) {
        if (!isChatroomErrorPresentedGlobally(error)) {
          showGenesisToast(context, chatroomOperationErrorMessage(error));
        }
      }
    } finally {
      if (mounted &&
          bindingGeneration == _replyBindingGeneration &&
          widget.locationId == location &&
          identical(controller, _replyController)) {
        _setLocationChatState(() => _preparingReplyAction = false);
      }
    }
  }
}
