import '../models/photo_task.dart';
export '../models/photo_task.dart';

typedef ChatPhoto = PhotoTask;
typedef ChatPhotoStatus = PhotoTaskStatus;
int chatPhotoId(Object? value) => photoTaskId(value);

class ChatPhotoRequest {
  const ChatPhotoRequest({
    required this.requestId,
    required this.worldId,
    required this.locationId,
    this.roundId,
    this.cardId,
  });
  final int? roundId, cardId;
  final String requestId, worldId, locationId;
  Map<String, dynamic> toJson() => {
    'client_request_id': requestId,
    'world_id': worldId,
    'location_id': locationId,
    if (roundId != null) 'conversation_round_id': '$roundId',
    if (cardId != null) 'card_id': cardId,
  };
  factory ChatPhotoRequest.fromJson(Map<String, dynamic> json) =>
      ChatPhotoRequest(
        requestId: json['client_request_id'] as String,
        worldId: json['world_id'] as String,
        locationId: json['location_id'] as String,
        roundId: json['conversation_round_id'] == null
            ? null
            : chatPhotoId(json['conversation_round_id']),
        cardId: json['card_id'] == null ? null : chatPhotoId(json['card_id']),
      );
}

class ChatPhotoReceipt {
  ChatPhotoReceipt.fromJson(Map<String, dynamic> json)
    : worldId = json['world_id'] as String,
      locationId = json['location_id'] as String,
      roundId = chatPhotoId(json['conversation_round_id']),
      globalMessageId = chatPhotoId(json['global_message_id']),
      cardId = json['card_id'] == null ? null : chatPhotoId(json['card_id']),
      messageId = json['card_id'] != null ? 0 : chatPhotoId(json['message_id']),
      locationMessageId = json['card_id'] != null
          ? 0
          : chatPhotoId(json['location_message_id']),
      photo = ChatPhoto.fromJson(json['photo']) {
    if (json['source'] != 'chat' || worldId.isEmpty || locationId.isEmpty) {
      throw const FormatException('Invalid chat photo receipt');
    }
  }
  final String worldId, locationId;
  final int roundId, globalMessageId, messageId, locationMessageId;
  final int? cardId;
  final ChatPhoto photo;
  Map<String, dynamic> toMessageJson() => {
    'type': 'live_photo',
    'sender_type': 'live_photo',
    'conversation_type': 'live_photo',
    'message_type': 'image',
    'world_id': worldId,
    'location_id': locationId,
    'conversation_round_id': roundId,
    'global_message_id': globalMessageId,
    if (cardId == null) 'message_id': messageId,
    if (cardId == null) 'location_message_id': locationMessageId,
    'payload': {
      if (cardId != null) 'card_id': cardId,
      'content': photo.imageUrl,
      'photo': photo.toJson(),
    },
  };
}

class ChatPhotoTarget {
  const ChatPhotoTarget({
    required this.locationId,
    required this.roundId,
    required this.globalMessageId,
    this.cardId,
  });
  final String locationId;
  final int roundId, globalMessageId;
  final int? cardId;
  static ChatPhotoTarget? tryParse(Object? value) {
    if (value is! Map ||
        value['source'] != 'chat' ||
        value['location_id'] is! String ||
        (value['location_id'] as String).isEmpty) {
      return null;
    }
    try {
      return ChatPhotoTarget(
        locationId: value['location_id'] as String,
        roundId: chatPhotoId(value['conversation_round_id']),
        globalMessageId: chatPhotoId(value['chat_global_message_id']),
        cardId: value['card_id'] == null ? null : chatPhotoId(value['card_id']),
      );
    } on FormatException {
      return null;
    }
  }
}
