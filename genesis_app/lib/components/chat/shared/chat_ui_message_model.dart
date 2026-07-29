part of 'chat_ui_library.dart';

class ChatMessageVm {
  ChatMessageVm({
    required this.localId,
    this.clientMsgId = '',
    this.globalMessageId = 0,
    this.messageId,
    this.locationMessageId = 0,
    this.roundId = '',
    this.tickNo = 0,
    required this.senderId,
    required this.senderName,
    this.avatarUrl = '',
    this.imageUrl = '',
    this.isPlayerControlledRole = false,
    required this.text,
    this.currentTime = '',
    required this.isMe,
    required this.status,
    this.senderType = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChatMessageVm.system(String text) {
    return ChatMessageVm(
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
  String clientMsgId;
  int globalMessageId;
  int? messageId;
  int locationMessageId;
  String roundId;
  int tickNo;
  final String senderId;
  String senderName;
  String avatarUrl;
  String imageUrl;
  bool isPlayerControlledRole;
  String text;
  String currentTime;
  bool isMe;
  String status;
  final String senderType;
  String? error;
  final DateTime createdAt;

  bool get isSystem => senderType == 'system' || isNarrator || isTick;

  bool get isNarrator => senderType == 'narrator';

  bool get isTick => senderType == 'tick';

  bool get isImage =>
      senderType == 'image' ||
      senderType == 'nar_pic' ||
      imageUrl.trim().isNotEmpty;
}

typedef ChatMessageLongPressStart =
    void Function(
      BuildContext context,
      ChatMessageVm message,
      LongPressStartDetails details,
    );

typedef ChatMessageTap = void Function(ChatMessageVm message);
