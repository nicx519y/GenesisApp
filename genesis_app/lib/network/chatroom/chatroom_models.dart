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
    this.worldId = '',
    this.sessionId = '',
    this.locationId = '',
    this.userId = '',
    this.senderId = '',
    this.senderName = '',
    this.errCode = '',
    this.errMsg = '',
    this.msgId,
    this.conversationRoundId,
    this.clientMsgId = '',
    this.broadcast,
  });

  final String type;
  final int? ts;
  final Map<String, dynamic> payload;
  final String worldId;
  final String sessionId;
  final String locationId;
  final String userId;
  final String senderId;
  final String senderName;
  final String errCode;
  final String errMsg;
  final int? msgId;
  final int? conversationRoundId;
  final String clientMsgId;
  final bool? broadcast;

  factory ChatroomEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatroomEnvelope(
      type: asString(json['type']),
      ts: json['ts'] == null ? null : asInt(json['ts']),
      payload: _optionalJsonMap(json['payload']),
      worldId: asString(json['world_id']),
      sessionId: asString(json['session_id']),
      locationId: asString(json['location_id']),
      userId: asString(json['user_id']),
      senderId: asString(json['sender_id']),
      senderName: asString(json['sender_name']),
      errCode: asString(json['err_code']),
      errMsg: asString(json['err_msg']),
      msgId: json['msg_id'] == null ? null : asInt(json['msg_id']),
      conversationRoundId: json['conversation_round_id'] == null
          ? null
          : asInt(json['conversation_round_id']),
      clientMsgId: asString(json['client_msg_id']),
      broadcast: json.containsKey('broadcast')
          ? asBool(json['broadcast'])
          : null,
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
    final json = <String, Object?>{
      'type': type,
      'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
      if (worldId.isNotEmpty) 'world_id': worldId,
      if (locationId.isNotEmpty) 'location_id': locationId,
      if (payload.isNotEmpty) 'payload': payload,
    };
    return jsonEncode(json);
  }

  Map<String, dynamic> get mergedPayload {
    final merged = <String, dynamic>{...payload};

    if (worldId.isNotEmpty) merged['world_id'] = worldId;
    if (sessionId.isNotEmpty) merged['session_id'] = sessionId;
    if (locationId.isNotEmpty) merged['location_id'] = locationId;
    if (userId.isNotEmpty) merged['user_id'] = userId;
    if (senderId.isNotEmpty) merged['sender_id'] = senderId;
    if (senderName.isNotEmpty) merged['sender_name'] = senderName;
    if (errCode.isNotEmpty) merged['code'] = errCode;
    if (errMsg.isNotEmpty) merged['code_msg'] = errMsg;
    if (msgId != null) merged['message_id'] = msgId;
    if (conversationRoundId != null) {
      merged['conversation_round_id'] = conversationRoundId;
    }
    if (clientMsgId.isNotEmpty) merged['client_msg_id'] = clientMsgId;
    if (broadcast != null) merged['broadcast'] = broadcast;
    merged.putIfAbsent('code', () => 0);
    merged.putIfAbsent('code_msg', () => '');
    return merged;
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
}

class ChatroomDisconnected extends ChatroomEvent {
  const ChatroomDisconnected();
}

class ChatroomFailureEvent extends ChatroomEvent implements Exception {
  const ChatroomFailureEvent({
    required this.code,
    required this.message,
    this.sourceType = '',
    this.requestType = '',
    this.cause,
  });

  final String code;
  final String message;
  final String sourceType;
  final String requestType;
  final Object? cause;

  factory ChatroomFailureEvent.fromError(
    ChatroomErrorEvent error, {
    String requestType = '',
  }) {
    return ChatroomFailureEvent(
      code: error.code,
      message: error.message,
      sourceType: error.sourceType,
      requestType: requestType,
      cause: error.cause ?? error,
    );
  }

  factory ChatroomFailureEvent.fromPayloadEvent(
    ChatroomPayloadEvent event, {
    String sourceType = '',
    String requestType = '',
    Object? cause,
  }) {
    return ChatroomFailureEvent(
      code: event.code.toString(),
      message: event.codeMsg.isEmpty
          ? 'Chatroom request failed'
          : event.codeMsg,
      sourceType: sourceType.isEmpty ? chatroomEventType(event) : sourceType,
      requestType: requestType,
      cause: cause ?? event,
    );
  }

  ChatroomFailureEvent withRequestType(String value) {
    return ChatroomFailureEvent(
      code: code,
      message: message,
      sourceType: sourceType,
      requestType: value,
      cause: cause,
    );
  }

  @override
  String toString() {
    final prefix = requestType.isEmpty
        ? sourceType
        : '$requestType/$sourceType';
    return 'ChatroomFailureEvent($prefix $code): $message';
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
    required this.clientMsgId,
  });

  final int messageId;
  final String conversationRoundId;
  final String clientMsgId;

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
      clientMsgId: asString(payload['client_msg_id']),
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
    required this.clientMsgId,
    required this.createdAt,
  });

  final String clientMsgId;
  final DateTime? createdAt;

  factory ChatroomUserMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
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
      broadcast: asBool(payload['broadcast']),
      clientMsgId: asString(payload['client_msg_id']),
      createdAt: asDateTime(payload['created_at']),
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
    required this.createdAt,
  });

  final DateTime? createdAt;

  factory ChatroomNarratorMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
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
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name'], fallback: 'Narrator'),
      content: asString(payload['content']),
      broadcast: asBool(payload['broadcast']),
      createdAt: asDateTime(payload['created_at']),
    );
  }
}

class ChatroomAiStreamStart extends ChatroomEvent {
  const ChatroomAiStreamStart({
    required this.sessionId,
    required this.locationId,
    required this.messageId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
  });

  final String sessionId;
  final String locationId;
  final int messageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;

  factory ChatroomAiStreamStart.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    final roundId = asString(payload['conversation_round_id']);
    return ChatroomAiStreamStart(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
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
    required this.locationId,
    required this.messageId,
    required this.conversationRoundId,
    required this.senderId,
    required this.chunk,
    required this.isDelta,
  });

  final String sessionId;
  final String locationId;
  final int messageId;
  final String conversationRoundId;
  final String senderId;
  final String chunk;
  final bool isDelta;

  factory ChatroomAiStreamChunk.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomAiStreamChunk(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      chunk: asString(payload['chunk'], fallback: asString(payload['content'])),
      isDelta: asBool(payload['is_delta'], fallback: true),
    );
  }
}

class ChatroomAiStreamEnd extends ChatroomEvent {
  const ChatroomAiStreamEnd({
    required this.sessionId,
    required this.locationId,
    required this.messageId,
    required this.conversationRoundId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final String sessionId;
  final String locationId;
  final int messageId;
  final String conversationRoundId;
  final String senderId;
  final String content;
  final DateTime? createdAt;

  factory ChatroomAiStreamEnd.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomAiStreamEnd(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
      messageId: asInt(payload['message_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      content: asString(payload['content']),
      createdAt: asDateTime(payload['created_at']),
    );
  }
}

class ChatroomWorldNotification extends ChatroomEvent {
  const ChatroomWorldNotification({
    required this.worldId,
    required this.locationId,
    required this.eventType,
    required this.title,
    required this.summary,
    required this.detailUrl,
    required this.ts,
    required this.broadcast,
  });

  final String worldId;
  final String locationId;
  final String eventType;
  final String title;
  final String summary;
  final String detailUrl;
  final DateTime? ts;
  final bool broadcast;

  factory ChatroomWorldNotification.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomWorldNotification(
      worldId: asString(payload['world_id'], fallback: envelope.worldId),
      locationId: asString(payload['location_id']),
      eventType: asString(payload['event_type'], fallback: envelope.type),
      title: asString(payload['title']),
      summary: asString(payload['summary']),
      detailUrl: asString(payload['detail_url']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      broadcast: false,
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
    this.sourceType = 'error',
    this.cause,
  });

  final String sessionId;
  final String conversationRoundId;
  final String senderId;
  final String sourceType;
  final String code;
  final String message;
  final Object? cause;

  factory ChatroomErrorEvent.fromPayload(
    Map<String, dynamic> payload, {
    String sourceType = 'error',
  }) {
    return ChatroomErrorEvent(
      sessionId: asString(payload['session_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      sourceType: sourceType,
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

class ChatroomMessageHandlers {
  const ChatroomMessageHandlers({
    this.onEvent,
    this.onJoined,
    this.onDisconnected,
    this.onAck,
    this.onError,
    this.onFailure,
    this.onWorldNotification,
    this.onUserMessage,
    this.onNarratorMessage,
    this.onAiStreamStart,
    this.onAiStreamChunk,
    this.onAiStreamEnd,
  });

  final void Function(ChatroomEvent event)? onEvent;
  final void Function(ChatroomJoined event)? onJoined;
  final void Function(ChatroomDisconnected event)? onDisconnected;
  final void Function(ChatroomAck event)? onAck;
  final void Function(ChatroomErrorEvent event)? onError;
  final void Function(ChatroomFailureEvent event)? onFailure;
  final void Function(ChatroomWorldNotification event)? onWorldNotification;
  final void Function(ChatroomUserMessage event)? onUserMessage;
  final void Function(ChatroomNarratorMessage event)? onNarratorMessage;
  final void Function(ChatroomAiStreamStart event)? onAiStreamStart;
  final void Function(ChatroomAiStreamChunk event)? onAiStreamChunk;
  final void Function(ChatroomAiStreamEnd event)? onAiStreamEnd;

  void handle(ChatroomEvent event) {
    onEvent?.call(event);
    switch (event) {
      case ChatroomJoined e:
        onJoined?.call(e);
      case ChatroomDisconnected e:
        onDisconnected?.call(e);
      case ChatroomAck e:
        onAck?.call(e);
      case ChatroomErrorEvent e:
        onError?.call(e);
      case ChatroomFailureEvent e:
        onFailure?.call(e);
      case ChatroomWorldNotification e:
        onWorldNotification?.call(e);
      case ChatroomUserMessage e:
        onUserMessage?.call(e);
      case ChatroomNarratorMessage e:
        onNarratorMessage?.call(e);
      case ChatroomAiStreamStart e:
        onAiStreamStart?.call(e);
      case ChatroomAiStreamChunk e:
        onAiStreamChunk?.call(e);
      case ChatroomAiStreamEnd e:
        onAiStreamEnd?.call(e);
    }
  }
}

ChatroomEvent chatroomEventFromEnvelope(ChatroomEnvelope envelope) {
  switch (envelope.type) {
    case 'ack':
      return ChatroomAck.fromPayload(envelope.mergedPayload);
    case 'error':
      return ChatroomErrorEvent.fromPayload(
        envelope.mergedPayload,
        sourceType: envelope.type,
      );
    case 'tick_start':
    case 'tick_end':
    case 'tick_done':
    case 'world_change':
    case 'user_location_change':
    case 'world_new_message':
      return ChatroomWorldNotification.fromEnvelope(envelope);
    case 'nar_new_message':
      return ChatroomNarratorMessage.fromEnvelope(envelope);
    case 'user_message':
      return ChatroomUserMessage.fromEnvelope(envelope);
    case 'llm_stream_start':
      return ChatroomAiStreamStart.fromEnvelope(envelope);
    case 'llm_chunk':
      return ChatroomAiStreamChunk.fromEnvelope(envelope);
    case 'llm_stream_end':
      return ChatroomAiStreamEnd.fromEnvelope(envelope);
    default:
      throw ChatroomProtocolException('Unsupported type: ${envelope.type}');
  }
}

String chatroomEventType(ChatroomEvent event) {
  switch (event) {
    case ChatroomJoined():
      return 'join';
    case ChatroomDisconnected():
      return 'unsupported';
    case ChatroomAck():
      return 'ack';
    case ChatroomErrorEvent e:
      return e.sourceType;
    case ChatroomFailureEvent e:
      return e.sourceType;
    case ChatroomWorldNotification():
      return 'world_change';
    case ChatroomUserMessage():
      return 'user_message';
    case ChatroomNarratorMessage():
      return 'nar_new_message';
    case ChatroomAiStreamStart():
      return 'llm_stream_start';
    case ChatroomAiStreamChunk():
      return 'llm_chunk';
    case ChatroomAiStreamEnd():
      return 'llm_stream_end';
  }
}

Map<String, dynamic> _optionalJsonMap(Object? value) {
  if (value == null) return const <String, dynamic>{};
  return asJsonMap(value);
}

String _worldId(Map<String, dynamic> payload) {
  return asString(payload['world_id']);
}
