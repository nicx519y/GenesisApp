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
    this.mySessionId = '',
    this.clientMsgId = '',
    this.worldId = '',
    this.sessionId = '',
    this.locationId = '',
    this.userId = '',
    this.senderName = '',
    this.errCode = '',
    this.errMsg = '',
    this.msgId,
    this.conversationRoundId,
  });

  final String type;
  final int? ts;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> worldPayload;
  final bool? broadcast;
  final String mySessionId;
  final String clientMsgId;
  final String worldId;
  final String sessionId;
  final String locationId;
  final String userId;
  final String senderName;
  final String errCode;
  final String errMsg;
  final int? msgId;
  final int? conversationRoundId;

  factory ChatroomEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatroomEnvelope(
      type: asString(json['type']),
      ts: json['ts'] == null ? null : asInt(json['ts']),
      payload: _optionalJsonMap(json['payload']),
      worldPayload: _optionalJsonMap(json['world_payload']),
      broadcast: json['broadcast'] == null ? null : asBool(json['broadcast']),
      mySessionId: asString(json['my_session_id']),
      clientMsgId: asString(json['client_msg_id']),
      worldId: asString(json['world_id']),
      sessionId: asString(json['session_id']),
      locationId: asString(json['location_id']),
      userId: asString(json['user_id']),
      senderName: asString(json['sender_name']),
      errCode: asString(json['err_code']),
      errMsg: asString(json['err_msg']),
      msgId: json['msg_id'] == null ? null : asInt(json['msg_id']),
      conversationRoundId: json['conversation_round_id'] == null
          ? null
          : asInt(json['conversation_round_id']),
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
      if (clientMsgId.isNotEmpty) 'client_msg_id': clientMsgId,
      if (worldId.isNotEmpty) 'world_id': worldId,
      if (locationId.isNotEmpty) 'location_id': locationId,
      if (payload.isNotEmpty) 'payload': payload,
    };
    return jsonEncode(json);
  }

  Map<String, dynamic> get mergedPayload {
    final merged = <String, dynamic>{...payload};
    void putString(String key, String value) {
      if (value.isNotEmpty && !merged.containsKey(key)) merged[key] = value;
    }

    putString('client_msg_id', clientMsgId);
    putString('world_id', worldId);
    putString('session_id', sessionId);
    putString('location_id', locationId);
    putString('user_id', userId);
    putString('sender_name', senderName);
    putString('err_code', errCode);
    putString('err_msg', errMsg);
    if (msgId != null && !merged.containsKey('msg_id')) {
      merged['msg_id'] = msgId;
    }
    if (conversationRoundId != null &&
        !merged.containsKey('conversation_round_id')) {
      merged['conversation_round_id'] = conversationRoundId;
    }
    if (merged.containsKey('msg_id') && !merged.containsKey('message_id')) {
      merged['message_id'] = merged['msg_id'];
    }
    if (merged.containsKey('client_msg_id') &&
        !merged.containsKey('client_uuid')) {
      merged['client_uuid'] = merged['client_msg_id'];
    }
    if (merged.containsKey('err_code') && !merged.containsKey('code')) {
      merged['code'] = merged['err_code'];
    }
    if (merged.containsKey('err_msg') && !merged.containsKey('code_msg')) {
      merged['code_msg'] = merged['err_msg'];
    }
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

class ChatroomHeartbeat extends ChatroomPayloadEvent {
  const ChatroomHeartbeat({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    required this.mySessionId,
  });

  final String mySessionId;

  factory ChatroomHeartbeat.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomHeartbeat(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: asInt(payload['code']),
      codeMsg: asString(payload['code_msg']),
      ts: asDateTime(payload['ts']),
      mySessionId: envelope.mySessionId,
    );
  }
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
    final payload = envelope.mergedPayload;
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

  factory ChatroomAiStreamStart.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
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

  factory ChatroomAiStreamChunk.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomAiStreamChunk(
      sessionId: asString(payload['session_id']),
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

  factory ChatroomAiStreamEnd.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
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
    final payload = envelope.worldPayload.isNotEmpty
        ? envelope.worldPayload
        : envelope.mergedPayload;
    return ChatroomWorldNotification(
      worldId: asString(payload['world_id'], fallback: envelope.worldId),
      eventType: asString(payload['event_type'], fallback: envelope.type),
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
    this.onLeaved,
    this.onKicked,
    this.onDisconnected,
    this.onHeartbeat,
    this.onAck,
    this.onError,
    this.onFailure,
    this.onInputBlocked,
    this.onInputReady,
    this.onWorldNotification,
    this.onQueuePosition,
    this.onUserMessage,
    this.onCharacterMessage,
    this.onNarratorMessage,
    this.onAiStreamStart,
    this.onAiStreamChunk,
    this.onAiStreamEnd,
  });

  final void Function(ChatroomEvent event)? onEvent;
  final void Function(ChatroomJoined event)? onJoined;
  final void Function(ChatroomLeaved event)? onLeaved;
  final void Function(ChatroomKicked event)? onKicked;
  final void Function(ChatroomDisconnected event)? onDisconnected;
  final void Function(ChatroomHeartbeat event)? onHeartbeat;
  final void Function(ChatroomAck event)? onAck;
  final void Function(ChatroomErrorEvent event)? onError;
  final void Function(ChatroomFailureEvent event)? onFailure;
  final void Function(ChatroomInputBlocked event)? onInputBlocked;
  final void Function(ChatroomInputReady event)? onInputReady;
  final void Function(ChatroomWorldNotification event)? onWorldNotification;
  final void Function(ChatroomQueuePosition event)? onQueuePosition;
  final void Function(ChatroomUserMessage event)? onUserMessage;
  final void Function(ChatroomCharacterMessage event)? onCharacterMessage;
  final void Function(ChatroomNarratorMessage event)? onNarratorMessage;
  final void Function(ChatroomAiStreamStart event)? onAiStreamStart;
  final void Function(ChatroomAiStreamChunk event)? onAiStreamChunk;
  final void Function(ChatroomAiStreamEnd event)? onAiStreamEnd;

  void handle(ChatroomEvent event) {
    onEvent?.call(event);
    switch (event) {
      case ChatroomJoined e:
        onJoined?.call(e);
      case ChatroomLeaved e:
        onLeaved?.call(e);
      case ChatroomKicked e:
        onKicked?.call(e);
      case ChatroomDisconnected e:
        onDisconnected?.call(e);
      case ChatroomHeartbeat e:
        onHeartbeat?.call(e);
      case ChatroomAck e:
        onAck?.call(e);
      case ChatroomErrorEvent e:
        onError?.call(e);
      case ChatroomFailureEvent e:
        onFailure?.call(e);
      case ChatroomInputBlocked e:
        onInputBlocked?.call(e);
      case ChatroomInputReady e:
        onInputReady?.call(e);
      case ChatroomWorldNotification e:
        onWorldNotification?.call(e);
      case ChatroomQueuePosition e:
        onQueuePosition?.call(e);
      case ChatroomUserMessage e:
        onUserMessage?.call(e);
      case ChatroomCharacterMessage e:
        onCharacterMessage?.call(e);
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
    case 'joined':
      return ChatroomJoined.fromPayload(envelope.mergedPayload);
    case 'leaved':
      return ChatroomLeaved.fromPayload(envelope.mergedPayload);
    case 'kicked':
      return ChatroomKicked.fromPayload(envelope.mergedPayload);
    case 'disconnected':
      return const ChatroomDisconnected();
    case 'heartbeat':
      return ChatroomHeartbeat.fromEnvelope(envelope);
    case 'ack':
      return ChatroomAck.fromPayload(envelope.mergedPayload);
    case 'error':
    case 'ai_error':
      return ChatroomErrorEvent.fromPayload(
        envelope.mergedPayload,
        sourceType: envelope.type,
      );
    case 'input_blocked':
      return ChatroomInputBlocked.fromPayload(envelope.mergedPayload);
    case 'input_ready':
      return ChatroomInputReady.fromPayload(envelope.mergedPayload);
    case 'world_notification':
    case 'tick_start':
    case 'tick_done':
    case 'world_change':
    case 'user_location_change':
    case 'world_new_message':
    case 'nar_new_message':
      return ChatroomWorldNotification.fromEnvelope(envelope);
    case 'user_message':
      return ChatroomUserMessage.fromEnvelope(envelope);
    case 'character_message':
      return ChatroomCharacterMessage.fromEnvelope(envelope);
    case 'narrator_message':
      return ChatroomNarratorMessage.fromEnvelope(envelope);
    case 'ai_stream_start':
    case 'llm_stream_start':
      return ChatroomAiStreamStart.fromEnvelope(envelope);
    case 'ai_stream_chunk':
    case 'llm_chunk':
      return ChatroomAiStreamChunk.fromEnvelope(envelope);
    case 'ai_stream_end':
    case 'llm_stream_end':
      return ChatroomAiStreamEnd.fromEnvelope(envelope);
    case 'queue_position':
      return ChatroomQueuePosition.fromPayload(envelope.mergedPayload);
    default:
      throw ChatroomProtocolException('Unsupported type: ${envelope.type}');
  }
}

String chatroomEventType(ChatroomEvent event) {
  switch (event) {
    case ChatroomJoined():
      return 'joined';
    case ChatroomLeaved():
      return 'leaved';
    case ChatroomKicked():
      return 'kicked';
    case ChatroomDisconnected():
      return 'disconnected';
    case ChatroomHeartbeat():
      return 'heartbeat';
    case ChatroomAck():
      return 'ack';
    case ChatroomErrorEvent e:
      return e.sourceType;
    case ChatroomFailureEvent e:
      return e.sourceType;
    case ChatroomInputBlocked():
      return 'input_blocked';
    case ChatroomInputReady():
      return 'input_ready';
    case ChatroomWorldNotification():
      return 'world_notification';
    case ChatroomQueuePosition():
      return 'queue_position';
    case ChatroomUserMessage():
      return 'user_message';
    case ChatroomCharacterMessage():
      return 'character_message';
    case ChatroomNarratorMessage():
      return 'narrator_message';
    case ChatroomAiStreamStart():
      return 'ai_stream_start';
    case ChatroomAiStreamChunk():
      return 'ai_stream_chunk';
    case ChatroomAiStreamEnd():
      return 'ai_stream_end';
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
