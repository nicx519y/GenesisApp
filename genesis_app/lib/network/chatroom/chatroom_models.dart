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
  const ChatroomEnvelope({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;

  factory ChatroomEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatroomEnvelope(
      type: asString(json['type']),
      payload: asJsonMap(json['payload']),
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
    return jsonEncode(<String, Object?>{'type': type, 'payload': payload});
  }
}

sealed class ChatroomEvent {
  const ChatroomEvent();
}

class ChatroomJoined extends ChatroomEvent {
  const ChatroomJoined({
    required this.sessionId,
    required this.worldInstanceId,
    required this.locationId,
    required this.onlineUsers,
  });

  final String sessionId;
  final String worldInstanceId;
  final String locationId;
  final List<ChatroomOnlineUser> onlineUsers;

  factory ChatroomJoined.fromPayload(Map<String, dynamic> payload) {
    final users = payload['online_users'] is List
        ? asJsonList(payload['online_users'])
        : const <Map<String, dynamic>>[];
    return ChatroomJoined(
      sessionId: asString(payload['session_id']),
      worldInstanceId: asString(payload['world_instance_id']),
      locationId: asString(payload['location_id']),
      onlineUsers: users
          .map((user) => ChatroomOnlineUser.fromPayload(asJsonMap(user)))
          .toList(growable: false),
    );
  }
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

class ChatroomAck extends ChatroomEvent {
  const ChatroomAck({
    required this.sessionId,
    required this.messageId,
    required this.conversationRoundId,
    required this.clientMsgId,
    required this.queuePosition,
  });

  final String sessionId;
  final int messageId;
  final String conversationRoundId;
  final String clientMsgId;
  final int queuePosition;

  factory ChatroomAck.fromPayload(Map<String, dynamic> payload) {
    return ChatroomAck(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      clientMsgId: asString(payload['client_msg_id']),
      queuePosition: asInt(payload['queue_position']),
    );
  }
}

class ChatroomUserMessage extends ChatroomEvent {
  const ChatroomUserMessage({
    required this.sessionId,
    required this.messageId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final String sessionId;
  final int messageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;
  final String userId;
  final String content;
  final DateTime? createdAt;

  factory ChatroomUserMessage.fromPayload(Map<String, dynamic> payload) {
    return ChatroomUserMessage(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type']),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
      userId: asString(payload['user_id']),
      content: asString(payload['content']),
      createdAt: asDateTime(payload['created_at']),
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
    return ChatroomAiStreamStart(
      sessionId: asString(payload['session_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: asString(payload['sender_type']),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
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
      message: asString(payload['message']),
    );
  }

  @override
  String toString() => 'ChatroomErrorEvent($code): $message';
}

ChatroomEvent chatroomEventFromEnvelope(ChatroomEnvelope envelope) {
  switch (envelope.type) {
    case 'joined':
      return ChatroomJoined.fromPayload(envelope.payload);
    case 'ack':
      return ChatroomAck.fromPayload(envelope.payload);
    case 'user_message':
      return ChatroomUserMessage.fromPayload(envelope.payload);
    case 'ai_stream_start':
      return ChatroomAiStreamStart.fromPayload(envelope.payload);
    case 'ai_stream_chunk':
      return ChatroomAiStreamChunk.fromPayload(envelope.payload);
    case 'ai_stream_end':
      return ChatroomAiStreamEnd.fromPayload(envelope.payload);
    case 'ai_error':
    case 'error':
      return ChatroomErrorEvent.fromPayload(envelope.payload);
    case 'queue_position':
      return ChatroomQueuePosition.fromPayload(envelope.payload);
    default:
      throw ChatroomProtocolException('Unsupported type: ${envelope.type}');
  }
}
