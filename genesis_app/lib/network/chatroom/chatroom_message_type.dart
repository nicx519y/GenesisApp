const String chatroomTextMessageType = 'text';
const String chatroomImageMessageType = 'image';
const String chatroomNarrationMessageType = 'narration';
const int chatroomNarrationMinAppVersion = 5002;
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

/// The message compatibility version is independent of the native build number.
int chatroomAppVersionNumber(String version) {
  final match = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:[-+][0-9A-Za-z.-]+)?$',
  ).firstMatch(version.trim());
  if (match == null) return 0;
  return int.parse(match[1]!) * 1000000 +
      int.parse(match[2]!) * 1000 +
      int.parse(match[3]!);
}

bool chatroomMessageVersionIsVisible(int minAppVersion, int appVersion) =>
    minAppVersion <= 0 || appVersion >= minAppVersion;

/// Only user text modes are selectable; image sending retains its own contract.
String normalizeOutgoingChatroomMessageType(String value) =>
    value.trim().toLowerCase() == chatroomNarrationMessageType
    ? chatroomNarrationMessageType
    : chatroomTextMessageType;
