part of 'location_chat_page.dart';

extension _LocationChatSendActions on _LocationChatPanelState {
  Future<void> _send() async {
    final service = _service;
    if (service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _awaitingAiResponse ||
        _sending) {
      return;
    }
    final text = normalizeGenesisUgcTextForDisplay(_textController.text);
    if (isGenesisUgcTextBlank(text)) return;

    final clientMsgId = _nextClientMsgId();
    final localMessage = ChatMessageVm(
      localId: 'local-$clientMsgId',
      clientMsgId: clientMsgId,
      senderId: _mySenderId,
      senderName: _localSelfDisplayName(),
      avatarUrl: _resizedLocationChatAvatarUrl(_localSelfAvatarUrl()),
      isPlayerControlledRole: _identityCandidatesArePlayerControlledRole([
        _myUserId,
        _mySenderId,
      ]),
      text: text,
      isMe: true,
      status: 'sending',
    );

    _setLocationChatState(() {
      _sending = true;
      _awaitingAiResponse = true;
      _awaitingAiResponseRoundId = '';
      _messages.add(localMessage);
      _hasDraftText = false;
      _textController.clear();
    });
    _recordPanelDebug(
      action: 'optimisticSend',
      details: {
        'clientMsgId': clientMsgId,
        'vm': LocationChatDebugSlice.debugRenderMessage(localMessage),
      },
    );
    _scrollToBottom();

    await _submitLocalMessage(
      service: service,
      localMessage: localMessage,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> _retryFailedMessage(ChatMessageVm message) async {
    final service = _service;
    if (!message.isMe ||
        message.status != 'failed' ||
        service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _awaitingAiResponse ||
        _sending) {
      return;
    }

    final clientMsgId = _nextClientMsgId();
    _setLocationChatState(() {
      message.clientMsgId = clientMsgId;
      message.status = 'sending';
      message.error = null;
      _sending = true;
      _awaitingAiResponse = true;
      _awaitingAiResponseRoundId = '';
    });
    _recordPanelDebug(
      action: 'retrySend',
      details: {'clientMsgId': clientMsgId, 'localId': message.localId},
    );

    await _submitLocalMessage(
      service: service,
      localMessage: message,
      clientMsgId: clientMsgId,
    );
  }

  Future<void> _submitLocalMessage({
    required WorldChatroomService service,
    required ChatMessageVm localMessage,
    required String clientMsgId,
  }) async {
    try {
      final ack = await service.sendMessage(
        localMessage.text,
        clientMsgId: clientMsgId,
      );
      if (!mounted) return;
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'location_chat_send_message',
        object1: widget.worldId,
        object2: widget.locationId,
        object3: ack.messageId,
      );
      unawaited(_markRecentWorldChatLocation());
      _setLocationChatState(() {
        localMessage.globalMessageId = ack.globalMessageId;
        localMessage.messageId = ack.messageId;
        localMessage.locationMessageId = ack.locationMessageId;
        localMessage.roundId = ack.conversationRoundId;
        localMessage.status = 'sent';
        _awaitingAiResponseRoundId = ack.conversationRoundId.trim();
        _sending = false;
      });
      _recordPanelDebug(
        action: 'sendAck',
        details: {
          'clientMsgId': clientMsgId,
          'globalMessageId': ack.globalMessageId,
          'messageId': ack.messageId,
          'locationMessageId': ack.locationMessageId,
          'roundId': ack.conversationRoundId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final restoredDraft = recoverLocationChatDraftAfterRetriableAckFailure(
        failure: e,
        localMessage: localMessage,
        messages: _messages,
        activeSendFailure: true,
      );
      _setLocationChatState(() {
        if (restoredDraft != null) {
          _hasDraftText = restoredDraft.trim().isNotEmpty;
          _textController.value = TextEditingValue(
            text: restoredDraft,
            selection: TextSelection.collapsed(offset: restoredDraft.length),
          );
        } else {
          localMessage.status = 'failed';
          localMessage.error = e.toString();
        }
        _awaitingAiResponse = false;
        _awaitingAiResponseRoundId = '';
        _sending = false;
      });
      if (restoredDraft != null && _shouldShowDraftRestoreToast(e)) {
        showGenesisToast(
          context,
          _locationChatDraftRestoreToastMessage(e),
          duration: const Duration(seconds: 4),
        );
      }
      _recordPanelDebug(
        action: 'sendFailed',
        details: {'clientMsgId': clientMsgId, 'error': '$e'},
      );
    }
  }

  Future<void> _markRecentWorldChatLocation() async {
    final uid = await resolveRecentWorldChatUid(AppServicesScope.read(context));
    await recentWorldChatStore.markRecentChat(
      uid: uid,
      worldId: widget.worldId,
      locationId: widget.locationId,
      locationPathIds: widget.recentChatLocationPathIds,
    );
  }

  String _nextClientMsgId() {
    _clientMsgCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_clientMsgCounter';
  }

  String _latestMessageLocalId() {
    final nonSystem = _messages.where((message) => !message.isSystem);
    if (nonSystem.isEmpty) return '';
    return nonSystem.last.localId;
  }

  bool _syncHasMoreOlderMessagesForSource(List<WorldChatroomMessage> source) {
    final hasOlderCursor = _oldestLocationMessageId(source) > 0;
    if (!hasOlderCursor && source.isNotEmpty) {
      _olderMessagesExhaustedByCursorlessContent = true;
    }
    final nextHasMoreOlder =
        hasOlderCursor &&
        !_olderMessagesExhaustedByRemote &&
        !_olderMessagesExhaustedByCursorlessContent;
    if (_hasMoreOlderMessages == nextHasMoreOlder) return false;
    _hasMoreOlderMessages = nextHasMoreOlder;
    return true;
  }
}
