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

/// Return-to-room presentation event, separate from persisted chat messages.
class ChatroomPhoneCharactersMoved extends ChatroomEvent {
  ChatroomPhoneCharactersMoved.fromV2Message(ChatroomV2Message message)
    : worldId = message.worldId.trim(),
      triggerUid = message.triggerUid,
      ts = message.ts ?? 0,
      movements = _phoneMovements(message.payload['content']) {
    if (message.streamType.isNotEmpty ||
        worldId.isEmpty ||
        ts <= 0 ||
        message.errNo != 0) {
      throw const FormatException('Invalid phone movement envelope');
    }
  }

  final String worldId, triggerUid;
  final int ts;
  final List<ChatroomV2CharacterMovement> movements;

  // No event_id is supplied. Preserve batch order because a character may
  // appear more than once, in which case the last movement wins.
  String get deduplicationKey => jsonEncode([
    worldId,
    ts,
    triggerUid,
    movements.map((m) => m.toJson()).toList(growable: false),
  ]);
}

List<ChatroomV2CharacterMovement> _phoneMovements(Object? value) {
  if (value is! List || value.length > chatroomMaxCollectionItems) {
    throw const FormatException('Invalid phone movement content');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid phone movement item');
      }
      String id(String key) {
        final value = item[key];
        if (value is! String ||
            value.trim().isEmpty ||
            value.length > chatroomMaxStringCodeUnits ||
            value.contains('\u0000')) {
          throw const FormatException('Invalid phone movement ID');
        }
        return value.trim();
      }

      return ChatroomV2CharacterMovement(
        characterId: id('char_id'),
        oldLocationId: id('old_loc_id'),
        toLocationId: id('to_loc_id'),
      );
    }),
  );
}
