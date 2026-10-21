part of 'chatroom_models.dart';

/// Phone business fields live entirely in payload; no location is required.
class ChatroomPhoneEvent extends ChatroomEvent {
  ChatroomPhoneEvent.fromV2Message(ChatroomV2Message message)
    : type = message.type,
      worldId = message.worldId,
      eventId = phoneText(message.payload['event_id']),
      requestId = message.payload['client_request_id'] as String?,
      sessionId = message.payload['dm_session_id'] == null
          ? null
          : phoneId(message.payload['dm_session_id']),
      messages = message.type == 'phone.messages.delivered'
          ? phoneList(message.payload['messages'], PhoneMessage.fromJson)
          : const [],
      notification = message.type == 'phone.post.notification.created'
          ? PhoneNotification.fromJson({
              ...message.payload,
              'world_id': message.worldId,
            })
          : null,
      jobStatus = message.payload['job_status'] as String?,
      sourceMessageId = message.type == 'phone.reply.updated'
          ? phoneId(message.payload['message_id'])
          : null,
      failure =
          message.type == 'phone.reply.updated' &&
              message.payload['failure'] != null
          ? phoneText(phoneMap(message.payload['failure'])['message'])
          : null {
    if (message.streamType.isNotEmpty ||
        worldId.isEmpty ||
        eventId.isEmpty ||
        message.errNo != 0) {
      throw const FormatException('Invalid phone event envelope');
    }
    if (type == 'phone.reply.updated' &&
        (!{'generating', 'failed'}.contains(jobStatus) ||
            sessionId == null ||
            jobStatus == 'failed' && (failure ?? '').isEmpty ||
            (requestId ?? '').isEmpty)) {
      throw const FormatException('Invalid phone reply event');
    }
    if (type == 'phone.messages.delivered' &&
        (sessionId == null ||
            messages.any(
              (m) => m.worldId != worldId || m.sessionId != sessionId,
            ))) {
      throw const FormatException('Invalid phone delivery scope');
    }
  }
  final String type, worldId, eventId;
  final String? requestId, failure, jobStatus;
  final int? sessionId, sourceMessageId;
  final List<PhoneMessage> messages;
  final PhoneNotification? notification;
}

/// A canonical location message, stored and ordered like other formal messages.
class ChatroomPhoneCharactersMoved extends ChatroomMessageEvent {
  ChatroomPhoneCharactersMoved._(
    ChatroomV2Message message,
    this.timelinePayload,
  ) : createdAt = asDateTime(message.createdAt) ?? asDateTime(message.ts),
      currentTime = message.currentTime,
      super(
        sessionId: message.sessionId,
        worldId: message.worldId,
        locationId: message.locationId,
        userId: message.userId,
        code: message.errNo,
        codeMsg: message.errMsg,
        ts: asDateTime(message.ts),
        conversationType: message.conversationType,
        triggerUid: message.triggerUid,
        globalMessageId: message.globalMessageId!,
        messageId: message.messageId!,
        locationMessageId: message.locationMessageId!,
        conversationRoundId: '${message.conversationRoundId}',
        roundOrder: asInt(message.payload['round_order']),
        senderType: chatroomPhoneCharactersMovedSenderType,
        senderId: message.senderId,
        senderName: message.senderName,
        content: encodeChatroomTimelinePayload(timelinePayload),
        broadcast: false,
        businessType: message.type,
        streamType: message.streamType,
        minAppVersion: message.minAppVersion,
        rawPayload: message.payload,
      );

  factory ChatroomPhoneCharactersMoved.fromV2Message(
    ChatroomV2Message message,
  ) {
    if (message.streamType.isNotEmpty ||
        message.errNo != 0 ||
        message.worldId.trim().isEmpty ||
        message.locationId.trim().isEmpty ||
        (message.globalMessageId ?? 0) <= 0 ||
        (message.messageId ?? 0) <= 0 ||
        (message.locationMessageId ?? 0) <= 0 ||
        (message.conversationRoundId ?? 0) <= 0 ||
        message.conversationType != chatroomPhoneCharactersMovedSenderType ||
        message.senderType != chatroomPhoneCharactersMovedSenderType) {
      throw const FormatException('Invalid canonical phone movement message');
    }
    return ChatroomPhoneCharactersMoved._(
      message,
      ChatroomPhoneCharactersMovedPayload.fromJson(message.payload),
    );
  }

  final ChatroomPhoneCharactersMovedPayload timelinePayload;
  final DateTime? createdAt;
  final String currentTime;
}
