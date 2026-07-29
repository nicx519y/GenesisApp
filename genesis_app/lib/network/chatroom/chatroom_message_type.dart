const String chatroomTextMessageType = 'text';
const String chatroomImageMessageType = 'image';
const String chatroomNarratorPictureSenderId = 'nar_pic';

enum ChatroomMessageRenderKind { text, image, hidden }

String normalizeChatroomMessageType(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized.isEmpty ? chatroomTextMessageType : normalized;
}

String resolveIncomingChatroomMessageType({
  required bool hasMessageTypeField,
  required Object? rawMessageType,
  required Object? senderId,
}) {
  final normalizedSenderId = senderId?.toString().trim().toLowerCase() ?? '';
  if (!hasMessageTypeField &&
      normalizedSenderId == chatroomNarratorPictureSenderId) {
    return chatroomImageMessageType;
  }
  return normalizeChatroomMessageType(rawMessageType);
}

ChatroomMessageRenderKind resolveChatroomMessageRenderKind({
  required Object? messageType,
  required Object? senderId,
}) {
  final normalizedType = normalizeChatroomMessageType(messageType);
  final normalizedSenderId = senderId?.toString().trim().toLowerCase() ?? '';
  if (normalizedType == chatroomTextMessageType) {
    return ChatroomMessageRenderKind.text;
  }
  if (normalizedType == chatroomImageMessageType &&
      normalizedSenderId == chatroomNarratorPictureSenderId) {
    return ChatroomMessageRenderKind.image;
  }
  return ChatroomMessageRenderKind.hidden;
}
