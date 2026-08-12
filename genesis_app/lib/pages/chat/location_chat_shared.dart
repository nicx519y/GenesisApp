part of 'location_chat_page.dart';

String selectedModelCodeFromUserInfo(Map<String, dynamic> userInfo) {
  final direct = asString(userInfo['selected_model_code']).trim();
  if (direct.isNotEmpty) return direct;
  final nestedUser = userInfo['user'];
  if (nestedUser is! Map) return '';
  return asString(nestedUser['selected_model_code']).trim();
}

@visibleForTesting
void preserveUnmatchedLocationChatLocalMessages({
  required List<ChatMessageVm> previous,
  required List<ChatMessageVm> reconciled,
  required Set<String> usedLocalIds,
}) {
  for (final message in previous) {
    if (usedLocalIds.contains(message.localId) ||
        !message.isMe ||
        message.clientMsgId.trim().isEmpty ||
        !_shouldPreserveUnmatchedLocationChatLocalMessage(message)) {
      continue;
    }
    usedLocalIds.add(message.localId);
    reconciled.add(message);
  }
}

bool _shouldPreserveUnmatchedLocationChatLocalMessage(ChatMessageVm message) {
  if (message.status == 'sending' || message.status == 'failed') return true;

  // A V2 ACK only confirms that the command was accepted. Until the
  // canonical user echo supplies its ids, this is still the optimistic row
  // and must survive unrelated chatroom state updates.
  return message.status == 'sent' &&
      message.globalMessageId <= 0 &&
      (message.messageId ?? 0) <= 0 &&
      message.locationMessageId <= 0;
}

const Set<String> _locationChatDraftRecoverableFailureCodes = <String>{
  '1002',
  '1008',
  '10001',
  '2006',
  '2010',
  '3001',
  '5000',
};

const Set<String> _locationChatDraftRecoverableSendFailureCodes = <String>{
  'ack_timeout',
  'connect_failed',
  'send_message_send_failed',
  'socket_closed',
  'socket_error',
  'stream_missing',
};

String? recoverLocationChatDraftAfterRetriableAckFailure({
  required Object failure,
  required ChatMessageVm localMessage,
  required List<ChatMessageVm> messages,
  bool activeSendFailure = false,
}) {
  if (failure is! ChatroomFailureEvent ||
      !_shouldRecoverLocationChatDraftAfterFailure(
        failure,
        activeSendFailure: activeSendFailure,
      )) {
    return null;
  }
  messages.removeWhere((message) => identical(message, localMessage));
  return localMessage.text;
}

bool _shouldRecoverLocationChatDraftAfterFailure(
  ChatroomFailureEvent failure, {
  required bool activeSendFailure,
}) {
  final code = failure.code.trim();
  if (_locationChatDraftRecoverableFailureCodes.contains(code)) return true;
  if (!activeSendFailure && failure.requestType.trim() != 'send_message') {
    return false;
  }
  return _locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(
        failure.sourceType.trim(),
      );
}

String _locationChatDraftRestoreToastMessage(Object failure) {
  if (failure is! ChatroomFailureEvent) {
    return 'Something went wrong. Please try again later.';
  }
  final code = failure.code.trim();
  final sourceType = failure.sourceType.trim();
  if (_locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(sourceType)) {
    return 'Something went wrong. Please try again later.';
  }
  return chatroomFailureToastMessage(failure);
}

bool _shouldShowDraftRestoreToast(Object failure) {
  if (failure is! ChatroomFailureEvent) return true;
  final code = failure.code.trim();
  final sourceType = failure.sourceType.trim();
  return _locationChatDraftRecoverableSendFailureCodes.contains(code) ||
      _locationChatDraftRecoverableSendFailureCodes.contains(sourceType);
}
