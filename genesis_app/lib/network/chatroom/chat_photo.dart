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
  });
  final String requestId, worldId, locationId;
  Map<String, dynamic> toJson() => {
    'client_request_id': requestId,
    'world_id': worldId,
    'location_id': locationId,
  };
  factory ChatPhotoRequest.fromJson(Map<String, dynamic> json) =>
      ChatPhotoRequest(
        requestId: json['client_request_id'] as String,
        worldId: json['world_id'] as String,
        locationId: json['location_id'] as String,
      );
}

class ChatPhotoReceipt {
  ChatPhotoReceipt.fromJson(Map<String, dynamic> json)
    : worldId = json['world_id'] as String,
      locationId = json['location_id'] as String,
      roundId = chatPhotoId(json['conversation_round_id']),
      globalMessageId = chatPhotoId(json['global_message_id']),
      messageId = chatPhotoId(json['message_id']),
      locationMessageId = chatPhotoId(json['location_message_id']),
      photo = ChatPhoto.fromJson(json['photo']) {
    if (json['source'] != 'chat' || worldId.isEmpty || locationId.isEmpty) {
      throw const FormatException('Invalid chat photo receipt');
    }
  }
  final String worldId, locationId;
  final int roundId, globalMessageId, messageId, locationMessageId;
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
    'message_id': messageId,
    'location_message_id': locationMessageId,
    'payload': {'content': photo.imageUrl, 'photo': photo.toJson()},
  };
}

class ChatPhotoTarget {
  const ChatPhotoTarget({
    required this.locationId,
    required this.roundId,
    required this.globalMessageId,
  });
  final String locationId;
  final int roundId, globalMessageId;
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
      );
    } on FormatException {
      return null;
    }
  }
}
