import 'package:flutter/foundation.dart';

import '../json_utils.dart';

@immutable
class WorldMessage {
  const WorldMessage({
    required this.id,
    required this.worldId,
    required this.locationId,
    required this.uid,
    required this.content,
    required this.messageType,
    required this.createdAt,
  });

  final String id;
  final String worldId;
  final String locationId;
  final String uid;
  final String content;
  final String messageType;
  final DateTime? createdAt;

  factory WorldMessage.fromJson(Map<String, dynamic> json) {
    return WorldMessage(
      id: asString(json['id']),
      worldId: asString(json['world_id']),
      locationId: asString(json['location_id']),
      uid: asString(json['uid']),
      content: asString(json['content']),
      messageType: asString(json['message_type']),
      createdAt: asDateTime(json['created_at']),
    );
  }
}
