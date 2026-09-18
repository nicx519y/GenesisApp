part of 'location_chat_page.dart';

extension _LocationChatSendActions on _LocationChatPanelState {
  String get _initialMessageText =>
      _initialOutgoingMessage?.text ?? _textController.serializedText;

  void _maybeSendInitialMessage() {
    if (!_initialMessageSendPending || _initialMessageSendScheduled) return;
    if (!widget.active ||
        _service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _sendAwaitingResponse ||
        _replyGenerationInProgress ||
        _sending ||
        isGenesisUgcTextBlank(_initialMessageText)) {
      return;
    }
    _initialMessageSendScheduled = true;
    scheduleMicrotask(() async {
      _initialMessageSendScheduled = false;
      if (!mounted ||
          !_initialMessageSendPending ||
          !widget.active ||
          _service == null ||
          _chatroomState.joinedLocationId != widget.locationId ||
          _chatroomState.inputBlocked ||
          _sendAwaitingResponse ||
          _replyGenerationInProgress ||
          _sending ||
          isGenesisUgcTextBlank(_initialMessageText)) {
        return;
      }
      _initialMessageSendPending = false;
      await _send(outgoingMessage: _initialOutgoingMessage);
    });
  }

  Future<void> _send({
    ChatMessageVm? outgoingMessage,
    String? textOverride,
    ChatroomInspirationSource? inspirationSource,
    int? inspirationEpoch,
    bool positionWaitingImmediately = false,
  }) async {
    final service = _service;
    if (service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _sendAwaitingResponse ||
        _replyGenerationInProgress ||
        _preparingReplyAction ||
        _replyCardTransitionBusy ||
        _sending) {
      return;
    }
    final draftAtSubmit = _textController.serializedText;
    final text = normalizeGenesisUgcTextForDisplay(
      textOverride ?? outgoingMessage?.text ?? draftAtSubmit,
    );
    if (isGenesisUgcTextBlank(text)) return;
    final controller = _replyController;
    final replyPresentationState = controller?.presentationStateFor(
      widget.locationId,
    );
    final replyActionsSuppressionIdentity = inspirationSource != null
        ? '${inspirationSource.worldId}/${inspirationSource.locationId}/${inspirationSource.roundId}'
        : replyPresentationState != null
        ? '${widget.worldId}/${widget.locationId}/${replyPresentationState.roundId}'
        : null;
    final outgoingClientMsgId = outgoingMessage?.clientMsgId;
    final outgoingText = outgoingMessage?.text;
    final outgoingStatus = outgoingMessage?.status;
    final outgoingError = outgoingMessage?.error;
    late final String clientMsgId;
    late final ChatMessageVm localMessage;
    var optimisticMessageAdded = false;

    void addOptimisticMessage() {
      final needsLatestMessageReveal =
          positionWaitingImmediately &&
          _scrollCoordinator.prepareWaitingReplyPosition();
      clientMsgId = _nextClientMsgId();
      localMessage =
          outgoingMessage ??
          ChatMessageVm(
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
        _clearAckLoading();
        _sending = true;
        if (replyActionsSuppressionIdentity != null) {
          _suppressedReplyActionsIdentity = replyActionsSuppressionIdentity;
        }
        localMessage.clientMsgId = clientMsgId;
        localMessage.text = text;
        localMessage.status = 'sending';
        localMessage.error = null;
        if (!_messages.contains(localMessage)) _messages.add(localMessage);
        if (positionWaitingImmediately) {
          _preAckWaitingClientMsgId = clientMsgId;
          _preAckWaitingMessageLocalId = localMessage.localId;
          _preAckWaitingAccepted = false;
        }
        if (outgoingMessage != null) return;
        if (_textController.serializedText == draftAtSubmit) {
          _hasDraftText = false;
          _textController.clear();
        } else {
          _hasDraftText = !isGenesisUgcTextBlank(
            _textController.serializedText,
          );
        }
      });
      optimisticMessageAdded = true;
      _recordPanelDebug(
        action: 'optimisticSend',
        details: {
          'clientMsgId': clientMsgId,
          'vm': LocationChatDebugSlice.debugRenderMessage(localMessage),
        },
      );
      if (outgoingMessage == null &&
          (!positionWaitingImmediately || needsLatestMessageReveal)) {
        _scrollCoordinator.requestBottom(
          reason: LocationChatBottomReason.sentMessage,
          behavior: LocationChatBottomBehavior.jump,
        );
      }
    }

    void rollbackOptimisticMessage() {
      if (outgoingMessage == null) {
        _messages.remove(localMessage);
        if (isGenesisUgcTextBlank(_textController.serializedText) &&
            !isGenesisUgcTextBlank(draftAtSubmit)) {
          _textController.setSerializedText(draftAtSubmit);
          _hasDraftText = true;
        }
      } else {
        localMessage.clientMsgId = outgoingClientMsgId!;
        localMessage.text = outgoingText!;
        localMessage.status = outgoingStatus!;
        localMessage.error = outgoingError;
      }
    }

    void cancelImmediateWaiting() {
      if (_preAckWaitingClientMsgId != clientMsgId) return;
      _clearPreAckWaiting(resetPosition: true);
    }

    // All send gestures insert the bubble and hide the previous reply's
    // controls in the same state update, before any reply finalization awaits.
    addOptimisticMessage();

    if (controller != null) {
      final location = widget.locationId;
      final bindingGeneration = _replyBindingGeneration;
      try {
        await controller.finalizeBeforeSend(
          location,
          expectedSource: inspirationSource,
        );
        if (inspirationSource != null &&
            !(_inspirationController?.isCurrent(
                  inspirationSource,
                  inspirationEpoch!,
                ) ??
                false)) {
          throw StateError(
            'The reply changed. Please select inspiration again.',
          );
        }
      } catch (error) {
        if (mounted &&
            bindingGeneration == _replyBindingGeneration &&
            widget.locationId == location &&
            identical(service, _service)) {
          _setLocationChatState(() {
            _sending = false;
            cancelImmediateWaiting();
            if (optimisticMessageAdded) {
              rollbackOptimisticMessage();
            }
            if (_suppressedReplyActionsIdentity ==
                replyActionsSuppressionIdentity) {
              _suppressedReplyActionsIdentity = null;
            }
          });
          if (!isChatroomErrorPresentedGlobally(error)) {
            showGenesisToast(context, chatroomOperationErrorMessage(error));
          }
        } else if (mounted && optimisticMessageAdded) {
          _setLocationChatState(() {
            cancelImmediateWaiting();
            rollbackOptimisticMessage();
            _sending = false;
            if (_suppressedReplyActionsIdentity ==
                replyActionsSuppressionIdentity) {
              _suppressedReplyActionsIdentity = null;
            }
          });
        }
        return;
      }
      if (!mounted ||
          bindingGeneration != _replyBindingGeneration ||
          !widget.active ||
          location != widget.locationId ||
          !identical(service, _service)) {
        if (mounted && optimisticMessageAdded) {
          _setLocationChatState(() {
            cancelImmediateWaiting();
            rollbackOptimisticMessage();
            _sending = false;
            if (_suppressedReplyActionsIdentity ==
                replyActionsSuppressionIdentity) {
              _suppressedReplyActionsIdentity = null;
            }
          });
        }
        return;
      }
      if (_chatroomState.joinedLocationId != location ||
          _chatroomState.inputBlocked ||
          _sendAwaitingResponse ||
          widget.worldTickInProgress) {
        _setLocationChatState(() {
          _sending = false;
          cancelImmediateWaiting();
          if (optimisticMessageAdded) {
            rollbackOptimisticMessage();
          }
          if (_suppressedReplyActionsIdentity ==
              replyActionsSuppressionIdentity) {
            _suppressedReplyActionsIdentity = null;
          }
        });
        return;
      }
    }

    await _submitLocalMessage(
      service: service,
      localMessage: localMessage,
      clientMsgId: clientMsgId,
      isInitialSend: true,
      replyActionsSuppressionIdentity: replyActionsSuppressionIdentity,
    );
  }

  Future<void> _retryFailedMessage(ChatMessageVm message) async {
    if (_replyCardTransitionBusy) return;
    final service = _service;
    if (!message.isMe ||
        message.status != 'failed' ||
        service == null ||
        _chatroomState.joinedLocationId != widget.locationId ||
        _chatroomState.inputBlocked ||
        _sendAwaitingResponse ||
        _replyGenerationInProgress ||
        _preparingReplyAction ||
        _sending) {
      return;
    }

    final controller = _replyController;
    if (controller != null) {
      final location = widget.locationId;
      final bindingGeneration = _replyBindingGeneration;
      _setLocationChatState(() => _sending = true);
      try {
        await controller.finalizeBeforeSend(location);
      } catch (error) {
        if (mounted &&
            bindingGeneration == _replyBindingGeneration &&
            widget.locationId == location &&
            identical(service, _service)) {
          _setLocationChatState(() => _sending = false);
          if (!isChatroomErrorPresentedGlobally(error)) {
            showGenesisToast(context, chatroomOperationErrorMessage(error));
          }
        }
        return;
      }
      if (!mounted ||
          bindingGeneration != _replyBindingGeneration ||
          !widget.active ||
          location != widget.locationId ||
          !identical(service, _service)) {
        return;
      }
      if (_chatroomState.joinedLocationId != location ||
          _chatroomState.inputBlocked ||
          _sendAwaitingResponse ||
          widget.worldTickInProgress) {
        _setLocationChatState(() => _sending = false);
        return;
      }
    }

    final clientMsgId = _nextClientMsgId();
    _setLocationChatState(() {
      _clearAckLoading();
      message.clientMsgId = clientMsgId;
      message.status = 'sending';
      message.error = null;
      _sending = true;
    });
    _recordPanelDebug(
      action: 'retrySend',
      details: {'clientMsgId': clientMsgId, 'localId': message.localId},
    );

    await _submitLocalMessage(
      service: service,
      localMessage: message,
      clientMsgId: clientMsgId,
      isInitialSend: false,
    );
  }

  Future<void> _submitLocalMessage({
    required WorldChatroomService service,
    required ChatMessageVm localMessage,
    required String clientMsgId,
    required bool isInitialSend,
    String? replyActionsSuppressionIdentity,
  }) async {
    var receiptReceived = false;
    final sentLocationId = widget.locationId;
    try {
      if (isInitialSend) {
        unawaited(
          FirebaseAnalyticsMonitoring.recordMessageSent(
            worldId: widget.worldId,
            locationId: widget.locationId,
          ),
        );
      }
      final handle = service.sendMessage(
        localMessage.text,
        clientMsgId: clientMsgId,
      );
      final receipt = await handle.receipt;
      receiptReceived = true;
      if (!mounted) {
        service.cancelCanonicalMessageWait(clientMsgId);
        return;
      }
      unawaited(
        runLocationChatMetadataUpdateBestEffort(_markRecentWorldChatLocation),
      );
      _setLocationChatState(() {
        localMessage.status = 'sent';
        _sending = false;
        _startAckLoading(
          service: service,
          locationId: sentLocationId,
          clientMsgId: clientMsgId,
          localMessage: localMessage,
        );
      });
      _recordPanelDebug(
        action: 'sendReceipt',
        details: {
          'clientMsgId': receipt.clientMsgId,
          'receivedAt': receipt.receivedAt?.toIso8601String(),
        },
      );

      WorldChatroomMessage canonicalMessage;
      try {
        canonicalMessage = await handle.canonicalMessage.timeout(
          const Duration(seconds: 5),
        );
      } on TimeoutException {
        await service.refreshLatestMessages(
          locationId: widget.locationId,
          limit: 20,
          emitLatestFetched: false,
        );
        canonicalMessage = await handle.canonicalMessage.timeout(
          const Duration(seconds: 2),
        );
      }
      if (!mounted) return;
      GenesisTelemetry.collectLog(
        actionType: 'event',
        action: 'location_chat_send_message',
        object1: widget.worldId,
        object2: widget.locationId,
        object3: canonicalMessage.messageId,
      );
      _setLocationChatState(() {
        ChatMessageVm target = localMessage;
        for (final message in _messages) {
          if (message.clientMsgId.trim() == clientMsgId) {
            target = message;
            break;
          }
        }
        target.globalMessageId = canonicalMessage.globalMessageId;
        target.messageId = canonicalMessage.messageId;
        target.locationMessageId = canonicalMessage.locationMessageId;
        target.roundId = canonicalMessage.conversationRoundId;
        target.status = 'sent';
        _sending = false;
      });
      _recordPanelDebug(
        action: 'sendCanonicalEcho',
        details: {
          'clientMsgId': clientMsgId,
          'globalMessageId': canonicalMessage.globalMessageId,
          'messageId': canonicalMessage.messageId,
          'locationMessageId': canonicalMessage.locationMessageId,
          'roundId': canonicalMessage.conversationRoundId,
        },
      );
    } catch (e) {
      if (receiptReceived) {
        service.cancelCanonicalMessageWait(clientMsgId, reason: e);
      }
      if (!mounted) return;
      _setLocationChatState(() {
        if (!receiptReceived && _preAckWaitingClientMsgId == clientMsgId) {
          _clearPreAckWaiting(resetPosition: true);
        }
        if (!receiptReceived && _ackLoadingClientMsgId == clientMsgId) {
          _clearAckLoading();
        }
        if (!receiptReceived) {
          // ACK rejection, timeout, and transport failure share the same retry
          // affordance for composer and Inspiration sends.
          localMessage.status = 'failed';
          localMessage.error = null;
        } else {
          // The command was accepted. Keep the optimistic message as sent so
          // a sync timeout cannot invite an accidental duplicate retry.
          localMessage.status = 'sent';
          localMessage.error = null;
        }
        _sending = false;
        if (!receiptReceived &&
            _suppressedReplyActionsIdentity ==
                replyActionsSuppressionIdentity) {
          _suppressedReplyActionsIdentity = null;
        }
      });
      _recordPanelDebug(
        action: 'sendFailed',
        details: {'clientMsgId': clientMsgId, 'error': '$e'},
      );
    }
  }

  Future<void> _markRecentWorldChatLocation() async {
    final services = AppServicesScope.read(context);
    final worldId = widget.worldId;
    final locationId = widget.locationId;
    final locationPathIds = List<String>.of(widget.recentChatLocationPathIds);
    final uid = await resolveRecentWorldChatUid(services);
    await recentWorldChatStore.markRecentChat(
      uid: uid,
      worldId: worldId,
      locationId: locationId,
      locationPathIds: locationPathIds,
    );
  }

  String _nextClientMsgId() {
    _clientMsgCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_clientMsgCounter';
  }

  String _latestMessageLocalId() {
    final unreadCandidates = _messages.where(
      (message) => message.status != 'system',
    );
    if (unreadCandidates.isEmpty) return '';
    return unreadCandidates.last.localId;
  }

  bool _syncHasMoreOlderMessagesForSource(List<WorldChatroomMessage> source) {
    if (widget.active &&
        widget.retainOpeningPreviewUntilHistory &&
        !_openingPreviewResolved) {
      return false;
    }
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
