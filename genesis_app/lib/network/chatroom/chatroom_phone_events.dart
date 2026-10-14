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
      failure = message.type == 'phone.reply.updated'
          ? phoneText(phoneMap(message.payload['failure'])['message'])
          : null {
    if (message.streamType.isNotEmpty ||
        worldId.isEmpty ||
        eventId.isEmpty ||
        message.errNo != 0) {
      throw const FormatException('Invalid phone event envelope');
    }
    if (type == 'phone.reply.updated') phoneId(message.payload['message_id']);
    if (type == 'phone.reply.updated' &&
        (message.payload['job_status'] != 'failed' ||
            sessionId == null ||
            failure!.isEmpty ||
            (requestId ?? '').isEmpty)) {
      throw const FormatException('Invalid phone failure event');
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
  final String? requestId, failure;
  final int? sessionId;
  final List<PhoneMessage> messages;
  final PhoneNotification? notification;
}
