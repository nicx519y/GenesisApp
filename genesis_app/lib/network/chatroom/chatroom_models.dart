import 'dart:convert';

import '../json_utils.dart';
import 'chatroom_message_type.dart';
import 'chatroom_timeline_payload.dart';

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
    this.schemaVersion,
    this.eventId = '',
    this.ts,
    this.payload = const <String, dynamic>{},
    this.worldId = '',
    this.sessionId = '',
    this.locationId = '',
    this.userId = '',
    this.senderId = '',
    this.senderName = '',
    this.errNo = '',
    this.errMsg = '',
    this.currentTime = '',
    this.globalMsgId,
    this.msgId,
    this.locationMsgId,
    this.conversationRoundId,
    this.tickNo,
    this.subTickNo,
    this.clientMsgId = '',
    this.broadcast,
  });

  final String type;
  final int? schemaVersion;
  final String eventId;
  final int? ts;
  final Map<String, dynamic> payload;
  final String worldId;
  final String sessionId;
  final String locationId;
  final String userId;
  final String senderId;
  final String senderName;
  final String errNo;
  final String errMsg;
  final String currentTime;
  final int? globalMsgId;
  final int? msgId;
  final int? locationMsgId;
  final int? conversationRoundId;
  final int? tickNo;
  final int? subTickNo;
  final String clientMsgId;
  final bool? broadcast;

  factory ChatroomEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatroomEnvelope(
      type: asString(json['type']),
      schemaVersion: json['schema_version'] == null
          ? null
          : asInt(json['schema_version']),
      eventId: asString(json['event_id']),
      ts: json['ts'] == null ? null : asInt(json['ts']),
      payload: _optionalJsonMap(json['payload']),
      worldId: asString(json['world_id']),
      sessionId: asString(json['session_id']),
      locationId: asString(json['location_id']),
      userId: asString(json['user_id']),
      senderId: asString(json['sender_id']),
      senderName: asString(json['sender_name']),
      errNo: asString(json['err_no']),
      errMsg: asString(json['err_msg']),
      currentTime: _currentTime(json),
      globalMsgId: json['global_msg_id'] == null
          ? null
          : asInt(json['global_msg_id']),
      msgId: json['msg_id'] == null ? null : asInt(json['msg_id']),
      locationMsgId: json['location_msg_id'] == null
          ? null
          : asInt(json['location_msg_id']),
      conversationRoundId: json['conversation_round_id'] == null
          ? null
          : asInt(json['conversation_round_id']),
      tickNo: json['tick_no'] == null ? null : asInt(json['tick_no']),
      subTickNo: json['sub_tick_no'] == null
          ? null
          : asInt(json['sub_tick_no']),
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
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (eventId.isNotEmpty) 'event_id': eventId,
      'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
      if (worldId.isNotEmpty) 'world_id': worldId,
      if (locationId.isNotEmpty) 'location_id': locationId,
      if (tickNo != null) 'tick_no': tickNo,
      if (subTickNo != null) 'sub_tick_no': subTickNo,
      if (payload.isNotEmpty) 'payload': payload,
    };
    return jsonEncode(json);
  }

  Map<String, dynamic> get mergedPayload {
    final merged = <String, dynamic>{...payload};

    if (schemaVersion != null) merged['schema_version'] = schemaVersion;
    if (eventId.isNotEmpty) merged['event_id'] = eventId;
    if (ts != null) merged['ts'] = ts;
    if (worldId.isNotEmpty) merged['world_id'] = worldId;
    if (sessionId.isNotEmpty) merged['session_id'] = sessionId;
    if (locationId.isNotEmpty) merged['location_id'] = locationId;
    if (userId.isNotEmpty) merged['user_id'] = userId;
    if (senderId.isNotEmpty) merged['sender_id'] = senderId;
    if (senderName.isNotEmpty) merged['sender_name'] = senderName;
    if (errNo.isNotEmpty) merged['err_no'] = errNo;
    if (errMsg.isNotEmpty) merged['err_msg'] = errMsg;
    if (currentTime.isNotEmpty) merged['current_time'] = currentTime;
    if (globalMsgId != null) merged['global_msg_id'] = globalMsgId;
    if (msgId != null) merged['msg_id'] = msgId;
    if (locationMsgId != null) merged['location_msg_id'] = locationMsgId;
    if (conversationRoundId != null) {
      merged['conversation_round_id'] = conversationRoundId;
    }
    if (tickNo != null) merged['tick_no'] = tickNo;
    if (subTickNo != null) merged['sub_tick_no'] = subTickNo;
    if (clientMsgId.isNotEmpty) merged['client_msg_id'] = clientMsgId;
    if (broadcast != null) merged['broadcast'] = broadcast;
    merged.putIfAbsent('err_no', () => '');
    merged.putIfAbsent('err_msg', () => '');
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
    this.detail = '',
    this.clientMsgId = '',
    this.sourceType = '',
    this.requestType = '',
    this.cause,
  });

  final String code;
  final String message;
  final String detail;
  final String clientMsgId;
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
    String clientMsgId = '',
    Object? cause,
  }) {
    final ack = event is ChatroomAck ? event : null;
    return ChatroomFailureEvent(
      code: event.code.toString(),
      message: event.codeMsg.isEmpty ? 'Something went wrong' : event.codeMsg,
      detail: ack?.errorDetail ?? '',
      clientMsgId: clientMsgId.isNotEmpty
          ? clientMsgId
          : (ack?.clientMsgId ?? ''),
      sourceType: sourceType.isEmpty ? chatroomEventType(event) : sourceType,
      requestType: requestType,
      cause: cause ?? event,
    );
  }

  ChatroomFailureEvent withRequestType(String value) {
    return ChatroomFailureEvent(
      code: code,
      message: message,
      detail: detail,
      clientMsgId: clientMsgId,
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
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.clientMsgId,
    this.errorDetail = '',
  });

  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final String clientMsgId;
  final String errorDetail;

  factory ChatroomAck.fromPayload(Map<String, dynamic> payload) {
    return ChatroomAck(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: _wsCode(payload),
      codeMsg: asString(payload['err_msg']),
      ts: asDateTime(payload['ts']),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      clientMsgId: asString(payload['client_msg_id']),
      errorDetail: asString(payload['err_detail']),
    );
  }
}

class ChatroomBalanceLow extends ChatroomEvent {
  const ChatroomBalanceLow({required this.balance, required this.message});

  final int balance;
  final String message;

  factory ChatroomBalanceLow.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomBalanceLow(
      balance: asInt(payload['balance']),
      message: asString(payload['message']),
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
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.messageType = chatroomTextMessageType,
    required this.broadcast,
  });

  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType;
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
    super.globalMessageId,
    required super.messageId,
    super.locationMessageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.messageType,
    required super.broadcast,
    required this.currentTime,
    required this.clientMsgId,
    required this.createdAt,
  });

  final String currentTime;
  final String clientMsgId;
  final DateTime? createdAt;

  factory ChatroomUserMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomUserMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: _wsCode(payload),
      codeMsg: asString(payload['err_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: 0,
      senderType: asString(payload['sender_type'], fallback: 'user'),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name']),
      content: asString(payload['content']),
      currentTime: _currentTime(payload),
      broadcast: asBool(payload['broadcast']),
      clientMsgId: asString(payload['client_msg_id']),
      createdAt: asDateTime(payload['ts'] ?? envelope.ts),
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
    super.globalMessageId,
    required super.messageId,
    super.locationMessageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.messageType,
    required super.broadcast,
    required this.currentTime,
    required this.createdAt,
  });

  final String currentTime;
  final DateTime? createdAt;

  factory ChatroomNarratorMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    final senderId = asString(payload['sender_id']);
    return ChatroomNarratorMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: _wsCode(payload),
      codeMsg: asString(payload['err_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: 0,
      senderType: asString(payload['sender_type'], fallback: 'narrator'),
      senderId: senderId,
      senderName: asString(payload['sender_name'], fallback: 'Narrator'),
      content: asString(payload['content']),
      messageType: resolveIncomingChatroomMessageType(
        hasMessageTypeField: payload.containsKey('message_type'),
        rawMessageType: payload['message_type'],
        senderId: senderId,
      ),
      currentTime: _currentTime(payload),
      broadcast: asBool(payload['broadcast']),
      createdAt: asDateTime(payload['ts'] ?? envelope.ts),
    );
  }
}

class ChatroomTickAdvanceMessage extends ChatroomMessageEvent {
  const ChatroomTickAdvanceMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    super.globalMessageId,
    required super.messageId,
    super.locationMessageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.messageType,
    required super.broadcast,
    required this.tickNo,
    required this.subTickNo,
    required this.currentTime,
  });

  final int tickNo;
  final int subTickNo;
  final String currentTime;

  factory ChatroomTickAdvanceMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    final currentTime = _currentTime(payload);
    return ChatroomTickAdvanceMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: asString(payload['location_id']),
      userId: asString(payload['user_id']),
      code: _wsCode(payload),
      codeMsg: asString(payload['err_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: 0,
      senderType: 'tick',
      senderId: 'tick',
      senderName: 'Time',
      content: asString(payload['content'], fallback: currentTime),
      broadcast: asBool(payload['broadcast']),
      tickNo: asInt(payload['tick_no']),
      subTickNo: asInt(payload['sub_tick_no']),
      currentTime: currentTime,
    );
  }
}

class ChatroomAiStreamStart extends ChatroomEvent {
  const ChatroomAiStreamStart({
    required this.sessionId,
    required this.locationId,
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.currentTime,
  });

  final String sessionId;
  final String locationId;
  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;
  final String currentTime;

  factory ChatroomAiStreamStart.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    final roundId = asString(payload['conversation_round_id']);
    return ChatroomAiStreamStart(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: roundId,
      roundOrder: 0,
      senderType: asString(payload['sender_type'], fallback: 'character'),
      senderId: asString(payload['sender_id']),
      senderName: asString(payload['sender_name'], fallback: 'AI'),
      currentTime: _currentTime(payload),
    );
  }
}

class ChatroomAiStreamChunk extends ChatroomEvent {
  const ChatroomAiStreamChunk({
    required this.sessionId,
    required this.locationId,
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.senderId,
    required this.seq,
    required this.chunk,
    required this.isDelta,
    required this.currentTime,
  });

  final String sessionId;
  final String locationId;
  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final String senderId;
  final int seq;
  final String chunk;
  final bool isDelta;
  final String currentTime;

  factory ChatroomAiStreamChunk.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomAiStreamChunk(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      seq: asInt(payload['seq']),
      chunk: asString(payload['content']),
      isDelta: true,
      currentTime: _currentTime(payload),
    );
  }
}

class ChatroomAiStreamEnd extends ChatroomEvent {
  const ChatroomAiStreamEnd({
    required this.sessionId,
    required this.locationId,
    this.globalMessageId = 0,
    required this.messageId,
    this.locationMessageId = 0,
    required this.conversationRoundId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.currentTime,
  });

  final String sessionId;
  final String locationId;
  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final String senderId;
  final String content;
  final DateTime? createdAt;
  final String currentTime;

  factory ChatroomAiStreamEnd.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomAiStreamEnd(
      sessionId: asString(payload['session_id']),
      locationId: asString(payload['location_id']),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: asInt(payload['msg_id']),
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      senderId: asString(payload['sender_id']),
      content: asString(payload['content']),
      createdAt: asDateTime(payload['ts'] ?? envelope.ts),
      currentTime: _currentTime(payload),
    );
  }
}

class ChatroomWorldNotification extends ChatroomEvent {
  const ChatroomWorldNotification({
    required this.worldId,
    required this.locationId,
    required this.eventType,
    this.schemaVersion,
    this.eventId = '',
    required this.title,
    required this.summary,
    required this.detailUrl,
    required this.ts,
    required this.broadcast,
    this.currentTime = '',
    this.timelinePayload,
  });

  final String worldId;
  final String locationId;
  final String eventType;
  final int? schemaVersion;
  final String eventId;
  final String title;
  final String summary;
  final String detailUrl;
  final DateTime? ts;
  final bool broadcast;
  final String currentTime;
  final ChatroomTimelinePayload? timelinePayload;

  factory ChatroomWorldNotification.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    ChatroomTimelinePayload? timelinePayload;
    if (isChatroomTimelinePayloadSenderType(envelope.type)) {
      try {
        timelinePayload = decodeChatroomTimelinePayload(
          senderType: envelope.type,
          rawPayload: envelope.payload,
        );
      } catch (error) {
        throw ChatroomProtocolException(
          'Invalid ${envelope.type} payload',
          error: error,
        );
      }
    }
    return ChatroomWorldNotification(
      worldId: asString(payload['world_id'], fallback: envelope.worldId),
      locationId: asString(payload['location_id']),
      eventType: asString(payload['event_type'], fallback: envelope.type),
      schemaVersion: envelope.schemaVersion,
      eventId: envelope.eventId,
      title: asString(payload['title']),
      summary: asString(payload['summary']),
      detailUrl: asString(payload['detail_url']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      broadcast: asBool(payload['broadcast']),
      currentTime: _currentTime(payload),
      timelinePayload: timelinePayload,
    );
  }
}

class ChatroomStoryEventsMessage extends ChatroomMessageEvent {
  const ChatroomStoryEventsMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    super.globalMessageId,
    required super.messageId,
    super.locationMessageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.messageType,
    required super.broadcast,
    required this.schemaVersion,
    required this.eventId,
    required this.tickNo,
    required this.subTickNo,
    required this.currentTime,
    required this.createdAt,
    required this.timelinePayload,
  });

  final int? schemaVersion;
  final String eventId;
  final int tickNo;
  final int subTickNo;
  final String currentTime;
  final DateTime? createdAt;
  final ChatroomStoryEventsPayload timelinePayload;

  factory ChatroomStoryEventsMessage.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    final messageId = asInt(payload['msg_id']);
    if (messageId <= 0) {
      throw const ChatroomProtocolException(
        'story_events msg_id must be a positive integer',
      );
    }
    late final ChatroomStoryEventsPayload timelinePayload;
    try {
      final decoded = decodeChatroomTimelinePayload(
        senderType: chatroomStoryEventsSenderType,
        rawPayload: envelope.payload,
      );
      if (decoded is! ChatroomStoryEventsPayload) {
        throw const FormatException('story_events payload type mismatch');
      }
      timelinePayload = decoded;
    } catch (error) {
      throw ChatroomProtocolException(
        'Invalid story_events payload',
        error: error,
      );
    }
    final senderId = asString(payload['sender_id'], fallback: 'sub_tick');
    return ChatroomStoryEventsMessage(
      sessionId: asString(payload['session_id']),
      worldId: _worldId(payload),
      locationId: timelinePayload.locationId,
      userId: asString(payload['user_id']),
      code: _wsCode(payload),
      codeMsg: asString(payload['err_msg']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      globalMessageId: asInt(payload['global_msg_id']),
      messageId: messageId,
      locationMessageId: asInt(payload['location_msg_id']),
      conversationRoundId: asString(payload['conversation_round_id']),
      roundOrder: asInt(payload['round_order']),
      senderType: chatroomStoryEventsSenderType,
      senderId: senderId,
      senderName: asString(payload['sender_name'], fallback: senderId),
      content: encodeChatroomTimelinePayload(timelinePayload),
      broadcast: asBool(payload['broadcast']),
      schemaVersion: envelope.schemaVersion,
      eventId: envelope.eventId,
      tickNo: asInt(payload['tick_no']),
      subTickNo: asInt(payload['sub_tick_no']),
      currentTime: _currentTime(payload),
      createdAt: asDateTime(payload['ts'] ?? envelope.ts),
      timelinePayload: timelinePayload,
    );
  }
}

class ChatroomCharactersMovedMessage extends ChatroomMessageEvent {
  const ChatroomCharactersMovedMessage({
    required super.sessionId,
    required super.worldId,
    required super.locationId,
    required super.userId,
    required super.code,
    required super.codeMsg,
    required super.ts,
    super.globalMessageId,
    required super.messageId,
    super.locationMessageId,
    required super.conversationRoundId,
    required super.roundOrder,
    required super.senderType,
    required super.senderId,
    required super.senderName,
    required super.content,
    super.messageType,
    required super.broadcast,
    required this.schemaVersion,
    required this.eventId,
    required this.tickNo,
    required this.subTickNo,
    required this.currentTime,
    required this.createdAt,
    required this.timelinePayload,
  });

  final int? schemaVersion;
  final String eventId;
  final int tickNo;
  final int subTickNo;
  final String currentTime;
  final DateTime? createdAt;
  final ChatroomCharactersMovedPayload timelinePayload;

  factory ChatroomCharactersMovedMessage.fromEnvelope(
    ChatroomEnvelope envelope,
  ) {
    final payload = envelope.mergedPayload;
    final messageId = envelope.msgId ?? 0;
    if (messageId <= 0) {
      throw const ChatroomProtocolException(
        'characters_moved msg_id must be a positive integer',
      );
    }
    final locationId = envelope.locationId.trim();
    late final ChatroomCharactersMovedPayload timelinePayload;
    try {
      final decoded = decodeChatroomTimelinePayload(
        senderType: chatroomCharactersMovedSenderType,
        rawPayload: envelope.payload,
      );
      if (decoded is! ChatroomCharactersMovedPayload) {
        throw const FormatException('characters_moved payload type mismatch');
      }
      timelinePayload = decoded;
    } catch (error) {
      throw ChatroomProtocolException(
        'Invalid characters_moved payload',
        error: error,
      );
    }
    final senderId = envelope.senderId.trim().isEmpty
        ? 'sub_tick'
        : envelope.senderId;
    return ChatroomCharactersMovedMessage(
      sessionId: envelope.sessionId,
      worldId: envelope.worldId,
      locationId: locationId,
      userId: envelope.userId,
      code: _wsCode(payload),
      codeMsg: envelope.errMsg,
      ts: asDateTime(envelope.ts),
      globalMessageId: envelope.globalMsgId ?? 0,
      messageId: messageId,
      locationMessageId: envelope.locationMsgId ?? 0,
      conversationRoundId: asString(envelope.conversationRoundId),
      roundOrder: asInt(payload['round_order']),
      senderType: chatroomCharactersMovedSenderType,
      senderId: senderId,
      senderName: envelope.senderName.trim().isEmpty
          ? senderId
          : envelope.senderName,
      content: encodeChatroomTimelinePayload(timelinePayload),
      broadcast: envelope.broadcast ?? false,
      schemaVersion: envelope.schemaVersion,
      eventId: envelope.eventId,
      tickNo: envelope.tickNo ?? 0,
      subTickNo: envelope.subTickNo ?? 0,
      currentTime: envelope.currentTime,
      createdAt: asDateTime(envelope.ts),
      timelinePayload: timelinePayload,
    );
  }
}

class ChatroomNewUserJoinEvent extends ChatroomEvent {
  const ChatroomNewUserJoinEvent({
    required this.worldId,
    required this.characterId,
    required this.characterType,
    required this.characterName,
    required this.playerUid,
    required this.playerUsername,
    required this.ts,
    this.currentTime = '',
  });

  final String worldId;
  final String characterId;
  final String characterType;
  final String characterName;
  final String playerUid;
  final String playerUsername;
  final DateTime? ts;
  final String currentTime;

  factory ChatroomNewUserJoinEvent.fromEnvelope(ChatroomEnvelope envelope) {
    final payload = envelope.mergedPayload;
    return ChatroomNewUserJoinEvent(
      worldId: asString(payload['world_id'], fallback: envelope.worldId),
      characterId: asString(payload['char_id']),
      characterType: asString(payload['type']),
      characterName: asString(payload['name']),
      playerUid: asString(payload['player_uid']),
      playerUsername: asString(payload['player_username']),
      ts: asDateTime(payload['ts'] ?? envelope.ts),
      currentTime: _currentTime(payload),
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
      code: asString(payload['err_no'], fallback: 'error'),
      message: asString(payload['err_msg']),
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
    this.onBalanceLow,
    this.onWorldNotification,
    this.onStoryEventsMessage,
    this.onCharactersMovedMessage,
    this.onUserMessage,
    this.onNarratorMessage,
    this.onTickAdvanceMessage,
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
  final void Function(ChatroomBalanceLow event)? onBalanceLow;
  final void Function(ChatroomWorldNotification event)? onWorldNotification;
  final void Function(ChatroomStoryEventsMessage event)? onStoryEventsMessage;
  final void Function(ChatroomCharactersMovedMessage event)?
  onCharactersMovedMessage;
  final void Function(ChatroomUserMessage event)? onUserMessage;
  final void Function(ChatroomNarratorMessage event)? onNarratorMessage;
  final void Function(ChatroomTickAdvanceMessage event)? onTickAdvanceMessage;
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
      case ChatroomBalanceLow e:
        onBalanceLow?.call(e);
      case ChatroomWorldNotification e:
        onWorldNotification?.call(e);
      case ChatroomStoryEventsMessage e:
        onStoryEventsMessage?.call(e);
      case ChatroomCharactersMovedMessage e:
        onCharactersMovedMessage?.call(e);
      case ChatroomNewUserJoinEvent():
        break;
      case ChatroomUserMessage e:
        onUserMessage?.call(e);
      case ChatroomNarratorMessage e:
        onNarratorMessage?.call(e);
      case ChatroomTickAdvanceMessage e:
        onTickAdvanceMessage?.call(e);
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
    case 'balance_low':
      return ChatroomBalanceLow.fromEnvelope(envelope);
    case 'tick_start':
    case 'tick_done':
    case 'world_change':
    case 'user_location_change':
    case 'world_new_message':
    case 'user_enter_location':
    case 'map_updated':
    case 'character_updated':
      return ChatroomWorldNotification.fromEnvelope(envelope);
    case 'story_events':
      return ChatroomStoryEventsMessage.fromEnvelope(envelope);
    case 'characters_moved':
      return (envelope.msgId ?? 0) > 0
          ? ChatroomCharactersMovedMessage.fromEnvelope(envelope)
          : ChatroomWorldNotification.fromEnvelope(envelope);
    case 'new_user_join':
      return ChatroomNewUserJoinEvent.fromEnvelope(envelope);
    case 'tick_advance':
      return ChatroomTickAdvanceMessage.fromEnvelope(envelope);
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
    case ChatroomBalanceLow():
      return 'balance_low';
    case ChatroomWorldNotification e:
      return e.eventType;
    case ChatroomStoryEventsMessage():
      return 'story_events';
    case ChatroomCharactersMovedMessage():
      return 'characters_moved';
    case ChatroomNewUserJoinEvent():
      return 'new_user_join';
    case ChatroomUserMessage():
      return 'user_message';
    case ChatroomNarratorMessage():
      return 'nar_new_message';
    case ChatroomTickAdvanceMessage():
      return 'tick_advance';
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

String _currentTime(Map<String, dynamic> payload) {
  return _findCurrentTime(payload);
}

String _findCurrentTime(Object? value) {
  if (value is Map) {
    final snakeCase = asString(value['current_time']);
    if (snakeCase.trim().isNotEmpty) return snakeCase;
    final camelCase = asString(value['currentTime']);
    if (camelCase.trim().isNotEmpty) return camelCase;
    for (final child in value.values) {
      final currentTime = _findCurrentTime(child);
      if (currentTime.trim().isNotEmpty) return currentTime;
    }
  } else if (value is Iterable) {
    for (final child in value) {
      final currentTime = _findCurrentTime(child);
      if (currentTime.trim().isNotEmpty) return currentTime;
    }
  }
  return '';
}

int _wsCode(Map<String, dynamic> payload) {
  final raw = payload['err_no'];
  if (raw == null || asString(raw).isEmpty) return 0;
  return asInt(raw);
}
