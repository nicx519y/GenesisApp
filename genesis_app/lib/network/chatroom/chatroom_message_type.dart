const String chatroomTextMessageType = 'text';

String normalizeChatroomMessageType(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized.isEmpty ? chatroomTextMessageType : normalized;
}
