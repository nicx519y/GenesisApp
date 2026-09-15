part of 'location_chat_page.dart';

const Duration _locationChatAckLoadingTimeout = Duration(seconds: 10);

extension _LocationChatAckLoading on _LocationChatPanelState {
  void _startAckLoading({
    required WorldChatroomService service,
    required String locationId,
    required String clientMsgId,
    required ChatMessageVm localMessage,
  }) {
    if (!mounted ||
        !identical(service, _service) ||
        locationId != widget.locationId) {
      return;
    }
    var sentMessage = localMessage;
    for (final message in _messages) {
      if (message.clientMsgId == clientMsgId) {
        sentMessage = message;
        break;
      }
    }
    if (sentMessage.status == 'failed') return;

    _clearAckLoading();
    _inspirationAckPreviousRound = _messages
        .where((message) => message.localId != sentMessage.localId)
        .fold<int>(
          0,
          (round, message) =>
              math.max(round, int.tryParse(message.roundId) ?? 0),
        );
    _ackLoadingClientMsgId = clientMsgId;
    _ackLoadingMessageLocalId = sentMessage.localId;
    if (_dismissAckLoadingIfVisible()) return;
    _ackLoadingTimeout = Timer(_locationChatAckLoadingTimeout, () {
      if (!mounted || _ackLoadingClientMsgId != clientMsgId) return;
      _setLocationChatState(_clearAckLoading);
    });
    if (_scrollCoordinator.shouldFollowLatest &&
        _scrollCoordinator.isAtBottom) {
      _scrollCoordinator.requestBottom(
        reason: LocationChatBottomReason.replyGeneration,
        behavior: LocationChatBottomBehavior.jump,
      );
    }
  }

  void _clearAckLoading() {
    _ackLoadingTimeout?.cancel();
    _ackLoadingTimeout = null;
    _ackLoadingClientMsgId = null;
    _ackLoadingMessageLocalId = null;
  }

  String _ackLoadingRoundId() {
    final clientMsgId = _ackLoadingClientMsgId;
    if (clientMsgId == null) return '';
    for (final message in _messages) {
      if (message.clientMsgId == clientMsgId &&
          message.roundId.trim().isNotEmpty) {
        return message.roundId.trim();
      }
    }
    final activeRound =
        _service?.state.conversationRoundStatesByLocation[widget.locationId] ??
        _chatroomState.conversationRoundStatesByLocation[widget.locationId];
    return activeRound?.clientMsgId == clientMsgId
        ? activeRound!.conversationRoundId.trim()
        : '';
  }

  bool _hasVisibleAiReplyForRound(
    List<ChatMessageVm> messages,
    String roundId,
  ) {
    if (roundId.isEmpty) return false;
    return messages.any(
      (message) =>
          message.roundId == roundId &&
          !message.isMe &&
          (message.senderType == 'character' ||
              message.senderType == 'ai' ||
              message.isNarrator) &&
          (message.text.trim().isNotEmpty ||
              message.imageUrl.trim().isNotEmpty),
    );
  }

  bool _dismissAckLoadingIfVisible() {
    final clientMsgId = _ackLoadingClientMsgId;
    if (clientMsgId == null) return false;
    for (final message in _messages) {
      if (message.clientMsgId == clientMsgId) {
        _ackLoadingMessageLocalId = message.localId;
        break;
      }
    }
    final roundId = _ackLoadingRoundId();
    if (roundId.isEmpty) return false;
    final presentationState = _replyController?.presentationStateFor(
      widget.locationId,
    );
    final displayMessages = _replyProjection
        .presentation(presentationState)
        .messages;
    if (!_hasVisibleAiReplyForRound(displayMessages, roundId)) return false;
    _clearAckLoading();
    return true;
  }
}
