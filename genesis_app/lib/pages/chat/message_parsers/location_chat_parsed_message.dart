import '../../../components/chat/shared/chat_ui.dart';
import '../../../network/chatroom/world_chatroom_service.dart';

class LocationChatParsedMessage {
  const LocationChatParsedMessage({
    required this.source,
    required this.localId,
    required this.clientMsgId,
    required this.globalMessageId,
    required this.messageId,
    required this.locationMessageId,
    required this.roundId,
    required this.tickNo,
    required this.subTickNo,
    required this.senderId,
    required this.senderName,
    required this.avatarUrl,
    required this.imageUrl,
    required this.timelinePayload,
    required this.isPlayerControlledRole,
    required this.text,
    required this.currentTime,
    required this.isMe,
    required this.status,
    required this.senderType,
    required this.createdAt,
  });

  final WorldChatroomMessage source;
  final String localId;
  final String clientMsgId;
  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String roundId;
  final int tickNo;
  final int subTickNo;
  final String senderId;
  final String senderName;
  final String avatarUrl;
  final String imageUrl;
  final ChatTimelinePayloadVm? timelinePayload;
  final bool isPlayerControlledRole;
  final String text;
  final String currentTime;
  final bool isMe;
  final String status;
  final String senderType;
  final DateTime createdAt;
}
