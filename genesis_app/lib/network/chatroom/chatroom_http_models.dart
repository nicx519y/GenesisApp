import '../json_utils.dart';

class ChatroomHttpMessage {
  const ChatroomHttpMessage({
    required this.messageId,
    required this.locationId,
    required this.conversationRoundId,
    required this.roundOrder,
    this.tickNo = 0,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.userId,
    this.clientMsgId = '',
    required this.content,
    this.currentTime = '',
    required this.createdAt,
  });

  final int messageId;
  final String locationId;
  final int conversationRoundId;
  final int roundOrder;
  final int tickNo;
  final String senderType;
  final String senderId;
  final String senderName;
  final String userId;
  final String clientMsgId;
  final String content;
  final String currentTime;
  final DateTime? createdAt;

  factory ChatroomHttpMessage.fromJson(Map<String, dynamic> json) {
    return ChatroomHttpMessage(
      messageId: asInt(json['msg_id'], fallback: asInt(json['message_id'])),
      locationId: asString(json['location_id']),
      conversationRoundId: asInt(json['conversation_round_id']),
      roundOrder: asInt(json['round_order']),
      tickNo: asInt(json['tick_no']),
      senderType: asString(json['sender_type']),
      senderId: asString(json['sender_id']),
      senderName: asString(json['sender_name']),
      userId: asString(json['user_id']),
      clientMsgId: asString(json['client_msg_id']),
      content: asString(json['content']),
      currentTime: asString(json['current_time']),
      createdAt: asDateTime(json['ts']) ?? asDateTime(json['created_at']),
    );
  }
}

class ChatroomLocationCharacter {
  const ChatroomLocationCharacter({
    required this.charId,
    required this.playerUid,
    required this.playerUsername,
    required this.name,
    required this.locationId,
  });

  final String charId;
  final String playerUid;
  final String playerUsername;
  final String name;
  final String locationId;

  bool get isPlayer => playerUid.trim().isNotEmpty;

  factory ChatroomLocationCharacter.fromJson(Map<String, dynamic> json) {
    return ChatroomLocationCharacter(
      charId: asString(json['char_id']),
      playerUid: asString(json['player_uid']),
      playerUsername: asString(json['player_username']),
      name: asString(json['name']),
      locationId: asString(json['location_id']),
    );
  }
}

class ChatroomCharacterLocationGroup {
  const ChatroomCharacterLocationGroup({
    required this.locationId,
    required this.characters,
  });

  final String locationId;
  final List<ChatroomLocationCharacter> characters;

  factory ChatroomCharacterLocationGroup.fromJson(Map<String, dynamic> json) {
    final rawCharacters = json['characters'] is List
        ? asJsonList(json['characters'])
        : const [];
    return ChatroomCharacterLocationGroup(
      locationId: asString(json['location_id']),
      characters: rawCharacters
          .map((item) => ChatroomLocationCharacter.fromJson(asJsonMap(item)))
          .toList(growable: false),
    );
  }
}

class ChatroomUserLocationsResponse {
  const ChatroomUserLocationsResponse({
    required this.worldId,
    required this.locations,
  });

  final String worldId;
  final List<ChatroomCharacterLocationGroup> locations;

  factory ChatroomUserLocationsResponse.fromJson(Map<String, dynamic> json) {
    final rawLocations = json['locations'] is List
        ? asJsonList(json['locations'])
        : const [];
    return ChatroomUserLocationsResponse(
      worldId: asString(json['world_id']),
      locations: rawLocations
          .map(
            (item) => ChatroomCharacterLocationGroup.fromJson(asJsonMap(item)),
          )
          .toList(growable: false),
    );
  }
}

class ChatroomLocationMessages {
  const ChatroomLocationMessages({
    required this.locationId,
    required this.messages,
  });

  final String locationId;
  final List<ChatroomHttpMessage> messages;

  factory ChatroomLocationMessages.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] is List
        ? asJsonList(json['messages'])
        : const [];
    return ChatroomLocationMessages(
      locationId: asString(json['location_id']),
      messages: rawMessages
          .map((item) => ChatroomHttpMessage.fromJson(asJsonMap(item)))
          .toList(growable: false),
    );
  }
}

class ChatroomWorldMessagesResponse {
  const ChatroomWorldMessagesResponse({required this.locations});

  final List<ChatroomLocationMessages> locations;

  factory ChatroomWorldMessagesResponse.fromJson(Map<String, dynamic> json) {
    final rawLocations = json['locations'] is List
        ? asJsonList(json['locations'])
        : const [];
    return ChatroomWorldMessagesResponse(
      locations: rawLocations
          .map((item) => ChatroomLocationMessages.fromJson(asJsonMap(item)))
          .toList(growable: false),
    );
  }
}

class ChatroomMessageListResponse {
  const ChatroomMessageListResponse({
    required this.messages,
    required this.hasMore,
    required this.newestMessageId,
  });

  final List<ChatroomHttpMessage> messages;
  final bool hasMore;
  final int newestMessageId;

  factory ChatroomMessageListResponse.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] is List
        ? asJsonList(json['messages'])
        : const [];
    final messages = rawMessages
        .map((item) => ChatroomHttpMessage.fromJson(asJsonMap(item)))
        .toList(growable: false);
    return ChatroomMessageListResponse(
      messages: messages,
      hasMore: asBool(json['has_more']),
      newestMessageId: asInt(
        json['newest_message_id'],
        fallback: messages.fold<int>(
          0,
          (previous, message) =>
              message.messageId > previous ? message.messageId : previous,
        ),
      ),
    );
  }
}

class ChatroomTickProgress {
  const ChatroomTickProgress({
    required this.progress,
    required this.pendingMessages,
    required this.activeLlmCalls,
  });

  final int progress;
  final int pendingMessages;
  final int activeLlmCalls;

  factory ChatroomTickProgress.fromJson(Map<String, dynamic> json) {
    return ChatroomTickProgress(
      progress: asInt(json['progress']),
      pendingMessages: asInt(json['pending_messages']),
      activeLlmCalls: asInt(json['active_llm_calls']),
    );
  }
}

class ChatroomNarratorLocationGroup {
  const ChatroomNarratorLocationGroup({
    required this.locationId,
    required this.locationName,
    required this.locationSummary,
    required this.characters,
    required this.initialDialogue,
  });

  final String locationId;
  final String locationName;
  final String locationSummary;
  final List<ChatroomNarratorCharacter> characters;
  final List<ChatroomNarratorDialogueLine> initialDialogue;

  Map<String, Object?> toJson() {
    return {
      'location_id': locationId,
      'location_name': locationName,
      'location_summary': locationSummary,
      'characters': characters
          .map((character) => character.toJson())
          .toList(growable: false),
      'initial_dialogue': initialDialogue
          .map((line) => line.toJson())
          .toList(growable: false),
    };
  }
}

class ChatroomNarratorCharacter {
  const ChatroomNarratorCharacter({required this.charId, required this.name});

  final String charId;
  final String name;

  Map<String, Object?> toJson() => {'char_id': charId, 'name': name};
}

class ChatroomNarratorDialogueLine {
  const ChatroomNarratorDialogueLine({
    required this.charId,
    required this.charName,
    required this.content,
  });

  final String charId;
  final String charName;
  final String content;

  Map<String, Object?> toJson() {
    return {'char_id': charId, 'char_name': charName, 'content': content};
  }
}
