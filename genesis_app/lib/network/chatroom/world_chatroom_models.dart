part of 'world_chatroom_service.dart';

class WorldChatroomState {
  const WorldChatroomState({
    this.world,
    this.locationTree = const <LocationTreeNode<Map<String, dynamic>>>[],
    this.processedLocationTree,
    this.entitiesById = const <String, WorldChatroomEntity>{},
    this.entitiesByLocation = const <String, List<WorldChatroomEntity>>{},
    this.worldMessages = const <WorldChatroomMessage>[],
    this.messagesByLocation = const <String, List<WorldChatroomMessage>>{},
    this.streamMessagesByKey = const <String, WorldChatroomMessage>{},
    this.lastMessageId = 0,
    this.connected = false,
    this.joining = false,
    this.joinedLocationId = '',
    this.inputBlocked = false,
    this.reconnecting = false,
    this.latestSocketCurrentTime = '',
    this.latestSocketTickNo = 0,
    this.latestSocketCurrentTimeRevision = 0,
    this.latestNewUserJoin,
    this.latestNewUserJoinRevision = 0,
    this.lastFailure,
  });

  final WorldDetail? world;
  final List<LocationTreeNode<Map<String, dynamic>>> locationTree;
  final ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree;
  final Map<String, WorldChatroomEntity> entitiesById;
  final Map<String, List<WorldChatroomEntity>> entitiesByLocation;
  final List<WorldChatroomMessage> worldMessages;
  final Map<String, List<WorldChatroomMessage>> messagesByLocation;
  final Map<String, WorldChatroomMessage> streamMessagesByKey;
  final int lastMessageId;
  final bool connected;
  final bool joining;
  final String joinedLocationId;
  final bool inputBlocked;
  final bool reconnecting;
  final String latestSocketCurrentTime;
  final int latestSocketTickNo;
  final int latestSocketCurrentTimeRevision;
  final ChatroomNewUserJoinEvent? latestNewUserJoin;
  final int latestNewUserJoinRevision;
  final ChatroomFailureEvent? lastFailure;

  WorldChatroomState copyWith({
    WorldDetail? world,
    List<LocationTreeNode<Map<String, dynamic>>>? locationTree,
    ProcessedLocationTree<Map<String, dynamic>>? processedLocationTree,
    Map<String, WorldChatroomEntity>? entitiesById,
    Map<String, List<WorldChatroomEntity>>? entitiesByLocation,
    List<WorldChatroomMessage>? worldMessages,
    Map<String, List<WorldChatroomMessage>>? messagesByLocation,
    Map<String, WorldChatroomMessage>? streamMessagesByKey,
    int? lastMessageId,
    bool? connected,
    bool? joining,
    String? joinedLocationId,
    bool? inputBlocked,
    bool? reconnecting,
    String? latestSocketCurrentTime,
    int? latestSocketTickNo,
    int? latestSocketCurrentTimeRevision,
    ChatroomNewUserJoinEvent? latestNewUserJoin,
    int? latestNewUserJoinRevision,
    ChatroomFailureEvent? lastFailure,
  }) {
    return WorldChatroomState(
      world: world ?? this.world,
      locationTree: locationTree ?? this.locationTree,
      processedLocationTree:
          processedLocationTree ?? this.processedLocationTree,
      entitiesById: entitiesById ?? this.entitiesById,
      entitiesByLocation: entitiesByLocation ?? this.entitiesByLocation,
      worldMessages: worldMessages ?? this.worldMessages,
      messagesByLocation: messagesByLocation ?? this.messagesByLocation,
      streamMessagesByKey: streamMessagesByKey ?? this.streamMessagesByKey,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      connected: connected ?? this.connected,
      joining: joining ?? this.joining,
      joinedLocationId: joinedLocationId ?? this.joinedLocationId,
      inputBlocked: inputBlocked ?? this.inputBlocked,
      reconnecting: reconnecting ?? this.reconnecting,
      latestSocketCurrentTime:
          latestSocketCurrentTime ?? this.latestSocketCurrentTime,
      latestSocketTickNo: latestSocketTickNo ?? this.latestSocketTickNo,
      latestSocketCurrentTimeRevision:
          latestSocketCurrentTimeRevision ??
          this.latestSocketCurrentTimeRevision,
      latestNewUserJoin: latestNewUserJoin ?? this.latestNewUserJoin,
      latestNewUserJoinRevision:
          latestNewUserJoinRevision ?? this.latestNewUserJoinRevision,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}

enum WorldChatroomEntityType { character, player }

class WorldChatroomEntity {
  const WorldChatroomEntity({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.type,
    required this.locationId,
    this.isAi = false,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final WorldChatroomEntityType type;
  final String locationId;
  final bool isAi;
}

class WorldChatroomMessage {
  const WorldChatroomMessage({
    this.globalMessageId = 0,
    required this.messageId,
    int? locationMessageId,
    required this.conversationRoundId,
    required this.roundOrder,
    this.tickNo = 0,
    required this.locationId,
    required this.senderType,
    this.userId = '',
    required this.senderId,
    required this.senderName,
    this.clientMsgId = '',
    required this.content,
    this.messageType = chatroomTextMessageType,
    this.currentTime = '',
    required this.createdAt,
    this.streaming = false,
    this.isLlmStreamMessage = false,
  }) : locationMessageId = locationMessageId ?? 0;

  final int globalMessageId;
  final int messageId;
  final int locationMessageId;
  final String conversationRoundId;
  final int roundOrder;
  final int tickNo;
  final String locationId;
  final String senderType;
  final String userId;
  final String senderId;
  final String senderName;
  final String clientMsgId;
  final String content;
  final String messageType;
  final String currentTime;
  final DateTime? createdAt;
  final bool streaming;
  final bool isLlmStreamMessage;

  int get locationQueueMessageId => locationMessageId;

  int get conversationRoundNumber => int.tryParse(conversationRoundId) ?? 0;

  factory WorldChatroomMessage.fromHttpMessage(ChatroomHttpMessage message) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: _safeLocationMessageId(
        () => message.locationMessageId,
      ),
      conversationRoundId: '${message.conversationRoundId}',
      roundOrder: 0,
      tickNo: message.tickNo,
      locationId: message.locationId,
      senderType: message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: '',
      content: message.content,
      messageType: message.messageType,
      currentTime: message.currentTime,
      createdAt: message.createdAt,
    );
  }

  factory WorldChatroomMessage.fromStorageJson(Map<String, dynamic> json) {
    final senderId = asString(json['sender_id']);
    return WorldChatroomMessage(
      globalMessageId: asInt(json['global_msg_id']),
      messageId: asInt(json['msg_id']),
      locationMessageId: asInt(json['location_msg_id']),
      conversationRoundId: asString(
        json['conversation_round_id'],
        fallback: '${asInt(json['conversation_round_id'])}',
      ),
      roundOrder: asInt(json['round_order']),
      tickNo: asInt(json['tick_no']),
      locationId: asString(json['location_id']),
      senderType: asString(json['sender_type']),
      userId: asString(json['user_id']),
      senderId: senderId,
      senderName: asString(json['sender_name']),
      clientMsgId: asString(json['client_msg_id']),
      content: asString(json['content']),
      messageType: resolveIncomingChatroomMessageType(
        hasMessageTypeField: json.containsKey('message_type'),
        rawMessageType: json['message_type'],
        senderId: senderId,
      ),
      currentTime: asString(json['current_time']),
      createdAt: asDateTime(json['ts']),
      isLlmStreamMessage: asBool(json['is_llm_stream']),
    );
  }

  factory WorldChatroomMessage.fromUserMessage(ChatroomUserMessage message) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: _safeLocationMessageId(
        () => message.locationMessageId,
      ),
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType: message.senderType.isEmpty ? 'user' : message.senderType,
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      clientMsgId: message.clientMsgId,
      content: message.content,
      messageType: message.messageType,
      currentTime: message.currentTime,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromNarratorMessage(
    ChatroomNarratorMessage message,
  ) {
    final senderType = message.senderType.trim().toLowerCase();
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: _safeLocationMessageId(
        () => message.locationMessageId,
      ),
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      locationId: message.locationId,
      senderType:
          senderType == 'narrator' && _senderIdIsNarrator(message.senderId)
          ? 'narrator'
          : 'character',
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      messageType: message.messageType,
      currentTime: message.currentTime,
      createdAt: message.createdAt ?? message.ts,
    );
  }

  factory WorldChatroomMessage.fromTickAdvanceMessage(
    ChatroomTickAdvanceMessage message,
  ) {
    return WorldChatroomMessage(
      globalMessageId: message.globalMessageId,
      messageId: message.messageId,
      locationMessageId: _safeLocationMessageId(
        () => message.locationMessageId,
      ),
      conversationRoundId: message.conversationRoundId,
      roundOrder: message.roundOrder,
      tickNo: message.tickNo,
      locationId: message.locationId,
      senderType: 'tick',
      userId: message.userId,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content.isEmpty ? message.currentTime : message.content,
      messageType: message.messageType,
      currentTime: message.currentTime,
      createdAt: message.ts,
    );
  }

  factory WorldChatroomMessage.fromAiStreamStart(ChatroomAiStreamStart event) {
    return WorldChatroomMessage(
      globalMessageId: event.globalMessageId,
      messageId: event.messageId,
      locationMessageId: _safeLocationMessageId(() => event.locationMessageId),
      conversationRoundId: event.conversationRoundId,
      roundOrder: event.roundOrder,
      tickNo: 0,
      locationId: event.locationId,
      senderType: event.senderType,
      userId: '',
      senderId: event.senderId,
      senderName: event.senderName,
      content: '',
      currentTime: event.currentTime,
      createdAt: null,
      streaming: true,
      isLlmStreamMessage: true,
    );
  }

  WorldChatroomMessage copyWith({
    int? globalMessageId,
    int? messageId,
    int? locationMessageId,
    String? conversationRoundId,
    int? roundOrder,
    int? tickNo,
    String? locationId,
    String? senderType,
    String? userId,
    String? senderId,
    String? senderName,
    String? clientMsgId,
    String? content,
    String? messageType,
    String? currentTime,
    DateTime? createdAt,
    bool? streaming,
    bool? isLlmStreamMessage,
  }) {
    return WorldChatroomMessage(
      globalMessageId: globalMessageId ?? this.globalMessageId,
      messageId: messageId ?? this.messageId,
      locationMessageId: locationMessageId ?? this.locationMessageId,
      conversationRoundId: conversationRoundId ?? this.conversationRoundId,
      roundOrder: roundOrder ?? this.roundOrder,
      tickNo: tickNo ?? this.tickNo,
      locationId: locationId ?? this.locationId,
      senderType: senderType ?? this.senderType,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      currentTime: currentTime ?? this.currentTime,
      createdAt: createdAt ?? this.createdAt,
      streaming: streaming ?? this.streaming,
      isLlmStreamMessage: isLlmStreamMessage ?? this.isLlmStreamMessage,
    );
  }
}

int _safeLocationMessageId(int Function() read) {
  try {
    return read();
  } on TypeError {
    return 0;
  }
}

bool _senderIdIsNarrator(String senderId) {
  return const {'nar', 'nar_pic'}.contains(senderId.trim().toLowerCase());
}
