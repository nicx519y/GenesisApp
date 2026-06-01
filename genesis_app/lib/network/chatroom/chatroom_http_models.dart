import '../json_utils.dart';

class ChatroomHttpMessage {
  const ChatroomHttpMessage({
    required this.messageId,
    required this.locationId,
    required this.conversationRoundId,
    required this.roundOrder,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final int messageId;
  final String locationId;
  final int conversationRoundId;
  final int roundOrder;
  final String senderType;
  final String senderId;
  final String senderName;
  final String userId;
  final String content;
  final DateTime? createdAt;

  factory ChatroomHttpMessage.fromJson(Map<String, dynamic> json) {
    return ChatroomHttpMessage(
      messageId: asInt(json['message_id']),
      locationId: asString(json['location_id']),
      conversationRoundId: asInt(json['conversation_round_id']),
      roundOrder: asInt(json['round_order']),
      senderType: asString(json['sender_type']),
      senderId: asString(json['sender_id']),
      senderName: asString(json['sender_name']),
      userId: asString(json['user_id']),
      content: asString(json['content']),
      createdAt: asDateTime(json['created_at']),
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
    return ChatroomMessageListResponse(
      messages: rawMessages
          .map((item) => ChatroomHttpMessage.fromJson(asJsonMap(item)))
          .toList(growable: false),
      hasMore: asBool(json['has_more']),
      newestMessageId: asInt(json['newest_message_id']),
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
