class LocationChatMessageVm {
  LocationChatMessageVm({
    required this.localId,
    this.messageId,
    this.roundId = '',
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isMe,
    required this.status,
    this.senderType = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory LocationChatMessageVm.system(String text) {
    return LocationChatMessageVm(
      localId: 'system-${DateTime.now().microsecondsSinceEpoch}',
      senderId: '',
      senderName: '',
      text: text,
      isMe: false,
      status: 'system',
      senderType: 'system',
    );
  }

  final String localId;
  int? messageId;
  String roundId;
  final String senderId;
  final String senderName;
  String text;
  final bool isMe;
  String status;
  final String senderType;
  String? error;
  final DateTime createdAt;

  bool get isSystem => senderType == 'system';
}

String firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
