import '../../network/chatroom/world_chatroom_service.dart';

String latestChatLocationIdFromMessages({
  required bool allLocationsLoaded,
  required Map<String, List<WorldChatroomMessage>> messagesByLocation,
  required Iterable<String> allowedLocationIds,
}) {
  if (!allLocationsLoaded) return '';

  DateTime? latestTime;
  var latestGlobalMessageId = 0;
  var latestMessageId = 0;
  var latestLocationId = '';

  for (final rawLocationId in allowedLocationIds) {
    final locationId = rawLocationId.trim();
    if (locationId.isEmpty) continue;
    final messages =
        messagesByLocation[locationId] ?? const <WorldChatroomMessage>[];
    for (final message in messages) {
      final createdAt = message.createdAt;
      if (createdAt == null || !_countsAsChatMessage(message)) continue;
      if (!_isNewerMessage(
        createdAt: createdAt,
        globalMessageId: message.globalMessageId,
        messageId: message.messageId,
        latestTime: latestTime,
        latestGlobalMessageId: latestGlobalMessageId,
        latestMessageId: latestMessageId,
      )) {
        continue;
      }
      latestTime = createdAt;
      latestGlobalMessageId = message.globalMessageId;
      latestMessageId = message.messageId;
      latestLocationId = locationId;
    }
  }

  return latestLocationId;
}

bool _countsAsChatMessage(WorldChatroomMessage message) {
  final senderType = message.senderType.trim().toLowerCase();
  return senderType != 'tick' && senderType != 'system';
}

bool _isNewerMessage({
  required DateTime createdAt,
  required int globalMessageId,
  required int messageId,
  required DateTime? latestTime,
  required int latestGlobalMessageId,
  required int latestMessageId,
}) {
  if (latestTime == null || createdAt.isAfter(latestTime)) return true;
  if (createdAt.isBefore(latestTime)) return false;
  if (globalMessageId != latestGlobalMessageId) {
    return globalMessageId > latestGlobalMessageId;
  }
  return messageId > latestMessageId;
}
