import 'dart:convert';

import '../json_utils.dart';

class ChatroomProtocolException implements Exception {
  const ChatroomProtocolException(this.message, {this.error});

  final String message;
  final Object? error;

  @override
  String toString() => 'ChatroomProtocolException: $message';
}

class ChatroomEnvelope {
  const ChatroomEnvelope({
    required this.type,
    this.ts,
    this.payload = const <String, dynamic>{},
    this.worldPayload = const <String, dynamic>{},
    this.broadcast,
  });

  final String type;
  final int? ts;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> worldPayload;
  final bool? broadcast;

  factory ChatroomEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatroomEnvelope(
      type: asString(json['type']),
      ts: json['ts'] == null ? null : asInt(json['ts']),
      payload: _optionalJsonMap(json['payload']),
      worldPayload: _optionalJsonMap(json['world_payload']),
      broadcast: json['broadcast'] == null ? null : asBool(json['broadcast']),
    );
  }

  factory ChatroomEnvelope.decode(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is! Map) {
        throw const ChatroomProtocolException('Envelope is not a JSON object');
      }
      return ChatroomEnvelope.fromJson(asJsonMap(decoded));
    } on ChatroomProtocolException {
      rethrow;
    } catch (e) {
      throw ChatroomProtocolException('Invalid JSON envelope', error: e);
    }
  }

  String encode() {
    return jsonEncode(<String, Object?>{
      'type': type,
      'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
  }
}

sealed class ChatroomEvent {
  const ChatroomEvent();
}

sealed class ChatroomPayloadEvent extends ChatroomEvent {
  const ChatroomPayloadEvent({
    required this.sessionId,
    required this.worldId,
    required this.locationId,
    required this.userId,
    required this.code,
    required this.codeMsg,
    required this.ts,
  });

  final String sessionId;
  final String worldId;
  final String locationId;
  final String userId;
  final int code;
  final String codeMsg;
  final DateTime? ts;

  String get worldInstanceId => worldId;

  bool get ok => code == 0;
}

class ChatroomJoined extends ChatroomPayloadEvent {
  const ChatroomJoined({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required this.onlineUsers,
  });

  final List<ChatroomOnlineUser> onlineUsers;

  factory ChatroomJoined.fromPayload(Map<String, dynamic> payload) {
    final users = payload['online_users'] is List
        ? asJsonList(payload['online_users'])
        : const <Object?>[];
    return ChatroomJoined(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
      onlineUsers: users
          .map((user) => ChatroomOnlineUser.fromPayload(asJsonMap(user)))
          .toList(growable: false),
    );
  }
}

class ChatroomLeaved extends ChatroomPayloadEvent {
  const ChatroomLeaved({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
  });

  factory ChatroomLeaved.fromPayload(Map<String, dynamic> payload) {
    return ChatroomLeaved(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
    );
  }
}

class ChatroomKicked extends ChatroomPayloadEvent {
  const ChatroomKicked({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
  });

  factory ChatroomKicked.fromPayload(Map<String, dynamic> payload) {
    return ChatroomKicked(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
    );
  }
}

class ChatroomDisconnected extends ChatroomEvent {
  const ChatroomDisconnected();
}

class ChatroomOnlineUser {
  const ChatroomOnlineUser({
    required this.userId,
    required this.senderId,
    required this.senderName,
  });

  final String userId;
  final String senderId;
  final String senderName;

  factory ChatroomOnlineUser.fromPayload(Map<String, dynamic> payload) {
    return ChatroomOnlineUser(
      userId: asString(payload['user_id']),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
    );
  }
}

class ChatroomAck extends ChatroomPayloadEvent {
  const ChatroomAck({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required this.messageId,
    required this.conversationRoundId,
    required this.clientUuid,
    required this.queuePosition,
  });

  final int messageId;
  final String conversationRoundId;
  final String clientUuid;
  final int queuePosition;

  String get clientMsgId => clientUuid;

  factory ChatroomAck.fromPayload(Map<String, dynamic> payload) {
    return ChatroomAck(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      clientUuid: asString(
        payload['client_uuid'],
        fallback: asString(payload['client_msg_id']),
      ),
      queuePosition: asInt(payload['queue_position']),
    );
  }
}

sealed class ChatroomMessageEvent extends ChatroomPayloadEvent {
  const ChatroomMessageEvent({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required this.messageId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.broadcast,
  });

  final int messageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;
  final String content;
  final bool broadcast;
}

class ChatroomUserMessage extends ChatroomMessageEvent {
  const ChatroomUserMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required super.messageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.broadcast,
    required this.createdAt,
  });

  final DateTime? createdAt;

  factory ChatroomUserMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.payload;
    return ChatroomUserMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type']),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
      content: asString(payload['content']),
      broadcast: envelope.broadcast ?? asBool(payload['broadcast']),
      createdAt: asDateTime(payload['created_at']),
    );
  }
}

class ChatroomCharacterMessage extends ChatroomMessageEvent {
  const ChatroomCharacterMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required super.messageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.broadcast,
  });

  factory ChatroomCharacterMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.payload;
    return ChatroomCharacterMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type'], fallback: 'character'),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
      content: asString(payload['content']),
      broadcast: envelope.broadcast ?? asBool(payload['broadcast']),
    );
  }
}

class ChatroomNarratorMessage extends ChatroomMessageEvent {
  const ChatroomNarratorMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required super.messageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    required super.broadcast,
  });

  factory ChatroomNarratorMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.payload;
    return ChatroomNarratorMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type'], fallback: 'narrator'),
      senderId: asString(payload['sender_id'], fallback: 'narrator'),
      senderName: asString(payload['sender_name'], fallback: 'Narrator'),
      content: asString(payload['content']),
      broadcast: envelope.broadcast ?? asBool(payload['broadcast']),
    );
  }
}

class ChatroomAiStreamStart extends ChatroomEvent {
  const ChatroomAiStreamStart({
    required this.sessionId,
    required this.messageId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
  });

  final String sessionId;
  final int messageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;

  factory ChatroomAiStreamStart.fromPayload(Map<String, dynamic> payload) {
    final roundId = asString(payload['conversation_round_id']);
    return ChatroomAiStreamStart(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: roundId,
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type'], fallback: 'character'),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name'], fallback: 'AI'),
    );
  }
}

class ChatroomAiStreamChunk extends ChatroomEvent {
  const ChatroomAiStreamChunk({
    required this.sessionId,
    required this.messageId,
    required this.conversationRoundId,
    required this.senderId,
    required this.chunk,
    required this.isDelta,
  });

  final String sessionId;
  final int messageId;
  final String conversationRoundId;
  final String senderId;
  final String chunk;
  final bool isDelta;

  factory ChatroomAiStreamChunk.fromPayload(Map<String, dynamic> payload) {
    return ChatroomAiStreamChunk(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      chunk: asString(payload['chunk']),
      isDelta: asBool(payload['is_delta'], fallback: true),
    );
  }
}

class ChatroomAiStreamEnd extends ChatroomEvent {
  const ChatroomAiStreamEnd({
    required this.sessionId,
    required this.messageId,
    required this.conversationRoundId,
    required this.senderId,
    required this.createdAt,
  });

  final String sessionId;
  final int messageId;
  final String conversationRoundId;
  final String senderId;
  final DateTime? createdAt;

  factory ChatroomAiStreamEnd.fromPayload(Map<String, dynamic> payload) {
    return ChatroomAiStreamEnd(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      createdAt: asDateTime(payload['created_at']),
    );
  }
}

class ChatroomInputBlocked extends ChatroomPayloadEvent {
  const ChatroomInputBlocked({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
  });

  factory ChatroomInputBlocked.fromPayload(Map<String, dynamic> payload) {
    return ChatroomInputBlocked(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
    );
  }
}

class ChatroomInputReady extends ChatroomPayloadEvent {
  const ChatroomInputReady({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
  });

  factory ChatroomInputReady.fromPayload(Map<String, dynamic> payload) {
    return ChatroomInputReady(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
    );
  }
}

class ChatroomWorldNotification extends ChatroomEvent {
  const ChatroomWorldNotification({
    required this.worldId,
    required this.eventType,
    required this.title,
    required this.summary,
    required this.detailUrl,
    required this.ts,
    required this.broadcast,
  });

  final String worldId;
  final String eventType;
  final String title;
  final String summary;
  final String detailUrl;
  final DateTime? ts;
  final bool broadcast;

  factory ChatroomWorldNotification.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.worldPayload;
    return ChatroomWorldNotification(
      worldId: asString(payload['world_id']),
      eventType: asString(payload['event_type']),
      title: asString(payload['title']),
      summary: asString(payload['summary']),
      detailUrl: asString(payload['detail_url']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      broadcast: envelope.broadcast ?? false,
    );
  }
}

class ChatroomQueuePosition extends ChatroomEvent {
  const ChatroomQueuePosition({
    required this.sessionId,
    required this.conversationRoundId,
    required this.position,
    required this.estimatedWaitSeconds,
  });

  final String sessionId;
  final String conversationRoundId;
  final int position;
  final int estimatedWaitSeconds;

  factory ChatroomQueuePosition.fromPayload(Map<String, dynamic> payload) {
    return ChatroomQueuePosition(
      sessionId: asString(payload['session_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      position: asInt(payload['position']),
      estimatedWaitSeconds: asInt(payload['estimated_wait_seconds']),
    );
  }
}

class ChatroomErrorEvent extends ChatroomEvent implements Exception {
  const ChatroomErrorEvent({
    required this.code,
    required this.message,
    this.sessionId = '',
    this.conversationRoundId = '',
    this.senderId = '',
    this.cause,
  });

  final String sessionId;
  final String conversationRoundId;
  final String senderId;
  final String code;
  final String message;
  final Object? cause;

  factory ChatroomErrorEvent.fromPayload(Map<String, dynamic> payload) {
    return ChatroomErrorEvent(
      sessionId: asString(payload['session_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      code: asString(
        payload['code'],
        fallback: asString(payload['error_code'], fallback: 'error'),
      ),
      message: asString(
        payload['code_msg'],
        fallback: asString(payload['message']),
      ),
    );
  }

  @override
  String toString() => 'ChatroomErrorEvent($code): $message';
}

ChatroomEvent chatroomEventFromEnvelope(ChatroomEnvelope envelope) {
  switch (envelope.type) {
    case 'joined':
      return ChatroomJoined.fromPayload(envelope.payload);
    case 'leaved':
      return ChatroomLeaved.fromPayload(envelope.payload);
    case 'kicked':
      return ChatroomKicked.fromPayload(envelope.payload);
    case 'disconnected':
      return const ChatroomDisconnected();
    case 'ack':
      return ChatroomAck.fromPayload(envelope.payload);
    case 'error':
    case 'ai_error':
      return ChatroomErrorEvent.fromPayload(envelope.payload);
    case 'input_blocked':
      return ChatroomInputBlocked.fromPayload(envelope.payload);
    case 'input_ready':
      return ChatroomInputReady.fromPayload(envelope.payload);
    case 'world_notification':
      return ChatroomWorldNotification.fromEnvelope(envelope);
    case 'user_message':
      return ChatroomUserMessage.fromEnvelope(envelope);
    case 'character_message':
      return ChatroomCharacterMessage.fromEnvelope(envelope);
    case 'narrator_message':
      return ChatroomNarratorMessage.fromEnvelope(envelope);
    case 'ai_stream_start':
      return ChatroomAiStreamStart.fromPayload(envelope.payload);
    case 'ai_stream_chunk':
      return ChatroomAiStreamChunk.fromPayload(envelope.payload);
    case 'ai_stream_end':
      return ChatroomAiStreamEnd.fromPayload(envelope.payload);
    case 'queue_position':
      return ChatroomQueuePosition.fromPayload(envelope.payload);
    default:
      throw ChatroomProtocolException('Unsupported type: ${envelope.type}');
  }
}

Map<String, dynamic> _optionalJsonMap(Object? value) {
  if (value == null) return const <String, dynamic>{};
  return asJsonMap(value);
}

String _worldId(Map<String, dynamic> payload) {
  return asString(
    payload['world_id'],
    fallback: asString(payload['world_instance_id']),
  );
}
