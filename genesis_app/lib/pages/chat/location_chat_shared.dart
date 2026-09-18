part of 'location_chat_page.dart';

String selectedModelTitleFromUserInfo(
  Map<String, dynamic> userInfo,
  String modelCode,
) {
  final code = modelCode.trim();
  if (code.isEmpty) return '';
  return gemModelTitlesFromUserInfo(userInfo)[code] ?? '';
}

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
